import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

enum TransformType { matrix, translate, scale, rotate, skewX, skewY }

class Transform {
  Transform({required this.type, required this.parameterList});

  final TransformType? type;
  final List<double> parameterList;

  static List<Transform> parse(String? string) {
    if (string == null) {
      return [];
    }

    final joinedTransformNames = TransformType.values.join('|');
    final transforms = RegExp('($joinedTransformNames)s*(([^)]*))s*')
        .allMatches(string)
        .map((m) {
          final name = m.group(1)!;
          final type = TransformType.values.firstWhere(
            (value) => name == value.name,
          );

          final parameterString = m.group(2)!;
          final parameterMatches = RegExp(
            r'[\w.-]+',
          ).allMatches(parameterString);
          final parameterList = parameterMatches
              .map((m) => double.parse(m.group(0)!))
              .toList();

          return Transform(type: type, parameterList: parameterList);
        })
        .toList();

    return transforms;
  }

  Matrix3? get matrix {
    return switch (type) {
      TransformType.matrix => Matrix3.fromList([
        ...parameterList,
        ...List.filled(9 - parameterList.length, 0),
      ]),
      TransformType.translate => _getTranslateMatrix(
        dx: parameterList[0],
        dy: [...parameterList, .0][1],
      ),
      TransformType.scale => _getScaleMatrix(
        sw: parameterList[0],
        sh: [...parameterList, .0][1],
      ),
      TransformType.rotate => () {
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
      }(),
      TransformType.skewX => _skewX(degrees: parameterList[0]),
      TransformType.skewY => _skewY(degrees: parameterList[0]),
      null => null,
    };
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
