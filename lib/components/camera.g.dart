// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera.dart';

// **************************************************************************
// SystemGenerator
// **************************************************************************

abstract class _$CameraControlSystem extends EntitySystem {
  late final Mapper<Velocity> velocityMapper;
  late final Mapper<Orientation> orientationMapper;
  late final Mapper<CameraConfiguration> cameraConfigurationMapper;
  _$CameraControlSystem()
      : super(Aspect.empty()
          ..allOf([Velocity, Orientation, CameraConfiguration]));
  @override
  void initialize() {
    super.initialize();
    velocityMapper = Mapper<Velocity>(world);
    orientationMapper = Mapper<Orientation>(world);
    cameraConfigurationMapper = Mapper<CameraConfiguration>(world);
  }

  @override
  void processEntities(Iterable<int> entities) {
    final velocityMapper = this.velocityMapper;
    final orientationMapper = this.orientationMapper;
    final cameraConfigurationMapper = this.cameraConfigurationMapper;
    for (final entity in entities) {
      processEntity(entity, velocityMapper[entity], orientationMapper[entity],
          cameraConfigurationMapper[entity]);
    }
  }

  void processEntity(int entity, Velocity velocity, Orientation orientation,
      CameraConfiguration cameraConfiguration);
}
