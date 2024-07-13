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
  bool needsRebuild = false;

  ChunkMeshState state = ChunkMeshState.empty;

  ChunkMeshComponent(this.spawnTime);
}

const renderDistance = (horizontal: 8, vertical: 6);

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
  EntityProcessingSystem,
  allOf: [Position, ChunkDataComponent, ChunkMeshComponent],
  manager: [ChunkManager, TagManager],
)
class ChunkLoadingSystem extends _$ChunkLoadingSystem {
  final ChunkGenWorkers _generators;

  ChunkLoadingSystem(this._generators);

  @override
  void processEntity(int entity, Position pos, ChunkDataComponent data, ChunkMeshComponent mesh) {
    final cameraPos = positionMapper[tagManager.getEntity('active_camera')!].value;

    final maxHorizontal = renderDistance.horizontal + 1;
    final maxVertical = renderDistance.vertical + 1;
    if ((data.pos.x - cameraPos.x / 16).abs() < maxHorizontal &&
        (data.pos.z - cameraPos.z / 16).abs() < maxHorizontal &&
        (data.pos.y - cameraPos.y / 16).abs() < maxVertical) return;

    mesh.buffer?.delete();
    world.deleteEntity(entity);
  }

  @override
  void processEntities(Iterable<int> entities) {
    super.processEntities(entities);

    final cameraPos = positionMapper[tagManager.getEntity('active_camera')!].value;
    final chunks = world.chunks;

    final cameraChunkPos = DiscretePosition(
      (cameraPos.x / 16).toInt(),
      (cameraPos.y / 16).toInt(),
      (cameraPos.z / 16).toInt(),
    );
    for (final chunkPos
        in iterateOutwards(renderDistance.horizontal, renderDistance.vertical, basePos: cameraChunkPos)) {
      if (chunkManager.entityForChunk(chunkPos) != null) continue;

      final status = chunks.statusAt(chunkPos);
      switch (status) {
        case ChunkStatus.empty:
          if (_generators.taskCount >= _generators.size * 8) continue;
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

typedef CompileWorkers = WorkerPool<(Obj, ChunkView), BufferWriter>;

@Generate(
  EntitySystem,
  mapper: [Position, ChunkDataComponent, ChunkMeshComponent],
  manager: [TagManager, ChunkManager],
)
class ChunkRenderSystem extends _$ChunkRenderSystem {
  static final cubeTexture = loadTexture('grass', mipmap: true);
  static final cube = loadObj(File('resources/cube.obj'));

  final Frustum _frustum = Frustum();
  final RenderContext _context;
  final CompileWorkers _compilers;

  ChunkRenderSystem(this._context, this._compilers) : super(Aspect.empty());

  @override
  void processEntities(Iterable<int> entities) {
    final program = _context.findProgram('terrain');
    final worldProjection = world.properties['world_projection'] as Matrix4;
    final viewMatrix = world.properties['view_matrix'] as Matrix4;

    program.uniformMat4('uProjection', worldProjection);
    program.uniformMat4('uView', viewMatrix);
    program.uniformSampler('uTexture', cubeTexture, 0);
    program.use();

    final chunkStorage = world.chunks;
    _frustum.setFromMatrix(worldProjection * viewMatrix);

    final cameraPos = positionMapper[tagManager.getEntity('active_camera')!].value;
    final cameraChunkPos = DiscretePosition(
      (cameraPos.x / 16).toInt(),
      (cameraPos.y / 16).toInt(),
      (cameraPos.z / 16).toInt(),
    );

    for (final chunkPos
        in iterateOutwards(renderDistance.horizontal, renderDistance.vertical, basePos: cameraChunkPos)) {
      final entity = chunkManager.entityForChunk(chunkPos);
      if (entity == null) continue;

      final chunkBasePos = chunkPos.toVec3()..scale(16);
      if (!_frustum.intersectsWithAabb3(Aabb3.minMax(chunkBasePos, chunkBasePos + Vector3.all(16)))) {
        continue;
      }

      _renderChunk(
        chunkStorage,
        positionMapper[entity],
        chunkDataComponentMapper[entity],
        chunkMeshComponentMapper[entity],
      );
    }
  }

  void _renderChunk(ChunkStorage chunks, Position pos, ChunkDataComponent data, ChunkMeshComponent mesh) {
    switch (mesh.state) {
      case ChunkMeshState.empty:
        if (chunks.statusAt(data.pos) != ChunkStatus.loaded) return;

        if (_tryScheduleRebuild(chunks, data, mesh)) {
          mesh.state = ChunkMeshState.building;
        }
      case ChunkMeshState.ready:
        if (mesh.needsRebuild && _tryScheduleRebuild(chunks, data, mesh)) {
          mesh.needsRebuild = false;
        }

        final chunkBuffer = mesh.buffer!;
        if (chunkBuffer.isEmpty) return;

        final offset = 1.0 - min((world.time(1) - mesh.spawnTime), 1.0);
        chunkBuffer.program.uniform3vf('uOffset', pos.value - (Vector3(0, 16, 0) * offset.easeQuartic()));

        chunkBuffer.drawAndCount();
      default:
    }
  }

  bool _tryScheduleRebuild(ChunkStorage chunks, ChunkDataComponent data, ChunkMeshComponent mesh) {
    if (_compilers.taskCount >= _compilers.size * 4) return false;

    _compilers.process((cube, chunks.maskChunkForCompilation(data.pos))).then((buffer) {
      final chunkBuffer = mesh.buffer ??= MeshBuffer(terrainVertexDescriptor, _context.findProgram('terrain'));

      chunkBuffer.clear();
      chunkBuffer.buffer = buffer;

      chunkBuffer.upload();
      mesh.state = ChunkMeshState.ready;
    });
    return true;
  }
}

Future<CompileWorkers> createChunkCompileWorkers(int size) {
  return WorkerPool.create(() => initDiamondGL(), _compileChunk, size, (idx) => 'chunk-compile-worker-$idx');
}

BufferWriter _compileChunk((Obj, ChunkView) command) {
  final (cube, chunks) = command;

  final buffer = BufferWriter();
  final builder = terrainVertexDescriptor.createBuilder(buffer);

  final chunk = chunks.chunkAt(DiscretePosition.origin());
  for (var x = 0; x < Chunk.size; x++) {
    for (var y = 0; y < Chunk.size; y++) {
      for (var z = 0; z < Chunk.size; z++) {
        final pos = DiscretePosition(x, y, z);
        if (!chunk.hasBlockAt(pos)) continue;

        for (final Tri(:vertices, :normals, :uvs) in cube.tris) {
          final vtx1 = cube.vertices[vertices.$1 - 1],
              vtx2 = cube.vertices[vertices.$2 - 1],
              vtx3 = cube.vertices[vertices.$3 - 1];

          if (chunks.hasBlockAt(pos.offset(x: -1)) && vtx1.x == -.5 && vtx2.x == -.5 && vtx3.x == -.5) {
            continue;
          }

          if (chunks.hasBlockAt(pos.offset(x: 1)) && vtx1.x == .5 && vtx2.x == .5 && vtx3.x == .5) {
            continue;
          }

          if (chunks.hasBlockAt(pos.offset(z: -1)) && vtx1.z == -.5 && vtx2.z == -.5 && vtx3.z == -.5) {
            continue;
          }

          if (chunks.hasBlockAt(pos.offset(z: 1)) && vtx1.z == .5 && vtx2.z == .5 && vtx3.z == .5) {
            continue;
          }

          if (chunks.hasBlockAt(pos.offset(y: -1)) && vtx1.y == -.5 && vtx2.y == -.5 && vtx3.y == -.5) {
            continue;
          }

          if (chunks.hasBlockAt(pos.offset(y: 1)) && vtx1.y == .5 && vtx2.y == .5 && vtx3.y == .5) {
            continue;
          }

          final offset = Vector3(x.toDouble() + .5, y.toDouble() + .5, z.toDouble() + .5);

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
