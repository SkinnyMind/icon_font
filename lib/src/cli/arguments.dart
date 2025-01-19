import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:icon_font/src/cli/formatter.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:yaml/yaml.dart';

class Arguments {
  const Arguments._();

  /// Parses argument list.
  ///
  /// Throws [CliHelpException], if 'help' option is present.
  ///
  /// Returns an instance of [CliArguments] containing all parsed data.
  static Map<CliArgument, Object?> _parseArguments({
    required ArgParser argParser,
    required List<String> args,
  }) {
    late final ArgResults argResults;
    try {
      argResults = argParser.parse(args);
    } on FormatException catch (err) {
      throw CliArgumentException(message: err.message);
    }

    if (argResults.flag(CliArgument.help.optionName)) {
      throw CliHelpException();
    }

    final options =
        CliArgument.values.where((arg) => arg.optionName.isNotEmpty);
    final positionalArgs = CliArgument.values.where(
      (arg) => arg.optionName.isEmpty,
    );
    final posArgsLength =
        math.min(positionalArgs.length, argResults.rest.length);

    final rawArgMap = <CliArgument, Object?>{
      for (final argument in options)
        argument: argResults[argument.optionName] as Object?,
      for (var i = 0; i < posArgsLength; i++)
        positionalArgs.elementAt(i): argResults.rest[i],
    };

    return rawArgMap;
  }

  static MapEntry<CliArgument, Object?>? _mapConfigKeyEntry(
    MapEntry<dynamic, dynamic> entry,
  ) {
    final dynamic rawKey = entry.key;
    void logUnknown() => logger.w('Unknown config parameter "$rawKey"');

    if (rawKey is! String) {
      logUnknown();
      return null;
    }

    late final CliArgument key;
    final configNames =
        CliArgument.values.where((arg) => arg.configName.isNotEmpty);
    try {
      key = configNames.firstWhere((e) => e.configName == rawKey);
    } on StateError catch (_) {
      logUnknown();
      return null;
    }

    return MapEntry<CliArgument, Object?>(key, entry.value);
  }

  /// Parses config file.
  ///
  /// Returns an instance of [CliArguments] containing all parsed data or null,
  /// if 'icon_font' key is not present in config file.
  static Map<CliArgument, Object?>? _parseConfig({required String config}) {
    final yamlMap = loadYaml(config) as Object?;

    if (yamlMap is! YamlMap) {
      return null;
    }

    final iconFontGeneratorYamlmap = yamlMap['icon_font'] as Object?;

    if (iconFontGeneratorYamlmap is! YamlMap) {
      return null;
    }

    final entries =
        iconFontGeneratorYamlmap.entries.map(_mapConfigKeyEntry).nonNulls;

    return Map<CliArgument, Object?>.fromEntries(entries);
  }

  /// Parses argument list and config file, validates parsed data.
  /// Config is used, if it contains 'icon_font' section.
  ///
  /// Throws [CliHelpException], if 'help' option is present.
  /// Throws [CliArgumentException], if there is an error in arg parsing.
  static CliArguments parseArgsAndConfig({
    required ArgParser argParser,
    required List<String> args,
  }) {
    var parsedArgs = _parseArguments(argParser: argParser, args: args);
    final dynamic configFile = parsedArgs[CliArgument.configFile];

    final configList = <String>[
      if (configFile is String) configFile,
      'pubspec.yaml',
      'icon_font.yaml',
    ].map(File.new);

    for (final configFile in configList) {
      if (configFile.existsSync()) {
        final parsedConfig = _parseConfig(
          config: configFile.readAsStringSync(),
        );

        if (parsedConfig != null) {
          logger.i('Using config ${configFile.path}');
          parsedArgs = parsedConfig;
          break;
        }
      }
    }

    return CliArguments.fromMap(map: parsedArgs.validateAndFormat());
  }
}

/// Contains all the parsed data for the application.
class CliArguments {
  CliArguments({
    required this.svgDir,
    required this.fontFile,
    required this.classFile,
    required this.className,
    required this.fontPackage,
    required this.iconList,
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
      iconList: map[CliArgument.iconList] as bool?,
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
  final bool? iconList;
  final String? fontName;
  final bool? recursive;
  final bool? ignoreShapes;
  final bool? normalize;
  final bool? verbose;
  final File? configFile;
}

enum CliArgument {
  // Required and not options
  svgDir(optionName: '', configName: 'input_svg_dir', allowedType: String),
  fontFile(optionName: '', configName: 'output_font_file', allowedType: String),

  // Class-related
  classFile(
    optionName: 'output-class-file',
    configName: 'output_class_file',
    allowedType: String,
  ),
  className(
    optionName: 'class-name',
    configName: 'class_name',
    allowedType: String,
  ),
  fontPackage(
    optionName: 'package',
    configName: 'package',
    allowedType: String,
  ),
  iconList(optionName: 'list', configName: 'list', allowedType: bool),

  // Font-related
  fontName(
    optionName: 'font-name',
    configName: 'font_name',
    allowedType: String,
  ),
  ignoreShapes(
    optionName: 'ignore-shapes',
    configName: 'ignore_shapes',
    allowedType: bool,
  ),
  normalize(
    optionName: 'normalize',
    configName: 'normalize',
    allowedType: bool,
  ),

  // Others
  recursive(
    optionName: 'recursive',
    configName: 'recursive',
    allowedType: bool,
  ),
  verbose(optionName: 'verbose', configName: 'verbose', allowedType: bool),

  // Only in CLI, not part of the config
  help(optionName: 'help', configName: '', allowedType: bool),
  configFile(optionName: 'config-file', configName: '', allowedType: String);

  const CliArgument({
    required this.optionName,
    required this.configName,
    required this.allowedType,
  });
  final String optionName;
  final String configName;
  final Type allowedType;
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
    for (final arg in CliArgument.values) {
      final argType = this[arg].runtimeType;

      if (argType != Null && arg.allowedType != argType) {
        final argName =
            arg.optionName.isNotEmpty ? arg.optionName : arg.configName;
        throw CliArgumentException(
          message: "'$argName' argument's type "
              "must be : ${arg.allowedType}, instead got '$argType'.",
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
    return Formatter.formatArguments(args: this).._validateFormatted();
  }
}
