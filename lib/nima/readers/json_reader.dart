import "dart:collection";
import "dart:typed_data";

import "stream_reader.dart";

abstract class JSONReader implements StreamReader {
  @override
  int blockType;

  dynamic _readObject;
  ListQueue _context;

  JSONReader(Map object) {
    _readObject = object["container"];
    _context = ListQueue<dynamic>();
    _context.addFirst(_readObject);
  }

  dynamic readProp(String label) {
    dynamic head = _context.first;
    if (head is Map) {
      dynamic prop = head[label];
      head.remove(label);
      return prop;
    } else if (head is List) {
      return head.removeAt(0);
    }
    return null;
  }

  @override
  double readFloat32(String label) {
    num f = readProp(label) as num;
    return f.toDouble();
  }

  // Reads the array into ar
  @override
  void readFloat32Array(Float32List ar, String label) {
    _readArray(ar, label);
  }

  @override
  void readFloat32ArrayOffset(
      Float32List ar, int length, int offset, String label) {
    _readArrayOffset(ar, length, offset, label);
  }

  void _readArrayOffset(List ar, int length, int offset, String label) {
    List array = readProp(label) as List;
    int end = offset + length;
    num listElement = ar.first as num;
    for (int i = offset; i < end; i++) {
      num val = array[i] as num;
      ar[i] = listElement is double ? val.toDouble() : val.toInt();
    }
  }

  void _readArray(List ar, String label) {
    List array = readProp(label) as List;
    for (int i = 0; i < ar.length; i++) {
      ar[i] = array[i];
    }
  }

  @override
  double readFloat64(String label) {
    num f = readProp(label) as num;
    return f.toDouble();
  }

  @override
  int readUint8(String label) {
    return readProp(label) as int;
  }

  @override
  int readUint8Length() {
    return _readLength();
  }

  @override
  bool isEOF() {
    return _context.length <= 1 && _readObject.length == 0;
  }

  @override
  int readInt8(String label) {
    return readProp(label) as int;
  }

  @override
  int readUint16(String label) {
    return readProp(label) as int;
  }

  @override
  void readUint8Array(Uint8List ar, int length, int offset, String label) {
    return _readArrayOffset(ar, length, offset, label);
  }

  @override
  void readUint16Array(Uint16List ar, int length, int offset, String label) {
    return _readArrayOffset(ar, length, offset, label);
  }

  @override
  int readInt16(String label) {
    return readProp(label) as int;
  }

  @override
  int readUint16Length() {
    return _readLength();
  }

  @override
  int readUint32Length() {
    return _readLength();
  }

  @override
  int readUint32(String label) {
    return readProp(label) as int;
  }

  @override
  int readInt32(String label) {
    return readProp(label) as int;
  }

  @override
  int readVersion() {
    return readProp("version") as int;
  }

  @override
  String readString(String label) {
    return readProp(label) as String;
  }

  @override
  bool readBool(String label) {
    return readProp(label) as bool;
  }

  // @hasOffset flag is needed for older (up until version 14) files.
  // Since the JSON Reader has been added in version 15, the field
  // here is optional.
  @override
  int readId(String label) {
    dynamic val = readProp(label);
    return (val is num ? val + 1 : 0).toInt();
  }

  @override
  void openArray(String label) {
    dynamic array = readProp(label);
    _context.addFirst(array);
  }

  @override
  void closeArray() {
    _context.removeFirst();
  }

  @override
  void openObject(String label) {
    dynamic o = readProp(label);
    _context.addFirst(o);
  }

  @override
  void closeObject() {
    _context.removeFirst();
  }

  int _readLength() => (_context.first as List)
      .length; // Maps and Lists both have a `length` property.
  @override
  String get containerType => "json";
  ListQueue get context => _context;
}
