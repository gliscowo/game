import 'dart:math';

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

    int leftEdge = max(x, other.x);
    int topEdge = max(y, other.y);

    int rightEdge = min(x + width, other.x + other.width);
    int bottomEdge = min(y + height, other.y + other.height);

    return Rectangle(leftEdge, topEdge, max(rightEdge - leftEdge, 0), max(bottomEdge - topEdge, 0));
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

void iterateRingColumns(int maxRadius, int halfHeightRange, void Function(DiscretePosition point) action) {
  for (var y = -halfHeightRange; y <= halfHeightRange; y++) {
    action(DiscretePosition(0, y, 0));
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
        for (var y = -halfHeightRange; y <= halfHeightRange; y++) {
          action(DiscretePosition(x, y, z));
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
