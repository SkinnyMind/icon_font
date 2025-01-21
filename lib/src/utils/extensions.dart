import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:icon_font/src/cli/arguments.dart';
import 'package:icon_font/src/svg/element.dart';
import 'package:icon_font/src/svg/shapes.dart';
import 'package:icon_font/src/svg/transform.dart';
import 'package:icon_font/src/svg/unknown_element.dart';
import 'package:icon_font/src/utils/otf_utils.dart';
import 'package:vector_math/vector_math.dart';
import 'package:xml/xml.dart';

typedef CliArgumentFormatter = Object Function(String arg);

extension PointExt<T extends num> on math.Point<T> {
  math.Point<int> toIntPoint() => math.Point<int>(x.toInt(), y.toInt());

  math.Point<double> toDoublePoint() =>
      math.Point<double>(x.toDouble(), y.toDouble());

  math.Point<num> getReflectionOf(math.Point<T> point) {
    return math.Point<num>(2 * x - point.x, 2 * y - point.y);
  }
}

extension XmlElementExt on XmlElement {
  num? getScalarAttribute(
    String name, {
    String? namespace,
    bool zeroIfAbsent = true,
  }) {
    final attr = getAttribute(name, namespace: namespace);

    if (attr == null) {
      return zeroIfAbsent ? 0 : null;
    }

    return num.parse(attr);
  }

  List<SvgElement> parseSvgElements({
    required SvgElement? parent,
    required bool ignoreShapes,
  }) {
    var elements = children
        .whereType<XmlElement>()
        .map(
          (e) => SvgElement.fromXmlElement(
            parent: parent,
            element: e,
            ignoreShapes: ignoreShapes,
          ),
        )
        // Ignoring unknown elements
        .where((e) => e is! UnknownElement)
        // Expanding groups
        .expand((e) {
      if (e is! GroupElement) {
        return [e];
      }

      e.applyTransformOnChildren();
      return e.elementList;
    });

    if (!ignoreShapes) {
      // Converting shapes into paths
      elements = elements.map(
        (e) => e is PathConvertible ? (e as PathConvertible).getPath() : e,
      );
    }

    return elements.toList();
  }

  Matrix3? parseTransformMatrix() {
    final transformList = Transform.parse(getAttribute('transform'));
    return generateTransformMatrix(transformList: transformList);
  }
}

extension CliArgumentMapExtension on Map<CliArgument, Object?> {
  /// Validates and formats CLI arguments.
  ///
  /// Throws [CliArgumentException], if argument is not valid.
  Map<CliArgument, Object?> validateAndFormat() {
    // Validate raw CLI arguments
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

    // Validate formatted CLI arguments.
    final formattedArguments = _formatArguments(args: this);
    final svgDir = formattedArguments[CliArgument.svgDir] as Directory?;
    final fontFile = formattedArguments[CliArgument.fontFile] as File?;

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

    return formattedArguments;
  }

  Map<CliArgument, Object?> _formatArguments({
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

extension XmlNodeUtils on XmlNode {
  double getDoubleAttribute(String name, [double defaultValue = 0]) =>
      double.tryParse(getAttribute(name) ?? '$defaultValue') ?? defaultValue;

  int getIntAttribute(String name, [int defaultValue = 0]) =>
      int.tryParse(getAttribute(name) ?? '$defaultValue') ?? defaultValue;
}

extension NumPretty on num {
  String toStringPretty([int? fractionDigits]) =>
      (fractionDigits != null ? toStringAsFixed(fractionDigits) : toString())
          .replaceFirst(RegExp(r'\.?0*$'), '');
}

extension OTFByteDateExt on ByteData {
  void setTag(int offset, String tag) {
    var currentOffset = offset;
    OtfUtils.convertStringToTag(tag)
        .forEach((b) => setUint8(currentOffset++, b));
  }

  ByteData sublistView(int offset, [int? length]) {
    return ByteData.sublistView(
      this,
      offset,
      length == null ? null : offset + length,
    );
  }
}

extension OTFStringExt on String {
  /// Returns ASCII-printable string
  String getAsciiPrintable() =>
      replaceAll(RegExp(r'([^\x00-\x7E]|[\(\[\]\(\)\{\}<>\/%])'), '');

  /// Returns ASCII-printable and PostScript-compatible string
  String getPostScriptString() =>
      getAsciiPrintable().replaceAll(RegExp(r'[^\x21-\x7E]'), '');
}
