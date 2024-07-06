import 'package:dartemis/dartemis.dart';

import 'camera.dart';
import 'transform.dart';

part 'debug.g.dart';

@Generate(EntityProcessingSystem, allOf: [CameraConfiguration, Position, Velocity])
class DebugCameraMovementSystem extends _$DebugCameraMovementSystem {
  @override
  void processEntity(int entity, CameraConfiguration cameraConfiguration, Position pos, Velocity velocity) {
    cameraConfiguration.forward.setValues(1, 0, 0);
    pos.y = 30;
    velocity.value.setValues(50, 0, 0);
  }
}
