import 'dart:io';

import 'package:icon_font/src/cli/arguments.dart';

typedef CliArgumentFormatter = Object Function(String arg);

class Formatter {
  const Formatter._();

  /// Formats arguments.
  static Map<CliArgument, Object?> formatArguments({
    required Map<CliArgument, Object?> args,
  }) {
    const argumentFormatters = <CliArgument, CliArgumentFormatter>{
      CliArgument.svgDir: Directory.new,
      CliArgument.fontFile: File.new,
      CliArgument.classFile: File.new,
      CliArgument.configFile: File.new,
    };

    return args.map<CliArgument, Object?>((k, v) {
      final formatter = argumentFormatters[k];

      if (formatter == null || v == null) {
        return MapEntry<CliArgument, Object?>(k, v);
      }

      return MapEntry<CliArgument, Object?>(k, formatter(v.toString()));
    });
  }
}
