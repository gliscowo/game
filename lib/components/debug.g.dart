// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debug.dart';

// **************************************************************************
// SystemGenerator
// **************************************************************************

abstract class _$DebugCameraMovementSystem extends EntitySystem {
  late final Mapper<CameraConfiguration> cameraConfigurationMapper;
  late final Mapper<Position> positionMapper;
  late final Mapper<Velocity> velocityMapper;
  _$DebugCameraMovementSystem()
      : super(Aspect.empty()..allOf([CameraConfiguration, Position, Velocity]));
  @override
  void initialize() {
    super.initialize();
    cameraConfigurationMapper = Mapper<CameraConfiguration>(world);
    positionMapper = Mapper<Position>(world);
    velocityMapper = Mapper<Velocity>(world);
  }

  @override
  void processEntities(Iterable<int> entities) {
    final cameraConfigurationMapper = this.cameraConfigurationMapper;
    final positionMapper = this.positionMapper;
    final velocityMapper = this.velocityMapper;
    for (final entity in entities) {
      processEntity(entity, cameraConfigurationMapper[entity],
          positionMapper[entity], velocityMapper[entity]);
    }
  }

  void processEntity(int entity, CameraConfiguration cameraConfiguration,
      Position position, Velocity velocity);
}

abstract class _$DebugCubeVisualizerSystem extends EntitySystem {
  late final Mapper<Position> positionMapper;
  late final Mapper<DebugCubeRenderer> debugCubeRendererMapper;
  _$DebugCubeVisualizerSystem()
      : super(Aspect.empty()..allOf([Position, DebugCubeRenderer]));
  @override
  void initialize() {
    super.initialize();
    positionMapper = Mapper<Position>(world);
    debugCubeRendererMapper = Mapper<DebugCubeRenderer>(world);
  }

  @override
  void processEntities(Iterable<int> entities) {
    final positionMapper = this.positionMapper;
    final debugCubeRendererMapper = this.debugCubeRendererMapper;
    for (final entity in entities) {
      processEntity(
          entity, positionMapper[entity], debugCubeRendererMapper[entity]);
    }
  }

  void processEntity(
      int entity, Position position, DebugCubeRenderer debugCubeRenderer);
}

abstract class _$DebugChunkGridRenderSystem extends EntitySystem {
  late final Mapper<ChunkGridRenderer> chunkGridRendererMapper;
  late final Mapper<Position> positionMapper;
  late final TagManager tagManager;
  _$DebugChunkGridRenderSystem()
      : super(Aspect.empty()..allOf([ChunkGridRenderer]));
  @override
  void initialize() {
    super.initialize();
    chunkGridRendererMapper = Mapper<ChunkGridRenderer>(world);
    positionMapper = Mapper<Position>(world);
    tagManager = world.getManager<TagManager>();
  }
}
