import "package:flutter/services.dart" show rootBundle;
import "nima/math/vec2d.dart";
import "nima/actor_bone.dart";
import "nima/actor_jelly_bone.dart";
import "nima/actor.dart";
import "nima/actor_image.dart";
import "nima/actor_component.dart";
import "dart:async";
import "dart:typed_data";
import "dart:ui" as ui;
import "nima/math/aabb.dart";

typedef void DrawCallback(ui.Canvas canvas);

class FlutterActorImage extends ActorImage
{
	Float32List _vertexBuffer;
	Float32List _uvBuffer;
	ui.Paint _paint;
	ui.Vertices _canvasVertices;
	Int32List _indices;
	DrawCallback onDraw;

	final Float64List _identityMatrix = new Float64List.fromList(<double>[
			1.0, 0.0, 0.0, 0.0,
			0.0, 1.0, 0.0, 0.0,
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0
		]);

	set textureIndex(int value)
	{
		if(this.textureIndex != value)
		{
			_paint = new ui.Paint()..shader = new ui.ImageShader((actor as FlutterActor).images[textureIndex], ui.TileMode.clamp, ui.TileMode.clamp, _identityMatrix);
			_paint.filterQuality = ui.FilterQuality.low;
			_paint.isAntiAlias = true;
		}
	}

    void dispose()
    {
        _uvBuffer = null;
        _vertexBuffer = null;
        _indices = null;
        _paint = null;
    }

	void init()
	{
		if(triangles == null)
		{
			return;
		}
		_vertexBuffer = makeVertexPositionBuffer();
		_uvBuffer = makeVertexUVBuffer();
		_indices = new Int32List.fromList(triangles); // nima runtime loads 16 bit indices
		updateVertexUVBuffer(_uvBuffer);
		int count = vertexCount;
		int idx = 0;
		ui.Image image = (actor as FlutterActor).images[textureIndex];
		
		// SKIA requires texture coordinates in full image space, not traditional normalized uv coordinates.
		for(int i = 0; i < count; i++)
		{
			_uvBuffer[idx] = _uvBuffer[idx]*image.width;
			_uvBuffer[idx+1] = _uvBuffer[idx+1]*image.height;
			idx += 2;
		}

		if(this.sequenceUVs != null)
		{
			for(int i = 0; i < this.sequenceUVs.length; i++)
			{
				this.sequenceUVs[i++] *= image.width;
				this.sequenceUVs[i] *= image.height;
			}
		}

		_paint = new ui.Paint()..shader = new ui.ImageShader((actor as FlutterActor).images[textureIndex], ui.TileMode.clamp, ui.TileMode.clamp, _identityMatrix);
		_paint.filterQuality = ui.FilterQuality.low;
		_paint.isAntiAlias = true;

	}

	void updateVertices()
	{
		if(triangles == null)
		{
			return;
		}
		updateVertexPositionBuffer(_vertexBuffer, false);
		
		//Float32List test = new Float32List.fromList([64.0, 32.0, 0.0, 224.0, 128.0, 224.0]);
		//Int32List colorTest = new Int32List.fromList([const ui.Color.fromARGB(255, 0, 255, 0).value, const ui.Color.fromARGB(255, 0, 255, 0).value, const ui.Color.fromARGB(255, 0, 255, 0).value]);
		//_canvasVertices = new ui.Vertices.raw(ui.VertexMode.triangles, test, colors:colorTest /*textureCoordinates: _uvBuffer, indices: _indices*/);
		int uvOffset;

		if(this.sequenceUVs != null)
		{
			int framesCount = this.sequenceFrames.length;
			int currentFrame = this.sequenceFrame % framesCount;

			SequenceFrame sf = this.sequenceFrames[currentFrame];
			uvOffset = sf.offset;
			textureIndex = sf.atlasIndex;

			int uvStride = 8;
			int uvRow = currentFrame * uvStride;
			Iterable<double> it = this.sequenceUVs.getRange(uvRow, uvRow + uvStride);
			List<double> uvList = new List.from(it);
			_uvBuffer = new Float32List.fromList(uvList);
		}
		_canvasVertices = new ui.Vertices.raw(ui.VertexMode.triangles, _vertexBuffer, indices: _indices, textureCoordinates: _uvBuffer);
	}

	draw(ui.Canvas canvas, double opacity)
	{
		if(triangles == null || this.renderCollapsed || opacity <= 0 || _canvasVertices == null)
		{
			return;
		}
		_paint.color = _paint.color.withOpacity(this.renderOpacity*opacity);
		_paint.isAntiAlias = true;
		canvas.drawVertices(_canvasVertices, ui.BlendMode.srcOver, _paint);
		if(onDraw != null)
		{
			onDraw(canvas);
		}
	}

	ActorComponent makeInstance(Actor resetActor)
	{
		FlutterActorImage instanceNode = new FlutterActorImage();
		instanceNode.copyImage(this, resetActor);
		return instanceNode;
	}

