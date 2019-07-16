## [1.0.5] - 2019-07-16 08:50:43

* Prevent advancing a null actor, which can occur due to a race condition when loading the Nima file.

## [1.0.4] - 2019-07-11 10:00:50

* Fix breaking index buffer format change (from Int32List to Uint16List).
* Lots of static analysis fixes.

## [1.0.3] - 2019-04-09 09:50:41

* Making sure the Nima Actor widget is disposed of properly when the leaf render widet is unmounted or the render box is detached.

## [1.0.0] - 5/5/2018

* Initial release with an example NimaActor widget that implements a LeafRenderObjectWidget that can render a Nima actor. Alignment is done based on the setup axis aligned bounding box.
