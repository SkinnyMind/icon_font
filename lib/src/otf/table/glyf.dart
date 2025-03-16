import 'dart:math' as math;
import 'dart:typed_data';

import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/glyph/header.dart';
import 'package:icon_font/src/otf/table/glyph/simple.dart';
import 'package:icon_font/src/otf/table/loca.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

class GlyphDataTable extends FontTable {
  GlyphDataTable({required TableRecordEntry? entry, required this.glyphList})
    : super.fromTableRecordEntry(entry);

  factory GlyphDataTable.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
    required IndexToLocationTable locationTable,
    required int numGlyphs,
  }) {
    final glyphList = <SimpleGlyph>[];

    for (var i = 0; i < numGlyphs; i++) {
      final headerOffset = entry.offset + locationTable.glyphOffsets[i];
      final nextHeaderOffset = entry.offset + locationTable.glyphOffsets[i + 1];
      final isEmpty = headerOffset == nextHeaderOffset;

      final header = GlyphHeader.fromByteData(
        byteData: byteData,
        offset: headerOffset,
      );

      if (header.isComposite) {
        Log.logger.w('Composite glyph (glyph header offset $headerOffset)');
      } else {
        final glyph =
            isEmpty
                ? SimpleGlyph.empty()
                : SimpleGlyph.fromByteData(
                  byteData: byteData,
                  header: header,
                  glyphOffset: headerOffset,
                );
        glyphList.add(glyph);
      }
    }

    return GlyphDataTable(entry: entry, glyphList: glyphList);
  }

  factory GlyphDataTable.fromGlyphs({required List<GenericGlyph> glyphList}) {
    final glyphListCopy = glyphList.map((e) => e.copy());

    for (final glyph in glyphListCopy) {
      for (final outline in glyph.outlines) {
        if (!outline.hasQuadCurves) {
          // TODO: implement cubic -> quad approximation
          throw UnimplementedError(
            'Cubic to quadratic curve conversion not supported',
          );
        }

        outline.compactImplicitPoints();
      }
    }

    final simpleGlyphList =
        glyphListCopy.map((e) => e.toSimpleTrueTypeGlyph()).toList();

    return GlyphDataTable(entry: null, glyphList: simpleGlyphList);
  }

  final List<SimpleGlyph> glyphList;

  @override
  int get size => glyphList.fold<int>(
    0,
    (p, v) => p + OtfUtils.getPaddedTableSize(actualSize: v.size),
  );

  int get maxPoints =>
      glyphList.fold<int>(0, (p, g) => math.max(p, g.pointList.length));

  int get maxContours =>
      glyphList.fold<int>(0, (p, g) => math.max(p, g.header.numberOfContours));

  int get maxSizeOfInstructions =>
      glyphList.fold<int>(0, (p, g) => math.max(p, g.instructions.length));

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    for (final glyph in glyphList) {
      if (glyph.isEmpty) {
        continue;
      }

      glyph.encodeToBinary(byteData.sublistView(offset, glyph.size));
      offset += OtfUtils.getPaddedTableSize(actualSize: glyph.size);
    }
  }
}
