import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/otf/otf.dart';
import 'package:icon_font/src/svg/svg.dart';
import 'package:icon_font/src/utils/constants.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

class IconFont {
  const IconFont._();

  /// Converts SVG icons to OTF font.
  ///
  /// * [svgMap] contains name (key) to data (value) SVG mapping. Required.
  ///
  /// * If [ignoreShapes] is set to false, shapes (circle, rect, etc.) are
  /// converted into paths. Defaults to true. NOTE: Attributes like "fill" or
  /// "stroke" are ignored,
  /// which means only shape's outline will be used.
  ///
  /// * If [normalize] is set to true,
  /// glyphs are resized and centered to fit in coordinates grid (unitsPerEm).
  /// Defaults to true.
  ///
  /// * [fontName] is a name for a generated font.
  ///
  /// Returns an instance of [SvgToOtfResult] class containing glyphs and a
  /// font.
  static SvgToOtfResult svgToOtf({
    required Map<String, String> svgMap,
    bool? ignoreShapes,
    bool? normalize,
    String? fontName,
  }) {
    normalize ??= true;
    ignoreShapes ??= true;

    final svgList = [
      for (final e in svgMap.entries)
        Svg.parse(name: e.key, xmlString: e.value, ignoreShapes: ignoreShapes),
    ];

    svgList.sort((a, b) => a.name.compareTo(b.name));

    if (!normalize) {
      for (var i = 1; i < svgList.length; i++) {
        if (svgList[i - 1].viewBox.height != svgList[i].viewBox.height) {
          Log.once(
            Level.warning,
            'Some SVG files contain different view box height, '
            'while normalization option is disabled. '
            'This is not recommended.',
          );
          break;
        }
      }
    }

    final glyphList = svgList.map(GenericGlyph.fromSvg).toList();

    final font = OpenTypeFont.createFromGlyphs(
      glyphList: glyphList,
      fontName: fontName,
      normalize: normalize,
      useOpenType: true,
      usePostV2: true,
    );

    return SvgToOtfResult._(glyphList: glyphList, font: font);
  }

  /// Generates a Flutter-compatible class for a list of glyphs.
  ///
  /// * [glyphList] is a list of non-default glyphs.
  ///
  /// * [className] is generated class' name (preferably, in PascalCase).
  ///
  /// * [familyName] is font's family name to use in IconData.
  ///
  /// * [package] is the name of a font package. Used to provide a font through
  /// package dependency.
  ///
  /// * [fontFileName] is font file's name. Used in generated docs for class.
  ///
  /// Returns content of a class file.
  static String generateFlutterClass({
    required List<GenericGlyph> glyphList,
    String? className,
    String? familyName,
    String? fontFileName,
    String? package,
    bool? iconList,
  }) {
    className ??= 'UiIcons';
    familyName ??= defaultFontFamily;
    fontFileName ??= 'icon_font_icons.otf';
    final packageName = package?.isEmpty ?? true ? null : package;
    final iconVarNames = _generateVariableNames(glyphList: glyphList);
    iconList ??= false;

    final replacedClassName = className
        .replaceAll(RegExp(r'[^a-zA-Z0-9_$]'), '')
        .replaceFirstMapped(RegExp(r'^[^a-zA-Z$]'), (_) => '');

    final classContent = [
      'const $replacedClassName._();',
      '',
      "static const iconFontFamily = '$familyName';",
      if (package != null) "static const iconFontPackage = '$packageName';",
      for (var i = 0; i < glyphList.length; i++)
        ..._generateIconConst(
          glyphList: glyphList,
          iconVarNames: iconVarNames,
          hasPackage: package != null,
          index: i,
        ),
      if (iconList) '',
      '/// List of all icons in this font.',
      'static const List<IconData> values = <IconData>[',
      for (final iconName in iconVarNames) ...['$iconName,'],
      '];',
    ].join('\n');

    return '''// Generated code: do not hand-edit.

import 'package:flutter/widgets.dart';

/// Identifiers for the icons.
///
/// Use with the [Icon] class to show specific icons.
///
/// Icons are identified by their name as listed below.
///
/// To use this class, make sure you declare the font in your
/// project's `pubspec.yaml` file in the `fonts` section. This ensures that
/// the "$familyName" font is included in your application. This font is used to
/// display the icons. For example:
///
/// ```yaml
/// flutter:
///   fonts:
///     - family: $familyName
///       fonts:
///         - asset: packages/package_name/fonts/$fontFileName
/// ```
@staticIconProvider
class $className {
$classContent
}
''';
  }

