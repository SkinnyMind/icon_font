import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/utils/constants.dart';
import 'package:icon_font/src/utils/extensions.dart';

class const TableRecordEntry({
  required final String tag,
  required final int checkSum,
  required final int offset,
  required final int length,
}) implements BinaryCodable {
  factory fromByteData(ByteData data, int entryOffset) => TableRecordEntry(
    tag: String.fromCharCodes(Uint8List.view(data.buffer, entryOffset, 4)),
    checkSum: data.getUint32(entryOffset + 4),
    offset: data.getUint32(entryOffset + 8),
    length: data.getUint32(entryOffset + 12),
  );

  @override
  int get size => tableRecordEntryLength;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setTag(0, tag)
      ..setUint32(4, checkSum)
      ..setUint32(8, offset)
      ..setUint32(12, length);
  }
}
