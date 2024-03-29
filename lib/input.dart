import 'package:dart_glfw/dart_glfw.dart';
import 'package:diamond_gl/diamond_gl.dart';

class InputProvider {
  final Window _context;
  InputProvider(this._context);

  bool get forwards => glfw.getKey(_context.handle, glfwKeyW) == glfwPress;
  bool get backwards => glfw.getKey(_context.handle, glfwKeyS) == glfwPress;
  bool get left => glfw.getKey(_context.handle, glfwKeyA) == glfwPress;
  bool get right => glfw.getKey(_context.handle, glfwKeyD) == glfwPress;
  bool get up => glfw.getKey(_context.handle, glfwKeySpace) == glfwPress;
  bool get down => glfw.getKey(_context.handle, glfwKeyLeftShift) == glfwPress;

  Stream<double> get scrollEvents => _context.onMouseScroll;
  Stream<MouseMoveEvent> get mouseMoveEvents =>
      _context.onMouseMove.where((event) => glfw.getInputMode(_context.handle, glfwCursor) == glfwCursorDisabled);
}