  static List<String> _generateVariableNames({
    required List<GenericGlyph> glyphList,
  }) {
    final iconNameSet = <String>{};

    return glyphList.map((g) {
      final baseName = p
          .basenameWithoutExtension(g.metadata.name!)
          .replaceAll(RegExp(r'[^a-zA-Z0-9_$-]'), '')
          .replaceFirstMapped(RegExp(r'^[^a-zA-Z$]'), (_) => '')
          .camelCase;
      final usingDefaultName = baseName.isEmpty;

      var variableName = usingDefaultName ? 'unnamed' : baseName;

      // Handling same names by adding numeration to them
      if (iconNameSet.contains(variableName)) {
        // If name already contains numeration, then splitting it
        final countMatch = RegExp(r'^(.*)_([0-9]+)$').firstMatch(variableName);

        var variableNameCount = 1;
        var variableWithoutCount = variableName;

        if (countMatch != null) {
          variableNameCount = int.parse(countMatch.group(2)!);
          variableWithoutCount = countMatch.group(1)!;
        }

        String variableNameWithCount;

        do {
          variableNameWithCount =
              '${variableWithoutCount}_${++variableNameCount}';
        } while (iconNameSet.contains(variableNameWithCount));

        variableName = variableNameWithCount;
      }

      iconNameSet.add(variableName);

      return variableName;
    }).toList()..sort();
  }

  static List<String> _generateIconConst({
    required List<GenericGlyph> glyphList,
    required List<String> iconVarNames,
    required bool hasPackage,
    required int index,
  }) {
    final glyphMeta = glyphList[index].metadata;

    final charCode = glyphMeta.charCode!;

    final varName = iconVarNames[index];
    final hexCode = charCode.toRadixString(16);

    final posParamList = [
      'fontFamily: iconFontFamily',
      if (hasPackage) 'fontPackage: iconFontPackage',
    ];

    final posParamString = posParamList.join(', ');

    return [
      '',
      if (glyphMeta.preview != null) ...[
        "/// <image width='32px' src='data:image/svg+xml;base64,${glyphMeta.preview}'>",
      ],
      'static const IconData $varName = IconData(0x$hexCode, $posParamString);',
    ];
  }
}

/// Result of svg-to-otf conversion.
///
/// Contains list of generated glyphs and created font.
class SvgToOtfResult {
  SvgToOtfResult._({required this.glyphList, required this.font});

  final List<GenericGlyph> glyphList;
  final OpenTypeFont font;
}

class ReCase {
  ReCase(String text) {
    originalText = text;
    _words = _groupIntoWords(text);
  }

  final _upperAlphaRegex = RegExp('[A-Z]');

  final symbolSet = {' ', '.', '/', '_', r'\', '-'};

  late String originalText;
  late List<String> _words;

  List<String> _groupIntoWords(String text) {
    final sb = StringBuffer();
    final words = <String>[];
    final isAllCaps = text.toUpperCase() == text;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      final nextChar = i + 1 == text.length ? null : text[i + 1];

      if (symbolSet.contains(char)) {
        continue;
      }

      sb.write(char);

      final isEndOfWord =
          nextChar == null ||
          (_upperAlphaRegex.hasMatch(nextChar) && !isAllCaps) ||
          symbolSet.contains(nextChar);

      if (isEndOfWord) {
        words.add(sb.toString());
        sb.clear();
      }
    }

    return words;
  }

  String get camelCase => _getCamelCase();

  String _getCamelCase({String separator = ''}) {
    final words = _words.map(_upperCaseFirstLetter).toList();
    if (_words.isNotEmpty) {
      words[0] = words[0].toLowerCase();
    }

    return words.join(separator);
  }

  String _upperCaseFirstLetter(String word) {
    return '${word.substring(0, 1).toUpperCase()}'
        '${word.substring(1).toLowerCase()}';
  }
}

extension StringReCase on String {
  String get camelCase => ReCase(this).camelCase;
}
