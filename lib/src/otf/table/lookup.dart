import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/otf/table/coverage.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

abstract class const SubstitutionSubtable() implements BinaryCodable {
  static SubstitutionSubtable? fromByteData({
    required ByteData byteData,
    required int offset,
    required int lookupType,
  }) {
    return switch (lookupType) {
      4 => LigatureSubstitutionSubtable.fromByteData(
        byteData: byteData,
        offset: offset,
      ),
      _ => () {
        Log.unsupportedTableFormat('Lookup', lookupType);
        return null;
      }(),
    };
  }

  int get maxContext;
}

class const LigatureSubstitutionSubtable({
  required final int substFormat,
  required final int coverageOffset,
  required final int ligatureSetCount,
  required final List<int> ligatureSetOffsets,
  required final CoverageTable? coverageTable,
}) extends SubstitutionSubtable {
  factory fromByteData({required ByteData byteData, required int offset}) {
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

class const LookupTable({
  required final int lookupType,
  required final int lookupFlag,
  required final int subTableCount,
  required final List<int> subtableOffsets,
  required final int? markFilteringSet,
  required final List<SubstitutionSubtable> subtables,
}) implements BinaryCodable {
  factory fromByteData({required ByteData byteData, required int offset}) {
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

class const LookupListTable({
  required final int lookupCount,
  required final List<int> lookups,
  required final List<LookupTable> lookupTables,
}) implements BinaryCodable {
  factory fromByteData({required ByteData byteData, required int offset}) {
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

  factory create() {
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

    return const LookupListTable(
      lookupCount: 1,
      lookups: [4],
      lookupTables: lookupTables,
    );
  }

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
