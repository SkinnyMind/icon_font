import 'dart:math';
import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/common/calculatable_offsets.dart';
import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/common/outline.dart';
import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/cff1.dart';
import 'package:icon_font/src/otf/table/cff2.dart';
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
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

/// An OpenType font.
/// Contains either TrueType (glyf table) or OpenType (CFF2 table) outlines
class OpenTypeFont implements BinaryCodable {
  OpenTypeFont({required this.offsetTable, required this.tableMap});

  /// Generates new OpenType font.
  ///
  /// Mutates every glyph's metadata,
  /// so that it contains newly generated charcode.
  ///
  /// * [glyphList] is a list of generic glyphs. Required.
  /// * [fontName] is a font name.
  ///   If null, glyph names are omitted (PostScriptV3 table is generated).
  /// * [description] is a font description for naming table.
  /// * [revision] is a font revision. Defaults to 1.0.
  /// * [achVendID] is a vendor ID in OS/2 table. Defaults to 4 spaces.
  /// * If [useOpenType] is set to true, OpenType outlines
  /// in CFF table format are generated.
  /// Otherwise, a font with TrueType outlines (TTF) is generated.
  /// Defaults to true.
  /// * If [usePostV2] is set to true, post table of version 2 is generated
  /// (containing a name for each glyph).
  /// Otherwise, version 3 table (without glyph names) is generated.
  /// Defaults to false.
  /// * If [normalize] is set to true,
  /// glyphs are resized and centered to fit in coordinates grid (unitsPerEm).
  /// Defaults to true.
  factory OpenTypeFont.createFromGlyphs({
    required List<GenericGlyph> glyphList,
    String? fontName,
    String? description,
    Revision? revision,
    String? achVendID,
    bool? useOpenType,
    bool? usePostV2,
    bool? normalize,
  }) {
    var localFontName = (fontName?.isEmpty ?? false) ? null : fontName;
    var localGlyphList = glyphList;

    revision ??= const Revision(1, 0);
    achVendID ??= '    ';
    localFontName ??= defaultFontFamily;
    useOpenType ??= true;
    normalize ??= true;
    usePostV2 ??= false;

    localGlyphList = _generateCharCodes(glyphList: localGlyphList);

    // A power of two is recommended only for TrueType outlines
    final unitsPerEm = useOpenType ? defaultOpenTypeUnitsPerEm : 1024;

    final GlyphScalingStrategy scalingStrategy;
    final int ascender;
    final int descender;

    if (normalize) {
      const baselineExtension = 150;
      ascender = unitsPerEm - baselineExtension;
      descender = -baselineExtension;
      scalingStrategy = AscenderDescenderScalingStrategy(
        ascender: ascender,
        descender: descender,
      );
    } else {
      ascender = unitsPerEm;
      descender = 0;
      scalingStrategy = FontHeightScalingStrategy(unitsPerEm);
    }

    final resizedGlyphList = _resizeAndCenter(
      glyphList: localGlyphList,
      strategy: scalingStrategy,
    );

    final defaultGlyphList = _generateDefaultGlyphList(ascender: ascender);
    final fullGlyphList = [...defaultGlyphList, ...resizedGlyphList];

    final defaultGlyphMetricsList = defaultGlyphList
        .map((g) => g.metrics)
        .toList();

    // If normalization is off every custom glyph's size equals unitsPerEm
    final customGlyphMetricsList = normalize
        ? resizedGlyphList.map((g) => g.metrics).toList()
        : List.filled(
            resizedGlyphList.length,
            GenericGlyphMetrics.square(unitsPerEm: unitsPerEm),
          );

    final glyphMetricsList = [
      ...defaultGlyphMetricsList,
      ...customGlyphMetricsList,
    ];

    final glyf = useOpenType
        ? null
        : GlyphDataTable.fromGlyphs(glyphList: fullGlyphList);
    final head = HeaderTable.create(
      glyphMetricsList: glyphMetricsList,
      glyf: glyf,
      revision: revision,
      unitsPerEm: unitsPerEm,
    );
    final loca = useOpenType
        ? null
        : IndexToLocationTable.create(
            indexToLocFormat: head.indexToLocFormat,
            glyf: glyf!,
          );
    final hmtx = HorizontalMetricsTable.create(
      glyphMetricsList: glyphMetricsList,
      unitsPerEm: unitsPerEm,
    );
    final hhea = HorizontalHeaderTable.create(
      glyphMetricsList: glyphMetricsList,
      hmtx: hmtx,
      ascender: ascender,
      descender: descender,
    );
    final post = PostScriptTable.create(
      glyphList: resizedGlyphList,
      usePostV2: usePostV2,
    );
    final name = NamingTable.create(
      fontName: localFontName,
      description: description,
      revision: revision,
    );

    if (name == null) {
      throw TableDataFormatException('Unknown "name" table format');
    }

    final maxp = MaximumProfileTable.create(
      numGlyphs: fullGlyphList.length,
      glyf: glyf,
    );
    final cmap = CharacterToGlyphTable.create(fullGlyphList: fullGlyphList);
    final gsub = GlyphSubstitutionTable.create();
    final os2 = OS2Table.create(
      hmtx: hmtx,
      head: head,
      hhea: hhea,
      cmap: cmap,
      gsub: gsub,
      achVendID: achVendID,
      version: OS2TableVersion.v5.value,
    );

    final cff = useOpenType
        ? CFF1Table.create(
            glyphList: fullGlyphList,
            head: head,
            hmtx: hmtx,
            name: name,
          )
        : null;

    final tables = <String, FontTable>{
      if (!useOpenType) ...{kGlyfTag: glyf!, kLocaTag: loca!},
      if (useOpenType) ...{kCFFTag: cff!},
      kCmapTag: cmap,
      kMaxpTag: maxp,
      kHeadTag: head,
      kHmtxTag: hmtx,
      kHheaTag: hhea,
      kPostTag: post,
      kNameTag: name,
      kGSUBTag: gsub,
      kOS2Tag: os2,
    };

    final offsetTable = OffsetTable.create(
      numTables: tables.length,
      isOpenType: useOpenType,
    );

    return OpenTypeFont(offsetTable: offsetTable, tableMap: tables);
  }