	AABB computeAABB()
	{
		this.updateVertices();
		
		double min_x = double.infinity;
		double min_y = double.infinity;
		double max_x = double.negativeInfinity;
		double max_y = double.negativeInfinity;

		int readIdx = 0;
		if(_vertexBuffer != null)
		{
			int nv = _vertexBuffer.length ~/ 2;

			for(int i = 0; i < nv; i++)
			{
				double x = _vertexBuffer[readIdx++];
				double y = _vertexBuffer[readIdx++];
				if(x < min_x)
				{
					min_x = x;
				}
				if(y < min_y)
				{
					min_y = y;
				}
				if(x > max_x)
				{
					max_x = x;
				}
				if(y > max_y)
				{
					max_y = y;
				}
			}
		}

		return new AABB.fromValues(min_x, min_y, max_x, max_y);
	}
}

class FlutterActor extends Actor
{
	bool _isInstance = false;
	List<ui.Image> _images;

	List<ui.Image> get images
	{
		return _images;
	}

	ActorImage makeImageNode()
	{
		return new FlutterActorImage();
	}

	Future<bool> loadFromBundle(String filename) async
	{
		ByteData data = await rootBundle.load(filename);
		super.load(data);

		List<Future<ui.Codec>> waitList = new List<Future<ui.Codec>>();
		_images = new List<ui.Image>(this.texturesUsed);

        List atlases = this.atlases;
        bool isOOB = atlases != null && atlases.length > 0 && atlases.first is String;

        // Support for older runtimes where atlases were always stored externally.
        if(atlases == null)
        {
            for(int i = 0; i < this.texturesUsed; i++)
            {
                String atlasFilename;
                if(this.texturesUsed == 1)
                {
                    int dotIdx = filename.indexOf(".");
                    dotIdx = dotIdx > -1 ? dotIdx : filename.length;
                    filename = filename.substring(0, dotIdx);
                    atlasFilename = filename + ".png";
                }
                else
                {
                    atlasFilename = filename + i.toString() + ".png";
                }
                ByteData data = await rootBundle.load(atlasFilename);
                Uint8List list = new Uint8List.view(data.buffer);
                waitList.add(ui.instantiateImageCodec(list));
            }
        }
        else if(isOOB)
        {
            int pathIdx = filename.lastIndexOf('/') + 1;
            String basePath = filename.substring(0, pathIdx);

            for(int i = 0; i < atlases.length; i++)
            {
                String atlasPath = basePath + atlases[i];
                ByteData data = await rootBundle.load(atlasPath);
                Uint8List list = new Uint8List.view(data.buffer);
                waitList.add(ui.instantiateImageCodec(list));
            }
        }
        // If the 'atlases' List doesn't contain file paths, it should contain the bytes directly; images are in-band.
        else 
        {
            for(int i = 0; i < atlases.length; i++)
            {
                waitList.add(ui.instantiateImageCodec(atlases[i]));
            }
        }

		List<ui.Codec> codecs = await Future.wait(waitList);
		List<ui.FrameInfo> frames = await Future.wait(codecs.map((codec) => codec.getNextFrame()));
		for(int i = 0; i < frames.length; i++)
		{
			_images[i] = frames[i].image;
		}

		for(FlutterActorImage image in imageNodes)
		{
			image.init();
		}

		return true;
	}

	void advance(double seconds)
	{
		super.advance(seconds);

		for(FlutterActorImage image in imageNodes)
		{
			image.updateVertices();
		}
	}

	draw(ui.Canvas canvas, [double opacity=1.0])
	{
		// N.B. imageNodes are sorted as necessary by Actor.
		for(FlutterActorImage image in imageNodes)
		{
			image.draw(canvas, opacity);
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

	set isInstance(bool val)
	{
		this._isInstance = true;
	}

    dispose()
    {
        for(FlutterActorImage img in imageNodes)
        {
            img.dispose();
            if(!_isInstance)
            {
                img.disposeGeometry();
            }
        }
    }

	Actor makeInstance()
	{
		FlutterActor actorInstance = new FlutterActor();
		actorInstance.copyActor(this);
		actorInstance.isInstance = true;
		actorInstance._images = this._images;
		for(FlutterActorImage img in actorInstance.imageNodes)
		{
			img.init();
		}
		return actorInstance;
	}

	AABB computeAABB()
	{
		double minX = double.infinity;
		double minY = double.infinity;
		double maxX = double.negativeInfinity;
		double maxY = double.negativeInfinity;

		for(FlutterActorImage image in imageNodes)
		{
			if(image.opacity < 0.01) continue;

			AABB aabb = image.computeAABB();
			if(aabb == null)
			{
				continue;
			}

			if(aabb[0] < minX)
			{
				minX = aabb[0];
			}

			if(aabb[1] < minY)
			{
				minY = aabb[1];
			}

			if(aabb[2] > maxX)
			{
				maxX = aabb[2];
			}

			if(aabb[3] > maxY)
			{
				maxY = aabb[3];
			}
		}

		return new AABB.fromValues(minX, minY, maxX, maxY);
	}

}
