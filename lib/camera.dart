import 'dart:math';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

class Camera {
  final Vector3 pos = Vector3(-10, 0, 0);
  final Vector3 forward = Vector3(1, 0, 0);
  double yaw = 0, pitch = 0, roll = 0;
  double speed = 10;

  final Matrix4 _viewMatrix = Matrix4.zero();

  void update(Window window, double delta) {
    final adjustedSpeed = speed * delta;

    forward
      ..setValues(
        cos(yaw) * cos(pitch),
        sin(pitch),
        sin(yaw) * cos(pitch),
      )
      ..normalize();

    final forwardHorizontal = forward.clone()
      ..[1] = 0
      ..normalize();
    if (glfw.getKey(window.handle, glfwKeyW) == glfwPress) {
      pos.add(forwardHorizontal * adjustedSpeed);
    }

    if (glfw.getKey(window.handle, glfwKeyS) == glfwPress) {
      pos.add(forwardHorizontal * -adjustedSpeed);
    }

    if (glfw.getKey(window.handle, glfwKeyA) == glfwPress) {
      pos.add((forward.cross(Vector3(0, 1, 0))..normalize()) * -adjustedSpeed);
    }

    if (glfw.getKey(window.handle, glfwKeyD) == glfwPress) {
      pos.add((forward.cross(Vector3(0, 1, 0))..normalize()) * adjustedSpeed);
    }

    if (glfw.getKey(window.handle, glfwKeySpace) == glfwPress) {
      pos.add(Vector3(0, adjustedSpeed, 0));
    }

    if (glfw.getKey(window.handle, glfwKeyLeftShift) == glfwPress) {
      pos.add(Vector3(0, -adjustedSpeed, 0));
    }
  }

  void onMouseMove(double x, double y) {
    yaw += x * .001;
    pitch = (pitch + y * -.001).clamp(-89 * degrees2Radians, 89 * degrees2Radians);
  }

  Matrix4 get viewMatrix {
    setViewMatrix(_viewMatrix, pos, pos + forward, Vector3(0, 1, 0));
    return _viewMatrix;
  }
}
