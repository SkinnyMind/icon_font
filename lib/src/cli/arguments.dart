import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:icon_font/src/cli/formatter.dart';
import 'package:icon_font/src/utils/enum_class.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:yaml/yaml.dart';

const _kDefaultConfigPathList = ['pubspec.yaml', 'icon_font.yaml'];
const _kPositionalArguments = [CliArgument.svgDir, CliArgument.fontFile];

const _kArgAllowedTypes = <CliArgument, List<Type>>{
  CliArgument.svgDir: [String],
  CliArgument.fontFile: [String],
  CliArgument.classFile: [String],
  CliArgument.className: [String],
  CliArgument.fontPackage: [String],
  CliArgument.fontName: [String],
  CliArgument.normalize: [bool],
  CliArgument.ignoreShapes: [bool],
  CliArgument.recursive: [bool],
  CliArgument.format: [bool],
  CliArgument.verbose: [bool],
  CliArgument.help: [bool],
  CliArgument.configFile: [String],
};

const kDefaultVerbose = false;
const kDefaultFormat = false;
const kDefaultRecursive = false;

const kOptionNames = EnumClass<CliArgument, String>({
  // svgDir and fontFile are not options

  CliArgument.classFile: 'output-class-file',
  CliArgument.className: 'class-name',
  CliArgument.fontPackage: 'package',
  CliArgument.format: 'format',

  CliArgument.fontName: 'font-name',
  CliArgument.normalize: 'normalize',
  CliArgument.ignoreShapes: 'ignore-shapes',

  CliArgument.recursive: 'recursive',
  CliArgument.verbose: 'verbose',

  CliArgument.help: 'help',
  CliArgument.configFile: 'config-file',
});

const kConfigKeys = EnumClass<CliArgument, String>({
  CliArgument.svgDir: 'input_svg_dir',
  CliArgument.fontFile: 'output_font_file',

  CliArgument.classFile: 'output_class_file',
  CliArgument.className: 'class_name',
  CliArgument.fontPackage: 'package',
  CliArgument.format: 'format',

  CliArgument.fontName: 'font_name',
  CliArgument.normalize: 'normalize',
  CliArgument.ignoreShapes: 'ignore_shapes',

  CliArgument.recursive: 'recursive',
  CliArgument.verbose: 'verbose',

  // help and configFile are not part of config
});

final Map<CliArgument, String> argumentNames = {
  ...kConfigKeys.map,
  ...kOptionNames.map,
};

enum CliArgument {
  // Required
  svgDir,
  fontFile,

  // Class-related
  classFile,
  className,
  fontPackage,
  format,

  // Font-related
  fontName,
  ignoreShapes,
  normalize,

  // Others
  recursive,
  verbose,

  // Only in CLI
  help,
  configFile,
}

/// Contains all the parsed data for the application.
class CliArguments {
  CliArguments({
    required this.svgDir,
    required this.fontFile,
    required this.classFile,
    required this.className,
    required this.fontPackage,
    required this.format,
    required this.fontName,
    required this.recursive,
    required this.ignoreShapes,
    required this.normalize,
    required this.verbose,
    required this.configFile,
  });

  /// Creates [CliArguments] for a map of raw values.
  ///
  /// Validates type of each argument and formats them.
  ///
  /// Throws [CliArgumentException], if there is an error in arg parsing
  /// or if argument has wrong type.
  factory CliArguments.fromMap({required Map<CliArgument, Object?> map}) {
    return CliArguments(
      svgDir: map[CliArgument.svgDir]! as Directory,
      fontFile: map[CliArgument.fontFile]! as File,
      classFile: map[CliArgument.classFile] as File?,
      className: map[CliArgument.className] as String?,
      fontPackage: map[CliArgument.fontPackage] as String?,
      format: map[CliArgument.format] as bool?,
      fontName: map[CliArgument.fontName] as String?,
      recursive: map[CliArgument.recursive] as bool?,
      ignoreShapes: map[CliArgument.ignoreShapes] as bool?,
      normalize: map[CliArgument.normalize] as bool?,
      verbose: map[CliArgument.verbose] as bool?,
      configFile: map[CliArgument.configFile] as File?,
    );
  }

  final Directory svgDir;
  final File fontFile;
  final File? classFile;
  final String? className;
  final String? fontPackage;
  final bool? format;
  final String? fontName;
  final bool? recursive;
  final bool? ignoreShapes;
  final bool? normalize;
  final bool? verbose;
  final File? configFile;
}

