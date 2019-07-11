import "value_time_curve_interpolator.dart";
import "../readers/stream_reader.dart";
import "../actor_component.dart";
import "../actor_node.dart";
import "../actor_bone_base.dart";
import "../actor_constraint.dart";
import "../actor_image.dart";
import "../actor.dart";
import "../actor_node_solo.dart";
import "../math/mat2d.dart";
import "dart:collection";
import "dart:typed_data";

abstract class KeyFrameInterpolator {
  bool setNextFrame(KeyFrameWithInterpolation frame, KeyFrame nextFrame);
}

// TODO: CSS style curve interoplation
class ProgressionTimeCurveInterpolator extends KeyFrameInterpolator {
  bool setNextFrame(KeyFrameWithInterpolation frame, KeyFrame nextFrame) {
    return false;
  }
}

enum InterpolationTypes {
  Hold,
  Linear,
  Mirrored,
  Asymmetric,
  Disconnected,
  Progression
}

HashMap<int, InterpolationTypes> interpolationTypesLookup =
    HashMap<int, InterpolationTypes>.fromIterables([
  0,
  1,
  2,
  3,
  4,
  5
], [
  InterpolationTypes.Hold,
  InterpolationTypes.Linear,
  InterpolationTypes.Mirrored,
  InterpolationTypes.Asymmetric,
  InterpolationTypes.Disconnected,
  InterpolationTypes.Progression
]);

abstract class KeyFrame {
  double _time;

  double get time {
    return _time;
  }

  static bool read(StreamReader reader, KeyFrame frame) {
    frame._time = reader.readFloat64("time");

    return true;
  }

  void setNext(KeyFrame frame);
  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix);
  void apply(ActorComponent component, double mix);
}

abstract class KeyFrameWithInterpolation extends KeyFrame {
  InterpolationTypes _interpolationType;
  KeyFrameInterpolator _interpolator;

  InterpolationTypes get interpolationType {
    return _interpolationType;
  }

  KeyFrameInterpolator get interpolator {
    return _interpolator;
  }

  static bool read(StreamReader reader, KeyFrameWithInterpolation frame) {
    if (!KeyFrame.read(reader, frame)) {
      return false;
    }
    int type = reader.readUint8("type");

    InterpolationTypes actualType = interpolationTypesLookup[type];
    if (actualType == null) {
      actualType = InterpolationTypes.Linear;
    }

    frame._interpolationType = actualType;
    switch (frame._interpolationType) {
      case InterpolationTypes.Mirrored:
      case InterpolationTypes.Asymmetric:
      case InterpolationTypes.Disconnected:
      case InterpolationTypes.Hold:
        frame._interpolator =
            ValueTimeCurveInterpolator.read(reader, frame._interpolationType);
        break;

      default:
        frame._interpolator = null;
        break;
    }
    return true;
  }

  void setNext(KeyFrame frame) {
    // Null out the interpolator if the next frame doesn't validate.
    if (_interpolator != null && !_interpolator.setNextFrame(this, frame)) {
      _interpolator = null;
    }
  }
}

abstract class KeyFrameNumeric extends KeyFrameWithInterpolation {
  double _value;

  double get value {
    return _value;
  }

  static bool read(StreamReader reader, KeyFrameNumeric frame) {
    if (!KeyFrameWithInterpolation.read(reader, frame)) {
      return false;
    }
    frame._value = reader.readFloat32("value");
    /*if(frame._interpolator != null)
		{
			// TODO: in the future, this could also be a progression curve.
			ValueTimeCurveInterpolator vtci = frame._interpolator as ValueTimeCurveInterpolator;
			if(vtci != null)
			{
			vtci.SetKeyFrameValue(m_Value);
			}
		}*/
    return true;
  }

  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix) {
    if (_interpolator != null && _interpolator is ValueTimeCurveInterpolator) {
      double v = (_interpolator as ValueTimeCurveInterpolator).get(time);
      setValue(component, v, mix);
    } else {
      switch (_interpolationType) {
        case InterpolationTypes.Hold:
          {
            setValue(component, _value, mix);
            break;
          }

        case InterpolationTypes.Linear:
          {
            KeyFrameNumeric to = toFrame as KeyFrameNumeric;

            double f = (time - _time) / (to._time - _time);
            setValue(component, _value * (1.0 - f) + to._value * f, mix);
            break;
          }

        default:
          // Not handled, interpolator must be a valuetimecuve or hold/linear.
          break;
      }
    }
  }

  void apply(ActorComponent component, double mix) {
    setValue(component, _value, mix);
  }

  void setValue(ActorComponent component, double value, double mix);

  @override
  void setNext(KeyFrame frame) {
    // Special case where we are linear but the next frame has in curve values
    if (frame != null &&
        _interpolationType == InterpolationTypes.Linear &&
        frame is KeyFrameWithInterpolation &&
        frame.interpolator is ValueTimeCurveInterpolator) {
      // Linear cubic interpolator, so that we can set it up with the next frame.
      _interpolator =
          ValueTimeCurveInterpolator.fromValues(0.0, _value, 0.0, _value);
    }

    super.setNext(frame);
  }
}

