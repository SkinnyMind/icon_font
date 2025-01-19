import 'dart:typed_data';

import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/glyf.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

class IndexToLocationTable extends FontTable {
  IndexToLocationTable({
    required TableRecordEntry? entry,
    required this.glyphOffsets,
    required this.isShort,
  }) : super.fromTableRecordEntry(entry);

  factory IndexToLocationTable.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
    required int indexToLocFormat,
    required int numGlyphs,
  }) {
    final isShort = indexToLocFormat == 0;

    final offsets = <int>[
      for (var i = 0; i < numGlyphs + 1; i++)
        isShort
            ? byteData.getUint16(entry.offset + 2 * i) * 2
            : byteData.getUint32(entry.offset + 4 * i),
    ];

    return IndexToLocationTable(
      entry: entry,
      glyphOffsets: offsets,
      isShort: isShort,
    );
  }

  factory IndexToLocationTable.create({
    required int indexToLocFormat,
    required GlyphDataTable glyf,
  }) {
    final isShort = indexToLocFormat == 0;
    final offsets = <int>[];

    var offset = 0;

    for (final glyph in glyf.glyphList) {
      offsets.add(offset);
      offset += OtfUtils.getPaddedTableSize(actualSize: glyph.size);
    }

    offsets.add(offset);

    return IndexToLocationTable(
      entry: null,
      glyphOffsets: offsets,
      isShort: isShort,
    );
  }

  final List<int> glyphOffsets;
  final bool isShort;

  @override
  void encodeToBinary(ByteData byteData) {
    for (var i = 0; i < glyphOffsets.length; i++) {
      final offset = isShort ? glyphOffsets[i] ~/ 2 : glyphOffsets[i];
      isShort
          ? byteData.setUint16(2 * i, offset)
          : byteData.setUint32(4 * i, offset);
    }
  }

  @override
  int get size => glyphOffsets.length * (isShort ? 2 : 4);
}
