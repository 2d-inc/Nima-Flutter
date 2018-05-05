import 'package:flutter/material.dart';
import 'package:nima/nima.dart';
import 'package:nima/nima/actor_node.dart';
import 'package:nima/nima/math/aabb.dart';
import 'package:nima/nima/animation/actor_animation.dart';
import 'dart:math';
import 'package:flutter/scheduler.dart';

typedef void NimaAnimationCompleted(String name);

class NimaActor extends LeafRenderObjectWidget
{
	final String filename;
	final BoxFit fit;
	final Alignment alignment;
	final String animation;
	final bool paused;
	final NimaAnimationCompleted completed;

	NimaActor(this.filename, {this.animation, this.fit, this.alignment = Alignment.center, this.paused = false, this.completed});

	@override
	RenderObject createRenderObject(BuildContext context) 
	{
		return new NimaActorRenderObject()..filename = filename
											..fit = fit
											..alignment = alignment
											..animationName = animation
											..completed = completed
											..isPlaying = !paused && animation != null;
	}

	@override
	void updateRenderObject(BuildContext context, covariant NimaActorRenderObject renderObject)
	{
		renderObject..filename = filename
											..fit = fit
											..alignment = alignment
											..animationName = animation
											..completed = completed
											..isPlaying = !paused && animation != null;
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
			SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
		}
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
		
		if(_lastFrameTime == 0 || _actor == null)
		{
			_lastFrameTime = t;
			SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
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
			
			lastMix = min(1.0, layer.mix/_mixSeconds);
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

		if(_isPlaying)
		{
			SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
		}

		_actor.advance(elapsedSeconds);
		ActorNode node = _actor.getNode("IK_leg_left");
		//print("NODE ${node.x} ${node.y}");
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