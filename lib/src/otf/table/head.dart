import 'dart:math' as math;
import 'dart:typed_data';

import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/otf/table/all.dart';
import 'package:icon_font/src/utils/konst.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

class HeaderTable extends FontTable {
  HeaderTable({
    required TableRecordEntry? entry,
    required this.fontRevision,
    required this.checkSumAdjustment,
    required this.flags,
    required this.unitsPerEm,
    required this.created,
    required this.modified,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.macStyle,
    required this.lowestRecPPEM,
    required this.indexToLocFormat,
  })  : majorVersion = 1,
        minorVersion = 0,
        fontDirectionHint = 2,
        glyphDataFormat = 0,
        magicNumber = 0x5F0F3CF5,
        super.fromTableRecordEntry(entry);

  HeaderTable._({
    required TableRecordEntry entry,
    required this.majorVersion,
    required this.minorVersion,
    required this.fontRevision,
    required this.checkSumAdjustment,
    required this.magicNumber,
    required this.flags,
    required this.unitsPerEm,
    required this.created,
    required this.modified,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.macStyle,
    required this.lowestRecPPEM,
    required this.fontDirectionHint,
    required this.indexToLocFormat,
    required this.glyphDataFormat,
  }) : super.fromTableRecordEntry(entry);

  factory HeaderTable.fromByteData({
    required ByteData data,
    required TableRecordEntry entry,
  }) {
    final createdAt = _longDateTimeStart.add(
      Duration(seconds: data.getInt64(entry.offset + 20)),
    );
    final modifiedAt = _longDateTimeStart.add(
      Duration(seconds: data.getInt64(entry.offset + 28)),
    );

    return HeaderTable._(
      entry: entry,
      majorVersion: data.getUint16(entry.offset),
      minorVersion: data.getUint16(entry.offset + 2),
      fontRevision: Revision.fromInt32(data.getInt32(entry.offset + 4)),
      checkSumAdjustment: data.getUint32(entry.offset + 8),
      magicNumber: data.getUint32(entry.offset + 12),
      flags: data.getUint16(entry.offset + 16),
      unitsPerEm: data.getUint16(entry.offset + 18),
      created: createdAt,
      modified: modifiedAt,
      xMin: data.getInt16(entry.offset + 36),
      yMin: data.getInt16(entry.offset + 38),
      xMax: data.getInt16(entry.offset + 40),
      yMax: data.getInt16(entry.offset + 42),
      macStyle: data.getUint16(entry.offset + 44),
      lowestRecPPEM: data.getUint16(entry.offset + 46),
      fontDirectionHint: data.getInt16(entry.offset + 48),
      indexToLocFormat: data.getInt16(entry.offset + 50),
      glyphDataFormat: data.getInt16(entry.offset + 52),
    );
  }

  factory HeaderTable.create({
    required List<GenericGlyphMetrics> glyphMetricsList,
    required GlyphDataTable? glyf,
    required Revision revision,
    required int unitsPerEm,
  }) {
    final now = DateTime.now();
    final xMin = glyphMetricsList.fold<int>(
      kInt32Max,
      (prev, m) => math.min(prev, m.xMin),
    );
    final yMin = glyphMetricsList.fold<int>(
      kInt32Max,
      (prev, m) => math.min(prev, m.yMin),
    );
    final xMax = glyphMetricsList.fold<int>(
      kInt32Min,
      (prev, m) => math.max(prev, m.xMax),
    );
    final yMax = glyphMetricsList.fold<int>(
      kInt32Min,
      (prev, m) => math.max(prev, m.yMax),
    );

    return HeaderTable(
      entry: null,
      fontRevision: revision,
      // Setting checkSum to zero first, calculating it at last for the entire
      // font
      checkSumAdjustment: 0,
      flags: 0x000B,
      unitsPerEm: unitsPerEm,
      created: now,
      modified: now,
      xMin: xMin,
      yMin: yMin,
      xMax: xMax,
      yMax: yMax,
      macStyle: 0,
      lowestRecPPEM: 8,
      indexToLocFormat: glyf == null || glyf.size < 0x20000 ? 0 : 1,
    );
  }

  final int majorVersion;
  final int minorVersion;
  final Revision fontRevision;
  final int checkSumAdjustment;
  final int magicNumber;
  final int flags;
  final int unitsPerEm;
  final DateTime created;
  final DateTime modified;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  final int macStyle;
  final int lowestRecPPEM;
  final int fontDirectionHint;
  final int indexToLocFormat;
  final int glyphDataFormat;

  static final _longDateTimeStart = DateTime.parse('1904-01-01T00:00:00.000Z');

  @override
  int get size => 54;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, majorVersion)
      ..setUint16(2, minorVersion)
      ..setInt32(4, fontRevision.int32value)
      ..setUint32(8, checkSumAdjustment)
      ..setUint32(12, magicNumber)
      ..setUint16(16, flags)
      ..setUint16(18, unitsPerEm)
      ..setInt64(20, created.difference(_longDateTimeStart).inSeconds)
      ..setInt64(28, modified.difference(_longDateTimeStart).inSeconds)
      ..setInt16(36, xMin)
      ..setInt16(38, yMin)
      ..setInt16(40, xMax)
      ..setInt16(42, yMax)
      ..setUint16(44, macStyle)
      ..setUint16(46, lowestRecPPEM)
      ..setInt16(48, fontDirectionHint)
      ..setInt16(50, indexToLocFormat)
      ..setInt16(52, glyphDataFormat);
  }
}
