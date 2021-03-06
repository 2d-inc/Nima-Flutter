import 'dart:typed_data';

import "block_reader.dart";
import "json_block_reader.dart";

abstract class StreamReader {
  int blockType = 0;

  // Instantiate the right type of Reader based on the input values
  factory StreamReader(dynamic data) {
    StreamReader reader;
    if (data is ByteData) {
      reader = BlockReader(data);
      // Move the readIndex forward for the binary reader.
      reader.readUint8("N");
      reader.readUint8("I");
      reader.readUint8("M");
      reader.readUint8("A");
    } else if (data is Map) {
      reader = JSONBlockReader(data);
    }
    return reader;
  }

  bool isEOF();

  int readUint8Length();
  int readUint16Length();
  int readUint32Length();

  int readUint8(String label);
  void readUint8Array(Uint8List list, int length, int offset, String label);
  int readInt8(String label);
  int readUint16(String label);
  void readUint16Array(Uint16List ar, int length, int offset, String label);
  int readInt16(String label);
  int readInt32(String label);
  int readUint32(String label);
  int readVersion();
  double readFloat32(String label);
  void readFloat32Array(Float32List ar, String label);
  void readFloat32ArrayOffset(
      Float32List ar, int length, int offset, String label);
  double readFloat64(String label);

  String readString(String label);

  bool readBool(String label);

  int readId(String label);

  StreamReader readNextBlock(Map<String, int> types);

  void openArray(String label);
  void closeArray();
  void openObject(String label);
  void closeObject();

  String get containerType;
}
