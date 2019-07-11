import "actor.dart";
import "actor_node.dart";
import "actor_targeted_constraint.dart";
import "math/mat2d.dart";
import "math/vec2d.dart";
import "readers/stream_reader.dart";

class DistanceMode {
  static const int Closer = 0;
  static const int Further = 1;
  static const int Exact = 2;
}

class ActorDistanceConstraint extends ActorTargetedConstraint {
  double _distance = 100.0;
  int _mode = DistanceMode.Closer;

  ActorDistanceConstraint() : super();

  static ActorDistanceConstraint read(
      Actor actor, StreamReader reader, ActorDistanceConstraint component) {
    component ??= ActorDistanceConstraint();
    ActorTargetedConstraint.read(actor, reader, component);

    component._distance = reader.readFloat32("distance");
    component._mode = reader.readUint8("modeId");

    return component;
  }

  @override
  ActorDistanceConstraint makeInstance(Actor resetActor) {
    ActorDistanceConstraint node = ActorDistanceConstraint();
    node.copyDistanceConstraint(this, resetActor);
    return node;
  }

  void copyDistanceConstraint(ActorDistanceConstraint node, Actor resetActor) {
    copyTargetedConstraint(node, resetActor);
    _distance = node._distance;
    _mode = node._mode;
  }

  @override
  void constrain(ActorNode node) {
    ActorNode t = target as ActorNode;
    if (t == null) {
      return;
    }

    ActorNode p = parent;
    Vec2D targetTranslation = t.getWorldTranslation(Vec2D());
    Vec2D ourTranslation = p.getWorldTranslation(Vec2D());

    Vec2D toTarget = Vec2D.subtract(Vec2D(), ourTranslation, targetTranslation);
    double currentDistance = Vec2D.length(toTarget);
    switch (_mode) {
      case DistanceMode.Closer:
        if (currentDistance < _distance) {
          return;
        }
        break;

      case DistanceMode.Further:
        if (currentDistance > _distance) {
          return;
        }
        break;
    }

    if (currentDistance < 0.001) {
      return;
    }

    Vec2D.scale(toTarget, toTarget, 1.0 / currentDistance);
    Vec2D.scale(toTarget, toTarget, _distance);

    Mat2D world = p.worldTransform;
    Vec2D position = Vec2D.lerp(Vec2D(), ourTranslation,
        Vec2D.add(Vec2D(), targetTranslation, toTarget), strength);
    world[4] = position[0];
    world[5] = position[1];
  }

  @override
  void update(int dirt) {}
  @override
  void completeResolve() {}

  double get distance => _distance;
  int get mode => _mode;

  set distance(double d) {
    if (_distance != d) {
      _distance = d;
      markDirty();
    }
  }

  set mode(int m) {
    if (_mode != m) {
      _mode = m;
      markDirty();
    }
  }
}
