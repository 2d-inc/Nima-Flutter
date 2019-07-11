import "dart:async";
import "dart:typed_data";
import "dart:ui" as ui;
import "package:flutter/services.dart" show rootBundle;
import "nima/actor.dart";
import "nima/actor_component.dart";
import "nima/actor_image.dart";
import "nima/math/aabb.dart";

typedef void DrawCallback(ui.Canvas canvas);

class FlutterActorImage extends ActorImage {
  Float32List _vertexBuffer;
  Float32List _uvBuffer;
  ui.Paint _paint;
  ui.Vertices _canvasVertices;
  Uint16List _indices;
  DrawCallback onDraw;

  final Float64List _identityMatrix = Float64List.fromList(<double>[
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0
  ]);

  set textureIndex(int value) {
    if (textureIndex != value) {
      _paint = ui.Paint()
        ..shader = ui.ImageShader((actor as FlutterActor).images[textureIndex],
            ui.TileMode.clamp, ui.TileMode.clamp, _identityMatrix);
      _paint.filterQuality = ui.FilterQuality.low;
      _paint.isAntiAlias = true;
    }
  }

  void dispose() {
    _uvBuffer = null;
    _vertexBuffer = null;
    _indices = null;
    _paint = null;
  }

  void init() {
    if (triangles == null) {
      return;
    }
    _vertexBuffer = makeVertexPositionBuffer();
    _uvBuffer = makeVertexUVBuffer();
    _indices =
        Uint16List.fromList(triangles); // nima runtime loads 16 bit indices
    updateVertexUVBuffer(_uvBuffer);
    int count = vertexCount;
    int idx = 0;
    ui.Image image = (actor as FlutterActor).images[textureIndex];

    // SKIA requires texture coordinates in full image space, 
	// not traditional normalized uv coordinates.
    for (int i = 0; i < count; i++) {
      _uvBuffer[idx] = _uvBuffer[idx] * image.width;
      _uvBuffer[idx + 1] = _uvBuffer[idx + 1] * image.height;
      idx += 2;
    }

    if (sequenceUVs != null) {
      for (int i = 0; i < sequenceUVs.length; i++) {
        sequenceUVs[i++] *= image.width;
        sequenceUVs[i] *= image.height;
      }
    }

    _paint = ui.Paint()
      ..shader = ui.ImageShader((actor as FlutterActor).images[textureIndex],
          ui.TileMode.clamp, ui.TileMode.clamp, _identityMatrix);
    _paint.filterQuality = ui.FilterQuality.low;
    _paint.isAntiAlias = true;
  }

  void updateVertices() {
    if (triangles == null) {
      return;
    }
    updateVertexPositionBuffer(_vertexBuffer, false);

    //Float32List test = new Float32List.fromList([64.0, 32.0, 0.0, 224.0, 128.0, 224.0]);
    //Int32List colorTest = new Int32List.fromList([const ui.Color.fromARGB(255, 0, 255, 0).value, const ui.Color.fromARGB(255, 0, 255, 0).value, const ui.Color.fromARGB(255, 0, 255, 0).value]);
    //_canvasVertices = new ui.Vertices.raw(ui.VertexMode.triangles, test, colors:colorTest /*textureCoordinates: _uvBuffer, indices: _indices*/);
    //int uvOffset;

    if (sequenceUVs != null) {
      int framesCount = sequenceFrames.length;
      int currentFrame = sequenceFrame % framesCount;

      SequenceFrame sf = sequenceFrames[currentFrame];
      //uvOffset = sf.offset;
      textureIndex = sf.atlasIndex;

      int uvStride = 8;
      int uvRow = currentFrame * uvStride;
      Iterable<double> it = sequenceUVs.getRange(uvRow, uvRow + uvStride);
      List<double> uvList = List.from(it);
      _uvBuffer = Float32List.fromList(uvList);
    }
    _canvasVertices = ui.Vertices.raw(ui.VertexMode.triangles, _vertexBuffer,
        indices: _indices, textureCoordinates: _uvBuffer);
  }

  void draw(ui.Canvas canvas, double opacity) {
    if (triangles == null ||
        renderCollapsed ||
        opacity <= 0 ||
        _canvasVertices == null) {
      return;
    }
    _paint.color = _paint.color.withOpacity(renderOpacity * opacity);
    _paint.isAntiAlias = true;
    canvas.drawVertices(_canvasVertices, ui.BlendMode.srcOver, _paint);
    if (onDraw != null) {
      onDraw(canvas);
    }
  }

  @override
  ActorComponent makeInstance(Actor resetActor) {
    FlutterActorImage instanceNode = FlutterActorImage();
    instanceNode.copyImage(this, resetActor);
    return instanceNode;
  }

  AABB computeAABB() {
    updateVertices();

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    int readIdx = 0;
    if (_vertexBuffer != null) {
      int nv = _vertexBuffer.length ~/ 2;

      for (int i = 0; i < nv; i++) {
        double x = _vertexBuffer[readIdx++];
        double y = _vertexBuffer[readIdx++];
        if (x < minX) {
          minX = x;
        }
        if (y < minY) {
          minY = y;
        }
        if (x > maxX) {
          maxX = x;
        }
        if (y > maxY) {
          maxY = y;
        }
      }
    }

    return AABB.fromValues(minX, minY, maxX, maxY);
  }
}

class FlutterActor extends Actor {
  bool _isInstance = false;
  List<ui.Image> _images;

  List<ui.Image> get images {
    return _images;
  }

