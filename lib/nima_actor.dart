import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nima/nima.dart';
import 'package:nima/nima/math/aabb.dart';
import 'package:nima/nima/animation/actor_animation.dart';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:nima/nima/math/mat2d.dart';
import 'package:nima/nima/math/vec2d.dart';

typedef void NimaAnimationCompleted(String name);

abstract class NimaController
{
	void initialize(FlutterActor actor);
	void setViewTransform(Mat2D viewTransform);
	void advance(FlutterActor actor,double elapsed);
}

class NimaActor extends LeafRenderObjectWidget
{
	final String filename;
	final BoxFit fit;
	final Alignment alignment;
	final String animation;
	final double mixSeconds;
	final bool paused;
	final NimaAnimationCompleted completed;
	final NimaController controller;
	final bool clip;

	NimaActor(this.filename, {this.animation, this.fit, this.mixSeconds = 0.2, this.clip=true, this.alignment = Alignment.center, this.paused = false, this.completed, this.controller});

	@override
	RenderObject createRenderObject(BuildContext context) 
	{
		return new NimaActorRenderObject()..filename = filename
											..fit = fit
											..alignment = alignment
											..animationName = animation
											..completed = completed
											..mixSeconds = mixSeconds
											..controller = controller
											..isPlaying = !paused && animation != null
											..clip = clip;
	}

	@override
	void updateRenderObject(BuildContext context, covariant NimaActorRenderObject renderObject)
	{
		renderObject..filename = filename
									..fit = fit
									..alignment = alignment
									..animationName = animation
									..completed = completed
									..mixSeconds = mixSeconds
									..controller = controller
									..isPlaying = !paused && animation != null
									..clip = clip;
	}
}

class NimaAnimationLayer
{
	String name;
	ActorAnimation animation;
	double time = 0.0;
	double mix = 0.0;
}

class NimaActorRenderObject extends RenderBox
{
	String _filename;
	BoxFit _fit;
	Alignment _alignment;
	String _animationName;
	double _mixSeconds = 0.2;
	double _lastFrameTime = 0.0;
	NimaAnimationCompleted _completedCallback;
	NimaController _controller;
	bool _isFrameScheduled = false;

	List<NimaAnimationLayer> _animationLayers = new List<NimaAnimationLayer>();
	bool _isPlaying;

	FlutterActor _actor;
	AABB _setupAABB;

	NimaAnimationCompleted get completed => _completedCallback;
	set completed(NimaAnimationCompleted value)
	{
		if(_completedCallback != value)
		{
			_completedCallback = value;
		}
	}

	void scheduleFrame()
	{
		if(!_isFrameScheduled)
		{
			_isFrameScheduled = true;
			SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
		}
	}
	
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

	bool get isPlaying => _isPlaying;
	set isPlaying(bool value)
	{
		if(_isPlaying == value)
		{
			return;
		}
		_isPlaying = value;
		if(_isPlaying)
		{
			scheduleFrame();
		}
	}

	bool _clip = true;
	bool get clip => _clip;
	set clip(bool value)
	{
		if(_clip == value)
		{
			return;
		}
		_clip = value;
		markNeedsPaint();
	}

	String get animationName => _animationName;
	set animationName(String value)
	{
		if(_animationName == value)
		{
			return;
		}
		_animationName = value;
		_updateAnimation();
	}

	void _updateAnimation({bool onlyWhenMissing = false})
	{
		if(onlyWhenMissing && _animationLayers.length != 0)
		{
			return;
		}
		if(_animationName == null || _actor == null)
		{
			return;
		}
		ActorAnimation animation = _actor.getAnimation(_animationName);
		_animationLayers.add(new NimaAnimationLayer()
												..name = _animationName
												..animation = animation
												..mix = 0.0);
	}

	NimaController get controller => _controller;
	set controller(NimaController control)
	{
		if(_controller == control)
		{
			return;
		}
		_controller = control;
		if(_controller != null && _actor != null)
		{
			_controller.initialize(_actor);
		}
	}

	double get mixSeconds => _mixSeconds;
	set mixSeconds(double seconds)
	{
		if(_mixSeconds != seconds)
		{
			return;
		}
		_mixSeconds = seconds;
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
				if(_controller != null)
				{
					_controller.initialize(_actor);
				}
				_updateAnimation(onlyWhenMissing:true);
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

	void beginFrame(Duration timeStamp)
	{
		final double t = timeStamp.inMicroseconds / Duration.microsecondsPerMillisecond / 1000.0;
		_isFrameScheduled = false;
		if(_lastFrameTime == 0 || _actor == null)
		{
			_lastFrameTime = t;
			scheduleFrame();
			return;
		}

		double elapsedSeconds = t - _lastFrameTime;
		_lastFrameTime = t;

		int lastFullyMixed = -1;
		double lastMix = 0.0;

		List<NimaAnimationLayer> completed = new List<NimaAnimationLayer>();

		for(int i = 0; i < _animationLayers.length; i++)
		{
			NimaAnimationLayer layer = _animationLayers[i];
			layer.mix += elapsedSeconds;
			layer.time += elapsedSeconds;
			
			lastMix = _mixSeconds == null || _mixSeconds == 0.0 ? 1.0 : min(1.0, layer.mix/_mixSeconds);
			if(layer.animation.isLooping)
			{
				layer.time %= layer.animation.duration;
			}
			layer.animation.apply(layer.time, _actor, lastMix);
			if(lastMix == 1.0)
			{
				lastFullyMixed = i;
			}

			if(layer.time > layer.animation.duration)
			{
				completed.add(layer);
			}
		}

		//print("T ${_animationLayers.length} $lastFullyMixed");
		if(lastFullyMixed != -1)
		{
			_animationLayers.removeRange(0, lastFullyMixed);
		}

		if(_animationName == null && _animationLayers.length == 1 && lastMix == 1.0)
		{
			// Remove remaining animation.
			_animationLayers.removeAt(0);
		}

		for(NimaAnimationLayer animation in completed)
		{
			_animationLayers.remove(animation);
			if(_completedCallback != null)
			{
				_completedCallback(animation.name);
			}
		}
		
		if(_controller != null)
		{
			_controller.advance(_actor, elapsedSeconds);
		}

		if(_isPlaying)
		{
			scheduleFrame();
		}
		
		_actor.advance(elapsedSeconds);

		markNeedsPaint();
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
			if(_clip)
			{	
				canvas.clipRect(offset & size);
			}
			
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
			
			if(_controller != null)
			{
				Mat2D transform = new Mat2D();
				transform[4] = offset.dx + size.width/2.0 + (_alignment.x * size.width/2.0);
				transform[5] = offset.dy + size.height/2.0 + (_alignment.y * size.height/2.0);
				Mat2D.scale(transform, transform, new Vec2D.fromValues(scaleX, -scaleY));
				Mat2D center = new Mat2D();
				center[4] = x;
				center[5] = y;
				Mat2D.multiply(transform, transform, center);
				_controller.setViewTransform(transform);
			}

			canvas.translate(offset.dx + size.width/2.0 + (_alignment.x * size.width/2.0), offset.dy + size.height/2.0 + (_alignment.y * size.height/2.0));
			canvas.scale(scaleX, -scaleY);
			canvas.translate(x, y);
			_actor.draw(canvas);
			canvas.restore();
		}
	}
}