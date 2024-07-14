import 'package:vector_math/vector_math.dart';

import 'chunk_storage.dart';

typedef BlockHit = ({DiscretePosition pos, int blockId});
typedef ExactBlockHit = ({DiscretePosition blockPos, Vector3 pos, AxisDirection side, int blockId});

extension WithSide on BlockHit {
  ExactBlockHit exact(AxisDirection side, Vector3 exactPos) =>
      (blockPos: pos, pos: exactPos, side: side, blockId: blockId);
}

extension Raycasting on ChunkView {
  ExactBlockHit? raycast(Ray ray, double maxDistance) => raycastBetween(ray.origin, ray.at(maxDistance));

  /// Like [raycastBlockBetween] but with an additional step for determining the
  /// precise intersection point
  ExactBlockHit? raycastBetween(Vector3 from, Vector3 to) {
    final blockHit = raycastBlockBetween(from, to);
    if (blockHit == null) return null;

    Quad quadForDirection(AxisDirection direction, DiscretePosition block) => switch (direction) {
          AxisDirection.positiveX =>
            Quad.points(Vector3(.5, -.5, -.5), Vector3(.5, .5, -.5), Vector3(.5, .5, .5), Vector3(.5, -.5, .5)),
          AxisDirection.negativeX =>
            Quad.points(Vector3(-.5, -.5, -.5), Vector3(-.5, .5, -.5), Vector3(-.5, .5, .5), Vector3(-.5, -.5, .5)),
          AxisDirection.positiveY =>
            Quad.points(Vector3(-.5, .5, -.5), Vector3(.5, .5, -.5), Vector3(.5, .5, .5), Vector3(-.5, .5, .5)),
          AxisDirection.negativeY =>
            Quad.points(Vector3(-.5, -.5, -.5), Vector3(.5, -.5, -.5), Vector3(.5, -.5, .5), Vector3(-.5, -.5, .5)),
          AxisDirection.positiveZ =>
            Quad.points(Vector3(-.5, -.5, .5), Vector3(.5, -.5, .5), Vector3(.5, .5, .5), Vector3(-.5, .5, .5)),
          AxisDirection.negativeZ =>
            Quad.points(Vector3(-.5, -.5, -.5), Vector3(.5, -.5, -.5), Vector3(.5, .5, -.5), Vector3(-.5, .5, -.5))
        }
          ..translate(Vector3(block.x + .5, block.y + .5, block.z + .5));

    final ray = Ray.originDirection(from, to - from);
    final (side, rayT) = AxisDirection.values
        .map((direction) => (direction, ray.intersectsWithQuad(quadForDirection(direction, blockHit.pos))))
        .whereType<(AxisDirection, double)>()
        .reduce((a, b) => a.$2 < b.$2 ? a : b);

    return blockHit.exact(side, ray.at(rayT));
  }

  /// Test for block hits between [from] and [to], only returning the block position
  /// intersected and which block id occupies, but not where on that position
  /// the ray hit
  BlockHit? raycastBlockBetween(Vector3 from, Vector3 to) {
    final ray = to - from;

    final stepX = ray.x.sign.toInt(), stepY = ray.y.sign.toInt(), stepZ = ray.z.sign.toInt();
    final tDeltaX = stepX == 0 ? double.maxFinite : stepX / ray.x,
        tDeltaY = stepY == 0 ? double.maxFinite : stepY / ray.y,
        tDeltaZ = stepZ == 0 ? double.maxFinite : stepZ / ray.z;

    var tMaxX = tDeltaX * (stepX > 0 ? 1 - from.x % 1 : from.x % 1),
        tMaxY = tDeltaY * (stepY > 0 ? 1 - from.y % 1 : from.y % 1),
        tMaxZ = tDeltaZ * (stepZ > 0 ? 1 - from.z % 1 : from.z % 1);

    var x = from.x.floor(), y = from.y.floor(), z = from.z.floor();
    while (tMaxX <= 1.0 || tMaxY <= 1.0 || tMaxZ <= 1.0) {
      if (tMaxX < tMaxY) {
        if (tMaxX < tMaxZ) {
          x += stepX;
          tMaxX += tDeltaX;
        } else {
          z += stepZ;
          tMaxZ += tDeltaZ;
        }
      } else if (tMaxY < tMaxZ) {
        y += stepY;
        tMaxY += tDeltaY;
      } else {
        z += stepZ;
        tMaxZ += tDeltaZ;
      }

      final pos = DiscretePosition(x, y, z);
      if (blockAt(pos) case var blockId when blockId != 0) {
        return (pos: pos, blockId: blockId);
      }
    }

    return null;
  }
}
