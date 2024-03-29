import 'dart:io';

import 'package:vector_math/vector_math.dart';

class Obj {
  final List<Vector3> vertices;
  final List<Vector2> uvs;
  final List<Vector3> normals;
  final List<Tri> tris;

  Obj(this.vertices, this.uvs, this.normals, this.tris);
}

class Tri {
  final (int, int, int) vertices;
  final (int, int, int) uvs;
  final (int, int, int) normals;

  Tri(this.vertices, this.uvs, this.normals);
}

Obj loadObj(File from) {
  final vertices = <Vector3>[];
  final uvs = <Vector2>[];
  final normals = <Vector3>[];
  final tris = <Tri>[];

  for (final line in from.readAsLinesSync()) {
    final parts = line.trim().split(RegExp(r"\s+"));

    switch (parts.first) {
      case 'v':
        vertices.add(Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3])));
      case 'vt':
        uvs.add(Vector2(double.parse(parts[1]), double.parse(parts[2])));
      case 'vn':
        normals.add(Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3])));
      case 'f':
        final indices = parts.skip(1).take(3).expand((e) => e.split("/")).map(int.parse).toList();
        tris.add(Tri(
          (indices[0], indices[0 + 3], indices[0 + 6]),
          (indices[1], indices[1 + 3], indices[1 + 6]),
          (indices[2], indices[2 + 3], indices[2 + 6]),
        ));
    }
  }

  return Obj(vertices, uvs, normals, tris);
}
