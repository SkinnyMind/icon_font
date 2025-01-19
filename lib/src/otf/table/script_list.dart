import 'dart:typed_data';

import 'package:icon_font_generator/src/common/codable/binary.dart';
import 'package:icon_font_generator/src/otf/table/language_system.dart';
import 'package:icon_font_generator/src/utils/otf.dart';

const kScriptRecordSize = 6;

/// Alphabetically ordered (by tag) list of script records
final _defaultScriptRecordList = [
  /// Default
  ScriptRecord(scriptTag: 'DFLT', scriptOffset: null),

  /// Latin
  ScriptRecord(scriptTag: 'latn', scriptOffset: null),
];

const _kDefaultScriptTable = ScriptTable(
  defaultLangSysOffset: 4,
  langSysCount: 0,
  langSysRecords: [],
  langSysTables: [],
  defaultLangSys: LanguageSystemTable(
    lookupOrder: 0,
    requiredFeatureIndex: 0xFFFF, // no required features
    featureIndexCount: 1,
    featureIndices: [0],
  ),
);

class ScriptRecord implements BinaryCodable {
  ScriptRecord({required this.scriptTag, required this.scriptOffset});

  factory ScriptRecord.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    return ScriptRecord(
      scriptTag: byteData.getTag(offset),
      scriptOffset: byteData.getUint16(offset + 4),
    );
  }

  final String scriptTag;
  int? scriptOffset;

  @override
  int get size => kScriptRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setTag(0, scriptTag)
      ..setUint16(4, scriptOffset!);
  }
}

class ScriptTable implements BinaryCodable {
  const ScriptTable({
    required this.defaultLangSysOffset,
    required this.langSysCount,
    required this.langSysRecords,
    required this.langSysTables,
    required this.defaultLangSys,
  });

  factory ScriptTable.fromByteData({
    required ByteData byteData,
    required int offset,
    required ScriptRecord record,
  }) {
    offset += record.scriptOffset!;

    final defaultLangSysOffset = byteData.getUint16(offset);
    LanguageSystemTable? defaultLangSys;
    if (defaultLangSysOffset != 0) {
      defaultLangSys = LanguageSystemTable.fromByteData(
        byteData: byteData,
        offset: offset + defaultLangSysOffset,
      );
    }

    final langSysCount = byteData.getUint16(offset + 2);
    final langSysRecords = List.generate(
      langSysCount,
      (i) => LanguageSystemRecord.fromByteData(
        byteData: byteData,
        offset: offset + 4 + kLangSysRecordSize * i,
      ),
    );
    final langSysTables = langSysRecords
        .map(
          (r) => LanguageSystemTable.fromByteData(
            byteData: byteData,
            offset: offset + r.langSysOffset,
          ),
        )
        .toList();

    return ScriptTable(
      defaultLangSysOffset: defaultLangSysOffset,
      langSysCount: langSysCount,
      langSysRecords: langSysRecords,
      langSysTables: langSysTables,
      defaultLangSys: defaultLangSys,
    );
  }

  final int defaultLangSysOffset;
  final int langSysCount;
  final List<LanguageSystemRecord> langSysRecords;

  final List<LanguageSystemTable> langSysTables;
  final LanguageSystemTable? defaultLangSys;

  @override
  int get size {
    final recordListSize = langSysRecords.fold<int>(0, (p, r) => p + r.size);
    final tableListSize = langSysTables.fold<int>(0, (p, t) => p + t.size);

    return 4 + (defaultLangSys?.size ?? 0) + recordListSize + tableListSize;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint16(2, langSysCount);

    var recordOffset = 4;
    var tableRelativeOffset = 4 + kLangSysRecordSize * langSysRecords.length;

    for (var i = 0; i < langSysRecords.length; i++) {
      final record = langSysRecords[i]
        ..langSysOffset = tableRelativeOffset
        ..encodeToBinary(
          byteData.sublistView(recordOffset, kLangSysRecordSize),
        );

      final table = langSysTables[i];
      table.encodeToBinary(
        byteData.sublistView(tableRelativeOffset, table.size),
      );

      recordOffset += record.size;
      tableRelativeOffset += table.size;
    }

    final defaultRelativeLangSysOffset = tableRelativeOffset;
    byteData.setUint16(0, defaultRelativeLangSysOffset);

    defaultLangSys?.encodeToBinary(
      byteData.sublistView(
        defaultRelativeLangSysOffset,
        defaultLangSys!.size,
      ),
    );
  }
}

class ScriptListTable implements BinaryCodable {
  ScriptListTable({
    required this.scriptCount,
    required this.scriptRecords,
    required this.scriptTables,
  });

  factory ScriptListTable.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final scriptCount = byteData.getUint16(offset);
    final scriptRecords = List.generate(
      scriptCount,
      (i) => ScriptRecord.fromByteData(
        byteData: byteData,
        offset: offset + 2 + kScriptRecordSize * i,
      ),
    );
    final scriptTables = List.generate(
      scriptCount,
      (i) => ScriptTable.fromByteData(
        byteData: byteData,
        offset: offset,
        record: scriptRecords[i],
      ),
    );

    return ScriptListTable(
      scriptCount: scriptCount,
      scriptRecords: scriptRecords,
      scriptTables: scriptTables,
    );
  }

  factory ScriptListTable.create() {
    final scriptCount = _defaultScriptRecordList.length;

    return ScriptListTable(
      scriptCount: scriptCount,
      scriptRecords: _defaultScriptRecordList,
      scriptTables: List.generate(scriptCount, (index) => _kDefaultScriptTable),
    );
  }

  final int scriptCount;
  final List<ScriptRecord> scriptRecords;

  final List<ScriptTable> scriptTables;

  @override
  int get size {
    final recordListSize = scriptRecords.fold<int>(0, (p, r) => p + r.size);
    final tableListSize = scriptTables.fold<int>(0, (p, t) => p + t.size);

    return 2 + recordListSize + tableListSize;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint16(0, scriptCount);

    var recordOffset = 2;
    var tableRelativeOffset = 2 + kScriptRecordSize * scriptCount;

    for (var i = 0; i < scriptCount; i++) {
      final record = scriptRecords[i]
        ..scriptOffset = tableRelativeOffset
        ..encodeToBinary(byteData.sublistView(recordOffset, kScriptRecordSize));

      final table = scriptTables[i];
      table.encodeToBinary(
        byteData.sublistView(tableRelativeOffset, table.size),
      );

      recordOffset += record.size;
      tableRelativeOffset += table.size;
    }
  }
}
