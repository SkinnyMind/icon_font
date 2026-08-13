import 'dart:math' as math;
import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/utils/constants.dart';

class const OffsetTable({
  required final int sfntVersion,
  required final int numTables,
  required final int searchRange,
  required final int entrySelector,
  required final int rangeShift,
}) implements BinaryCodable {
  factory fromByteData({required ByteData data}) {
    return OffsetTable(
      sfntVersion: data.getUint32(0),
      numTables: data.getUint16(4),
      searchRange: data.getUint16(6),
      entrySelector: data.getUint16(8),
      rangeShift: data.getUint16(10),
    );
  }

  factory create({required int numTables, required bool isOpenType}) {
    final entrySelector = (math.log(numTables) / math.ln2).floor();
    final searchRange = 16 * math.pow(2, entrySelector).toInt();
    final rangeShift = numTables * 16 - searchRange;

    return OffsetTable(
      sfntVersion: isOpenType ? 0x4F54544F : 0x00010000,
      numTables: numTables,
      searchRange: searchRange,
      entrySelector: entrySelector,
      rangeShift: rangeShift,
    );
  }

  bool get isOpenType => sfntVersion == 0x4F54544F;

  @override
  int get size => offsetTableLength;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint32(0, sfntVersion)
      ..setUint16(4, numTables)
      ..setUint16(6, searchRange)
      ..setUint16(8, entrySelector)
      ..setUint16(10, rangeShift);
  }
}
