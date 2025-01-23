import 'dart:io';

import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/otf/otf.dart';
import 'package:icon_font/src/svg/svg.dart';
import 'package:icon_font/src/utils/constants.dart';
import 'package:test/test.dart';

void main() {
  const testAssetsDir = './test/assets';

  const testCompSvgPathList = [
    '$testAssetsDir/svg/comp_first.svg',
    '$testAssetsDir/svg/comp_second.svg',
    '$testAssetsDir/svg/comp_third.svg',
  ];

  group('OTF Normalization', () {
    List<GenericGlyph> createGlyphList() {
      final svgFileList = testCompSvgPathList.map(File.new);
      final svgList = svgFileList.map(
        (e) => Svg.parse(name: e.path, xmlString: e.readAsStringSync()),
      );
      return svgList.map(GenericGlyph.fromSvg).toList();
    }

    test('Metrics, normalization is off', () {
      final font = OpenTypeFont.createFromGlyphs(
        glyphList: createGlyphList(),
        normalize: false,
      );
      final widthList = font.hmtx.hMetrics.map((e) => e.advanceWidth);
      const unitsPerEm = defaultOpenTypeUnitsPerEm;

      expect(widthList, [350, 333, unitsPerEm, unitsPerEm, unitsPerEm]);
      expect(font.hhea.ascender, 1000);
      expect(font.hhea.descender, 0);
    });

    test('Metrics, normalization is on', () {
      final font = OpenTypeFont.createFromGlyphs(
        glyphList: createGlyphList(),
        normalize: true,
      );
      final widthList = font.hmtx.hMetrics.map((e) => e.advanceWidth);

      expect(widthList, [298, 333, 362, 270, 208]);
      expect(font.hhea.ascender, 850);
      expect(font.hhea.descender, -150);
    });
  });
}
