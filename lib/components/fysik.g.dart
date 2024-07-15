// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fysik.dart';

// **************************************************************************
// SystemGenerator
// **************************************************************************

abstract class _$NoclipPhysicsSystem extends EntitySystem {
  late final Mapper<Position> positionMapper;
  late final Mapper<Velocity> velocityMapper;
  late final Mapper<MovementInput> movementInputMapper;
  late final Mapper<NoclipPhysics> noclipPhysicsMapper;
  _$NoclipPhysicsSystem()
      : super(Aspect.empty()
          ..allOf([Position, Velocity, MovementInput, NoclipPhysics]));
  @override
  void initialize() {
    super.initialize();
    positionMapper = Mapper<Position>(world);
    velocityMapper = Mapper<Velocity>(world);
    movementInputMapper = Mapper<MovementInput>(world);
    noclipPhysicsMapper = Mapper<NoclipPhysics>(world);
  }

  @override
  void processEntities(Iterable<int> entities) {
    final positionMapper = this.positionMapper;
    final velocityMapper = this.velocityMapper;
    final movementInputMapper = this.movementInputMapper;
    final noclipPhysicsMapper = this.noclipPhysicsMapper;
    for (final entity in entities) {
      processEntity(entity, positionMapper[entity], velocityMapper[entity],
          movementInputMapper[entity], noclipPhysicsMapper[entity]);
    }
  }

  void processEntity(int entity, Position position, Velocity velocity,
      MovementInput movementInput, NoclipPhysics noclipPhysics);
}

abstract class _$ColliderPhysicsSystem extends EntitySystem {
  late final Mapper<Position> positionMapper;
  late final Mapper<Velocity> velocityMapper;
  late final Mapper<MovementInput> movementInputMapper;
  late final Mapper<AabbCollider> aabbColliderMapper;
  _$ColliderPhysicsSystem()
      : super(Aspect.empty()
          ..allOf([Position, Velocity, MovementInput, AabbCollider]));
  @override
  void initialize() {
    super.initialize();
    positionMapper = Mapper<Position>(world);
    velocityMapper = Mapper<Velocity>(world);
    movementInputMapper = Mapper<MovementInput>(world);
    aabbColliderMapper = Mapper<AabbCollider>(world);
  }

  @override
  void processEntities(Iterable<int> entities) {
    final positionMapper = this.positionMapper;
    final velocityMapper = this.velocityMapper;
    final movementInputMapper = this.movementInputMapper;
    final aabbColliderMapper = this.aabbColliderMapper;
    for (final entity in entities) {
      processEntity(entity, positionMapper[entity], velocityMapper[entity],
          movementInputMapper[entity], aabbColliderMapper[entity]);
    }
  }

  void processEntity(int entity, Position position, Velocity velocity,
      MovementInput movementInput, AabbCollider aabbCollider);
}
