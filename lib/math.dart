import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'chunk_storage.dart';

extension DoubleLerp on double {
  double lerp(double delta, double other) => this + delta * (other - this);
}

extension IntLerp on int {
  int lerp(double delta, int other) => this + (delta * (other - this)).round();
}

double computeDelta(double current, double target, double delta) {
  double diff = target - current;
  delta = diff * delta;

  return delta.abs() > diff.abs() ? diff : delta;
}

abstract mixin class Rectangle {
  int get x;
  int get y;

  int get width;
  int get height;

  bool isInBoundingBox(double x, double y) => x >= this.x && x < this.x + width && y >= this.y && y < this.y + height;
  bool intersects(Rectangle other) =>
      other.x < x + width && other.x + other.width >= x && other.y < y + height && other.y + other.height >= y;

  Rectangle intersection(Rectangle other) {
    // my brain is fucking dead on the floor
    // this code is really, really simple
    // and honestly quite obvious
    //
    // my brain did not agree
    // glisco, 2022

    int leftEdge = math.max(x, other.x);
    int topEdge = math.max(y, other.y);

    int rightEdge = math.min(x + width, other.x + other.width);
    int bottomEdge = math.min(y + height, other.y + other.height);

    return Rectangle(leftEdge, topEdge, math.max(rightEdge - leftEdge, 0), math.max(bottomEdge - topEdge, 0));
  }

  factory Rectangle(int x, int y, int width, int height) => _Rectangle(x, y, width, height);
}

class _Rectangle with Rectangle {
  @override
  final int x, y, width, height;

  _Rectangle(this.x, this.y, this.width, this.height);
}

class Size {
  static const Size zero = Size(0, 0);

  final int width, height;
  const Size(this.width, this.height);

  Size copy({int? width, int? height}) => Size(width ?? this.width, height ?? this.height);

  @override
  int get hashCode => Object.hash(width, height);

  @override
  bool operator ==(Object other) => other is Size && other.width == width && other.height == height;
}

extension StretchAndMove on Aabb3 {
  void stretch(Vector3 pos) {
    if (pos.x < 0) {
      min.x += pos.x;
    } else if (pos.x > 0) {
      max.x += pos.x;
    }

    if (pos.y < 0) {
      min.y += pos.y;
    } else if (pos.y > 0) {
      max.y += pos.y;
    }

    if (pos.z < 0) {
      min.z += pos.z;
    } else if (pos.z > 0) {
      max.z += pos.z;
    }
  }
}

Iterable<DiscretePosition> iterateOutwards(
  int maxRadius,
  int halfHeightRange, {
  DiscretePosition basePos = const DiscretePosition.origin(),
}) sync* {
  yield basePos;
  for (var y = 0; y <= halfHeightRange; y++) {
    yield DiscretePosition(basePos.x, basePos.y - y, basePos.z);
    yield DiscretePosition(basePos.x, basePos.y + y, basePos.z);
  }

  for (var radius = 0; radius < maxRadius; radius++) {
    //start at top-left
    final sideLength = radius * 2 + 1;

    var x = -radius;
    var z = -radius;

    //point to the right
    var dx = 1;
    var dz = 0;

    for (int side = 0; side < 4; ++side) {
      for (int i = 1; i < sideLength; ++i) {
        yield DiscretePosition(basePos.x + x, basePos.y, basePos.x + z);
        for (var y = 0; y <= halfHeightRange; y++) {
          yield DiscretePosition(basePos.x + x, basePos.y - y, basePos.z + z);
          yield DiscretePosition(basePos.x + x, basePos.y + y, basePos.z + z);
        }

        x += dx;
        z += dz;
      }

      //turn right
      int t = dx;
      dx = -dz;
      dz = t;
    }
  }
}

Iterable<DiscretePosition> between(DiscretePosition from, DiscretePosition to) sync* {
  final min = DiscretePosition(math.min(from.x, to.x), math.min(from.y, to.y), math.min(from.z, to.z));
  final max = DiscretePosition(math.max(from.x, to.x), math.max(from.y, to.y), math.max(from.z, to.z));

  for (var x = min.x; x <= max.x; x++) {
    for (var y = min.y; y <= max.y; y++) {
      for (var z = min.z; z <= max.z; z++) {
        yield DiscretePosition(x, y, z);
      }
    }
  }
}
