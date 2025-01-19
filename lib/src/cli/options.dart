import 'package:args/args.dart';

import 'package:icon_font/src/cli/arguments.dart';

class Options {
  const Options._();

  static void define({required ArgParser argParser}) {
    argParser
      ..addSeparator('Flutter class options:')
      ..addOption(
        CliArgument.classFile.optionName,
        abbr: 'o',
        help: 'Output path for Flutter-compatible class that contains '
            'identifiers for the icons.',
        valueHelp: 'path',
      )
      ..addOption(
        CliArgument.className.optionName,
        abbr: 'c',
        help: 'Name for a generated class.',
        valueHelp: 'name',
      )
      ..addOption(
        CliArgument.fontPackage.optionName,
        abbr: 'f',
        help: 'Name of a package that provides a font. Used to provide a font '
            'through package dependency.',
        valueHelp: 'name',
      )
      ..addFlag(
        CliArgument.iconList.optionName,
        abbr: 'l',
        help: 'Generate a list of icons.',
      )
      ..addSeparator('Font options:')
      ..addOption(
        CliArgument.fontName.optionName,
        abbr: 'n',
        help: 'Name for a generated font.',
        valueHelp: 'name',
      )
      ..addFlag(
        CliArgument.normalize.optionName,
        help: 'Enables glyph normalization for the font. Disable this if every '
            'icon has the same size and positioning.',
        defaultsTo: true,
      )
      ..addFlag(
        CliArgument.ignoreShapes.optionName,
        help: 'Disables SVG shape-to-path conversion (circle, rect, etc.).',
        defaultsTo: true,
      )
      ..addSeparator('Other options:')
      ..addOption(
        CliArgument.configFile.optionName,
        abbr: 'z',
        help: 'Path to icon_font yaml configuration file. pubspec.yaml '
            'and icon_font.yaml files are used by default.',
        valueHelp: 'path',
      )
      ..addFlag(
        CliArgument.recursive.optionName,
        abbr: 'r',
        help: 'Recursively look for .svg files.',
        negatable: false,
      )
      ..addFlag(
        CliArgument.verbose.optionName,
        abbr: 'v',
        help: 'Display every logging message.',
        negatable: false,
      )
      ..addFlag(
        CliArgument.help.optionName,
        abbr: 'h',
        help: 'Shows this usage information.',
        negatable: false,
      );
  }
}
