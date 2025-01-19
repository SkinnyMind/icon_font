import 'package:icon_font_generator/src/svg/element.dart';
import 'package:icon_font_generator/src/svg/shapes.dart';
import 'package:icon_font_generator/src/svg/transform.dart';
import 'package:icon_font_generator/src/svg/unknown_element.dart';
import 'package:vector_math/vector_math.dart';
import 'package:xml/xml.dart';

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
