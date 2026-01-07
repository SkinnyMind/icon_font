import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/utils/logger.dart';

abstract class CoverageTable implements BinaryCodable {
  const CoverageTable();

  static CoverageTable? fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final format = byteData.getUint16(offset);

    return switch (format) {
      1 => CoverageTableFormat1.fromByteData(
        byteData: byteData,
        offset: offset,
      ),
      _ => () {
        Log.unsupportedTableFormat('Coverage', format);
        return null;
      }(),
    };
  }
}

class CoverageTableFormat1 extends CoverageTable {
  const CoverageTableFormat1({
    required this.coverageFormat,
    required this.glyphCount,
    required this.glyphArray,
  });

  factory CoverageTableFormat1.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final coverageFormat = byteData.getUint16(offset);
    final glyphCount = byteData.getUint16(offset + 2);
    final glyphArray = List.generate(
      glyphCount,
      (i) => byteData.getUint16(offset + 4 + 2 * i),
    );

    return CoverageTableFormat1(
      coverageFormat: coverageFormat,
      glyphCount: glyphCount,
      glyphArray: glyphArray,
    );
  }

  final int coverageFormat;
  final int glyphCount;
  final List<int> glyphArray;

  @override
  int get size => 4 + 2 * glyphCount;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, coverageFormat)
      ..setUint16(2, glyphCount);

    for (var i = 0; i < glyphCount; i++) {
      byteData.setInt16(4 + 2 * i, glyphArray[i]);
    }
  }
}
