import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';

class const GlyphHeader({
  required final int numberOfContours,
  required final int xMin,
  required final int yMin,
  required final int xMax,
  required final int yMax,
}) implements BinaryCodable {
  factory fromByteData({required ByteData byteData, required int offset}) {
    return GlyphHeader(
      numberOfContours: byteData.getInt16(offset),
      xMin: byteData.getInt16(offset + 2),
      yMin: byteData.getInt16(offset + 4),
      xMax: byteData.getInt16(offset + 6),
      yMax: byteData.getInt16(offset + 8),
    );
  }

  bool get isComposite => numberOfContours.isNegative;

  @override
  int get size => 10;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setInt16(0, numberOfContours)
      ..setInt16(2, xMin)
      ..setInt16(4, yMin)
      ..setInt16(6, xMax)
      ..setInt16(8, yMax);
  }
}
