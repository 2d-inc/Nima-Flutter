import "dart:typed_data";
import "actor_component.dart";
import "actor_event.dart";
import "actor_node.dart";
import "actor_node_solo.dart";
import "actor_bone.dart";
import "actor_root_bone.dart";
import "actor_jelly_bone.dart";
import "jelly_component.dart";
import "actor_ik_constraint.dart";
import "actor_rotation_constraint.dart";
import "actor_translation_constraint.dart";
import "actor_scale_constraint.dart";
import "dependency_sorter.dart";
import "actor_image.dart";
import "animation/actor_animation.dart";
import "block_reader.dart";

class BlockTypes
{
	static const int Unknown = 0;
	static const int Components = 1;
	static const int ActorNode = 2;
	static const int ActorBone = 3;
	static const int ActorRootBone = 4;
	static const int ActorImage = 5;
	static const int View = 6;
	static const int Animation = 7;
	static const int Animations = 8;
	static const int Atlases = 9;
	static const int Atlas = 10;
	static const int ActorIKTarget = 11;
	static const int ActorEvent = 12;
	static const int CustomIntProperty = 13;
	static const int CustomFloatProperty = 14;
	static const int CustomStringProperty = 15;
	static const int CustomBooleanProperty = 16;
	static const int ActorColliderRectangle = 17;
	static const int ActorColliderTriangle = 18;
	static const int ActorColliderCircle = 19;
	static const int ActorColliderPolygon = 20;
	static const int ActorColliderLine = 21;
	static const int ActorImageSequence = 22;
	static const int ActorNodeSolo = 23;
	static const int JellyComponent = 28;
	static const int ActorJellyBone = 29;
	static const int ActorIKConstraint = 30;
	static const int ActorDistanceConstraint = 31;
	static const int ActorTranslationConstraint = 32;
	static const int ActorRotationConstraint = 33;
	static const int ActorScaleConstraint = 34;
	static const int ActorTransformConstraint = 35;
}

class ActorFlags
{
	static const int IsImageDrawOrderDirty = 1<<0;
	static const int IsVertexDeformDirty = 1<<1;
	static const int IsDirty = 1<<2;
}

class Actor
{
	int _flags = ActorFlags.IsImageDrawOrderDirty | ActorFlags.IsVertexDeformDirty;
	int _maxTextureIndex = 0;
	int _imageNodeCount = 0;
	int _nodeCount = 0;
	int _version = 0;
	int _dirtDepth = 0;
	ActorNode _root;
	List<ActorComponent> _components;
	List<ActorNode> _nodes;
	List<ActorImage> _imageNodes;
	List<ActorAnimation> _animations;
	List<ActorComponent> _dependencyOrder;

	Actor();

	bool addDependency(ActorComponent a, ActorComponent b)
	{
		List<ActorComponent> dependents = b.dependents;
		if(dependents == null)
		{
			b.dependents = dependents = new List<ActorComponent>();
		}
		if(dependents.contains(a))
		{
			return false;
		}
		dependents.add(a);
		return true;
	}

	void sortDependencies()
	{
		DependencySorter sorter = new DependencySorter();
		_dependencyOrder = sorter.sort(_root);
		int graphOrder = 0;
		for(ActorComponent component in _dependencyOrder)
		{
			component.graphOrder = graphOrder++;
			component.dirtMask = 255;
		}
		_flags |= ActorFlags.IsDirty;
	}

	bool addDirt(ActorComponent component, int value, bool recurse)
	{
		if((component.dirtMask & value) == value)
		{
			// Already marked.
			return false;
		}

		// Make sure dirt is set before calling anything that can set more dirt.
		int dirt = component.dirtMask | value;
		component.dirtMask = dirt;

		_flags |= ActorFlags.IsDirty;

		component.onDirty(dirt);

		// If the order of this component is less than the current dirt depth, update the dirt depth
		// so that the update loop can break out early and re-run (something up the tree is dirty).
		if(component.graphOrder < _dirtDepth)
		{
			_dirtDepth = component.graphOrder;	
		}
		if(!recurse)
		{
			return true;
		}
		List<ActorComponent> dependents = component.dependents;
		if(dependents != null)
		{
			for(ActorComponent d in dependents)
			{
				addDirt(d, value, recurse);
			}
		}

		return true;
	}

