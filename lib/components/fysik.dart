import 'package:dartemis/dartemis.dart';

import 'transform.dart';

part 'fysik.g.dart';

@Generate(
  EntityProcessingSystem,
  allOf: [Position, Velocity],
)
class VelocitySystem extends _$VelocitySystem {
  @override
  void processEntity(int entity, Position position, Velocity velocity) {
    position.value.add(velocity.value * delta);
  }
}

@Generate(
  EntityProcessingSystem,
  allOf: [Position, Velocity],
)
class AirDragSystem extends _$AirDragSystem {
  @override
  void processEntity(int entity, Position position, Velocity velocity) {
    velocity.value.scale(.875);
    if (velocity.value.length2 < .0005) velocity.value.setZero();
  }
}