  final OffsetTable offsetTable;
  final Map<String, FontTable> tableMap;

  HeaderTable get head => tableMap[kHeadTag]! as HeaderTable;

  MaximumProfileTable get maxp => tableMap[kMaxpTag]! as MaximumProfileTable;

  IndexToLocationTable get loca => tableMap[kLocaTag]! as IndexToLocationTable;

  GlyphDataTable get glyf => tableMap[kGlyfTag]! as GlyphDataTable;

  GlyphSubstitutionTable get gsub =>
      tableMap[kGSUBTag]! as GlyphSubstitutionTable;

  OS2Table get os2 => tableMap[kOS2Tag]! as OS2Table;

  PostScriptTable get post => tableMap[kPostTag]! as PostScriptTable;

  NamingTable get name => tableMap[kNameTag]! as NamingTable;

  CharacterToGlyphTable get cmap =>
      tableMap[kCmapTag]! as CharacterToGlyphTable;

  HorizontalHeaderTable get hhea =>
      tableMap[kHheaTag]! as HorizontalHeaderTable;

  HorizontalMetricsTable get hmtx =>
      tableMap[kHmtxTag]! as HorizontalMetricsTable;

  CFF1Table get cff => tableMap[kCFFTag]! as CFF1Table;

  CFF2Table get cff2 => tableMap[kCFF2Tag]! as CFF2Table;

  bool get isOpenType => offsetTable.isOpenType;

  String get familyName => name.familyName;

  @override
  void encodeToBinary(ByteData byteData) {
    var currentTableOffset = offsetTableLength + entryListSize;

    final entryList = <TableRecordEntry>[];

    /// Ordered list of table tags for encoding (Optimized Table Ordering)
    const tableTagsToEncode = {
      kHeadTag,
      kHheaTag,
      kMaxpTag,
      kOS2Tag,
      kHmtxTag,
      kNameTag, // NOTE: 'name' should be after 'cmap' for TTF
      kCmapTag,
      kLocaTag,
      kGlyfTag,
      kPostTag,
      kCFFTag,
      kCFF2Tag,
      kGSUBTag,
    };
    for (final tag in tableTagsToEncode) {
      final table = tableMap[tag];

      if (table == null) {
        continue;
      }

      if (table is CalculatableOffsets) {
        (table as CalculatableOffsets).recalculateOffsets();
      }

      final tableSize = table.size;

      table.encodeToBinary(byteData.sublistView(currentTableOffset, tableSize));
      final encodedTable = ByteData.sublistView(
        byteData,
        currentTableOffset,
        currentTableOffset + tableSize,
      );

      table.entry = TableRecordEntry(
        tag: tag,
        checkSum: OtfUtils.calculateTableChecksum(encodedTable: encodedTable),
        offset: currentTableOffset,
        length: tableSize,
      );
      entryList.add(table.entry!);

      currentTableOffset += OtfUtils.getPaddedTableSize(actualSize: tableSize);
    }

    // The directory entry tags must be in ascending order
    entryList.sort((e1, e2) => e1.tag.compareTo(e2.tag));

    for (var i = 0; i < entryList.length; i++) {
      final entryOffset = offsetTableLength + i * tableRecordEntryLength;
      final entryByteData = byteData.sublistView(
        entryOffset,
        tableRecordEntryLength,
      );
      entryList[i].encodeToBinary(entryByteData);
    }

    offsetTable.encodeToBinary(byteData.sublistView(0, offsetTableLength));

    // Setting checksum for whole font in the head table
    final fontChecksum = OtfUtils.calculateFontChecksum(byteData: byteData);
    byteData.setUint32(head.entry!.offset + 8, fontChecksum);
  }