abstract class KeyFrameInt extends KeyFrameWithInterpolation {
  double _value;

  double get value {
    return _value;
  }

  static bool read(StreamReader reader, KeyFrameInt frame) {
    if (!KeyFrameWithInterpolation.read(reader, frame)) {
      return false;
    }
    frame._value = reader.readInt32("value").toDouble();
    return true;
  }

  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix) {
    switch (_interpolationType) {
      case InterpolationTypes.Mirrored:
      case InterpolationTypes.Asymmetric:
      case InterpolationTypes.Disconnected:
        {
          ValueTimeCurveInterpolator interpolator =
              _interpolator as ValueTimeCurveInterpolator;
          if (interpolator != null) {
            double v = interpolator.get(time);
            setValue(component, v, mix);
          }
          break;
        }

      case InterpolationTypes.Hold:
        {
          setValue(component, _value, mix);
          break;
        }

      case InterpolationTypes.Linear:
        {
          KeyFrameInt to = toFrame as KeyFrameInt;

          double f = (time - _time) / (to._time - _time);
          setValue(component, _value * (1.0 - f) + to._value * f, mix);
          break;
        }

      default:
        break;
    }
  }

  void apply(ActorComponent component, double mix) {
    setValue(component, _value, mix);
  }

  void setValue(ActorComponent component, double value, double mix);
}

class KeyFrameIntProperty extends KeyFrameInt {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameIntProperty frame = KeyFrameIntProperty();
    if (KeyFrameInt.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  void setValue(ActorComponent component, double value, double mix) {
    // TODO
    //CustomIntProperty node = component as CustomIntProperty;
    //node.value = (node.value * (1.0 - mix) + value * mix).round();
  }
}

class KeyFrameFloatProperty extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameFloatProperty frame = KeyFrameFloatProperty();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  void setValue(ActorComponent component, double value, double mix) {
    // TODO
    // CustomFloatProperty node = component as CustomFloatProperty;
    // node.value = node.value * (1.0 - mix) + value * mix;
  }
}

class KeyFrameStringProperty extends KeyFrame {
  String _value;
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameStringProperty frame = KeyFrameStringProperty();
    if (!KeyFrame.read(reader, frame)) {
      return null;
    }
    frame._value = reader.readString("value");
    return frame;
  }

  @override
  void setNext(KeyFrame frame) {
    // Do nothing.
  }

  @override
  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix) {
    apply(component, mix);
  }

  @override
  void apply(ActorComponent component, double mix) {
    // CustomStringProperty prop = component as CustomStringProperty;
    // prop.value = _value;
  }
}

class KeyFrameBooleanProperty extends KeyFrame {
  bool _value;
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameBooleanProperty frame = KeyFrameBooleanProperty();
    if (!KeyFrame.read(reader, frame)) {
      return null;
    }
    frame._value = reader.readBool("value");
    return frame;
  }

  @override
  void setNext(KeyFrame frame) {
    // Do nothing.
  }

  @override
  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix) {
    apply(component, mix);
  }

  @override
  void apply(ActorComponent component, double mix) {
    // CustomBooleanProperty prop = component as CustomBooleanProperty;
    // prop.value = _value;
  }
}

