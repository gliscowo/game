import 'package:dartemis/dartemis.dart';
import 'package:vector_math/vector_math.dart';

import '../chunk_storage.dart';
import '../game.dart';
import '../math.dart';
import 'transform.dart';

part 'fysik.g.dart';

class MovementInput extends Component {
  final Vector3 value = Vector3.zero();
}

// --- noclip movement ---

class NoclipPhysics extends Component {
  static final _instance = NoclipPhysics._();
  NoclipPhysics._();

  factory NoclipPhysics() => _instance;
}

@Generate(
  EntityProcessingSystem,
  allOf: [Position, Velocity, MovementInput, NoclipPhysics],
)
class NoclipPhysicsSystem extends _$NoclipPhysicsSystem {
  @override
  void processEntity(int entity, Position position, Velocity velocity, MovementInput input, NoclipPhysics _) {
    if (input.value.length2 != 0) {
      velocity.value.setFrom(input.value);
    } else {
      velocity.value.scale(.85);
    }

    position.value.add(velocity.value * delta);
  }
}

// --- proper aabb collision handling ---

class AabbCollider extends Component {
  final double xSize, ySize, zSize;
  bool onGround = false;

  AabbCollider(this.xSize, this.ySize, this.zSize);

  Aabb3 toAabb({Vector3? pos}) => pos != null
      ? Aabb3.minMax(Vector3(pos.x - xSize / 2, pos.y, pos.z - zSize / 2),
          Vector3(pos.x + xSize / 2, pos.y + ySize, pos.z + zSize / 2))
      : Aabb3.minMax(Vector3(-xSize / 2, 0, -zSize / 2), Vector3(xSize / 2, ySize, zSize / 2));
}

@Generate(EntityProcessingSystem, allOf: [Position, Velocity, MovementInput, AabbCollider])
class ColliderPhysicsSystem extends _$ColliderPhysicsSystem {
  @override
  void processEntity(int entity, Position pos, Velocity velocity, MovementInput input, AabbCollider collider) {
    // apply gravity
    velocity.y -= 30 * delta;

    // --- apply movement input ---
    if (collider.onGround && input.value.y > 0) {
      velocity.value.y += 9;
    }

    velocity.value.add(
      input.value.clone()
        ..y = 0
        ..scale(collider.onGround ? .25 : .025),
    );

    // reset ground state
    collider.onGround = false;

    // --- collision detection ---

    bool aabbIntersect(Aabb3 box, Aabb3 other) {
      final otherMax = other.max;
      final otherMin = other.min;

      const epsilon = 1e-6;
      return (otherMax.x - box.min.x > epsilon) &&
          (otherMax.y - box.min.y > epsilon) &&
          (otherMax.z - box.min.z > epsilon) &&
          (box.max.x - otherMin.x > epsilon) &&
          (box.max.y - otherMin.y > epsilon) &&
          (box.max.z - otherMin.z > epsilon);
    }

    bool blockIntersect(Aabb3 block, Aabb3 collider, double offset, int offsetIdx) {
      collider
        ..min[offsetIdx] += offset
        ..max[offsetIdx] += offset;

      final collides = aabbIntersect(block, collider);

      collider
        ..min[offsetIdx] -= offset
        ..max[offsetIdx] -= offset;

      return collides;
    }

    final baseAabb = collider.toAabb(pos: pos.value);

    var dX = velocity.x * delta, dY = velocity.y * delta, dZ = velocity.z * delta;
    final testAabb = Aabb3.copy(baseAabb)..stretch(Vector3(dX, dY, dZ));
    final blockBox = Aabb3();

    for (final blockPos in between(DiscretePosition.floor(testAabb.min), DiscretePosition.floor(testAabb.max))) {
      if (world.chunks.blockAt(blockPos) == 0) continue;

      final aabb = Aabb3.copy(baseAabb);
      blockBox.min
        ..x = blockPos.x.toDouble()
        ..y = blockPos.y.toDouble()
        ..z = blockPos.z.toDouble();
      blockBox.max
        ..x = blockPos.x + 1
        ..y = blockPos.y + 1
        ..z = blockPos.z + 1;

      // skip all blocks we are already in
      if (aabbIntersect(blockBox, aabb)) {
        continue;
      }

      var xPenetration = 0.0, yPenetration = 0.0, zPenetration = 0.0;

      // --- y collision ---

      if (dY != 0 && blockIntersect(blockBox, aabb, dY, 1)) {
        if (dY < 0 && aabb.min.y + dY < blockBox.max.y) {
          yPenetration = aabb.min.y + dY - blockBox.max.y;
        }

        if (dY > 0 && aabb.max.y + dY > blockBox.min.y) {
          yPenetration = aabb.max.y + dY - blockBox.min.y;
        }
      }

      // --- x collision ---

      if (dX != 0 && blockIntersect(blockBox, aabb, dX, 0)) {
        if (dX < 0 && aabb.min.x + dX < blockBox.max.x) {
          xPenetration = aabb.min.x + dX - blockBox.max.x;
        }

        if (dX > 0 && aabb.max.x + dX > blockBox.min.x) {
          xPenetration = aabb.max.x + dX - blockBox.min.x;
        }
      }

      // --- z collision ---

      if (dZ != 0 && blockIntersect(blockBox, aabb, dZ, 2)) {
        if (dZ < 0 && aabb.min.z + dZ < blockBox.max.z) {
          zPenetration = aabb.min.z + dZ - blockBox.max.z;
        }

        if (dZ > 0 && aabb.max.z + dZ > blockBox.min.z) {
          zPenetration = aabb.max.z + dZ - blockBox.min.z;
        }
      }

      // --- collision response ---

      if (xPenetration != 0 || yPenetration != 0 || zPenetration != 0) {
        if (xPenetration.abs() > yPenetration.abs()) {
          if (xPenetration.abs() > zPenetration.abs()) {
            dX -= xPenetration;
            velocity.x = 0;
          } else {
            dZ -= zPenetration;
            velocity.z = 0;
          }
        } else {
          if (yPenetration.abs() > zPenetration.abs()) {
            dY -= yPenetration;
            velocity.y = 0;
          } else {
            dZ -= zPenetration;
            velocity.z = 0;
          }
        }
      }
    }

    pos.x += dX;
    pos.y += dY;
    pos.z += dZ;

    if ((pos.y.round() - pos.y).abs() < 1e-5 &&
        world.chunks.blockAt(DiscretePosition.floor(pos.value) - DiscretePosition(0, 1, 0)) != 0) {
      collider.onGround = true;
    }

    // --- apply drag ---

    if (collider.onGround) {
      velocity.value.scale(.8);
    } else {
      velocity.x *= .98;
      velocity.y *= .995;
      velocity.z *= .98;
    }

    if (velocity.value.length2 < .0005) velocity.value.setZero();
  }
}
