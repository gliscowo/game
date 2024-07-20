import 'package:cutesy/cutesy.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import '../texture.dart';
import '../vertex_descriptors.dart';

class TextureWidget extends Widget {
  final String texture;
  final int srcBlend, dstBlend;

  MeshBuffer<PosUvColorVertexFunction>? _mesh;

  TextureWidget(
    this.texture, {
    this.srcBlend = glSrcAlpha,
    this.dstBlend = glOneMinusSrcAlpha,
  });

  @override
  void draw(DrawContext context, int mouseX, int mouseY, double delta) {
    final mesh = _mesh ??= MeshBuffer(posUvColorVertexDescriptor, context.renderContext.findProgram('pos_uv_color'));
    mesh.clear();

    final xSize = width.toDouble(), ySize = height.toDouble();
    mesh
      ..vertex(Vector3(0, 0, 0), 0, 0, Color.white)
      ..vertex(Vector3(0, ySize, 0), 0, 1, Color.white)
      ..vertex(Vector3(xSize, 0, 0), 1, 0, Color.white)
      ..vertex(Vector3(0, ySize, 0), 0, 1, Color.white)
      ..vertex(Vector3(xSize, ySize, 0), 1, 1, Color.white)
      ..vertex(Vector3(ySize, 0, 0), 1, 0, Color.white)
      ..upload();

    mesh.program.uniformMat4('uTransform', Matrix4.translationValues(x.toDouble(), y.toDouble(), 0));
    mesh.program.uniformMat4('uProjection', context.projection);
    mesh.program.uniformSampler('uTexture', loadTexture(texture), 0);
    mesh.program.use();

    gl.blendFunc(srcBlend, dstBlend);

    mesh.draw();
  }

  @override
  void dismount(DismountReason reason) {
    super.dismount(reason);

    if (reason == DismountReason.removed) {
      _mesh?.delete();
    }
  }
}