	int get version
	{
		return _version;
	}
	
	List<ActorComponent> get components
	{
		return _components;
	}

	List<ActorNode> get nodes
	{
		return _nodes;
	}

	List<ActorAnimation> get animations
	{
		return _animations;
	}

	List<ActorImage> get imageNodes
	{
		return _imageNodes;
	}

	ActorComponent operator[](int index)
	{
		return _components[index];
	}

	int get componentCount
	{
		return _components.length;
	}

	int get nodeCount
	{
		return _nodeCount;
	}

	int get imageNodeCount
	{
		return _imageNodeCount;
	}

	int get texturesUsed
	{
		return _maxTextureIndex + 1;
	}

	ActorNode get root
	{
		return _root;
	}

	ActorAnimation getAnimation(String name)
	{
		for(ActorAnimation a in _animations)
		{
			if(a.name == name)
			{
				return a;
			}
		}
		return null;
	}

	ActorAnimationInstance getAnimationInstance(String name)
	{
		ActorAnimation animation = getAnimation(name);
		if(animation == null)
		{
			return null;
		}
		return new ActorAnimationInstance(this, animation);
	}

	ActorNode getNode(String name)
	{
		for(ActorNode node in _nodes)
		{
			if(node != null && node.name == name)
			{
				return node;
			}
		}
		return null;
	}

	void markImageDrawOrderDirty()
	{
		_flags |= ActorFlags.IsImageDrawOrderDirty;
	}

	bool get isVertexDeformDirty
	{
		return (_flags & ActorFlags.IsVertexDeformDirty) != 0x00;
	}

	void copyActor(Actor actor)
	{
		_animations = actor._animations;
		//_flags = actor._flags;
		_maxTextureIndex = actor._maxTextureIndex;
		_imageNodeCount = actor._imageNodeCount;
		_nodeCount = actor._nodeCount;

		if(actor.componentCount != 0)
		{
			_components = new List<ActorComponent>(actor.componentCount);
		}
		if(_nodeCount != 0) // This will always be at least 1.
		{
			_nodes = new List<ActorNode>(_nodeCount);
		}
		if(_imageNodeCount != 0)
		{
			_imageNodes = new List<ActorImage>(_imageNodeCount);
		}

		if(actor.componentCount != 0)
		{
			int idx = 0;
			int imgIdx = 0;
			int ndIdx = 0;

			for(ActorComponent component in actor.components)
			{
				if(component == null)
				{
					_components[idx++] = null;
					continue;
				}
				ActorComponent instanceComponent = component.makeInstance(this);
				_components[idx++] = instanceComponent;
				// ActorNode nodeInstance = instanceComponent as ActorNode;
				// if(nodeInstance != null)
				if(instanceComponent is ActorNode)
				{
					_nodes[ndIdx++] = instanceComponent;
				}

				// ActorImage imageInstance = instanceComponent as ActorImage;
				if(instanceComponent is ActorImage)
				{
					_imageNodes[imgIdx++] = instanceComponent;
				}
			}
		}

		_root = _components[0] as ActorNode;

		for(ActorComponent component in _components)
		{
			if(_root == component || component == null)
			{
				continue;
			}
			component.resolveComponentIndices(_components);
		}

		for(ActorComponent component in _components)
		{
			if(_root == component || component == null)
			{
				continue;
			}
			component.completeResolve();
		}

		sortDependencies();

		if (_imageNodes != null)
		{
			_imageNodes.sort((a,b) => a.drawOrder.compareTo(b.drawOrder));
			for(int i = 0; i < _imageNodes.length; i++)
			{
				_imageNodes[i].drawIndex = i;
			}
		}
	}

	void updateVertexDeform(ActorImage image) {}
	ActorImage makeImageNode()
	{
		return new ActorImage();
	}

