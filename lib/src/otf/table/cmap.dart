import 'dart:math' as math;
import 'dart:typed_data';

import 'package:icon_font_generator/src/common.dart';
import 'package:icon_font_generator/src/common/codable/binary.dart';
import 'package:icon_font_generator/src/otf/debugger.dart';
import 'package:icon_font_generator/src/otf/table/abstract.dart';
import 'package:icon_font_generator/src/otf/table/table_record_entry.dart';
import 'package:icon_font_generator/src/utils/otf.dart';

const _kFormat0 = 0;
const _kFormat4 = 4;
const _kFormat12 = 12;

const _kEncodingRecordSize = 8;
const _kSequentialMapGroupSize = 12;
const _kByteEncodingTableSize = 256 + 6;

/// Ordered list of encoding record templates, sorted by platform and encoding
/// ID
List<EncodingRecord> _getDefaultEncodingRecordList() => [
      /// Unicode (2.0 or later semantics BMP only), format 4
      EncodingRecord.create(platformID: kPlatformUnicode, encodingID: 3),

      /// Unicode (Unicode 2.0 or later semantics non-BMP characters allowed),
      /// format 12
      EncodingRecord.create(platformID: kPlatformUnicode, encodingID: 4),

      /// Macintosh, format 0
      EncodingRecord.create(platformID: kPlatformMacintosh, encodingID: 0),

      /// Windows (Unicode BMP-only UCS-2), format 4
      EncodingRecord.create(platformID: kPlatformWindows, encodingID: 1),

      /// Windows (Unicode UCS-4), format 12
      EncodingRecord.create(platformID: kPlatformWindows, encodingID: 10),
    ];

/// Ordered list of encoding record format for each template
const _kDefaultEncodingRecordFormatList = [
  _kFormat4,
  _kFormat12,
  _kFormat0,
  _kFormat4,
  _kFormat12,
];

class Segment {
  Segment({
    required this.startCode,
    required this.endCode,
    required this.startGlyphID,
  });

  final int startCode;
  final int endCode;
  final int startGlyphID;

  int get idDelta => startGlyphID - startCode;
}

class EncodingRecord implements BinaryCodable {
  EncodingRecord({
    required this.platformID,
    required this.encodingID,
    required this.offset,
  });

  EncodingRecord.create({
    required this.platformID,
    required this.encodingID,
  }) : offset = null;

  factory EncodingRecord.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    return EncodingRecord(
      platformID: byteData.getUint16(offset),
      encodingID: byteData.getUint16(offset + 2),
      offset: byteData.getUint32(offset + 4),
    );
  }

  final int platformID;
  final int encodingID;
  int? offset;

  @override
  int get size => _kEncodingRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, platformID)
      ..setUint16(2, encodingID)
      ..setUint32(4, offset!);
  }
}

class SequentialMapGroup implements BinaryCodable {
  SequentialMapGroup({
    required this.startCharCode,
    required this.endCharCode,
    required this.startGlyphID,
  });

  factory SequentialMapGroup.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    return SequentialMapGroup(
      startCharCode: byteData.getUint32(offset),
      endCharCode: byteData.getUint32(offset + 4),
      startGlyphID: byteData.getUint32(offset + 8),
    );
  }

  final int startCharCode;
  final int endCharCode;
  final int startGlyphID;

  @override
  int get size => _kSequentialMapGroupSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint32(0, startCharCode)
      ..setUint32(4, endCharCode)
      ..setUint32(8, startGlyphID);
  }
}

class CharacterToGlyphTableHeader implements BinaryCodable {
  CharacterToGlyphTableHeader({
    required this.version,
    required this.numTables,
    required this.encodingRecords,
  });

  factory CharacterToGlyphTableHeader.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final version = byteData.getUint16(entry.offset);
    final numTables = byteData.getUint16(entry.offset + 2);
    final encodingRecords = List.generate(
      numTables,
      (i) => EncodingRecord.fromByteData(
        byteData: byteData,
        offset: entry.offset + 4 + _kEncodingRecordSize * i,
      ),
    );

    return CharacterToGlyphTableHeader(
      version: version,
      numTables: numTables,
      encodingRecords: encodingRecords,
    );
  }

  final int version;
  final int numTables;
  final List<EncodingRecord> encodingRecords;

  @override
  int get size => 4 + _kEncodingRecordSize * encodingRecords.length;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, version)
      ..setUint16(2, numTables);

    for (var i = 0; i < encodingRecords.length; i++) {
      final r = encodingRecords[i];
      r.encodeToBinary(
        byteData.sublistView(4 + _kEncodingRecordSize * i, r.size),
      );
    }
  }
}

