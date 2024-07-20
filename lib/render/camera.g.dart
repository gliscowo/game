// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera.dart';

// **************************************************************************
// SystemGenerator
// **************************************************************************

abstract class _$CameraControlSystem extends EntitySystem {
  late final Mapper<MovementInput> movementInputMapper;
  late final Mapper<Orientation> orientationMapper;
  late final Mapper<CameraConfiguration> cameraConfigurationMapper;
  _$CameraControlSystem()
      : super(Aspect.empty()
          ..allOf([MovementInput, Orientation, CameraConfiguration]));
  @override
  void initialize() {
    super.initialize();
    movementInputMapper = Mapper<MovementInput>(world);
    orientationMapper = Mapper<Orientation>(world);
    cameraConfigurationMapper = Mapper<CameraConfiguration>(world);
  }

  @override
  void processEntities(Iterable<int> entities) {
    final movementInputMapper = this.movementInputMapper;
    final orientationMapper = this.orientationMapper;
    final cameraConfigurationMapper = this.cameraConfigurationMapper;
    for (final entity in entities) {
      processEntity(entity, movementInputMapper[entity],
          orientationMapper[entity], cameraConfigurationMapper[entity]);
    }
  }

  void processEntity(int entity, MovementInput movementInput,
      Orientation orientation, CameraConfiguration cameraConfiguration);
}
