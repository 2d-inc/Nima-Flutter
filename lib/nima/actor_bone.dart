import "actor.dart";
import "actor_bone_base.dart";
import "actor_component.dart";
import "actor_node.dart";
import "jelly_component.dart";
import "readers/stream_reader.dart";

class ActorBone extends ActorBoneBase {
  ActorBone _firstBone;
  JellyComponent jelly;

  ActorBone get firstBone {
    return _firstBone;
  }

  @override
  ActorComponent makeInstance(Actor resetActor) {
    ActorBone instanceNode = ActorBone();
    instanceNode.copyBoneBase(this, resetActor);
    return instanceNode;
  }

  @override
  void completeResolve() {
    super.completeResolve();
    if (children == null) {
      return;
    }
    for (final ActorNode node in children) {
      if (node is ActorBone) {
        _firstBone = node;
        return;
      }
    }
  }

  static ActorBone read(Actor actor, StreamReader reader, ActorBone node) {
    node ??= ActorBone();
    ActorBoneBase.read(actor, reader, node);
    return node;
  }
}
