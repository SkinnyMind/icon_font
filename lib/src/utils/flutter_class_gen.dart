import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/otf/defaults.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';

const _kUnnamedIconName = 'unnamed';
const _kDefaultIndent = 2;
const _kDefaultClassName = 'UiIcons';
const _kDefaultFontFileName = 'icon_font_icons.otf';

/// Removes any characters that are not valid for variable name.
///
/// Returns a new string.
String _getVarName(String string) {
  final replaced = string.replaceAll(RegExp(r'[^a-zA-Z0-9_$]'), '');
  return RegExp(r'^[a-zA-Z$].*').firstMatch(replaced)?.group(0) ?? '';
}

/// A helper for generating Flutter-compatible class with IconData objects for
/// each icon.
class FlutterClassGenerator {
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
  /// * [indent] is a number of spaces in leading indentation for class'
  /// members. Defaults to 2.
  FlutterClassGenerator({
    required this.glyphList,
    String? className,
    String? familyName,
    String? fontFileName,
    String? package,
    int? indent,
    bool? iconList = false,
  })  : _indent = ' ' * (indent ?? _kDefaultIndent),
        _className = _getVarName(className ?? _kDefaultClassName),
        _familyName = familyName ?? kDefaultFontFamily,
        _fontFileName = fontFileName ?? _kDefaultFontFileName,
        _iconVarNames = _generateVariableNames(glyphList: glyphList),
        _package = package?.isEmpty ?? true ? null : package,
        _iconList = iconList ?? false;

  final List<GenericGlyph> glyphList;
  final String _fontFileName;
  final String _className;
  final String _familyName;
  final String _indent;
  final String? _package;
  final List<String> _iconVarNames;
  final bool _iconList;

  static List<String> _generateVariableNames({
    required List<GenericGlyph> glyphList,
  }) {
    final iconNameSet = <String>{};

    return glyphList.map((g) {
      final baseName =
          _getVarName(p.basenameWithoutExtension(g.metadata.name!)).camelCase;
      final usingDefaultName = baseName.isEmpty;

      var variableName = usingDefaultName ? _kUnnamedIconName : baseName;

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
    }).toList();
  }

  bool get _hasPackage => _package != null;

  String get _fontFamilyConst =>
      "static const iconFontFamily = '$_familyName';";

  String get _fontPackageConst => "static const iconFontPackage = '$_package';";

  List<String> _generateIconConst({required int index}) {
    final glyphMeta = glyphList[index].metadata;

    final charCode = glyphMeta.charCode!;

    final varName = _iconVarNames[index];
    final hexCode = charCode.toRadixString(16);

    final posParamList = [
      'fontFamily: iconFontFamily',
      if (_hasPackage) 'fontPackage: iconFontPackage',
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

  String _generateIconList() {
    return [
      '',
      '/// List of all icons in this font.',
      'static const List<IconData> values = <IconData>[',
      for (final iconName in _iconVarNames) ...['$iconName,'],
      '];',
    ].join('\n');
  }

  /// Generates content for a class' file.
  String generate() {
    final classContent = [
      'const $_className._();',
      '',
      _fontFamilyConst,
      if (_hasPackage) _fontPackageConst,
      for (var i = 0; i < glyphList.length; i++)
        ..._generateIconConst(index: i),
      if (_iconList) _generateIconList(),
    ];

    final classContentString =
        classContent.map((e) => e.isEmpty ? '' : '$_indent$e').join('\n');

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
/// the "$_familyName" font is included in your application. This font is used to
/// display the icons. For example:
///
/// ```yaml
/// flutter:
///   fonts:
///     - family: $_familyName
///       fonts:
///         - asset: packages/package_name/fonts/$_fontFileName
/// ```
class $_className {
$classContentString
}
''';
  }
}
