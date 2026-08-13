import 'dart:math' as math;
import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

const _format0 = 0;
const _format4 = 4;
const _format12 = 12;

const _encodingRecordSize = 8;
const _sequentialMapGroupSize = 12;

/// Ordered list of encoding record format for each template
const _defaultEncodingRecordFormatList = [
  _format4,
  _format12,
  _format0,
  _format4,
  _format12,
];

class const Segment({
  required final int startCode,
  required final int endCode,
  required final int startGlyphID,
}) {
  int get idDelta => startGlyphID - startCode;
}

class EncodingRecord implements BinaryCodable {
  EncodingRecord({
    required this.platformID,
    required this.encodingID,
    required this.offset,
  });

  EncodingRecord.create({required this.platformID, required this.encodingID})
    : offset = null;

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
  int get size => _encodingRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, platformID)
      ..setUint16(2, encodingID)
      ..setUint32(4, offset!);
  }
}

class const SequentialMapGroup({
  required final int startCharCode,
  required final int endCharCode,
  required final int startGlyphID,
}) implements BinaryCodable {
  factory fromByteData({required ByteData byteData, required int offset}) {
    return SequentialMapGroup(
      startCharCode: byteData.getUint32(offset),
      endCharCode: byteData.getUint32(offset + 4),
      startGlyphID: byteData.getUint32(offset + 8),
    );
  }

  @override
  int get size => _sequentialMapGroupSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint32(0, startCharCode)
      ..setUint32(4, endCharCode)
      ..setUint32(8, startGlyphID);
  }
}

class const CharacterToGlyphTableHeader({
  required final int version,
  required final int numTables,
  required final List<EncodingRecord> encodingRecords,
}) implements BinaryCodable {
  factory fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final version = byteData.getUint16(entry.offset);
    final numTables = byteData.getUint16(entry.offset + 2);
    final encodingRecords = List.generate(
      numTables,
      (i) => EncodingRecord.fromByteData(
        byteData: byteData,
        offset: entry.offset + 4 + _encodingRecordSize * i,
      ),
    );

    return CharacterToGlyphTableHeader(
      version: version,
      numTables: numTables,
      encodingRecords: encodingRecords,
    );
  }

  @override
  int get size => 4 + _encodingRecordSize * encodingRecords.length;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, version)
      ..setUint16(2, numTables);

    for (var i = 0; i < encodingRecords.length; i++) {
      final r = encodingRecords[i];
      r.encodeToBinary(
        byteData.sublistView(4 + _encodingRecordSize * i, r.size),
      );
    }
  }
}

abstract class const CmapData({required final int format})
    implements BinaryCodable {
  static CmapData? fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final format = byteData.getUint16(offset);

    return switch (format) {
      _format0 => CmapByteEncodingTable.fromByteData(
        byteData: byteData,
        offset: offset,
      ),
      _format4 => CmapSegmentMappingToDeltaValuesTable.fromByteData(
        byteData: byteData,
        startOffset: offset,
      ),
      _format12 => CmapSegmentedCoverageTable.fromByteData(
        byteData: byteData,
        offset: offset,
      ),
      _ => () {
        Log.unsupportedTableFormat(kCmapTag, format);
        return null;
      }(),
    };
  }

  static CmapData? create({
    required List<Segment> segmentList,
    required int format,
  }) {
    return switch (format) {
      _format0 => CmapByteEncodingTable.create(),
      _format4 => CmapSegmentMappingToDeltaValuesTable.create(
        segmentList: segmentList,
      ),
      _format12 => CmapSegmentedCoverageTable.create(segmentList: segmentList),
      _ => () {
        Log.unsupportedTableFormat(kCmapTag, format);
        return null;
      }(),
    };
  }
}

