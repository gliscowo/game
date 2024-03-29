import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:dartemis/dartemis.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import '../chunk_storage.dart';
import '../context.dart';
import '../game.dart';
import '../obj.dart';
import '../texture.dart';
import '../vertex_descriptors.dart';
import 'transform.dart';

part 'chunk.g.dart';

class ChunkDataComponent extends Component {
  final DiscretePosition pos;
  ChunkDataComponent(this.pos);
}

enum ChunkMeshState { empty, building, ready }

class ChunkMeshComponent extends Component {
  MeshBuffer<TerrainVertexFunction>? buffer;
  ChunkMeshState state = ChunkMeshState.empty;
}

@Generate(
  EntityProcessingSystem,
  allOf: [Position, ChunkDataComponent, ChunkMeshComponent],
)
class ChunkRenderSystem extends _$ChunkRenderSystem {
  static final int cubeTexture = loadTexture("grass", mipmap: true);

  final Frustum _frustum = Frustum();
  final RenderContext _context;
  final List<ChunkCompileWorker> _workers;

  int _workerIndex = 0;
  int _enqueuedChunks = 0;

  ChunkRenderSystem(this._context, this._workers);

  @override
  void process() {
    final program = _context.findProgram("terrain");
    final worldProjection = world.properties["world_projection"] as Matrix4;
    final viewMatrix = world.properties["view_matrix"] as Matrix4;

    program.uniformMat4("uProjection", worldProjection);
    program.uniformMat4("uView", viewMatrix);
    program.uniformSampler("uTexture", cubeTexture, 0);
    program.use();

    _enqueuedChunks = 0;
    _frustum.setFromMatrix(worldProjection * viewMatrix);
    super.process();
  }

  @override
  void processEntity(int entity, Position pos, ChunkDataComponent data, ChunkMeshComponent mesh) {
    final chunkBuffer = mesh.buffer ??= MeshBuffer(terrainVertexDescriptor, _context.findProgram("terrain"));
    final chunkStorage = world.chunks;

    if (mesh.state == ChunkMeshState.empty &&
        _enqueuedChunks < 48 &&
        chunkStorage.statusAt(data.pos) != ChunkStatus.scheduled) {
      _workerIndex = ((_workerIndex + 1) % _workers.length);
      _workers[_workerIndex].enqueueChunk(
        chunkStorage.maskChunkForCompilation(data.pos),
        (buffer) {
          chunkBuffer.clear();
          chunkBuffer.buffer = buffer;

          chunkBuffer.upload();
          mesh.state = ChunkMeshState.ready;
        },
      );

      mesh.state = ChunkMeshState.building;
      _enqueuedChunks++;
    } else if (mesh.state == ChunkMeshState.ready &&
        chunkBuffer.vertexCount > 0 &&
        _frustum.intersectsWithAabb3(
            Aabb3.minMax(data.pos.toVec3()..scale(16), (data.pos.offset(x: 1, y: 1, z: 1)).toVec3()..scale(16)))) {
      chunkBuffer.program.uniform3vf("uOffset", pos.value);
      chunkBuffer.drawAndCount();
    }
  }
}

class ChunkCompileWorker {
  static final cube = loadObj(File("resources/cube.obj"));

  final Queue<void Function(BufferWriter)> _callbacks = Queue();
  final SendPort _commands;
  final ReceivePort _responses;
  final Isolate _isolate;

  ChunkCompileWorker._(this._commands, this._responses, this._isolate) {
    _responses.listen((message) => _handleResponse(message));
  }

  static Future<ChunkCompileWorker> spawn(int id) async {
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (initialMessage) {
      final commandPort = initialMessage as SendPort;
      connection.complete((ReceivePort.fromRawReceivePort(initPort), commandPort));
    };

    final isolate = await Isolate.spawn(_worker, initPort.sendPort, debugName: "chunk-compile-worker-$id");
    final (responses, commands) = await connection.future;

    return ChunkCompileWorker._(commands, responses, isolate);
  }

  void _handleResponse(Object message) {
    if (message is BufferWriter) {
      _callbacks.removeFirst().call(message);
    }
  }

  void enqueueChunk(ChunkStorage storage, void Function(BufferWriter) callback) {
    _commands.send(storage);
    _callbacks.add(callback);
  }

  void shutdown() {
    _isolate.kill(priority: Isolate.immediate);
    _responses.close();
  }

  static void _worker(SendPort responses) {
    initDiamondGL();

    final commands = ReceivePort();
    responses.send(commands.sendPort);

    commands.listen((storage) {
      if (storage is! ChunkStorage) return;
      responses.send(_compileChunk(storage));
    });
  }

  static BufferWriter _compileChunk(ChunkStorage storage) {
    final buffer = BufferWriter();
    final builder = terrainVertexDescriptor.createBuilder(buffer);

    final chunk = storage.chunkAt(DiscretePosition.origin());
    for (var x = 0; x < Chunk.size; x++) {
      for (var y = 0; y < Chunk.size; y++) {
        for (var z = 0; z < Chunk.size; z++) {
          final pos = DiscretePosition(x, y, z);
          if (!chunk.hasBlockAt(pos)) continue;

          for (final Tri(:vertices, :normals, :uvs) in cube.tris) {
            final vtx1 = cube.vertices[vertices.$1 - 1],
                vtx2 = cube.vertices[vertices.$2 - 1],
                vtx3 = cube.vertices[vertices.$3 - 1];

            if (storage.hasBlockAt(pos.offset(x: -1)) && vtx1.x == -.5 && vtx2.x == -.5 && vtx3.x == -.5) {
              continue;
            }

            if (storage.hasBlockAt(pos.offset(x: 1)) && vtx1.x == .5 && vtx2.x == .5 && vtx3.x == .5) {
              continue;
            }

            if (storage.hasBlockAt(pos.offset(z: -1)) && vtx1.z == -.5 && vtx2.z == -.5 && vtx3.z == -.5) {
              continue;
            }

            if (storage.hasBlockAt(pos.offset(z: 1)) && vtx1.z == .5 && vtx2.z == .5 && vtx3.z == .5) {
              continue;
            }

            if (storage.hasBlockAt(pos.offset(y: -1)) && vtx1.y == -.5 && vtx2.y == -.5 && vtx3.y == -.5) {
              continue;
            }

            if (storage.hasBlockAt(pos.offset(y: 1)) && vtx1.y == .5 && vtx2.y == .5 && vtx3.y == .5) {
              continue;
            }

            final offset = Vector3(x.toDouble(), y.toDouble(), z.toDouble());

            builder(
              vtx1 + offset,
              cube.normals[normals.$1 - 1],
              cube.uvs[uvs.$1 - 1].x,
              1 - cube.uvs[uvs.$1 - 1].y,
            );
            builder(
              vtx2 + offset,
              cube.normals[normals.$2 - 1],
              cube.uvs[uvs.$2 - 1].x,
              1 - cube.uvs[uvs.$2 - 1].y,
            );
            builder(
              vtx3 + offset,
              cube.normals[normals.$3 - 1],
              cube.uvs[uvs.$3 - 1].x,
              1 - cube.uvs[uvs.$3 - 1].y,
            );
          }
        }
      }
    }

    return buffer;
  }
}
