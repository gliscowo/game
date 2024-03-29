// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chunk.dart';

// **************************************************************************
// SystemGenerator
// **************************************************************************

abstract class _$ChunkRenderSystem extends EntitySystem {
  late final Mapper<Position> positionMapper;
  late final Mapper<ChunkDataComponent> chunkDataComponentMapper;
  late final Mapper<ChunkMeshComponent> chunkMeshComponentMapper;
  _$ChunkRenderSystem()
      : super(Aspect.empty()
          ..allOf([Position, ChunkDataComponent, ChunkMeshComponent]));
  @override
  void initialize() {
    super.initialize();
    positionMapper = Mapper<Position>(world);
    chunkDataComponentMapper = Mapper<ChunkDataComponent>(world);
    chunkMeshComponentMapper = Mapper<ChunkMeshComponent>(world);
  }

  @override
  void processEntities(Iterable<int> entities) {
    final positionMapper = this.positionMapper;
    final chunkDataComponentMapper = this.chunkDataComponentMapper;
    final chunkMeshComponentMapper = this.chunkMeshComponentMapper;
    for (final entity in entities) {
      processEntity(entity, positionMapper[entity],
          chunkDataComponentMapper[entity], chunkMeshComponentMapper[entity]);
    }
  }

  void processEntity(
      int entity,
      Position position,
      ChunkDataComponent chunkDataComponent,
      ChunkMeshComponent chunkMeshComponent);
}