class const CmapByteEncodingTable({
  required super.format,
  required final int length,
  required final int language,
  required final List<int> glyphIdArray,
}) extends CmapData {
  factory fromByteData({required ByteData byteData, required int offset}) {
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

  factory create() {
    return CmapByteEncodingTable(
      format: _format0,
      length: 256 + 6,
      language: 0,
      glyphIdArray: List.filled(256, 0), // Not using standard mac glyphs
    );
  }

  @override
  int get size => 256 + 6;

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

class const CmapSegmentMappingToDeltaValuesTable({
  required super.format,
  required final int length,
  required final int language,
  required final int segCount,
  required final int searchRange,
  required final int entrySelector,
  required final int rangeShift,
  required final List<int> endCode,
  required final int reservedPad,
  required final List<int> startCode,
  required final List<int> idDelta,
  required final List<int> idRangeOffset,
  required final List<int> glyphIdArray,
}) extends CmapData {
  factory fromByteData({required ByteData byteData, required int startOffset}) {
    final length = byteData.getUint16(startOffset + 2);
    final segCount = byteData.getUint16(startOffset + 6) ~/ 2;

    var offset = startOffset + 14;

    final endCode = List.generate(
      segCount,
      (i) => byteData.getUint16(offset + 2 * i),
    );
    offset += 2 * segCount;

    final reservedPad = byteData.getUint16(offset);
    offset += 2;

    final startCode = List.generate(
      segCount,
      (i) => byteData.getUint16(offset + 2 * i),
    );
    offset += 2 * segCount;

    final idDelta = List.generate(
      segCount,
      (i) => byteData.getInt16(offset + 2 * i),
    );
    offset += 2 * segCount;

    final idRangeOffset = List.generate(
      segCount,
      (i) => byteData.getUint16(offset + 2 * i),
    );
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

  factory create({required List<Segment> segmentList}) {
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
      format: _format4,
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

class const CmapSegmentedCoverageTable({
  required super.format,
  required final int reserved,
  required final int length,
  required final int language,
  required final int numGroups,
  required final List<SequentialMapGroup> groups,
}) extends CmapData {
  factory fromByteData({required ByteData byteData, required int offset}) {
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
          offset: offset + 16 + _sequentialMapGroupSize * i,
        ),
      ),
    );
  }

  factory create({required List<Segment> segmentList}) {
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
    final groupsSize = numGroups * _sequentialMapGroupSize;

    /// Two 2-byte variables
    /// Three 4-byte variables
    /// SequentialMapGroup (12-byte) array of [numGroups] length
    final length = 16 + groupsSize;

    return CmapSegmentedCoverageTable(
      format: _format12,
      reserved: 0,
      length: length,
      language: 0, // Roman language
      numGroups: numGroups,
      groups: groups,
    );
  }

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

class CharacterToGlyphTable({
  required TableRecordEntry? entry,
  required final CharacterToGlyphTableHeader header,
  required final List<CmapData> data,
}) extends FontTable {
  this : super.fromTableRecordEntry(entry);

  factory fromByteData({
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

    return CharacterToGlyphTable(entry: entry, header: header, data: data);
  }

  factory create({required List<GenericGlyph> fullGlyphList}) {
    final fullCharCodeList =
        fullGlyphList.map((e) => e.metadata.charCode).toList()
          ..removeAt(0); // removing .notdef
    final charCodeList = fullCharCodeList.whereType<int>().toList();

    final segmentList = _generateSegments(charCodeList: charCodeList);
    final segmentListFormat4 = [
      ...segmentList,
      const Segment(
        startCode: 0xFFFF,
        endCode: 0xFFFF,
        startGlyphID: 1,
      ), // Format 4 table must end with 0xFFFF char code
    ];

    final subtableByFormat = _defaultEncodingRecordFormatList
        .toSet()
        .fold<Map<int, CmapData?>>({}, (p, format) {
          p[format] = CmapData.create(
            segmentList: format == _format4 ? segmentListFormat4 : segmentList,
            format: format,
          );
          return p;
        });

    final subtables = [
      for (final format in _defaultEncodingRecordFormatList)
        if (subtableByFormat[format] != null) subtableByFormat[format]!,
    ];

    final header = CharacterToGlyphTableHeader(
      version: 0,
      numTables: subtables.length,
      encodingRecords: [
        // Unicode (2.0 or later semantics BMP only), format 4
        EncodingRecord.create(platformID: kPlatformUnicode, encodingID: 3),
        // Unicode (Unicode 2.0 or later semantics non-BMP characters allowed),
        // format 12
        EncodingRecord.create(platformID: kPlatformUnicode, encodingID: 4),
        // Macintosh, format 0
        EncodingRecord.create(platformID: kPlatformMacintosh, encodingID: 0),
        // Windows (Unicode BMP-only UCS-2), format 4
        EncodingRecord.create(platformID: kPlatformWindows, encodingID: 1),
        // Windows (Unicode UCS-4), format 12
        EncodingRecord.create(platformID: kPlatformWindows, encodingID: 10),
      ],
    );

    return CharacterToGlyphTable(entry: null, header: header, data: subtables);
  }

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