	void advance(double seconds)
	{
		if((_flags & ActorFlags.IsDirty) != 0)
		{
			const int MaxSteps = 100;
			int step = 0;
			int count = _dependencyOrder.length;
			while((_flags & ActorFlags.IsDirty) != 0 && step < MaxSteps)
			{
				_flags &= ~ActorFlags.IsDirty;
				// Track dirt depth here so that if something else marks dirty, we restart.
				for(int i = 0; i < count; i++)
				{
					ActorComponent component = _dependencyOrder[i];
					_dirtDepth = i;
					int d = component.dirtMask;
					if(d == 0)
					{
						continue;
					}
					component.dirtMask = 0;
					component.update(d);
					if(_dirtDepth < i)
					{
						break;
					}
				}
				step++;
			}
		}

		if((_flags & ActorFlags.IsImageDrawOrderDirty) != 0)
		{
			_flags &= ~ActorFlags.IsImageDrawOrderDirty;

			if (_imageNodes != null)
			{
				_imageNodes.sort((a,b) => a.drawOrder.compareTo(b.drawOrder));
				for(int i = 0; i < _imageNodes.length; i++)
				{
					_imageNodes[i].drawIndex = i;
				}
			}
		}
		if((_flags & ActorFlags.IsVertexDeformDirty) != 0)
		{
			_flags &= ~ActorFlags.IsVertexDeformDirty;
			for(int i = 0; i < _imageNodeCount; i++)
			{
				ActorImage imageNode = _imageNodes[i];
				if(imageNode != null && imageNode.isVertexDeformDirty)
				{
					imageNode.isVertexDeformDirty = false;
					updateVertexDeform(imageNode);
				}
			}
		}
	}

	void load(ByteData data)
	{
		BlockReader reader = new BlockReader(data);

		int N = reader.readUint8();
		int I = reader.readUint8();
		int M = reader.readUint8();
		int A = reader.readUint8();
		_version = reader.readUint32();

		if(N != 78 || I != 73 || M != 77 || A != 65)
		{
			return throw new UnsupportedError("Not a valid Nima file.");
		}
		if(_version < 12)
		{
			return throw new UnsupportedError("Nima file is too old.");
		}
		
		_root = new ActorNode.withActor(this);

		BlockReader block;
		while((block=reader.readNextBlock()) != null)
		{
			switch(block.blockType)
			{
				case BlockTypes.Components:
					readComponentsBlock(block);
					break;
				case BlockTypes.Animations:
					readAnimationsBlock(block);
					break;
			}
		}
	}

