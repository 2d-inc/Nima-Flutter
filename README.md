# Nima-Flutter
Flutter runtime written in Dart with SKIA based rendering.

## Installation
Add `nima` as a [dependency in your pubspec.yaml file](https://flutter.io/platform-plugins/).
## Exporting for Flutter
Export from Nima with the Export to Engine menu. In the Engine drop down, choose Generic.

## Adding Assets
Once you've exported your character file. Add the .nima file and and the .png atlas files to your project's [Flutter assets](https://flutter.io/assets-and-images/). 

Make sure the .png files are at the same level as the.nima file. If you renamed your .nima file, make sure to rename your assets accordingly. 

In the future we may opt to package the images into the .nima file as we do for WebGL. [Let us know](https://www.2dimensions.com/forum) if you're in favor of this!

## Example
Take a look at the provided [example application](https://github.com/2d-inc/Nima-Flutter/tree/master/example/hop) for how to use the NimaActor widget with an exported Nima character.

## Usage
The easiest way to get started is by using the provided NimaActor widget. This is a stateless Flutter widget that allows for one Nima character with one active animation playing. You can change the currently playing animation by changing the animation property's name. You can also specify the mixSeconds to determine how long it takes for the animation to interpolate from the previous one. A value of 0 means that it will just pop to the new animation. A value of 0.5 will mean it takes half of a second to fully mix the new animation on top of the old one.

```
import 'package:nima/nima_actor.dart';
class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return new NimaActor("assets/Hop", alignment:Alignment.center, fit:BoxFit.contain, animation:"idle");
  }
}
```

## Advanced Usage
For more advanced usage such as creating views with multiple Nima characters, multiple active animations, and controllers, please refer to the internals of nima_actor.dart to get acquainted with the API. We'll be posting more detailed tutorials and documentation regarding the inner workings of the API soon.
## Contributing
1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request.

## License
See the [LICENSE](LICENSE) file for license rights and limitations (MIT).