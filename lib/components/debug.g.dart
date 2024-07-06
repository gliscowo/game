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
