import 'dart:math' as math;

import 'package:icon_font_generator/src/utils/enum_class.dart';
import 'package:vector_math/vector_math.dart';

enum TransformType { matrix, translate, scale, rotate, skewX, skewY }

const _kTransformNameMap = EnumClass<TransformType, String>({
  TransformType.matrix: 'matrix',
  TransformType.translate: 'translate',
  TransformType.scale: 'scale',
  TransformType.rotate: 'rotate',
  TransformType.skewX: 'skewX',
  TransformType.skewY: 'skewY',
});

final _joinedTransformNames = _kTransformNameMap.values.join('|');

// Taken from svgicons2svgfont
final _transformRegExp = RegExp('($_joinedTransformNames)s*(([^)]*))s*');
final _transformParameterRegExp = RegExp(r'[\w.-]+');

class Transform {
  Transform({required this.type, required this.parameterList});

  final TransformType? type;
  final List<double> parameterList;

  static List<Transform> parse(String? string) {
    if (string == null) {
      return [];
    }

    final transforms = _transformRegExp.allMatches(string).map((m) {
      final name = m.group(1)!;
      final type = _kTransformNameMap.getKeyForValue(name);

      final parameterString = m.group(2)!;
      final parameterMatches =
          _transformParameterRegExp.allMatches(parameterString);
      final parameterList =
          parameterMatches.map((m) => double.parse(m.group(0)!)).toList();

      return Transform(type: type, parameterList: parameterList);
    }).toList();

    return transforms;
  }

  Matrix3? get matrix {
    switch (type) {
      case TransformType.matrix:
        return Matrix3.fromList(
          [...parameterList, ...List.filled(9 - parameterList.length, 0)],
        );
      case TransformType.translate:
        final dx = parameterList[0];
        final dy = [...parameterList, .0][1];

        return _getTranslateMatrix(dx: dx, dy: dy);
      case TransformType.scale:
        final sw = parameterList[0];
        final sh = [...parameterList, .0][1];

        return _getScaleMatrix(sw: sw, sh: sh);
      case TransformType.rotate:
        final degrees = parameterList[0];
        var transform = _getRotateMatrix(degrees: degrees);

        // The rotation is about the point (x, y)
        if (parameterList.length > 1) {
          final x = parameterList[1];
          final y = [...parameterList, .0][2];

          final t = _getTranslateMatrix(dx: x, dy: y)
            ..multiply(transform)
            ..multiply(_getTranslateMatrix(dx: -x, dy: -y));
          transform = t;
        }

        return transform;
      case TransformType.skewX:
        return _skewX(degrees: parameterList[0]);
      case TransformType.skewY:
        return _skewY(degrees: parameterList[0]);
      case null:
        return null;
    }
  }
}

/// Generates transform matrix for a list of transforms.
///
/// Returns null, if transformList is empty.
Matrix3? generateTransformMatrix({required List<Transform> transformList}) {
  if (transformList.isEmpty) {
    return null;
  }

  final matrix = Matrix3.identity();

  for (final t in transformList) {
    if (t.matrix != null) {
      matrix.multiply(t.matrix!);
    }
  }

  return matrix;
}

Matrix3 _getTranslateMatrix({required double dx, required double dy}) {
  return Matrix3.fromList([1, 0, dx, 0, 1, dy, 0, 0, 1]);
}

Matrix3 _getScaleMatrix({required double sw, required double sh}) {
  return Matrix3.fromList([sw, 0, 0, 0, sh, 0, 0, 0, 1]);
}

Matrix3 _getRotateMatrix({required double degrees}) {
  return Matrix3.rotationZ(radians(degrees));
}

Matrix3 _skewX({required double degrees}) {
  return Matrix3.fromList([1, 0, 0, math.tan(radians(degrees)), 1, 0, 0, 0, 1]);
}

Matrix3 _skewY({required double degrees}) {
  return Matrix3.fromList([1, math.tan(radians(degrees)), 0, 0, 1, 0, 0, 0, 1]);
}