  int get entryListSize => tableRecordEntryLength * tableMap.length;

  int get tableListSize => tableMap.values.fold<int>(
    0,
    (p, t) => p + OtfUtils.getPaddedTableSize(actualSize: t.size),
  );

  @override
  int get size => offsetTableLength + entryListSize + tableListSize;

  static List<GenericGlyph> _resizeAndCenter({
    required List<GenericGlyph> glyphList,
    required GlyphScalingStrategy strategy,
  }) {
    return glyphList.map((g) => strategy.scale(g)).toList();
  }

  static List<GenericGlyph> _generateCharCodes({
    required List<GenericGlyph> glyphList,
  }) {
    for (var i = 0; i < glyphList.length; i++) {
      glyphList[i].metadata.charCode = unicodePrivateUseAreaStart + i;
    }
    return glyphList;
  }

  /// Generates list of default glyphs (.notdef 'rectangle' and empty space)
  static List<GenericGlyph> _generateDefaultGlyphList({required int ascender}) {
    final notdef = _generateNotdefGlyph(ascender: ascender);
    final space = GenericGlyph.empty();

    // .notdef doesn't have charcode
    space.metadata.charCode = unicodeSpaceCharCode;

    return [notdef, space];
  }

  static GenericGlyph _generateNotdefGlyph({required int ascender}) {
    const kRelativeWidth = .7;
    const kRelativeThickness = .1;

    final xOuterOffset = (kRelativeWidth * ascender / 2).round();
    final thickness = (kRelativeThickness * xOuterOffset).round();

    final outerRect = Rectangle.fromPoints(
      const Point(0, 0),
      Point(xOuterOffset, ascender),
    );

    final innerRect = Rectangle.fromPoints(
      Point(thickness, thickness),
      Point(xOuterOffset - thickness, ascender - thickness),
    );

    final outlines = [
      // Outer rectangle clockwise
      Outline(
        pointList: [
          outerRect.bottomLeft,
          outerRect.bottomRight,
          outerRect.topRight,
          outerRect.topLeft,
        ],
        isOnCurveList: List.filled(4, true),
        hasCompactCurves: false,
        hasQuadCurves: true,
        fillRule: FillRule.nonzero,
      ),

      // Inner rectangle counter-clockwise
      Outline(
        pointList: [
          innerRect.bottomLeft,
          innerRect.topLeft,
          innerRect.topRight,
          innerRect.bottomRight,
        ],
        isOnCurveList: List.filled(4, true),
        hasCompactCurves: false,
        hasQuadCurves: true,
        fillRule: FillRule.nonzero,
      ),
    ];

    return GenericGlyph(outlines: outlines, bounds: outerRect);
  }
}

/// Interface for glyph scaling logic.
abstract class GlyphScalingStrategy {
  GenericGlyph scale(GenericGlyph glyph);
}

/// Strategy for resizing according to unitsPerEm (fontHeight).
class FontHeightScalingStrategy implements GlyphScalingStrategy {
  FontHeightScalingStrategy(this.fontHeight);

  final int fontHeight;

  @override
  GenericGlyph scale(GenericGlyph glyph) {
    return glyph.resize(
      fontHeight: fontHeight,
      ratioX: glyph.metadata.ratioX,
      ratioY: glyph.metadata.ratioY,
    );
  }
}

/// Strategy for resizing and centering within ascender/descender bounds.
class AscenderDescenderScalingStrategy implements GlyphScalingStrategy {
  AscenderDescenderScalingStrategy({
    required this.ascender,
    required this.descender,
  });

  final int ascender;
  final int descender;

  @override
  GenericGlyph scale(GenericGlyph glyph) {
    return glyph
        .resize(
          ascender: ascender,
          descender: descender,
          ratioX: glyph.metadata.ratioX,
          ratioY: glyph.metadata.ratioY,
        )
        .center(
          ascender: ascender,
          descender: descender,
          offset: glyph.metadata.offset ?? 0,
        );
  }
}
