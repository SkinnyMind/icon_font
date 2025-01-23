import 'dart:math' as math;
import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/utils/constants.dart';

class OffsetTable implements BinaryCodable {
  OffsetTable({
    required this.sfntVersion,
    required this.numTables,
    required this.searchRange,
    required this.entrySelector,
    required this.rangeShift,
  });

  factory OffsetTable.fromByteData({required ByteData data}) {
    final version = data.getUint32(0);

    return OffsetTable(
      sfntVersion: version,
      numTables: data.getUint16(4),
      searchRange: data.getUint16(6),
      entrySelector: data.getUint16(8),
      rangeShift: data.getUint16(10),
    );
  }

  factory OffsetTable.create({
    required int numTables,
    required bool isOpenType,
  }) {
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

  final int sfntVersion;
  final int numTables;
  final int searchRange;
  final int entrySelector;
  final int rangeShift;

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
