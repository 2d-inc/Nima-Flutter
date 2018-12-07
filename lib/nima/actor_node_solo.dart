import "actor.dart";
import "actor_component.dart";
import "actor_node.dart";
import "readers/stream_reader.dart";
import "dart:math";

class ActorNodeSolo extends ActorNode {
  int _activeChildIndex = 0;

  set activeChildIndex(int idx) {
    if (idx != this._activeChildIndex) {
      this.setActiveChildIndex(idx);
    }
  }

  int get activeChildIndex {
    return this._activeChildIndex;
  }

  void setActiveChildIndex(int idx) {
    if (this.children != null) {
      this._activeChildIndex = min(this.children.length, max(0, idx));
      for (int i = 0; i < this.children.length; i++) {
        var child = this.children[i];
        bool cv = (i != (this._activeChildIndex - 1));
        child.collapsedVisibility = cv; // Setter
      }
    }
  }

  ActorComponent makeInstance(Actor resetActor) {
    ActorNodeSolo soloInstance = ActorNodeSolo();
    soloInstance.copySolo(this, resetActor);
    return soloInstance;
  }

  void copySolo(ActorNodeSolo node, Actor resetActor) {
    copyNode(node, resetActor);
    _activeChildIndex = node._activeChildIndex;
  }

  static ActorNodeSolo read(
      Actor actor, StreamReader reader, ActorNodeSolo node) {
    if (node == null) {
      node = ActorNodeSolo();
    }

    ActorNode.read(actor, reader, node);
    node._activeChildIndex = reader.readUint32("activeChild");
    return node;
  }

  void completeResolve() {
    super.completeResolve();
    this.setActiveChildIndex(this.activeChildIndex);
  }
}
