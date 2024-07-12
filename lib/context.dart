import 'package:diamond_gl/diamond_gl.dart';

typedef ProgramLookup = GlProgram Function(String);

class RenderContext {
  final Window window;
  final Map<String, GlProgram> _programStore = {};

  RenderContext(this.window, List<GlProgram> programs) {
    for (final program in programs) {
      if (_programStore[program.name] != null) {
        throw ArgumentError('Duplicate program name ${program.name}', 'programs');
      }

      _programStore[program.name] = program;
    }
  }

  GlProgram findProgram(String name) {
    final program = _programStore[name];
    if (program == null) throw StateError('Missing required program $name');

    return program;
  }
}
