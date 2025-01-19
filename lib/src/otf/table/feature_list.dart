import 'dart:typed_data';

import 'package:icon_font/src/common/codable/binary.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

const kFeatureRecordSize = 6;

const _kDefaultFeatureTableList = [
  FeatureTable(featureParams: 0, lookupIndexCount: 1, lookupListIndices: [0]),
];

List<FeatureRecord> _createDefaultFeatureRecordList() => [
      FeatureRecord(featureTag: 'liga', featureOffset: null),
    ];

class FeatureRecord implements BinaryCodable {
  FeatureRecord({required this.featureTag, required this.featureOffset});

  factory FeatureRecord.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    return FeatureRecord(
      featureTag: byteData.getTag(offset),
      featureOffset: byteData.getUint16(offset + 4),
    );
  }

  final String featureTag;
  int? featureOffset;

  @override
  int get size => kFeatureRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setTag(0, featureTag)
      ..setUint16(4, featureOffset!);
  }
}

class FeatureTable implements BinaryCodable {
  const FeatureTable({
    required this.featureParams,
    required this.lookupIndexCount,
    required this.lookupListIndices,
  });

  factory FeatureTable.fromByteData(
    ByteData byteData,
    int offset,
    FeatureRecord record,
  ) {
    offset += record.featureOffset!;

    final lookupIndexCount = byteData.getUint16(offset + 2);
    final lookupListIndices = List.generate(
      lookupIndexCount,
      (i) => byteData.getUint16(offset + 4 + i * 2),
    );

    return FeatureTable(
      featureParams: byteData.getUint16(offset),
      lookupIndexCount: lookupIndexCount,
      lookupListIndices: lookupListIndices,
    );
  }

  final int featureParams;
  final int lookupIndexCount;
  final List<int> lookupListIndices;

  @override
  int get size => 4 + 2 * lookupIndexCount;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, featureParams)
      ..setUint16(2, lookupIndexCount);

    for (var i = 0; i < lookupIndexCount; i++) {
      byteData.setInt16(4 + 2 * i, lookupListIndices[i]);
    }
  }
}

class FeatureListTable implements BinaryCodable {
  FeatureListTable({
    required this.featureCount,
    required this.featureRecords,
    required this.featureTables,
  });

  factory FeatureListTable.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final featureCount = byteData.getUint16(offset);
    final featureRecords = List.generate(
      featureCount,
      (i) => FeatureRecord.fromByteData(
        byteData: byteData,
        offset: offset + 2 + kFeatureRecordSize * i,
      ),
    );
    final featureTables = List.generate(
      featureCount,
      (i) => FeatureTable.fromByteData(byteData, offset, featureRecords[i]),
    );

    return FeatureListTable(
      featureCount: featureCount,
      featureRecords: featureRecords,
      featureTables: featureTables,
    );
  }

  factory FeatureListTable.create() {
    final featureRecordList = _createDefaultFeatureRecordList();

    return FeatureListTable(
      featureCount: featureRecordList.length,
      featureRecords: featureRecordList,
      featureTables: _kDefaultFeatureTableList,
    );
  }

  final int featureCount;
  final List<FeatureRecord> featureRecords;

  final List<FeatureTable> featureTables;

  @override
  int get size {
    final recordListSize = featureRecords.fold<int>(0, (p, r) => p + r.size);
    final tableListSize = featureTables.fold<int>(0, (p, t) => p + t.size);

    return 2 + recordListSize + tableListSize;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint16(0, featureCount);

    var recordOffset = 2;
    var tableRelativeOffset = 2 + kFeatureRecordSize * featureCount;

    for (var i = 0; i < featureCount; i++) {
      final record = featureRecords[i]
        ..featureOffset = tableRelativeOffset
        ..encodeToBinary(
          byteData.sublistView(recordOffset, kFeatureRecordSize),
        );

      final table = featureTables[i];
      final tableSize = table.size;
      table
          .encodeToBinary(byteData.sublistView(tableRelativeOffset, tableSize));

      recordOffset += record.size;
      tableRelativeOffset += table.size;
    }
  }
}