abstract class CmapData implements BinaryCodable {
  CmapData({required this.format});

  static CmapData? fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final format = byteData.getUint16(offset);

    switch (format) {
      case _kFormat0:
        return CmapByteEncodingTable.fromByteData(
          byteData: byteData,
          offset: offset,
        );
      case _kFormat4:
        return CmapSegmentMappingToDeltaValuesTable.fromByteData(
          byteData: byteData,
          startOffset: offset,
        );
      case _kFormat12:
        return CmapSegmentedCoverageTable.fromByteData(
          byteData: byteData,
          offset: offset,
        );
      default:
        debugUnsupportedTableFormat(kCmapTag, format);
        return null;
    }
  }

  static CmapData? create({
    required List<Segment> segmentList,
    required int format,
  }) {
    switch (format) {
      case _kFormat0:
        return CmapByteEncodingTable.create();
      case _kFormat4:
        return CmapSegmentMappingToDeltaValuesTable.create(
          segmentList: segmentList,
        );
      case _kFormat12:
        return CmapSegmentedCoverageTable.create(segmentList: segmentList);
      default:
        debugUnsupportedTableFormat(kCmapTag, format);
        return null;
    }
  }

  final int format;
}

class CmapByteEncodingTable extends CmapData {
  CmapByteEncodingTable({
    required super.format,
    required this.length,
    required this.language,
    required this.glyphIdArray,
  });

  factory CmapByteEncodingTable.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    return CmapByteEncodingTable(
      format: byteData.getUint16(offset),
      length: byteData.getUint16(offset + 2),
      language: byteData.getUint16(offset + 4),
      glyphIdArray: List.generate(
        256,
        (i) => byteData.getUint8(offset + 6 + i),
      ),
    );
  }

  factory CmapByteEncodingTable.create() {
    return CmapByteEncodingTable(
      format: _kFormat0,
      length: _kByteEncodingTableSize,
      language: 0,
      glyphIdArray: List.filled(256, 0), // Not using standard mac glyphs
    );
  }

  final int length;
  final int language;
  final List<int> glyphIdArray;

  @override
  int get size => _kByteEncodingTableSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, format)
      ..setUint16(2, length)
      ..setUint16(4, language);

    for (var i = 0; i < glyphIdArray.length; i++) {
      byteData.setUint8(6 + i, glyphIdArray[i]);
    }
  }
}

class CmapSegmentMappingToDeltaValuesTable extends CmapData {
  CmapSegmentMappingToDeltaValuesTable({
    required super.format,
    required this.length,
    required this.language,
    required this.segCount,
    required this.searchRange,
    required this.entrySelector,
    required this.rangeShift,
    required this.endCode,
    required this.reservedPad,
    required this.startCode,
    required this.idDelta,
    required this.idRangeOffset,
    required this.glyphIdArray,
  });

  factory CmapSegmentMappingToDeltaValuesTable.fromByteData({
    required ByteData byteData,
    required int startOffset,
  }) {
    final length = byteData.getUint16(startOffset + 2);
    final segCount = byteData.getUint16(startOffset + 6) ~/ 2;

    var offset = startOffset + 14;

    final endCode =
        List.generate(segCount, (i) => byteData.getUint16(offset + 2 * i));
    offset += 2 * segCount;

    final reservedPad = byteData.getUint16(offset);
    offset += 2;

    final startCode =
        List.generate(segCount, (i) => byteData.getUint16(offset + 2 * i));
    offset += 2 * segCount;

    final idDelta =
        List.generate(segCount, (i) => byteData.getInt16(offset + 2 * i));
    offset += 2 * segCount;

    final idRangeOffset =
        List.generate(segCount, (i) => byteData.getUint16(offset + 2 * i));
    offset += 2 * segCount;

    final glyphIdArrayLength = ((startOffset + length) - offset) >> 1;
    final glyphIdArray = List.generate(
      glyphIdArrayLength,
      (i) => byteData.getUint16(offset + 2 * i),
    );

    return CmapSegmentMappingToDeltaValuesTable(
      format: byteData.getUint16(startOffset),
      length: length,
      language: byteData.getUint16(startOffset + 4),
      segCount: segCount,
      searchRange: byteData.getUint16(startOffset + 8),
      entrySelector: byteData.getUint16(startOffset + 10),
      rangeShift: byteData.getUint16(startOffset + 12),
      endCode: endCode,
      reservedPad: reservedPad,
      startCode: startCode,
      idDelta: idDelta,
      idRangeOffset: idRangeOffset,
      glyphIdArray: glyphIdArray,
    );
  }

