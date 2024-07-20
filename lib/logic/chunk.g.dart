// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chunk.dart';

// **************************************************************************
// SystemGenerator
// **************************************************************************

abstract class _$ChunkLoadingSystem extends EntitySystem {
  late final Mapper<Position> positionMapper;
  late final Mapper<ChunkData> chunkDataMapper;
  late final Mapper<ChunkMesh> chunkMeshMapper;
  late final ChunkManager chunkManager;
  late final TagManager tagManager;
  _$ChunkLoadingSystem()
      : super(Aspect.empty()..allOf([Position, ChunkData, ChunkMesh]));
  @override
  void initialize() {
    super.initialize();
    positionMapper = Mapper<Position>(world);
    chunkDataMapper = Mapper<ChunkData>(world);
    chunkMeshMapper = Mapper<ChunkMesh>(world);
    chunkManager = world.getManager<ChunkManager>();
    tagManager = world.getManager<TagManager>();
  }

  @override
  void processEntities(Iterable<int> entities) {
    final positionMapper = this.positionMapper;
    final chunkDataMapper = this.chunkDataMapper;
    final chunkMeshMapper = this.chunkMeshMapper;
    for (final entity in entities) {
      processEntity(entity, positionMapper[entity], chunkDataMapper[entity],
          chunkMeshMapper[entity]);
    }
  }

  void processEntity(
      int entity, Position position, ChunkData chunkData, ChunkMesh chunkMesh);
}

abstract class _$ChunkRenderSystem extends VoidEntitySystem {
  late final Mapper<Position> positionMapper;
  late final Mapper<ChunkData> chunkDataMapper;
  late final Mapper<ChunkMesh> chunkMeshMapper;
  late final TagManager tagManager;
  late final ChunkManager chunkManager;
  @override
  void initialize() {
    super.initialize();
    positionMapper = Mapper<Position>(world);
    chunkDataMapper = Mapper<ChunkData>(world);
    chunkMeshMapper = Mapper<ChunkMesh>(world);
    tagManager = world.getManager<TagManager>();
    chunkManager = world.getManager<ChunkManager>();
  }
}
