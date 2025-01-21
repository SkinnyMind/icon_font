import 'dart:math' as math;
import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/hhea.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/konst.dart';

const _kLongHorMetricSize = 4;

class LongHorMetric implements BinaryCodable {
  LongHorMetric({required this.advanceWidth, required this.lsb});

  factory LongHorMetric.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    return LongHorMetric(
      advanceWidth: byteData.getUint16(offset),
      lsb: byteData.getInt16(offset + 2),
    );
  }

  factory LongHorMetric.createForGlyph({
    required GenericGlyphMetrics metrics,
    required int unitsPerEm,
  }) {
    return metrics.width == 0
        ? LongHorMetric(advanceWidth: unitsPerEm ~/ 3, lsb: 0)
        : LongHorMetric(advanceWidth: metrics.xMax - metrics.xMin, lsb: 0);
  }

  final int advanceWidth;
  final int lsb;

  int getRsb({required int xMax, required int xMin}) =>
      advanceWidth - (lsb + xMax - xMin);

  @override
  int get size => _kLongHorMetricSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, advanceWidth)
      ..setInt16(2, lsb);
  }
}

class HorizontalMetricsTable extends FontTable {
  HorizontalMetricsTable({
    required TableRecordEntry? entry,
    required this.hMetrics,
    required this.leftSideBearings,
  }) : super.fromTableRecordEntry(entry);

  factory HorizontalMetricsTable.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
    required HorizontalHeaderTable hhea,
    required int numGlyphs,
  }) {
    final hMetrics = List.generate(
      hhea.numberOfHMetrics,
      (i) => LongHorMetric.fromByteData(
        byteData: byteData,
        offset: entry.offset + _kLongHorMetricSize * i,
      ),
    );
    final offset = entry.offset + _kLongHorMetricSize * hhea.numberOfHMetrics;
    final leftSideBearings = List.generate(
      numGlyphs - hhea.numberOfHMetrics,
      (i) => byteData.getInt16(offset + 2 * i),
    );

    return HorizontalMetricsTable(
      entry: entry,
      hMetrics: hMetrics,
      leftSideBearings: leftSideBearings,
    );
  }

  factory HorizontalMetricsTable.create({
    required List<GenericGlyphMetrics> glyphMetricsList,
    required int unitsPerEm,
  }) {
    final hMetrics = List.generate(
      glyphMetricsList.length,
      (i) => LongHorMetric.createForGlyph(
        metrics: glyphMetricsList[i],
        unitsPerEm: unitsPerEm,
      ),
    );

    return HorizontalMetricsTable(
      entry: null,
      hMetrics: hMetrics,
      leftSideBearings: [],
    );
  }

  final List<LongHorMetric> hMetrics;
  final List<int> leftSideBearings;

  @override
  int get size =>
      hMetrics.length * _kLongHorMetricSize + leftSideBearings.length * 2;

  int get advanceWidthMax =>
      hMetrics.fold<int>(0, (p, v) => math.max(p, v.advanceWidth));

  int get minLeftSideBearing =>
      hMetrics.fold<int>(kInt32Max, (p, v) => math.min(p, v.lsb));

  int getMinRightSideBearing({
    required List<GenericGlyphMetrics> glyphMetricsList,
  }) {
    var minRsb = kInt32Max;

    for (var i = 0; i < glyphMetricsList.length; i++) {
      final m = glyphMetricsList[i];
      final rsb = hMetrics[i].getRsb(xMax: m.xMax, xMin: m.xMin);

      minRsb = math.min(minRsb, rsb);
    }

    return minRsb;
  }

  int getMaxExtent({required List<GenericGlyphMetrics> glyphMetricsList}) {
    var maxExtent = kInt32Min;

    for (var i = 0; i < glyphMetricsList.length; i++) {
      final m = glyphMetricsList[i];
      final extent = hMetrics[i].lsb + (m.xMax - m.xMin);

      maxExtent = math.max(maxExtent, extent);
    }

    return maxExtent;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    for (final hMetric in hMetrics) {
      hMetric.encodeToBinary(byteData.sublistView(offset, hMetric.size));
      offset += hMetric.size;
    }

    for (final lsb in leftSideBearings) {
      byteData.setUint16(offset, lsb);
      offset += 2;
    }
  }
}