  factory CmapSegmentMappingToDeltaValuesTable.create({
    required List<Segment> segmentList,
  }) {
    final startCode = segmentList.map((e) => e.startCode).toList();
    final endCode = segmentList.map((e) => e.endCode).toList();
    final idDelta = segmentList.map((e) => e.idDelta).toList();

    final segCount = segmentList.length;

    // Ignoring glyphIdArray
    final glyphIdArray = <int>[];
    final idRangeOffset = List.generate(segCount, (_) => 0);

    final entrySelector = (math.log(segCount) / math.ln2).floor();
    final searchRange = 2 * math.pow(2, entrySelector).toInt();
    final rangeShift = 2 * segCount - searchRange;

    /// Eight 2-byte variable
    /// Four 2-byte arrays of [segCount] length
    /// glyphIdArray is zero length
    final length = 16 + 4 * 2 * segCount;

    return CmapSegmentMappingToDeltaValuesTable(
      format: _kFormat4,
      length: length,
      language: 0, // Roman language
      segCount: segCount,
      searchRange: searchRange,
      entrySelector: entrySelector,
      rangeShift: rangeShift,
      endCode: endCode,
      reservedPad: 0, // Reserved
      startCode: startCode,
      idDelta: idDelta,
      idRangeOffset: idRangeOffset,
      glyphIdArray: glyphIdArray,
    );
  }

  final int length;
  final int language;
  final int segCount;
  final int searchRange;
  final int entrySelector;
  final int rangeShift;
  final List<int> endCode;
  final int reservedPad;
  final List<int> startCode;
  final List<int> idDelta;
  final List<int> idRangeOffset;
  final List<int> glyphIdArray;

  @override
  int get size => length;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, format)
      ..setUint16(2, length)
      ..setUint16(4, language)
      ..setUint16(6, segCount * 2)
      ..setUint16(8, searchRange)
      ..setUint16(10, entrySelector)
      ..setUint16(12, rangeShift);

    var offset = 14;

    for (final code in endCode) {
      byteData.setUint16(offset, code);
      offset += 2;
    }

    byteData.setUint16(offset, reservedPad);
    offset += 2;

    for (final code in startCode) {
      byteData.setUint16(offset, code);
      offset += 2;
    }

    for (final delta in idDelta) {
      byteData.setUint16(offset, delta);
      offset += 2;
    }

    for (final rangeOffset in idRangeOffset) {
      byteData.setUint16(offset, rangeOffset);
      offset += 2;
    }

    for (final glyphId in glyphIdArray) {
      byteData.setUint16(offset, glyphId);
      offset += 2;
    }
  }
}

class CmapSegmentedCoverageTable extends CmapData {
  CmapSegmentedCoverageTable({
    required super.format,
    required this.reserved,
    required this.length,
    required this.language,
    required this.numGroups,
    required this.groups,
  });

  factory CmapSegmentedCoverageTable.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final numGroups = byteData.getUint32(offset + 12);

    return CmapSegmentedCoverageTable(
      format: byteData.getUint16(offset),
      reserved: byteData.getUint16(offset + 2),
      length: byteData.getUint32(offset + 4),
      language: byteData.getUint32(offset + 8),
      numGroups: numGroups,
      groups: List.generate(
        numGroups,
        (i) => SequentialMapGroup.fromByteData(
          byteData: byteData,
          offset: offset + 16 + _kSequentialMapGroupSize * i,
        ),
      ),
    );
  }

  factory CmapSegmentedCoverageTable.create({
    required List<Segment> segmentList,
  }) {
    final groups = segmentList
        .map(
          (e) => SequentialMapGroup(
            startCharCode: e.startCode,
            endCharCode: e.endCode,
            startGlyphID: e.startGlyphID,
          ),
        )
        .toList();

    final numGroups = groups.length;
    final groupsSize = numGroups * _kSequentialMapGroupSize;

    /// Two 2-byte variables
    /// Three 4-byte variables
    /// SequentialMapGroup (12-byte) array of [numGroups] length
    final length = 16 + groupsSize;

    return CmapSegmentedCoverageTable(
      format: _kFormat12,
      reserved: 0,
      length: length,
      language: 0, // Roman language
      numGroups: numGroups,
      groups: groups,
    );
  }

  final int reserved;
  final int length;
  final int language;
  final int numGroups;
  final List<SequentialMapGroup> groups;

  @override
  int get size => length;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, format)
      ..setUint16(2, reserved)
      ..setUint32(4, length)
      ..setUint32(8, language)
      ..setUint32(12, numGroups);

    var offset = 16;

    for (final group in groups) {
      group.encodeToBinary(byteData.sublistView(offset, group.size));
      offset += group.size;
    }
  }
}

