import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/konst.dart';

class LanguageSystemRecord implements BinaryCodable {
  LanguageSystemRecord({required this.langSysTag, required this.langSysOffset});

  factory LanguageSystemRecord.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final langSysTag = String.fromCharCodes(
      Uint8List.view(byteData.buffer, offset, 4),
    );
    return LanguageSystemRecord(
      langSysTag: langSysTag,
      langSysOffset: byteData.getUint16(offset + 4),
    );
  }

  final String langSysTag;
  int langSysOffset;

  @override
  int get size => kLangSysRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setTag(0, langSysTag)
      ..setUint16(4, langSysOffset);
  }
}

class LanguageSystemTable implements BinaryCodable {
  const LanguageSystemTable({
    required this.lookupOrder,
    required this.requiredFeatureIndex,
    required this.featureIndexCount,
    required this.featureIndices,
  });

  factory LanguageSystemTable.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final featureIndexCount = byteData.getUint16(offset + 4);
    final featureIndices = List.generate(
      featureIndexCount,
      (i) => byteData.getUint16(offset + 6 + 2 * i),
    );

    return LanguageSystemTable(
      lookupOrder: byteData.getUint16(offset),
      requiredFeatureIndex: byteData.getUint16(offset + 2),
      featureIndexCount: featureIndexCount,
      featureIndices: featureIndices,
    );
  }

  final int lookupOrder;
  final int requiredFeatureIndex;
  final int featureIndexCount;
  final List<int> featureIndices;

  @override
  int get size => 6 + 2 * featureIndexCount;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, lookupOrder)
      ..setUint16(2, requiredFeatureIndex)
      ..setUint16(4, featureIndexCount);

    for (var i = 0; i < featureIndexCount; i++) {
      byteData.setInt16(6 + 2 * i, featureIndices[i]);
    }
  }
}
