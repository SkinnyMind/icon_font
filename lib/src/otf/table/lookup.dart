import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/otf/table/coverage.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

abstract class SubstitutionSubtable implements BinaryCodable {
  const SubstitutionSubtable();

  static SubstitutionSubtable? fromByteData({
    required ByteData byteData,
    required int offset,
    required int lookupType,
  }) {
    switch (lookupType) {
      case 4:
        return LigatureSubstitutionSubtable.fromByteData(
          byteData: byteData,
          offset: offset,
        );
      default:
        Log.unsupportedTableFormat('Lookup', lookupType);
        return null;
    }
  }

  int get maxContext;
}

class LigatureSubstitutionSubtable extends SubstitutionSubtable {
  const LigatureSubstitutionSubtable({
    required this.substFormat,
    required this.coverageOffset,
    required this.ligatureSetCount,
    required this.ligatureSetOffsets,
    required this.coverageTable,
  });

  factory LigatureSubstitutionSubtable.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final coverageOffset = byteData.getUint16(offset + 2);
    final ligatureSetCount = byteData.getUint16(offset + 4);
    final subtableOffsets = List.generate(
      ligatureSetCount,
      (i) => byteData.getUint16(offset + 6 + 2 * i),
    );

    final coverageTable = CoverageTable.fromByteData(
      byteData: byteData,
      offset: offset + coverageOffset,
    );

    return LigatureSubstitutionSubtable(
      substFormat: byteData.getUint16(offset),
      coverageOffset: coverageOffset,
      ligatureSetCount: ligatureSetCount,
      ligatureSetOffsets: subtableOffsets,
      coverageTable: coverageTable,
    );
  }

  final int substFormat;
  final int coverageOffset;
  final int ligatureSetCount;
  final List<int> ligatureSetOffsets;

  final CoverageTable? coverageTable;

  @override
  int get size => 6 + 2 * ligatureSetCount + (coverageTable?.size ?? 0);

  /// NOTE: Should be calculated considering 'componentCount' of ligatures.
  ///
  /// Not supported yet - generating 0 ligature sets by default.
  @override
  int get maxContext => 0;

  @override
  void encodeToBinary(ByteData byteData) {
    final coverageOffset = 6 + 2 * ligatureSetCount;

    byteData
      ..setUint16(0, substFormat)
      ..setUint16(2, coverageOffset)
      ..setUint16(4, ligatureSetCount);

    for (var i = 0; i < ligatureSetCount; i++) {
      byteData.setInt16(6 + 2 * i, ligatureSetOffsets[i]);
    }

    coverageTable?.encodeToBinary(
      byteData.sublistView(coverageOffset, coverageTable!.size),
    );
  }
}

class LookupTable implements BinaryCodable {
  const LookupTable({
    required this.lookupType,
    required this.lookupFlag,
    required this.subTableCount,
    required this.subtableOffsets,
    required this.markFilteringSet,
    required this.subtables,
  });

  factory LookupTable.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final lookupType = byteData.getUint16(offset);
    final lookupFlag = byteData.getUint16(offset + 2);
    final subTableCount = byteData.getUint16(offset + 4);
    final subtableOffsets = List.generate(
      subTableCount,
      (i) => byteData.getUint16(offset + 6 + 2 * i),
    );
    final useMarkFilteringSet = _useMarkFilteringSet(lookupFlag: lookupFlag);
    final markFilteringSetOffset = offset + 6 + 2 * subTableCount;

    final subtables = List.generate(
      subTableCount,
      (i) => SubstitutionSubtable.fromByteData(
        byteData: byteData,
        offset: offset + subtableOffsets[i],
        lookupType: lookupType,
      ),
    ).whereType<SubstitutionSubtable>().toList();

    return LookupTable(
      lookupType: lookupType,
      lookupFlag: lookupFlag,
      subTableCount: subTableCount,
      subtableOffsets: subtableOffsets,
      markFilteringSet: useMarkFilteringSet
          ? byteData.getUint16(markFilteringSetOffset)
          : null,
      subtables: subtables,
    );
  }

  final int lookupType;
  final int lookupFlag;
  final int subTableCount;
  final List<int> subtableOffsets;
  final int? markFilteringSet;

  final List<SubstitutionSubtable> subtables;

  static bool _useMarkFilteringSet({required int lookupFlag}) =>
      OtfUtils.checkBitMask(value: lookupFlag, mask: 0x0010);

  @override
  int get size {
    final subtableListSize = subtables.fold<int>(0, (p, t) => p + t.size);

    return 6 + 2 * subTableCount + subtableListSize;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, lookupType)
      ..setUint16(2, lookupFlag)
      ..setUint16(4, subTableCount);

    var currentRelativeOffset = 6 + 2 * subTableCount;
    final subtableOffsetList = <int>[];

    for (final subtable in subtables) {
      subtable.encodeToBinary(
        byteData.sublistView(currentRelativeOffset, subtable.size),
      );
      subtableOffsetList.add(currentRelativeOffset);
      currentRelativeOffset += subtable.size;
    }

    for (var i = 0; i < subTableCount; i++) {
      byteData.setInt16(6 + 2 * i, subtableOffsetList[i]);
    }

    final useMarkFilteringSet = _useMarkFilteringSet(lookupFlag: lookupFlag);

    if (useMarkFilteringSet) {
      byteData.setUint16(6 + 2 * subTableCount, markFilteringSet!);
    }
  }
}

class LookupListTable implements BinaryCodable {
  LookupListTable({
    required this.lookupCount,
    required this.lookups,
    required this.lookupTables,
  });

  factory LookupListTable.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final lookupCount = byteData.getUint16(offset);
    final lookups = List.generate(
      lookupCount,
      (i) => byteData.getUint16(offset + 2 + 2 * i),
    );
    final lookupTables = List.generate(
      lookupCount,
      (i) => LookupTable.fromByteData(
        byteData: byteData,
        offset: offset + lookups[i],
      ),
    );

    return LookupListTable(
      lookupCount: lookupCount,
      lookups: lookups,
      lookupTables: lookupTables,
    );
  }

  factory LookupListTable.create() {
    const coverageTable = CoverageTableFormat1(
      coverageFormat: 1,
      glyphCount: 0,
      glyphArray: [],
    );
    const subtables = [
      LigatureSubstitutionSubtable(
        substFormat: 1,
        coverageOffset: 6,
        ligatureSetCount: 0,
        ligatureSetOffsets: [],
        coverageTable: coverageTable,
      ),
    ];
    const lookupTables = [
      LookupTable(
        lookupType: 4,
        lookupFlag: 0,
        subTableCount: 1,
        subtableOffsets: [8],
        markFilteringSet: null,
        subtables: subtables,
      ),
    ];

    return LookupListTable(
      lookupCount: 1,
      lookups: [4],
      lookupTables: lookupTables,
    );
  }

  final int lookupCount;
  final List<int> lookups;

  final List<LookupTable> lookupTables;

  @override
  int get size {
    final lookupListTableSize = lookupTables.fold<int>(0, (p, t) => p + t.size);

    return 2 + 2 * lookupCount + lookupListTableSize;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint16(0, lookupCount);

    var tableRelativeOffset = 2 + 2 * lookupCount;

    for (var i = 0; i < lookupCount; i++) {
      final subtable = lookupTables[i];
      subtable.encodeToBinary(
        byteData.sublistView(tableRelativeOffset, subtable.size),
      );

      byteData.setUint16(2 + 2 * i, tableRelativeOffset);
      tableRelativeOffset += subtable.size;
    }
  }
}