class CharacterToGlyphTable extends FontTable {
  CharacterToGlyphTable({
    required TableRecordEntry? entry,
    required this.header,
    required this.data,
  }) : super.fromTableRecordEntry(entry);

  factory CharacterToGlyphTable.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final header = CharacterToGlyphTableHeader.fromByteData(
      byteData: byteData,
      entry: entry,
    );
    final data = List.generate(
      header.numTables,
      (i) => CmapData.fromByteData(
        byteData: byteData,
        offset: entry.offset + header.encodingRecords[i].offset!,
      ),
    ).whereType<CmapData>().toList();

    return CharacterToGlyphTable(
      entry: entry,
      header: header,
      data: data,
    );
  }

  factory CharacterToGlyphTable.create({
    required List<GenericGlyph> fullGlyphList,
  }) {
    final fullCharCodeList = fullGlyphList
        .map((e) => e.metadata.charCode)
        .toList()
      ..removeAt(0); // removing .notdef
    final charCodeList = fullCharCodeList.whereType<int>().toList();

    final segmentList = _generateSegments(charCodeList: charCodeList);
    final segmentListFormat4 = [
      ...segmentList,
      Segment(
        startCode: 0xFFFF,
        endCode: 0xFFFF,
        startGlyphID: 1,
      ), // Format 4 table must end with 0xFFFF char code
    ];

    final subtableByFormat = _kDefaultEncodingRecordFormatList
        .toSet()
        .fold<Map<int, CmapData?>>({}, (p, format) {
      p[format] = CmapData.create(
        segmentList: format == _kFormat4 ? segmentListFormat4 : segmentList,
        format: format,
      );
      return p;
    });

    final subtables = [
      for (final format in _kDefaultEncodingRecordFormatList)
        if (subtableByFormat[format] != null) subtableByFormat[format]!,
    ];

    final header = CharacterToGlyphTableHeader(
      version: 0,
      numTables: subtables.length,
      encodingRecords: _getDefaultEncodingRecordList(),
    );

    return CharacterToGlyphTable(
      entry: null,
      header: header,
      data: subtables,
    );
  }

  final CharacterToGlyphTableHeader header;
  final List<CmapData> data;

  static List<Segment> _generateSegments({required List<int> charCodeList}) {
    var startCharCode = -1;
    var prevCharCode = -1;
    var startGlyphId = -1;

    final segmentList = <Segment>[];

    void saveSegment() {
      segmentList.add(
        Segment(
          startCode: startCharCode,
          endCode: prevCharCode,
          startGlyphID: startGlyphId + 1, // +1 because of .notdef
        ),
      );
    }

    for (var glyphId = 0; glyphId < charCodeList.length; glyphId++) {
      final charCode = charCodeList[glyphId];

      if (prevCharCode + 1 != charCode && startCharCode != -1) {
        // Save a segment, if there's a gap between previous and current codes
        saveSegment();

        // Next segment starts with new code
        startCharCode = charCode;
        startGlyphId = glyphId;
      } else if (startCharCode == -1) {
        // Start a new segment
        startCharCode = charCode;
        startGlyphId = glyphId;
      }

      prevCharCode = charCode;
    }

    // Closing the last segment
    if (startCharCode != -1 && prevCharCode != -1) {
      saveSegment();
    }

    return segmentList;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    var subtableIndex = 0;
    var offset = header.size;

    for (final subtable in data) {
      subtable.encodeToBinary(byteData.sublistView(offset, subtable.size));
      header.encodingRecords[subtableIndex++].offset = offset;
      offset += subtable.size;
    }

    header.encodeToBinary(byteData.sublistView(0, header.size));
  }

  @override
  int get size => header.size + data.fold<int>(0, (p, d) => p + d.size);
}
