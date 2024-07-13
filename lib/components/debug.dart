import 'dart:io';

import 'package:dartemis/dartemis.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../game.dart';
import '../obj.dart';
import '../vertex_descriptors.dart';
import 'camera.dart';
import 'transform.dart';

part 'debug.g.dart';

class DebugCubeRenderer extends Component {
  final Color color;
  final double scale;

  DebugCubeRenderer(this.color, {this.scale = 1});
}

@Generate(EntityProcessingSystem, allOf: [CameraConfiguration, Position, Velocity])
class DebugCameraMovementSystem extends _$DebugCameraMovementSystem {
  static bool move = true;

  @override
  void processEntity(int entity, CameraConfiguration cameraConfiguration, Position pos, Velocity velocity) {
    if (!move) return;

    cameraConfiguration.forward.setValues(1, 0, 0);
    pos.y = 30;
    velocity.value.setValues(50, 0, 0);
  }
}

@Generate(EntityProcessingSystem, allOf: [Position, DebugCubeRenderer])
class DebugCubeVisualizerSystem extends _$DebugCubeVisualizerSystem {
  final RenderContext _context;

  late final MeshBuffer<DebugEntityVertexFunction> _mesh;

  DebugCubeVisualizerSystem(this._context);

  @override
  void initialize() {
    super.initialize();

    final obj = loadObj(File('resources/cube.obj'));
    _mesh = MeshBuffer(debugEntityVertexDescriptor, _context.findProgram('debug_entity'));
    for (final Tri(:vertices) in obj.tris) {
      _mesh.vertex(obj.vertices[vertices.$1 - 1]);
      _mesh.vertex(obj.vertices[vertices.$2 - 1]);
      _mesh.vertex(obj.vertices[vertices.$3 - 1]);
    }

    _mesh.upload();
  }

  @override
  void processEntities(Iterable<int> entities) {
    final worldProjection = world.properties['world_projection'] as Matrix4;
    final viewMatrix = world.properties['view_matrix'] as Matrix4;

    _mesh.program.uniformMat4('uProjection', worldProjection);
    _mesh.program.uniformMat4('uView', viewMatrix);
    _mesh.program.use();

    super.processEntities(entities);
  }

  @override
  void processEntity(int entity, Position pos, DebugCubeRenderer cube) {
    _mesh.program.uniform1f('uScale', cube.scale);
    _mesh.program.uniform4vf('uSurfaceColor', cube.color.asVector());
    _mesh.program.uniform3vf('uPos', pos.value);
    _mesh.drawAndCount();

    world.deleteEntity(entity);
  }
}
