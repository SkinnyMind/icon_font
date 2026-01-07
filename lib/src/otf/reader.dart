import 'dart:typed_data';

import 'package:icon_font/src/otf/otf.dart';
import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/cff.dart';
import 'package:icon_font/src/otf/table/cmap.dart';
import 'package:icon_font/src/otf/table/glyf.dart';
import 'package:icon_font/src/otf/table/gsub.dart';
import 'package:icon_font/src/otf/table/head.dart';
import 'package:icon_font/src/otf/table/hhea.dart';
import 'package:icon_font/src/otf/table/hmtx.dart';
import 'package:icon_font/src/otf/table/loca.dart';
import 'package:icon_font/src/otf/table/maxp.dart';
import 'package:icon_font/src/otf/table/name.dart';
import 'package:icon_font/src/otf/table/offset.dart';
import 'package:icon_font/src/otf/table/os2.dart';
import 'package:icon_font/src/otf/table/post.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';
import 'package:icon_font/src/utils/constants.dart';
import 'package:icon_font/src/utils/exceptions.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

/// A helper for reading an OpenType font from a binary data.
class OTFReader {
  OTFReader.fromByteData(this._byteData);

  final ByteData _byteData;

  late OffsetTable _offsetTable;
  late OpenTypeFont _font;

  /// Tables by tags
  final _tableMap = <String, FontTable>{};

  /// Ordered set of table tags to parse first
  final _tagsParseOrder = <String>{kHeadTag, kMaxpTag, kLocaTag, kHheaTag};

  int get _indexToLocFormat => _font.head.indexToLocFormat;
  int get numGlyphs => _font.maxp.numGlyphs;

  /// Reads an OpenType font file and returns [OpenTypeFont] instance
  ///
  /// Throws [ChecksumException] if calculated checksum is different than
  /// expected
  OpenTypeFont read() {
    _tableMap.clear();

    final entryMap = <String, TableRecordEntry>{};

    _offsetTable = OffsetTable.fromByteData(data: _byteData);
    _font = OpenTypeFont(offsetTable: _offsetTable, tableMap: _tableMap);

    _readTableRecordEntries(outputMap: entryMap);
    _readTables(entryMap: entryMap);

    _validateChecksums();

    return _font;
  }

  int _readTableRecordEntries({
    required Map<String, TableRecordEntry> outputMap,
  }) {
    var offset = offsetTableLength;

    for (var i = 0; i < _offsetTable.numTables; i++) {
      final entry = TableRecordEntry.fromByteData(_byteData, offset);
      outputMap[entry.tag] = entry;
      _tagsParseOrder.add(entry.tag);

      offset += tableRecordEntryLength;
    }

    return offset;
  }

  void _readTables({required Map<String, TableRecordEntry> entryMap}) {
    for (final tag in _tagsParseOrder) {
      final entry = entryMap[tag];

      if (entry == null) {
        continue;
      }

      final table = _createTableFromEntry(entry: entry);

      if (table == null) {
        continue;
      }

      _tableMap[tag] = table;
    }
  }

  FontTable? _createTableFromEntry({required TableRecordEntry entry}) {
    return switch (entry.tag) {
      kHeadTag => HeaderTable.fromByteData(data: _byteData, entry: entry),
      kMaxpTag => MaximumProfileTable.fromByteData(
        data: _byteData,
        entry: entry,
      ),
      kLocaTag => IndexToLocationTable.fromByteData(
        byteData: _byteData,
        entry: entry,
        indexToLocFormat: _indexToLocFormat,
        numGlyphs: numGlyphs,
      ),
      kGlyfTag => GlyphDataTable.fromByteData(
        byteData: _byteData,
        entry: entry,
        locationTable: _font.loca,
        numGlyphs: numGlyphs,
      ),
      kGSUBTag => GlyphSubstitutionTable.fromByteData(
        byteData: _byteData,
        entry: entry,
      ),
      kOS2Tag => OS2Table.fromByteData(byteData: _byteData, entry: entry),
      kPostTag => PostScriptTable.fromByteData(
        byteData: _byteData,
        entry: entry,
      ),
      kNameTag => NamingTable.fromByteData(byteData: _byteData, entry: entry),
      kCmapTag => CharacterToGlyphTable.fromByteData(
        byteData: _byteData,
        entry: entry,
      ),
      kHheaTag => HorizontalHeaderTable.fromByteData(
        byteData: _byteData,
        entry: entry,
      ),
      kHmtxTag => HorizontalMetricsTable.fromByteData(
        byteData: _byteData,
        entry: entry,
        hhea: _font.hhea,
        numGlyphs: numGlyphs,
      ),
      kCFFTag ||
      kCFF2Tag => CFFTable.fromByteData(byteData: _byteData, entry: entry),
      _ => () {
        Log.logger.w('Unsupported table: ${entry.tag}');
        return null;
      }(),
    };
  }

  /// Validates tables' and font's checksum
  ///
  /// Throws [ChecksumException] if calculated checksum is different than
  /// expected
  void _validateChecksums() {
    final byteDataCopy =
        ByteData.sublistView(
          Uint8List.fromList([..._byteData.buffer.asUint8List()]),
        )..setUint32(
          _font.head.entry!.offset + 8,
          0,
        ); // Setting head table's checkSumAdjustment to 0

    for (final table in _font.tableMap.values) {
      final entry = table.entry!;

      final tableOffset = entry.offset;
      final tableLength = entry.length;

      final tableByteData = ByteData.sublistView(
        byteDataCopy,
        tableOffset,
        tableOffset + tableLength,
      );
      final actualChecksum = OtfUtils.calculateTableChecksum(
        encodedTable: tableByteData,
      );
      final expectedChecksum = entry.checkSum;

      if (actualChecksum != expectedChecksum) {
        throw ChecksumException.table(tableName: entry.tag);
      }
    }

    final actualFontChecksum = OtfUtils.calculateFontChecksum(
      byteData: byteDataCopy,
    );

    if (_font.head.checkSumAdjustment != actualFontChecksum) {
      throw ChecksumException.font();
    }
  }
}
