import 'package:dartemis/dartemis.dart';

const tickRate = 64;
const renderGroup = 1;
const logicGroup = 2;

// TODO feels like adding systems at runtime isn't exactly intended
class GameWorld extends World {
  bool _initialized = false;

  @override
  void addSystem(EntitySystem system, {bool passive = false, int group = 0}) {
    super.addSystem(system, passive: passive, group: group);
    if (_initialized) system.initialize();
  }

  @override
  void initialize() {
    if (_initialized) throw StateError('Tried to initialize game world twice');

    super.initialize();
    _initialized = true;
  }

  @override
  void process([int group = 0]) {
    if (!_initialized) throw StateError('Tried to process world before initialization');
    super.process(group);
  }
}