  @override
  ActorImage makeImageNode() {
    return FlutterActorImage();
  }

  Future<bool> loadFromBundle(String filename) async {
    ByteData data = await rootBundle.load(filename);
    super.load(data);

    List<Future<ui.Codec>> waitList = <Future<ui.Codec>>[];
    _images = List<ui.Image>(texturesUsed);

    List atlases = this.atlases;
    bool isOOB =
        atlases != null && atlases.isNotEmpty && atlases.first is String;

    // Support for older runtimes where atlases were always stored externally.
    if (atlases == null) {
      int dotIdx = filename.indexOf(".");
      dotIdx = dotIdx > -1 ? dotIdx : filename.length;
      filename = filename.substring(0, dotIdx);
      for (int i = 0; i < texturesUsed; i++) {
        String atlasFilename;
        if (texturesUsed == 1) {
          atlasFilename = filename + ".png";
        } else {
          atlasFilename = filename + i.toString() + ".png";
        }
        ByteData data = await rootBundle.load(atlasFilename);
        Uint8List list = Uint8List.view(data.buffer);
        waitList.add(ui.instantiateImageCodec(list));
      }
    } else if (isOOB) {
      int pathIdx = filename.lastIndexOf('/') + 1;
      String basePath = filename.substring(0, pathIdx);

      for (int i = 0; i < atlases.length; i++) {
        String atlasPath = basePath + (atlases[i] as String);
        ByteData data = await rootBundle.load(atlasPath);
        Uint8List list = Uint8List.view(data.buffer);
        waitList.add(ui.instantiateImageCodec(list));
      }
    }
    // If the 'atlases' List doesn't contain file paths, it should contain the bytes directly; images are in-band.
    else {
      for (int i = 0; i < atlases.length; i++) {
        waitList.add(ui.instantiateImageCodec(atlases[i] as Uint8List));
      }
    }

    List<ui.Codec> codecs = await Future.wait(waitList);
    List<ui.FrameInfo> frames =
        await Future.wait(codecs.map((codec) => codec.getNextFrame()));
    for (int i = 0; i < frames.length; i++) {
      _images[i] = frames[i].image;
    }

    for (final ActorImage image in imageNodes) {
      if (image is FlutterActorImage) {
        image.init();
      }
    }

    return true;
  }

  @override
  void advance(double seconds) {
    super.advance(seconds);

    for (final ActorImage image in imageNodes) {
      if (image is FlutterActorImage) {
        image.updateVertices();
      }
    }
  }

  void draw(ui.Canvas canvas, [double opacity = 1.0]) {
    // N.B. imageNodes are sorted as necessary by Actor.
    for (final ActorImage image in imageNodes) {
      if (image is FlutterActorImage) {
        image.draw(canvas, opacity);
      }
    }

    // Debug draw bones.
    // for(ActorComponent component in components)
    // {
    // 	if(component is ActorBone)
    // 	{
    // 		ui.Paint paint = new ui.Paint()
    // 							..color = new ui.Color.fromRGBO(255, 0, 0, 1.0)
    // 							..strokeWidth = 5.0
    // 							..style = ui.PaintingStyle.stroke;
    // 		ui.Path p = new ui.Path();
    // 		p.moveTo(component.worldTransform[4], component.worldTransform[5]);
    // 		Vec2D tipWorld = new Vec2D();
    // 		component.getTipWorldTranslation(tipWorld);
    // 		p.lineTo(tipWorld[0], tipWorld[1]);
    // 		canvas.drawPath(p, paint);
    // 	}
    // 	if(component is ActorJellyBone)
    // 	{
    // 		ui.Paint paint = new ui.Paint()
    // 							..color = new ui.Color.fromRGBO(0, 255, 255, 1.0)
    // 							..strokeWidth = 8.0
    // 							..style = ui.PaintingStyle.stroke;
    // 		ui.Path p = new ui.Path();
    // 		p.moveTo(component.worldTransform[4], component.worldTransform[5]);
    // 		Vec2D tipWorld = new Vec2D();
    // 		component.getTipWorldTranslation(tipWorld);
    // 		p.lineTo(tipWorld[0], tipWorld[1]);
    // 		canvas.drawPath(p, paint);
    // 	}
    // }
  }

  set isInstance(bool val) {
    _isInstance = true;
  }

  void dispose() {
    for (final ActorImage img in imageNodes) {
      if (img is FlutterActorImage) {
        img.dispose();
        if (!_isInstance) {
          img.disposeGeometry();
        }
      }
    }
  }

  Actor makeInstance() {
    FlutterActor actorInstance = FlutterActor();
    actorInstance.copyActor(this);
    actorInstance.isInstance = true;
    actorInstance._images = _images;
    for (final ActorImage img in actorInstance.imageNodes) {
      if (img is FlutterActorImage) {
        img.init();
      }
    }
    return actorInstance;
  }

  AABB computeAABB() {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final ActorImage image in imageNodes) {
      if (image is FlutterActorImage) {
        if (image.opacity < 0.01) continue;

        AABB aabb = image.computeAABB();
        if (aabb == null) {
          continue;
        }

        if (aabb[0] < minX) {
          minX = aabb[0];
        }

        if (aabb[1] < minY) {
          minY = aabb[1];
        }

        if (aabb[2] > maxX) {
          maxX = aabb[2];
        }

        if (aabb[3] > maxY) {
          maxY = aabb[3];
        }
      }
    }

    return AABB.fromValues(minX, minY, maxX, maxY);
  }
}
