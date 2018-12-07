class PropertyTypes {
  static const int Unknown = 0;
  static const int PosX = 1;
  static const int PosY = 2;
  static const int ScaleX = 3;
  static const int ScaleY = 4;
  static const int Rotation = 5;
  static const int Opacity = 6;
  static const int DrawOrder = 7;
  static const int Length = 8;
  static const int VertexDeform = 9;
  static const int ConstraintStrength = 10;
  static const int Trigger = 11;
  static const int IntProperty = 12;
  static const int FloatProperty = 13;
  static const int StringProperty = 14;
  static const int BooleanProperty = 15;
  static const int CollisionEnabled = 16;
  static const int Sequence = 17;
  static const int ActiveChildIndex = 18;
}

const Map<String, int> PropertyTypesMap = {
  "unknown": PropertyTypes.Unknown,
  "posX": PropertyTypes.PosX,
  "posY": PropertyTypes.PosY,
  "scaleX": PropertyTypes.ScaleX,
  "scaleY": PropertyTypes.ScaleY,
  "rotation": PropertyTypes.Rotation,
  "opacity": PropertyTypes.Opacity,
  "drawOrder": PropertyTypes.DrawOrder,
  "length": PropertyTypes.Length,
  "vertices": PropertyTypes.VertexDeform,
  "strength": PropertyTypes.ConstraintStrength,
  "trigger": PropertyTypes.Trigger,
  "intValue": PropertyTypes.IntProperty,
  "floatValue": PropertyTypes.FloatProperty,
  "stringValue": PropertyTypes.StringProperty,
  "boolValue": PropertyTypes.BooleanProperty,
  "isCollisionEnabled": PropertyTypes.CollisionEnabled,
  "sequence": PropertyTypes.Sequence,
  "activeChild": PropertyTypes.ActiveChildIndex
};