class KeyFrameCollisionEnabledProperty extends KeyFrame {
  bool _value;
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameCollisionEnabledProperty frame = KeyFrameCollisionEnabledProperty();
    if (!KeyFrame.read(reader, frame)) {
      return null;
    }
    frame._value = reader.readBool("value");
    return frame;
  }

  @override
  void setNext(KeyFrame frame) {
    // Do nothing.
  }

  @override
  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix) {
    apply(component, mix);
  }

  @override
  void apply(ActorComponent component, double mix) {
    // ActorCollider collider = component as ActorCollider;
    // collider.isCollisionEnabled = _value;
  }
}

class KeyFramePosX extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFramePosX frame = KeyFramePosX();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  @override
  void setValue(ActorComponent component, double value, double mix) {
    ActorNode node = component as ActorNode;
    node.x = node.x * (1.0 - mix) + value * mix;
  }
}

class KeyFramePosY extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFramePosY frame = KeyFramePosY();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  @override
  void setValue(ActorComponent component, double value, double mix) {
    ActorNode node = component as ActorNode;
    node.y = node.y * (1.0 - mix) + value * mix;
  }
}

class KeyFrameScaleX extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameScaleX frame = KeyFrameScaleX();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  @override
  void setValue(ActorComponent component, double value, double mix) {
    ActorNode node = component as ActorNode;
    node.scaleX = node.scaleX * (1.0 - mix) + value * mix;
  }
}

class KeyFrameScaleY extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameScaleY frame = KeyFrameScaleY();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  @override
  void setValue(ActorComponent component, double value, double mix) {
    ActorNode node = component as ActorNode;
    node.scaleY = node.scaleY * (1.0 - mix) + value * mix;
  }
}

class KeyFrameRotation extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameRotation frame = KeyFrameRotation();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  @override
  void setValue(ActorComponent component, double value, double mix) {
    ActorNode node = component as ActorNode;
    node.rotation = node.rotation * (1.0 - mix) + value * mix;
  }
}

class KeyFrameOpacity extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameOpacity frame = KeyFrameOpacity();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  @override
  void setValue(ActorComponent component, double value, double mix) {
    ActorNode node = component as ActorNode;
    node.opacity = node.opacity * (1.0 - mix) + value * mix;
  }
}

class KeyFrameLength extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameLength frame = KeyFrameLength();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  @override
  void setValue(ActorComponent component, double value, double mix) {
    ActorBoneBase bone = component as ActorBoneBase;
    if (bone == null) {
      return;
    }
    bone.length = bone.length * (1.0 - mix) + value * mix;
  }
}

class KeyFrameConstraintStrength extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameConstraintStrength frame = KeyFrameConstraintStrength();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  @override
  void setValue(ActorComponent component, double value, double mix) {
    ActorConstraint constraint = component as ActorConstraint;
    constraint.strength = constraint.strength * (1.0 - mix) + value * mix;
  }
}

class DrawOrderIndex {
  int nodeIdx;
  int order;
}

class KeyFrameDrawOrder extends KeyFrame {
  List<DrawOrderIndex> _orderedNodes;

  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameDrawOrder frame = KeyFrameDrawOrder();

    if (!KeyFrame.read(reader, frame)) {
      return null;
    }

    reader.openArray("drawOrder");
    int numOrderedNodes = reader.readUint16Length();
    frame._orderedNodes = List<DrawOrderIndex>(numOrderedNodes);
    for (int i = 0; i < numOrderedNodes; i++) {
      DrawOrderIndex drawOrder = DrawOrderIndex();
      reader.openObject("frame");
      drawOrder.nodeIdx = reader.readId("component");
      drawOrder.order = reader.readUint16("order");
      frame._orderedNodes[i] = drawOrder;
      reader.closeObject();
    }
    reader.closeArray();
    return frame;
  }

  @override
  void setNext(KeyFrame frame) {
    // Do nothing.
  }

  @override
  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix) {
    apply(component, mix);
  }

  @override
  void apply(ActorComponent component, double mix) {
    Actor actor = component.actor;

    for (final DrawOrderIndex doi in _orderedNodes) {
      ActorImage actorImage = actor[doi.nodeIdx] as ActorImage;
      if (actorImage != null) {
        actorImage.drawOrder = doi.order;
      }
    }
    actor.markImageDrawOrderDirty();
  }
}

