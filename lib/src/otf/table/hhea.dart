import 'dart:typed_data';

import 'package:icon_font_generator/src/common/generic_glyph.dart';
import 'package:icon_font_generator/src/otf/table/abstract.dart';
import 'package:icon_font_generator/src/otf/table/hmtx.dart';
import 'package:icon_font_generator/src/otf/table/table_record_entry.dart';
import 'package:icon_font_generator/src/utils/otf.dart';

const _kHheaTableSize = 36;

class HorizontalHeaderTable extends FontTable {
  HorizontalHeaderTable({
    required TableRecordEntry? entry,
    required this.majorVersion,
    required this.minorVersion,
    required this.ascender,
    required this.descender,
    required this.lineGap,
    required this.advanceWidthMax,
    required this.minLeftSideBearing,
    required this.minRightSideBearing,
    required this.xMaxExtent,
    required this.caretSlopeRise,
    required this.caretSlopeRun,
    required this.caretOffset,
    required this.metricDataFormat,
    required this.numberOfHMetrics,
  }) : super.fromTableRecordEntry(entry);

  factory HorizontalHeaderTable.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    return HorizontalHeaderTable(
      entry: entry,
      majorVersion: byteData.getUint16(entry.offset),
      minorVersion: byteData.getUint16(entry.offset + 2),
      ascender: byteData.getFWord(entry.offset + 4),
      descender: byteData.getFWord(entry.offset + 6),
      lineGap: byteData.getFWord(entry.offset + 8),
      advanceWidthMax: byteData.getUFWord(entry.offset + 10),
      minLeftSideBearing: byteData.getFWord(entry.offset + 12),
      minRightSideBearing: byteData.getFWord(entry.offset + 14),
      xMaxExtent: byteData.getFWord(entry.offset + 16),
      caretSlopeRise: byteData.getInt16(entry.offset + 18),
      caretSlopeRun: byteData.getInt16(entry.offset + 20),
      caretOffset: byteData.getInt16(entry.offset + 22),
      metricDataFormat: byteData.getInt16(entry.offset + 32),
      numberOfHMetrics: byteData.getUint16(entry.offset + 34),
    );
  }

  factory HorizontalHeaderTable.create({
    required List<GenericGlyphMetrics> glyphMetricsList,
    required HorizontalMetricsTable hmtx,
    required int ascender,
    required int descender,
  }) {
    return HorizontalHeaderTable(
      entry: null,
      majorVersion: 1,
      minorVersion: 0,
      ascender: ascender,
      descender: descender, // descender must be negative
      lineGap: 0,
      advanceWidthMax: hmtx.advanceWidthMax,
      minLeftSideBearing: hmtx.minLeftSideBearing,
      minRightSideBearing: hmtx.getMinRightSideBearing(
        glyphMetricsList: glyphMetricsList,
      ),
      xMaxExtent: hmtx.getMaxExtent(glyphMetricsList: glyphMetricsList),
      caretSlopeRise: 1,
      caretSlopeRun: 0,
      caretOffset: 0, // non-slanted font - no offset
      metricDataFormat: 0,
      numberOfHMetrics: glyphMetricsList.length,
    );
  }

  final int majorVersion;
  final int minorVersion;
  final int ascender;
  final int descender;
  final int lineGap;
  final int advanceWidthMax;
  final int minLeftSideBearing;
  final int minRightSideBearing;
  final int xMaxExtent;
  final int caretSlopeRise;
  final int caretSlopeRun;
  final int caretOffset;

  final int metricDataFormat;
  final int numberOfHMetrics;

  @override
  int get size => _kHheaTableSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, majorVersion)
      ..setUint16(2, minorVersion)
      ..setFWord(4, ascender)
      ..setFWord(6, descender)
      ..setFWord(8, lineGap)
      ..setUFWord(10, advanceWidthMax)
      ..setFWord(12, minLeftSideBearing)
      ..setFWord(14, minRightSideBearing)
      ..setFWord(16, xMaxExtent)
      ..setInt16(18, caretSlopeRise)
      ..setInt16(20, caretSlopeRun)
      ..setInt16(22, caretOffset)
      ..setInt16(32, metricDataFormat)
      ..setUint16(34, numberOfHMetrics);
  }
}
