import 'dart:math' as math;
import 'dart:typed_data';

import 'package:icon_font_generator/src/otf/debugger.dart';
import 'package:icon_font_generator/src/otf/table/abstract.dart';
import 'package:icon_font_generator/src/otf/table/cmap.dart';
import 'package:icon_font_generator/src/otf/table/gsub.dart';
import 'package:icon_font_generator/src/otf/table/head.dart';
import 'package:icon_font_generator/src/otf/table/hhea.dart';
import 'package:icon_font_generator/src/otf/table/hmtx.dart';
import 'package:icon_font_generator/src/otf/table/table_record_entry.dart';
import 'package:icon_font_generator/src/utils/exception.dart';
import 'package:icon_font_generator/src/utils/misc.dart';
import 'package:icon_font_generator/src/utils/otf.dart';

const _kVersion0 = 0x0000;
const _kVersion1 = 0x0001;
const _kVersion4 = 0x0004;
const _kVersion5 = 0x0005;

/// Byte size for fields added with specific version
const _kVersionDataSize = {
  _kVersion0: 78,
  _kVersion1: 8,
  _kVersion4: 10,
  _kVersion5: 4,
};

const _kDefaultSubscriptRelativeXsize = .65;
const _kDefaultSubscriptRelativeYsize = .7;
const _kDefaultSubscriptRelativeYoffset = .14;
const _kDefaultSuperscriptRelativeYoffset = .48;
const _kDefaultStrikeoutRelativeSize = .1;
const _kDefaultStrikeoutRelativeOffset = .26;

/// Default values for PANOSE classification:
///
/// * Family type: Latin Text
/// * Serif style: Any
/// * Font weight: Book
/// * Proportion: Modern
/// * Anything else: Any
const _kDefaultPANOSE = [2, 0, 5, 3, 0, 0, 0, 0, 0, 0];

class OS2Table extends FontTable {
  OS2Table._({
    required TableRecordEntry? entry,
    required this.version,
    required this.xAvgCharWidth,
    required this.usWeightClass,
    required this.usWidthClass,
    required this.fsType,
    required this.ySubscriptXSize,
    required this.ySubscriptYSize,
    required this.ySubscriptXOffset,
    required this.ySubscriptYOffset,
    required this.ySuperscriptXSize,
    required this.ySuperscriptYSize,
    required this.ySuperscriptXOffset,
    required this.ySuperscriptYOffset,
    required this.yStrikeoutSize,
    required this.yStrikeoutPosition,
    required this.sFamilyClass,
    required this.panose,
    required this.ulUnicodeRange1,
    required this.ulUnicodeRange2,
    required this.ulUnicodeRange3,
    required this.ulUnicodeRange4,
    required this.achVendID,
    required this.fsSelection,
    required this.usFirstCharIndex,
    required this.usLastCharIndex,
    required this.sTypoAscender,
    required this.sTypoDescender,
    required this.sTypoLineGap,
    required this.usWinAscent,
    required this.usWinDescent,
    required this.ulCodePageRange1,
    required this.ulCodePageRange2,
    required this.sxHeight,
    required this.sCapHeight,
    required this.usDefaultChar,
    required this.usBreakChar,
    required this.usMaxContext,
    required this.usLowerOpticalPointSize,
    required this.usUpperOpticalPointSize,
  }) : super.fromTableRecordEntry(entry);

  factory OS2Table.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final version = byteData.getInt16(entry.offset);

    final isV1 = version >= _kVersion1;
    final isV4 = version >= _kVersion4;
    final isV5 = version >= _kVersion5;

    if (version > _kVersion5) {
      debugUnsupportedTableVersion(kOS2Tag, version);
    }

