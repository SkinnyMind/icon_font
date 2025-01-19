import 'dart:math' as math;

import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/common/outline.dart';
import 'package:icon_font/src/utils/misc.dart';
import 'package:icon_font/src/utils/otf.dart';

const kDefaultAchVendID = '    ';
const kDefaultFontFamily = 'icon_font Icons';
const kDefaultTrueTypeUnitsPerEm = 1024; // A power of two is recommended
const kDefaultOpenTypeUnitsPerEm = 1000;
const kDefaultBaselineExtension = 150;
const kDefaultFontRevision = Revision(1, 0);

// Default glyph indicies for post table.
const kDefaultGlyphIndex = <int>[
  0, // .notdef
  3, // space
];

/// Generates list of default glyphs (.notdef 'rectangle' and empty space)
List<GenericGlyph> generateDefaultGlyphList({required int ascender}) {
  final notdef = _generateNotdefGlyph(ascender: ascender);
  final space = GenericGlyph.empty();

  // .notdef doesn't have charcode
  space.metadata.charCode = kUnicodeSpaceCharCode;

  return [notdef, space];
}

GenericGlyph _generateNotdefGlyph({required int ascender}) {
  const kRelativeWidth = .7;
  const kRelativeThickness = .1;

  final xOuterOffset = (kRelativeWidth * ascender / 2).round();
  final thickness = (kRelativeThickness * xOuterOffset).round();

  final outerRect = math.Rectangle.fromPoints(
    const math.Point(0, 0),
    math.Point(xOuterOffset, ascender),
  );

  final innerRect = math.Rectangle.fromPoints(
    math.Point(thickness, thickness),
    math.Point(xOuterOffset - thickness, ascender - thickness),
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
