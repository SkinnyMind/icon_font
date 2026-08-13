import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/utils/extensions.dart';

const _featureRecordSize = 6;

class FeatureRecord({
  required final String featureTag,
  required var int? featureOffset,
}) implements BinaryCodable {
  factory fromByteData({required ByteData byteData, required int offset}) {
    final featureTag = String.fromCharCodes(
      Uint8List.view(byteData.buffer, offset, 4),
    );
    return FeatureRecord(
      featureTag: featureTag,
      featureOffset: byteData.getUint16(offset + 4),
    );
  }

  @override
  int get size => _featureRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setTag(0, featureTag)
      ..setUint16(4, featureOffset!);
  }
}

class const FeatureTable({
  required final int featureParams,
  required final int lookupIndexCount,
  required final List<int> lookupListIndices,
}) implements BinaryCodable {
  factory fromByteData(ByteData byteData, int offset, FeatureRecord record) {
    final currentOffset = offset + record.featureOffset!;

    final lookupIndexCount = byteData.getUint16(currentOffset + 2);
    final lookupListIndices = List.generate(
      lookupIndexCount,
      (i) => byteData.getUint16(currentOffset + 4 + i * 2),
    );

    return FeatureTable(
      featureParams: byteData.getUint16(currentOffset),
      lookupIndexCount: lookupIndexCount,
      lookupListIndices: lookupListIndices,
    );
  }

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

class const FeatureListTable({
  required final int featureCount,
  required final List<FeatureRecord> featureRecords,
  required final List<FeatureTable> featureTables,
}) implements BinaryCodable {
  factory fromByteData({required ByteData byteData, required int offset}) {
    final featureCount = byteData.getUint16(offset);
    final featureRecords = List.generate(
      featureCount,
      (i) => FeatureRecord.fromByteData(
        byteData: byteData,
        offset: offset + 2 + _featureRecordSize * i,
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

  factory create() {
    final featureRecordList = [
      FeatureRecord(featureTag: 'liga', featureOffset: null),
    ];

    return FeatureListTable(
      featureCount: featureRecordList.length,
      featureRecords: featureRecordList,
      featureTables: const [
        FeatureTable(
          featureParams: 0,
          lookupIndexCount: 1,
          lookupListIndices: [0],
        ),
      ],
    );
  }

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
    var tableRelativeOffset = 2 + _featureRecordSize * featureCount;

    for (var i = 0; i < featureCount; i++) {
      final record = featureRecords[i]
        ..featureOffset = tableRelativeOffset
        ..encodeToBinary(
          byteData.sublistView(recordOffset, _featureRecordSize),
        );

      final table = featureTables[i];
      final tableSize = table.size;
      table.encodeToBinary(
        byteData.sublistView(tableRelativeOffset, tableSize),
      );

      recordOffset += record.size;
      tableRelativeOffset += table.size;
    }
  }
}
