import 'package:flutter/material.dart';
import 'package:nima/nima.dart';
import 'package:nima/nima/math/aabb.dart';
import 'dart:math';

class NimaActor extends LeafRenderObjectWidget
{
	final String filename;
	final BoxFit fit;
	final Alignment alignment;

	NimaActor(this.filename, {this.fit, this.alignment = Alignment.center});

	@override
	RenderObject createRenderObject(BuildContext context) 
	{
		return new NimaActorRenderObject()..filename = filename
											..fit = fit
											..alignment = alignment;
	}

	@override
	void updateRenderObject(BuildContext context, covariant NimaActorRenderObject renderObject)
	{
		renderObject..filename = filename
											..fit = fit
											..alignment = alignment;
	}
}

class NimaActorRenderObject extends RenderBox
{
	String _filename;
	BoxFit _fit;
	Alignment _alignment;

	FlutterActor _actor;
	AABB _setupAABB;

	BoxFit get fit => _fit;
	set fit(BoxFit value)
	{
		if(value == _fit)
		{
			return;
		}
		_fit = value;
		markNeedsPaint();
	}

	String get filename => _filename;
	set filename(String value)
	{
		if(_filename == value)
		{
			return;
		}
		_filename = value;
		if(_actor != null)
		{
			_actor.dispose();
			_actor = null;
		}
		if(_filename == null)
		{
			markNeedsPaint();
			return;
		}
		FlutterActor actor = new FlutterActor();

		actor.loadFromBundle(_filename).then((bool success)
		{
			if(success)
			{
				_actor = actor;
				_actor.advance(0.0);
				_setupAABB = _actor.computeAABB();
				markNeedsPaint();
			}
		});
	}

	AlignmentGeometry get alignment => _alignment;
	set alignment(AlignmentGeometry value)
	{
		if(value == _alignment)
		{
			return;
		}
		_alignment = value;
		markNeedsPaint();
	}

	@override
	bool get sizedByParent => true;
	
	@override
	bool hitTestSelf(Offset screenOffset) => true;

	@override
	void performResize() 
	{
		size = constraints.biggest;
	}

	@override
	void performLayout() 
	{
		super.performLayout();
	}

	@override
	void paint(PaintingContext context, Offset offset)
	{
		final Canvas canvas = context.canvas;

		if(_actor != null)
		{
			AABB bounds = _setupAABB;
			double contentHeight = bounds[3] - bounds[1];
			double contentWidth = bounds[2] - bounds[0];
			double x = -bounds[0] - contentWidth/2.0 - (_alignment.x * contentWidth/2.0);
			double y =  -bounds[1] - contentHeight/2.0 + (_alignment.y * contentHeight/2.0);

			double scaleX = 1.0, scaleY = 1.0;

			canvas.save();		
			canvas.clipRect(offset & size);
			
			switch(_fit)
			{
				case BoxFit.fill:
					scaleX = size.width/contentWidth;
					scaleY = size.height/contentHeight;
					break;
				case BoxFit.contain:
					double minScale = min(size.width/contentWidth, size.height/contentHeight);
					scaleX = scaleY = minScale;
					break;
				case BoxFit.cover:
					double maxScale = max(size.width/contentWidth, size.height/contentHeight);
					scaleX = scaleY = maxScale;
					break;
				case BoxFit.fitHeight:
					double minScale = size.height/contentHeight;
					scaleX = scaleY = minScale;
					break;
				case BoxFit.fitWidth:
					double minScale = size.width/contentWidth;
					scaleX = scaleY = minScale;
					break;
				case BoxFit.none:
					scaleX = scaleY = 1.0;
					break;
				case BoxFit.scaleDown:
					double minScale = min(size.width/contentWidth, size.height/contentHeight);
					scaleX = scaleY = minScale < 1.0 ? minScale : 1.0;
					break;
			}
			canvas.translate(offset.dx + size.width/2.0 + (_alignment.x * size.width/2.0), offset.dy + size.height/2.0 + (_alignment.y * size.height/2.0));
			//canvas.translate(offset.dx + size.width/2.0, offset.dy + size.height/2.0);
			//canvas.translate(offset.dx, offset.dy);
			canvas.scale(scaleX, -scaleY);
			canvas.translate(x, y);
			_actor.draw(canvas);
			canvas.restore();
		}
	}
}