    return OS2Table._(
      entry: entry,
      version: version,
      xAvgCharWidth: byteData.getInt16(entry.offset + 2),
      usWeightClass: byteData.getUint16(entry.offset + 4),
      usWidthClass: byteData.getUint16(entry.offset + 6),
      fsType: byteData.getUint16(entry.offset + 8),
      ySubscriptXSize: byteData.getInt16(entry.offset + 10),
      ySubscriptYSize: byteData.getInt16(entry.offset + 12),
      ySubscriptXOffset: byteData.getInt16(entry.offset + 14),
      ySubscriptYOffset: byteData.getInt16(entry.offset + 16),
      ySuperscriptXSize: byteData.getInt16(entry.offset + 18),
      ySuperscriptYSize: byteData.getInt16(entry.offset + 20),
      ySuperscriptXOffset: byteData.getInt16(entry.offset + 22),
      ySuperscriptYOffset: byteData.getInt16(entry.offset + 24),
      yStrikeoutSize: byteData.getInt16(entry.offset + 26),
      yStrikeoutPosition: byteData.getInt16(entry.offset + 28),
      sFamilyClass: byteData.getInt16(entry.offset + 30),
      panose: List.generate(
        10,
        (i) => byteData.getUint8(entry.offset + 32 + i),
      ),
      ulUnicodeRange1: byteData.getUint32(entry.offset + 42),
      ulUnicodeRange2: byteData.getUint32(entry.offset + 46),
      ulUnicodeRange3: byteData.getUint32(entry.offset + 50),
      ulUnicodeRange4: byteData.getUint32(entry.offset + 54),
      achVendID: byteData.getTag(entry.offset + 58),
      fsSelection: byteData.getUint16(entry.offset + 62),
      usFirstCharIndex: byteData.getUint16(entry.offset + 64),
      usLastCharIndex: byteData.getUint16(entry.offset + 66),
      sTypoAscender: byteData.getInt16(entry.offset + 68),
      sTypoDescender: byteData.getInt16(entry.offset + 70),
      sTypoLineGap: byteData.getInt16(entry.offset + 72),
      usWinAscent: byteData.getUint16(entry.offset + 74),
      usWinDescent: byteData.getUint16(entry.offset + 76),
      ulCodePageRange1: !isV1 ? null : byteData.getUint32(entry.offset + 78),
      ulCodePageRange2: !isV1 ? null : byteData.getUint32(entry.offset + 82),
      sxHeight: !isV4 ? null : byteData.getInt16(entry.offset + 86),
      sCapHeight: !isV4 ? null : byteData.getInt16(entry.offset + 88),
      usDefaultChar: !isV4 ? null : byteData.getUint16(entry.offset + 90),
      usBreakChar: !isV4 ? null : byteData.getUint16(entry.offset + 92),
      usMaxContext: !isV4 ? null : byteData.getUint16(entry.offset + 94),
      usLowerOpticalPointSize:
          !isV5 ? null : byteData.getUint16(entry.offset + 96),
      usUpperOpticalPointSize:
          !isV5 ? null : byteData.getUint16(entry.offset + 98),
    );
  }

  factory OS2Table.create({
    required HorizontalMetricsTable hmtx,
    required HeaderTable head,
    required HorizontalHeaderTable hhea,
    required CharacterToGlyphTable cmap,
    required GlyphSubstitutionTable gsub,
    required String achVendID,
    int version = _kVersion5,
  }) {
    final asciiAchVendID = achVendID.getAsciiPrintable();

    if (asciiAchVendID.length != 4) {
      throw TableDataFormatException(
        'Incorrect achVendID tag format in OS/2 table',
      );
    }

    final emSize = head.unitsPerEm;
    final height = hhea.ascender - hhea.descender;

    final isV1 = version >= _kVersion1;
    final isV4 = version >= _kVersion4;
    final isV5 = version >= _kVersion5;

    final scriptXsize = (emSize * _kDefaultSubscriptRelativeXsize).round();
    final scriptYsize = (height * _kDefaultSubscriptRelativeYsize).round();
    final subscriptYoffset =
        (height * _kDefaultSubscriptRelativeYoffset).round();
    final superscriptYoffset =
        (height * _kDefaultSuperscriptRelativeYoffset).round();
    final strikeoutSize = (height * _kDefaultStrikeoutRelativeSize).round();
    final strikeoutOffset = (height * _kDefaultStrikeoutRelativeOffset).round();

    final cmapFormat4subtable =
        cmap.data.whereType<CmapSegmentMappingToDeltaValuesTable>().first;

    return OS2Table._(
      entry: null,
      version: version,
      xAvgCharWidth: _getAverageWidth(hmtx: hmtx),
      usWeightClass: 400, // Regular weight
      usWidthClass: 5, // Normal width
      fsType: 0, // Installable embedding
      ySubscriptXSize: scriptXsize,
      ySubscriptYSize: scriptYsize,
      ySubscriptXOffset: 0,
      ySubscriptYOffset: subscriptYoffset,
      ySuperscriptXSize: scriptXsize,
      ySuperscriptYSize: scriptYsize,
      ySuperscriptXOffset: 0,
      ySuperscriptYOffset: superscriptYoffset,
      yStrikeoutSize: strikeoutSize,
      yStrikeoutPosition: strikeoutOffset,
      sFamilyClass: 0, // No Classification
      panose: _kDefaultPANOSE,
      // NOTE: Only 2 unicode ranges are used now.
      //
      // Should be made calculated, in case of using other ranges.
      // Bit 1: Basic Latin. Includes space
      ulUnicodeRange1: 1,
      // Bits 57 & 60: Non-Plane 0 and Private Use Area
      // 1 << 25, Bits 57 & 60: Non-Plane 0 and Private Use Area
      ulUnicodeRange2: (1 << 28) | (1 << 25),
      ulUnicodeRange3: 0,
      ulUnicodeRange4: 0,
      achVendID: asciiAchVendID,
      fsSelection: 0x40 | 0x80, // REGULAR and USE_TYPO_METRICS
      usFirstCharIndex: cmapFormat4subtable.startCode.first,
      usLastCharIndex: cmapFormat4subtable.endCode.last,
      sTypoAscender: hhea.ascender,
      sTypoDescender: hhea.descender,
      sTypoLineGap: hhea.lineGap,
      usWinAscent: math.max(head.yMax, hhea.ascender),
      usWinDescent: -math.min(head.yMin, hhea.descender),
      ulCodePageRange1: !isV1 ? null : 0, // The code page is not functional
      ulCodePageRange2: !isV1 ? null : 0,
      sxHeight: !isV4 ? null : 0,
      sCapHeight: !isV4 ? null : 0,
      usDefaultChar: !isV4 ? null : 0,
      usBreakChar: !isV4 ? null : kUnicodeSpaceCharCode,
      usMaxContext: !isV4 ? null : _getMaxContext(gsub: gsub),
      // For fonts that were not designed for multiple optical-size variants,
      // usLowerOpticalPointSize should be set to 0 (zero),
      // and usUpperOpticalPointSize should be set to 0xFFFF.
      usLowerOpticalPointSize: !isV5 ? null : 0,
      usUpperOpticalPointSize: !isV5 ? null : 0xFFFE,
    );
  }

  final int version;

  // Version 0
  final int xAvgCharWidth;
  final int usWeightClass;
  final int usWidthClass;
  final int fsType;
  final int ySubscriptXSize;
  final int ySubscriptYSize;
  final int ySubscriptXOffset;
  final int ySubscriptYOffset;
  final int ySuperscriptXSize;
  final int ySuperscriptYSize;
  final int ySuperscriptXOffset;
  final int ySuperscriptYOffset;
  final int yStrikeoutSize;
  final int yStrikeoutPosition;
  final int sFamilyClass;
  final List<int> panose;
  final int ulUnicodeRange1;
  final int ulUnicodeRange2;
  final int ulUnicodeRange3;
  final int ulUnicodeRange4;
  final String achVendID;
  final int fsSelection;
  final int usFirstCharIndex;
  final int usLastCharIndex;
  final int sTypoAscender;
  final int sTypoDescender;
  final int sTypoLineGap;
  final int usWinAscent;
  final int usWinDescent;

  // Version 1
  final int? ulCodePageRange1;
  final int? ulCodePageRange2;

  // Version 4
  final int? sxHeight;
  final int? sCapHeight;
  final int? usDefaultChar;
  final int? usBreakChar;
  final int? usMaxContext;

  // Version 5
  final int? usLowerOpticalPointSize;
  final int? usUpperOpticalPointSize;

  @override
  int get size {
    var size = 0;

    for (final e in _kVersionDataSize.entries) {
      if (e.key > version) {
        break;
      }

      size += e.value;
    }

    return size;
  }

  static int _getAverageWidth({required HorizontalMetricsTable hmtx}) {
    if (hmtx.hMetrics.isEmpty) {
      return 0;
    }

    final nonEmptyWidths = hmtx.hMetrics.where((m) => m.advanceWidth > 0);

    final widthSum = nonEmptyWidths.fold<int>(0, (p, m) => p + m.advanceWidth);
    return (widthSum / nonEmptyWidths.length).round();
  }

  // NOTE: GPOS is also used in calculation, not supported yet
  static int _getMaxContext({required GlyphSubstitutionTable gsub}) {
    if (gsub.lookupListTable.lookupTables.isEmpty) {
      return 0;
    }

    var maxContext = 0;

    for (final lookup in gsub.lookupListTable.lookupTables) {
      for (final subtable in lookup.subtables) {
        maxContext = math.max(maxContext, subtable.maxContext);
      }
    }

    return maxContext;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    final isV1 = version >= _kVersion1;
    final isV4 = version >= _kVersion4;
    final isV5 = version >= _kVersion5;

    if (version > _kVersion5) {
      debugUnsupportedTableVersion(kOS2Tag, version);
    }

    byteData
      ..setInt16(0, version)
      ..setInt16(2, xAvgCharWidth)
      ..setUint16(4, usWeightClass)
      ..setUint16(6, usWidthClass)
      ..setUint16(8, fsType)
      ..setInt16(10, ySubscriptXSize)
      ..setInt16(12, ySubscriptYSize)
      ..setInt16(14, ySubscriptXOffset)
      ..setInt16(16, ySubscriptYOffset)
      ..setInt16(18, ySuperscriptXSize)
      ..setInt16(20, ySuperscriptYSize)
      ..setInt16(22, ySuperscriptXOffset)
      ..setInt16(24, ySuperscriptYOffset)
      ..setInt16(26, yStrikeoutSize)
      ..setInt16(28, yStrikeoutPosition)
      ..setInt16(30, sFamilyClass)
      ..setUint32(42, ulUnicodeRange1)
      ..setUint32(46, ulUnicodeRange2)
      ..setUint32(50, ulUnicodeRange3)
      ..setUint32(54, ulUnicodeRange4)
      ..setTag(58, achVendID)
      ..setUint16(62, fsSelection)
      ..setUint16(64, usFirstCharIndex)
      ..setUint16(66, usLastCharIndex)
      ..setInt16(68, sTypoAscender)
      ..setInt16(70, sTypoDescender)
      ..setInt16(72, sTypoLineGap)
      ..setUint16(74, usWinAscent)
      ..setUint16(76, usWinDescent);

    for (var i = 0; i < panose.length; i++) {
      byteData.setUint8(32 + i, panose[i]);
    }

    if (isV1) {
      byteData
        ..setUint32(78, ulCodePageRange1!)
        ..setUint32(82, ulCodePageRange2!);
    }

    if (isV4) {
      byteData
        ..setInt16(86, sxHeight!)
        ..setInt16(88, sCapHeight!)
        ..setUint16(90, usDefaultChar!)
        ..setUint16(92, usBreakChar!)
        ..setUint16(94, usMaxContext!);
    }

    if (isV5) {
      byteData
        ..setUint16(96, usLowerOpticalPointSize!)
        ..setUint16(98, usUpperOpticalPointSize!);
    }
  }
}
