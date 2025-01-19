import 'dart:typed_data';

import 'package:icon_font/src/common/codable/binary.dart';

class PascalString implements BinaryCodable {
  PascalString({required this.string, required this.length});

  factory PascalString.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final length = byteData.getUint8(offset++);
    final bytes = List.generate(length, (i) => byteData.getUint8(offset + i));
    return PascalString(string: String.fromCharCodes(bytes), length: length);
  }

  factory PascalString.fromString(String string) =>
      PascalString(string: string, length: string.length);

  final String string;
  final int length;

  @override
  int get size => length + 1;

  @override
  String toString() => string;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint8(0, length);

    var offset = 1;

    for (final charCode in string.codeUnits) {
      byteData.setUint8(offset++, charCode);
    }
  }
}
