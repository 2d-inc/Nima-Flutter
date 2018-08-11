# Flutter + Nima IK
Example app showing how to manipulate an actor using a controller written in Dart.

<img width="400" alt="portfolio_view" src="https://github.com/2d-inc/Nima-Flutter/raw/master/example/ik/example%20images/viejo_example.gif">

## Intro
The purpose of this example is to show how you can manipulate elements in the hierarchy programmatically at run time in Flutter.

## Assets
The included example asset comes from a fairly complex rig:

<img width="400" alt="portfolio_view" src="https://github.com/2d-inc/Nima-Flutter/raw/master/example/ik/example%20images/Old Man Rig.png">

Even though the rig is complex, controlling it is easy. Moving the ctrl_shoot node will make the character point towards the target. A bullseye image has been added to the target to make the target visible.

Note that the ctrl_shoot isn't allowed to go above the horizon line (the horizontal origin) as the alignment of the bones in the rig wouldn't work in this case. This is done using the Translation Constraint applied to the ctrl_shoot node with a Max Value of 0. The complexity of this rig and how it works is the subject for another article!

## Controller
The NimaActor widget has a new property called controller which expects an object inheriting the NimaController interface. This interface allows for initializing the controller, advancing the controller (called before the actual rig is updated but after any NimaActor widget animations are applied). The controller allows you to apply programmatic logic to your actor. This could be custom animating, mixing animations, transforming images/nodes/etc. In this example we show how to translate the ctrl_shoot node such that it aligns with the touch coordinates of the screen.

The interface for a controller looks like this:
```
abstract class NimaController
{
    // use this method to find parts of the hierarchy, animations, etc that you can do once at init
    void initialize(FlutterActor actor);

    // set the view transform used by the NimaActor widget to draw the actor to the screen.
    void setViewTransform(Mat2D viewTransform);

    // perform any logic necessary prior to advancing the actor (running constraints/solvers/etc like IK)
    void advance(FlutterActor actor, double elapsed);
}
```

The specific implementation of the controller for this example is in [aim_controller.dart](https://github.com/2d-inc/Nima-Flutter/tree/master/example/ik/lib/aim_controller.dart).

## License
See the [LICENSE](LICENSE) file for license rights and limitations (MIT).