/// Parses argument list.
///
/// Throws [CliHelpException], if 'help' option is present.
///
/// Returns an instance of [CliArguments] containing all parsed data.
Map<CliArgument, Object?> parseArguments({
  required ArgParser argParser,
  required List<String> args,
}) {
  late final ArgResults argResults;
  try {
    argResults = argParser.parse(args);
  } on FormatException catch (err) {
    throw CliArgumentException(message: err.message);
  }

  if (argResults['help'] as bool) {
    throw CliHelpException();
  }

  final posArgsLength =
      math.min(_kPositionalArguments.length, argResults.rest.length);

  final rawArgMap = <CliArgument, Object?>{
    for (final e in kOptionNames.entries) e.key: argResults[e.value] as Object?,
    for (var i = 0; i < posArgsLength; i++)
      _kPositionalArguments[i]: argResults.rest[i],
  };

  return rawArgMap;
}

MapEntry<CliArgument, Object?>? _mapConfigKeyEntry(
  MapEntry<dynamic, dynamic> entry,
) {
  final dynamic rawKey = entry.key;
  void logUnknown() => logger.w('Unknown config parameter "$rawKey"');

  if (rawKey is! String) {
    logUnknown();
    return null;
  }

  final key = kConfigKeys.getKeyForValue(rawKey);
  if (key == null) {
    logUnknown();
    return null;
  }

  return MapEntry<CliArgument, Object?>(key, entry.value);
}

/// Parses config file.
///
/// Returns an instance of [CliArguments] containing all parsed data or null,
/// if 'icon_font' key is not present in config file.
Map<CliArgument, Object?>? parseConfig({required String config}) {
  final yamlMap = loadYaml(config) as Object?;

  if (yamlMap is! YamlMap) {
    return null;
  }

  final iconFontGeneratoryamlmap = yamlMap['icon_font'] as Object?;

  if (iconFontGeneratoryamlmap is! YamlMap) {
    return null;
  }

  final entries =
      iconFontGeneratoryamlmap.entries.map(_mapConfigKeyEntry).nonNulls;

  return Map<CliArgument, Object?>.fromEntries(entries);
}

/// Parses argument list and config file, validates parsed data.
/// Config is used, if it contains 'icon_font' section.
///
/// Throws [CliHelpException], if 'help' option is present.
/// Throws [CliArgumentException], if there is an error in arg parsing.
CliArguments parseArgsAndConfig({
  required ArgParser argParser,
  required List<String> args,
}) {
  var parsedArgs = parseArguments(argParser: argParser, args: args);
  final dynamic configFile = parsedArgs[CliArgument.configFile];

  final configList = <String>[
    if (configFile is String) configFile,
    ..._kDefaultConfigPathList,
  ].map(File.new);

  for (final configFile in configList) {
    if (configFile.existsSync()) {
      final parsedConfig = parseConfig(config: configFile.readAsStringSync());

      if (parsedConfig != null) {
        logger.i('Using config ${configFile.path}');
        parsedArgs = parsedConfig;
        break;
      }
    }
  }

  return CliArguments.fromMap(map: parsedArgs.validateAndFormat());
}

class CliArgumentException implements Exception {
  CliArgumentException({required this.message});

  final String message;

  @override
  String toString() => message;
}

class CliHelpException implements Exception {}

extension CliArgumentMapExtension on Map<CliArgument, Object?> {
  /// Validates raw CLI arguments.
  ///
  /// Throws [CliArgumentException], if argument is not valid.
  void _validateRaw() {
    // Validating types
    for (final e in _kArgAllowedTypes.entries) {
      final arg = e.key;
      final argType = this[arg].runtimeType;
      final allowedTypes = e.value;

      if (argType != Null && !allowedTypes.contains(argType)) {
        throw CliArgumentException(
          message: "'${argumentNames[arg]}' argument's type "
              'must be one of following: $allowedTypes, '
              "instead got '$argType'.",
        );
      }
    }
  }

  /// Validates formatted CLI arguments.
  ///
  /// Throws [CliArgumentException], if argument is not valid.
  void _validateFormatted() {
    final args = this;

    final svgDir = args[CliArgument.svgDir] as Directory?;
    final fontFile = args[CliArgument.fontFile] as File?;

    if (svgDir == null) {
      throw CliArgumentException(
        message: 'The input directory is not specified.',
      );
    }

    if (fontFile == null) {
      throw CliArgumentException(
        message: 'The output font file is not specified.',
      );
    }

    if (svgDir.statSync().type != FileSystemEntityType.directory) {
      throw CliArgumentException(
        message: "The input directory is not a directory or it doesn't exist.",
      );
    }
  }

  /// Validates and formats CLI arguments.
  ///
  /// Throws [CliArgumentException], if argument is not valid.
  Map<CliArgument, Object?> validateAndFormat() {
    _validateRaw();
    return formatArguments(args: this).._validateFormatted();
  }
}