	void readComponentsBlock(BlockReader block)
	{
		int componentCount = block.readUint16();
		_components = new List<ActorComponent>(componentCount+1);
		_components[0] = _root;

		// Guaranteed from the exporter to be in index order.
		BlockReader nodeBlock;

		int componentIndex = 1;
		_nodeCount = 1;
		while((nodeBlock=block.readNextBlock()) != null)
		{
			ActorComponent component;
			switch(nodeBlock.blockType)
			{
				case BlockTypes.ActorNode:
					component = ActorNode.read(this, nodeBlock, null);
					break;

				case BlockTypes.ActorBone:
					component = ActorBone.read(this, nodeBlock, null);
					break;

				case BlockTypes.ActorRootBone:
					component = ActorRootBone.read(this, nodeBlock, null);
					break;

				case BlockTypes.ActorImageSequence:
					_imageNodeCount++;
					component = ActorImage.readSequence(this, nodeBlock, makeImageNode());
					ActorImage ai = component as ActorImage;
					_maxTextureIndex = ai.sequenceFrames.last.atlasIndex; // Last atlasIndex is the biggest
					break;

				case BlockTypes.ActorImage:
					_imageNodeCount++;
					component = ActorImage.read(this, nodeBlock, makeImageNode());
					if((component as ActorImage).textureIndex > _maxTextureIndex)
					{
						_maxTextureIndex = (component as ActorImage).textureIndex;
					}
					break;

				case BlockTypes.ActorIKTarget:
					//component = ActorIKTarget.Read(this, nodeBlock);
					break;

				case BlockTypes.ActorEvent:
					component = ActorEvent.read(this, nodeBlock,  null);
					break;

				case BlockTypes.CustomIntProperty:
					//component = CustomIntProperty.Read(this, nodeBlock);
					break;

				case BlockTypes.CustomFloatProperty:
					//component = CustomFloatProperty.Read(this, nodeBlock);
					break;

				case BlockTypes.CustomStringProperty:
					//component = CustomStringProperty.Read(this, nodeBlock);
					break;

				case BlockTypes.CustomBooleanProperty:
					//component = CustomBooleanProperty.Read(this, nodeBlock);
					break;

				case BlockTypes.ActorColliderRectangle:
					//component = ActorColliderRectangle.Read(this, nodeBlock);
					break;

				case BlockTypes.ActorColliderTriangle:
					//component = ActorColliderTriangle.Read(this, nodeBlock);
					break;

				case BlockTypes.ActorColliderCircle:
					//component = ActorColliderCircle.Read(this, nodeBlock);
					break;

				case BlockTypes.ActorColliderPolygon:
					//component = ActorColliderPolygon.Read(this, nodeBlock);
					break;

				case BlockTypes.ActorColliderLine:
					//component = ActorColliderLine.Read(this, nodeBlock);
					break;

				case BlockTypes.ActorNodeSolo:
					component = ActorNodeSolo.read(this, nodeBlock, null);
					break;

				case BlockTypes.ActorJellyBone:
					component = ActorJellyBone.read(this, nodeBlock, null);
					break;

				case BlockTypes.JellyComponent:
					component = JellyComponent.read(this, nodeBlock, null);
					break;

				case BlockTypes.ActorIKConstraint:
					component = ActorIKConstraint.read(this, nodeBlock, null);
					break;

				case BlockTypes.ActorDistanceConstraint:
					//component = ActorDistanceConstraint.Read(this, nodeBlock);
					break;

				case BlockTypes.ActorTranslationConstraint:
					component = ActorTranslationConstraint.read(this, nodeBlock, null);
					break;

				case BlockTypes.ActorScaleConstraint:
					component = ActorScaleConstraint.read(this, nodeBlock, null);
					break;

				case BlockTypes.ActorRotationConstraint:
					component = ActorRotationConstraint.read(this, nodeBlock, null);
					break;

				case BlockTypes.ActorTransformConstraint:
					//component = ActorTransformConstraint.Read(this, nodeBlock);
					break;
			}

			if(component is ActorNode)
			{
				_nodeCount++;
			}

			_components[componentIndex] = component;
			if(component != null)
			{
				component.idx = componentIndex;
			}
			componentIndex++;
		}

		_imageNodes = new List<ActorImage>(_imageNodeCount);
		_nodes = new List<ActorNode>(_nodeCount);
		_nodes[0] = _root;

		// Resolve nodes.
		int imgIdx = 0;
		int anIdx = 0;

		for(int i = 1; i <= componentCount; i++)
		{
			ActorComponent c = _components[i];
			// Nodes can be null if we read from a file version that contained nodes that we don't interpret in this runtime.
			if(c != null)
			{
				c.resolveComponentIndices(_components);
			}

			if(c is ActorImage)
			{
				ActorImage ain = c;
				if(ain != null)
				{
					_imageNodes[imgIdx++] = ain;
				}
			}

			if(c is ActorNode)
			{
				ActorNode an = c;
				if(an != null)
				{
					_nodes[anIdx++] = an;
				}
			}
		}

		for(int i = 1; i <= componentCount; i++)
		{
			ActorComponent c = components[i];
			if(c != null)
			{
				c.completeResolve();
			}
		}

		sortDependencies();
	}

	void readAnimationsBlock(BlockReader block)
	{
		// Read animations.
		int animationCount = block.readUint16();
		_animations = new List<ActorAnimation>(animationCount);
		BlockReader animationBlock;
		int animationIndex = 0;
		
		while((animationBlock=block.readNextBlock()) != null)
		{
			switch(animationBlock.blockType)
			{
				case BlockTypes.Animation:
					ActorAnimation anim = ActorAnimation.read(animationBlock, _components);
					_animations[animationIndex++] = anim;
					break;
			}
		}
	}
}