class KeyFrameVertexDeform extends KeyFrameWithInterpolation {
  Float32List _vertices;

  Float32List get vertices {
    return _vertices;
  }

  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameVertexDeform frame = KeyFrameVertexDeform();
    if (!KeyFrameWithInterpolation.read(reader, frame)) {
      return null;
    }

    ActorImage imageNode = component as ActorImage;
    frame._vertices = Float32List(imageNode.vertexCount * 2);
    reader.readFloat32ArrayOffset(
        frame._vertices, frame._vertices.length, 0, "value");

    imageNode.doesAnimationVertexDeform = true;

    return frame;
  }

  void transformVertices(Mat2D wt) {
    int aiVertexCount = _vertices.length ~/ 2;
    Float32List fv = _vertices;

    int vidx = 0;
    for (int j = 0; j < aiVertexCount; j++) {
      double x = fv[vidx];
      double y = fv[vidx + 1];

      fv[vidx] = wt[0] * x + wt[2] * y + wt[4];
      fv[vidx + 1] = wt[1] * x + wt[3] * y + wt[5];

      vidx += 2;
    }
  }

  @override
  void setNext(KeyFrame frame) {
    // Do nothing.
  }

  @override
  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix) {
    ActorImage imageNode = component as ActorImage;
    Float32List wr = imageNode.animationDeformedVertices;
    Float32List to = (toFrame as KeyFrameVertexDeform)._vertices;
    int l = _vertices.length;

    double f = (time - _time) / (toFrame.time - _time);
    double fi = 1.0 - f;
    if (mix == 1.0) {
      for (int i = 0; i < l; i++) {
        wr[i] = _vertices[i] * fi + to[i] * f;
      }
    } else {
      double mixi = 1.0 - mix;
      for (int i = 0; i < l; i++) {
        double v = _vertices[i] * fi + to[i] * f;

        wr[i] = wr[i] * mixi + v * mix;
      }
    }

    imageNode.isVertexDeformDirty = true;
  }

  @override
  void apply(ActorComponent component, double mix) {
    ActorImage imageNode = component as ActorImage;
    int l = _vertices.length;
    Float32List wr = imageNode.animationDeformedVertices;
    if (mix == 1.0) {
      for (int i = 0; i < l; i++) {
        wr[i] = _vertices[i];
      }
    } else {
      double mixi = 1.0 - mix;
      for (int i = 0; i < l; i++) {
        wr[i] = wr[i] * mixi + _vertices[i] * mix;
      }
    }

    imageNode.isVertexDeformDirty = true;
  }
}

class KeyFrameTrigger extends KeyFrame {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameTrigger frame = KeyFrameTrigger();
    if (!KeyFrame.read(reader, frame)) {
      return null;
    }
    return frame;
  }

  @override
  void setNext(KeyFrame frame) {
    // Do nothing.
  }

  @override
  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix) {}

  @override
  void apply(ActorComponent component, double mix) {}
}

class KeyFrameActiveChild extends KeyFrame {
  int _value;

  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameActiveChild frame = KeyFrameActiveChild();
    if (!KeyFrame.read(reader, frame)) {
      return null;
    }
    frame._value = reader.readFloat32("value").toInt();
    return frame;
  }

  @override
  void setNext(KeyFrame frame) {
    // No Interpolation
  }

  @override
  void applyInterpolation(
      ActorComponent component, double time, KeyFrame toFrame, double mix) {
    apply(component, mix);
  }

  @override
  void apply(ActorComponent component, double mix) {
    ActorNodeSolo soloNode = component as ActorNodeSolo;
    soloNode.activeChildIndex = _value;
  }
}

class KeyFrameSequence extends KeyFrameNumeric {
  static KeyFrame read(StreamReader reader, ActorComponent component) {
    KeyFrameSequence frame = KeyFrameSequence();
    if (KeyFrameNumeric.read(reader, frame)) {
      return frame;
    }
    return null;
  }

  @override
  void setValue(ActorComponent component, double value, double mix) {
    ActorImage node = component as ActorImage;
    int frameIndex = value.floor() % node.sequenceFrames.length;
    if (frameIndex < 0) {
      frameIndex += node.sequenceFrames.length;
    }
    node.sequenceFrame = frameIndex;
  }
}
