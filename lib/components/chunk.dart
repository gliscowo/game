import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:dartemis/dartemis.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import '../chunk_storage.dart';
import '../context.dart';
import '../easing.dart';
import '../game.dart';
import '../math.dart';
import '../obj.dart';
import '../texture.dart';
import '../vertex_descriptors.dart';
import '../worker.dart';
import 'transform.dart';

part 'chunk.g.dart';

class ChunkDataComponent extends Component {
  final DiscretePosition pos;
  ChunkDataComponent(this.pos);
}

enum ChunkMeshState { empty, building, ready }

class ChunkMeshComponent extends Component {
  final double spawnTime;
  MeshBuffer<TerrainVertexFunction>? buffer;
  ChunkMeshState state = ChunkMeshState.empty;

  ChunkMeshComponent(this.spawnTime);
}

class ChunkManager extends Manager {
  final Map<DiscretePosition, int> _chunkEntitiesByPosition = HashMap();
  late final Mapper<ChunkDataComponent> _dataMapper;

  @override
  void initialize() {
    _dataMapper = Mapper(world);
  }

  @override
  void added(int entity) {
    final data = _dataMapper.getSafe(entity);
    if (data == null) return;

    _chunkEntitiesByPosition[data.pos] = entity;
  }

  @override
  void deleted(int entity) {
    final data = _dataMapper.getSafe(entity);
    if (data == null) return;

    _chunkEntitiesByPosition.remove(data.pos);
  }

  int? entityForChunk(DiscretePosition chunkPos) => _chunkEntitiesByPosition[chunkPos];
}

@Generate(
  IntervalEntityProcessingSystem,
  allOf: [Position, ChunkDataComponent, ChunkMeshComponent],
  manager: [ChunkManager, TagManager],
)
class ChunkLoadingSystem extends _$ChunkLoadingSystem {
  final ChunkGenWorkers _generators;

  ChunkLoadingSystem(this._generators) : super(.5);

  @override
  void processEntity(int entity) {
    final pos = chunkDataComponentMapper[entity].pos;
    final cameraPos = positionMapper[tagManager.getEntity('active_camera')!].value;

    const maxHorizontal = 17;
    const maxVertical = 9;
    if ((pos.x - cameraPos.x / 16).abs() < maxHorizontal &&
        (pos.z - cameraPos.z / 16).abs() < maxHorizontal &&
        (pos.y - cameraPos.y / 16).abs() < maxVertical) return;

    chunkMeshComponentMapper[entity].buffer?.delete();
    world.deleteEntity(entity);
  }

  @override
  void processEntities(Iterable<int> entities) {
    super.processEntities(entities);

    final cameraPos = positionMapper[tagManager.getEntity('active_camera')!].value;
    final chunks = world.chunks;

    for (var chunkPos in iterateRingColumns(16, 8)) {
      chunkPos = chunkPos.offset(
        x: (cameraPos.x / 16).toInt(),
        y: (cameraPos.y / 16).toInt(),
        z: (cameraPos.z / 16).toInt(),
      );

      if (chunkManager.entityForChunk(chunkPos) != null) continue;

      final status = chunks.statusAt(chunkPos);
      switch (status) {
        case ChunkStatus.empty:
          if (_generators.taskCount > _generators.size * 128) continue;
          chunks.scheduleChunk(_generators, chunkPos);
        case ChunkStatus.loaded:
          world.createEntity([
            Position(x: 16.0 * chunkPos.x, y: 16.0 * chunkPos.y, z: 16.0 * chunkPos.z),
            ChunkDataComponent(chunkPos),
            ChunkMeshComponent(world.time(1)),
          ]);
        default:
      }
    }
  }
}

typedef CompileWorkers = WorkerPool<(Obj, ChunkStorage), BufferWriter>;

@Generate(
  EntityProcessingSystem,
  allOf: [Position, ChunkDataComponent, ChunkMeshComponent],
)
class ChunkRenderSystem extends _$ChunkRenderSystem {
  static final cubeTexture = loadTexture("grass", mipmap: true);
  static final cube = loadObj(File("resources/cube.obj"));

  final Frustum _frustum = Frustum();
  final RenderContext _context;
  final CompileWorkers _compilers;

  ChunkStorage? _chunks;

  ChunkRenderSystem(this._context, this._compilers);

  @override
  void process() {
    final program = _context.findProgram("terrain");
    final worldProjection = world.properties["world_projection"] as Matrix4;
    final viewMatrix = world.properties["view_matrix"] as Matrix4;

    program.uniformMat4("uProjection", worldProjection);
    program.uniformMat4("uView", viewMatrix);
    program.uniformSampler("uTexture", cubeTexture, 0);
    program.use();

    _frustum.setFromMatrix(worldProjection * viewMatrix);
    _chunks = world.chunks;
    super.process();
    _chunks = null;
  }

  @override
  void processEntity(int entity, Position pos, ChunkDataComponent data, ChunkMeshComponent mesh) {
    final chunkBuffer = mesh.buffer ??= MeshBuffer(terrainVertexDescriptor, _context.findProgram("terrain"));
    final chunkStorage = _chunks!;

    final chunkBasePos = data.pos.toVec3()..scale(16);
    if (!_frustum.intersectsWithAabb3(Aabb3.minMax(chunkBasePos, chunkBasePos + Vector3.all(16)))) {
      return;
    }

    switch (mesh.state) {
      case ChunkMeshState.empty:
        if (_compilers.taskCount > _compilers.size * 4 || chunkStorage.statusAt(data.pos) != ChunkStatus.loaded) return;

        _compilers.process((cube, chunkStorage.maskChunkForCompilation(data.pos))).then((buffer) {
          chunkBuffer.clear();
          chunkBuffer.buffer = buffer;

          chunkBuffer.upload();
          mesh.state = ChunkMeshState.ready;
        });
      case ChunkMeshState.ready:
        if (chunkBuffer.isEmpty) return;

        final offset = 1.0 - min((world.time(1) - mesh.spawnTime), 1.0);
        chunkBuffer.program.uniform3vf("uOffset", pos.value - (Vector3(0, 16, 0) * offset.easeQuartic()));

        chunkBuffer.drawAndCount();
      default:
    }
  }
}

Future<CompileWorkers> createChunkCompileWorkers(int size) {
  return WorkerPool.create(() => initDiamondGL(), _compileChunk, size, (idx) => "chunk-compile-worker-$idx");
}

BufferWriter _compileChunk((Obj, ChunkStorage) command) {
  final (cube, storage) = command;

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
