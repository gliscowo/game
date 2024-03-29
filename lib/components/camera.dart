import 'dart:async';
import 'dart:math';

import 'package:dartemis/dartemis.dart';
import 'package:vector_math/vector_math.dart';

import '../input.dart';
import 'transform.dart';

part 'camera.g.dart';

class CameraConfiguration extends Component {
  final Vector3 forward = Vector3(1, 0, 0);
  double speed = 10;

  final Matrix4 _viewMatrix = Matrix4.zero();
  Matrix4 computeViewMatrix(Position pos) {
    setViewMatrix(_viewMatrix, pos.value, pos.value + forward, Vector3(0, 1, 0));
    return _viewMatrix;
  }
}

// class SetProjectionSystem extends _$SetProjectionSystem {}

@Generate(
  EntityProcessingSystem,
  allOf: [Velocity, Orientation, CameraConfiguration],
)
class CameraControlSystem extends _$CameraControlSystem {
  final InputProvider _input;
  final List<StreamSubscription> _subscriptions = [];

  double _scrollSinceLastTick = 0;
  double _dxSinceLastTick = 0, _dySinceLastTick = 0;

  CameraControlSystem(this._input);

  @override
  void initialize() {
    super.initialize();
    _subscriptions.addAll([
      _input.scrollEvents.listen((event) {
        _scrollSinceLastTick += event;
      }),
      _input.mouseMoveEvents.listen((event) {
        _dxSinceLastTick += event.deltaX;
        _dySinceLastTick += event.deltaY;
      })
    ]);
  }

  @override
  void destroy() {
    super.destroy();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
  }

  @override
  void process() {
    super.process();
    _scrollSinceLastTick = _dxSinceLastTick = _dySinceLastTick = 0;
  }

  @override
  void processEntity(int entity, Velocity velocity, Orientation orientation, CameraConfiguration camera) {
    camera.speed *= 1 + .1 * _scrollSinceLastTick;
    orientation.yaw += _dxSinceLastTick * .001;
    orientation.pitch =
        (orientation.pitch + _dySinceLastTick * -.001).clamp(-89 * degrees2Radians, 89 * degrees2Radians);

    camera.forward
      ..setValues(
        cos(orientation.yaw) * cos(orientation.pitch),
        sin(orientation.pitch),
        sin(orientation.yaw) * cos(orientation.pitch),
      )
      ..normalize();

    final inputVelocity = Vector3.zero();
    final forwardHorizontal = camera.forward.clone()
      ..[1] = 0
      ..normalize();
    if (_input.forwards) {
      inputVelocity.add(forwardHorizontal);
    }

    if (_input.backwards) {
      inputVelocity.add(-forwardHorizontal);
    }

    if (_input.left) {
      inputVelocity.add(camera.forward.cross(Vector3(0, -1, 0)));
    }

    if (_input.right) {
      inputVelocity.add(camera.forward.cross(Vector3(0, 1, 0)));
    }

    if (_input.up) {
      inputVelocity.add(Vector3(0, 1, 0));
    }

    if (_input.down) {
      inputVelocity.add(Vector3(0, -1, 0));
    }

    if (inputVelocity.length2 != 0) {
      inputVelocity
        ..normalize()
        ..scale(camera.speed);

      final resultingVelocity = velocity.value + inputVelocity;
      final maxSpeed = max(inputVelocity.length2, velocity.value.length2);

      if (resultingVelocity.length2 > maxSpeed) {
        resultingVelocity
          ..normalize()
          ..scale(sqrt(maxSpeed));
      }

      velocity.value.setFrom(resultingVelocity);
    }
  }
}
