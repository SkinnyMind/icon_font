import 'dart:typed_data';

import 'package:icon_font_generator/src/common/codable/binary.dart';
import 'package:icon_font_generator/src/utils/otf.dart';

const kTableRecordEntryLength = 16;

class TableRecordEntry implements BinaryCodable {
  TableRecordEntry({
    required this.tag,
    required this.checkSum,
    required this.offset,
    required this.length,
  });

  factory TableRecordEntry.fromByteData(ByteData data, int entryOffset) =>
      TableRecordEntry(
        tag: data.getTag(entryOffset),
        checkSum: data.getUint32(entryOffset + 4),
        offset: data.getUint32(entryOffset + 8),
        length: data.getUint32(entryOffset + 12),
      );

  final String tag;
  final int checkSum;
  final int offset;
  final int length;

  @override
  int get size => kTableRecordEntryLength;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setTag(0, tag)
      ..setUint32(4, checkSum)
      ..setUint32(8, offset)
      ..setUint32(12, length);
  }
}
