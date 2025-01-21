import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:dart_style/dart_style.dart';
import 'package:icon_font/src/cli/arguments.dart';
import 'package:icon_font/src/cli/options.dart';
import 'package:icon_font/src/common/api.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) {
  final argParser = ArgParser();
  Options.define(argParser: argParser);

  late final CliArguments parsedArgs;

  try {
    parsedArgs = Arguments.parseArgsAndConfig(
      argParser: argParser,
      args: args,
    );
  } on CliArgumentException catch (e) {
    _usageError(error: e.message, usage: argParser.usage);
  } on CliHelpException {
    _printHelp(usage: argParser.usage);
  } on YamlException catch (e) {
    Log.logger.e(e.toString());
    exit(66);
  }

  try {
    _run(parsedArgs);
  } on Object catch (e) {
    Log.logger.e(e.toString());
    exit(65);
  }
}

void _run(CliArguments parsedArgs) {
  final stopwatch = Stopwatch()..start();

  final isRecursive = parsedArgs.recursive ?? false;

  final hasClassFile = parsedArgs.classFile != null;
  if (hasClassFile && !parsedArgs.classFile!.existsSync()) {
    parsedArgs.classFile!.createSync(recursive: true);
  } else if (hasClassFile) {
    Log.logger.t('Output file for a Flutter class already exists '
        '(${parsedArgs.classFile!.path}) - overwriting it');
  }

  if (!parsedArgs.fontFile.existsSync()) {
    parsedArgs.fontFile.createSync(recursive: true);
  } else {
    Log.logger.t('Output file for a font file already exists '
        '(${parsedArgs.fontFile.path}) - overwriting it');
  }

  final svgFileList = parsedArgs.svgDir
      .listSync(recursive: isRecursive)
      .where((e) => p.extension(e.path).toLowerCase() == '.svg')
      .toList();

  if (svgFileList.isEmpty) {
    Log.logger.w("The input directory doesn't contain any SVG file "
        "(${parsedArgs.svgDir.path}).");
  }

  final svgMap = {
    for (final f in svgFileList)
      p.basenameWithoutExtension(f.path): File(f.path).readAsStringSync(),
  };

  final otfResult = IconFont.svgToOtf(
    svgMap: svgMap,
    ignoreShapes: parsedArgs.ignoreShapes,
    normalize: parsedArgs.normalize,
    fontName: parsedArgs.fontName,
  );

  /// Write OpenType font to a file.
  final file = File(parsedArgs.fontFile.path);
  file.createSync(recursive: true);
  final bytes = ByteData(otfResult.font.size);
  otfResult.font.encodeToBinary(bytes);
  final byteData = bytes;
  final extension = p.extension(file.path).toLowerCase();
  if (extension != '.otf' && otfResult.font.isOpenType) {
    Log.logger.w('A font that contains only CFF outline data should have an '
        '.OTF extension.');
  }
  file.writeAsBytesSync(byteData.buffer.asUint8List());

  if (parsedArgs.classFile == null) {
    Log.logger.t('No output path for Flutter class was specified - '
        'skipping class generation.');
  } else {
    final fontFileName = p.basename(parsedArgs.fontFile.path);

    var classString = IconFont.generateFlutterClass(
      glyphList: otfResult.glyphList,
      className: parsedArgs.className,
      fontFileName: fontFileName,
      familyName: otfResult.font.familyName,
      package: parsedArgs.fontPackage,
      iconList: parsedArgs.iconList,
    );

    Log.logger.i('Formatting generated Flutter class.');
    final formatter = DartFormatter(
      pageWidth: 80,
      languageVersion: Version(3, 6, 0),
    );
    classString = formatter.format(classString);

    parsedArgs.classFile!.writeAsStringSync(classString);
  }

  Log.logger.i('Generated in ${stopwatch.elapsedMilliseconds}ms');
}

void _printHelp({required String usage}) {
  _printUsage(usage: usage);
  exit(exitCode);
}

void _usageError({required String error, required String usage}) {
  _printUsage(usage: usage, error: error);
  exit(64);
}

void _printUsage({required String usage, String? error}) {
  final message = error ??
      'Converts .svg icons to an OpenType font and generates '
          'Flutter-compatible class.';

  stdout.write('''
$message

Usage:   icon_font <input-svg-dir> <output-font-file> [options]

Example: icon_font assets/svg/ fonts/my_icons_font.otf --output-class-file=lib/my_icons.dart

Converts every .svg file from <input-svg-dir> directory to an OpenType font and writes it to <output-font-file> file.
If "--output-class-file" option is specified, Flutter-compatible class that contains identifiers for the icons is generated.

$usage
''');
}
