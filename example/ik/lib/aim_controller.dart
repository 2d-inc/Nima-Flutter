import 'dart:ui';
import 'package:nima/nima.dart';
import 'package:nima/nima/actor_node.dart';
import 'package:nima/nima/math/mat2d.dart';
import 'package:nima/nima/math/vec2d.dart';
import 'package:nima/nima_actor.dart';

class AimController implements NimaController {
  Offset _screenTouch;
  Mat2D _viewTransform;
  ActorNode _aimTarget;

  @override
  void advance(FlutterActor actor, double elapsed) {
    if (_aimTarget == null || _screenTouch == null || _viewTransform == null) {
      return;
    }

    // Get inverse of view transform in order to compute world transform of touch coordinates.
    Mat2D inverseViewTransform = Mat2D();
    if (!Mat2D.invert(inverseViewTransform, _viewTransform)) {
      return;
    }

    // Get screen touch coordinates into world space.
    Vec2D worldTouch = Vec2D();
    Vec2D.transformMat2D(
        worldTouch,
        Vec2D.fromValues(_screenTouch.dx, _screenTouch.dy),
        inverseViewTransform);

    // Get inverse of target's parent space in order to compute proper local values for the target translation.
    Mat2D inverseTargetWorld = Mat2D();
    if (!Mat2D.invert(inverseTargetWorld, _aimTarget.parent.worldTransform)) {
      return;
    }

    Vec2D localTouchCoordinates = Vec2D();
    Vec2D.transformMat2D(localTouchCoordinates, worldTouch, inverseTargetWorld);

    // Set the target's translation to the computed local coords.
    _aimTarget.translation = localTouchCoordinates;
  }

  @override
  void initialize(FlutterActor actor) {
    _aimTarget = actor.getNode("ctrl_shoot");
  }

  void touchScreen(Offset offset) {
    _screenTouch = offset;
  }

  void setViewTransform(Mat2D viewTransform) {
    _viewTransform = viewTransform;
  }
}
