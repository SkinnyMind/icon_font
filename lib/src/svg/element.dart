import 'package:icon_font/src/svg/path.dart';
import 'package:icon_font/src/svg/shapes.dart';
import 'package:icon_font/src/svg/unknown_element.dart';
import 'package:icon_font/src/utils/svg.dart';
import 'package:vector_math/vector_math.dart';
import 'package:xml/xml.dart';

abstract class SvgElement {
  SvgElement({
    required this.parent,
    required this.xmlElement,
    Matrix3? transform,
  }) : transform = transform ?? xmlElement?.parseTransformMatrix();

  factory SvgElement.fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
    required bool ignoreShapes,
  }) {
    return switch (element.name.local) {
      'path' => PathElement.fromXmlElement(parent: parent, element: element),
      'g' => GroupElement.fromXmlElement(
          parent: parent,
          element: element,
          ignoreShapes: ignoreShapes,
        ),
      'rect' => RectElement.fromXmlElement(parent: parent, element: element),
      'circle' => CircleElement.fromXmlElement(
          parent: parent,
          element: element,
        ),
      'polyline' => PolylineElement.fromXmlElement(
          parent: parent,
          element: element,
        ),
      'polygon' => PolygonElement.fromXmlElement(
          parent: parent,
          element: element,
        ),
      'line' => LineElement.fromXmlElement(parent: parent, element: element),
      _ => UnknownElement(parent: parent, xmlElement: element),
    };
  }

  final XmlElement? xmlElement;
  Matrix3? transform;
  SvgElement? parent;

  /// Traverses parent elements and calculates result transform matrix.
  ///
  /// Returns result transform matrix or null, if there are no transforms.
  Matrix3? getResultTransformMatrix() {
    final transform = Matrix3.identity();
    SvgElement? element = this;

    while (element != null) {
      final elementTransform = element.transform;

      if (elementTransform != null) {
        transform.multiply(elementTransform);
      }

      element = element.parent;
    }

    return transform.isIdentity() ? null : transform;
  }
}

class GroupElement extends SvgElement {
  GroupElement({
    required this.elementList,
    required XmlElement element,
    super.parent,
  }) : super(xmlElement: element);

  factory GroupElement.fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
    required bool ignoreShapes,
  }) {
    final g = GroupElement(
      elementList: [],
      parent: parent,
      element: element,
    );

    final children = element.parseSvgElements(
      parent: g,
      ignoreShapes: ignoreShapes,
    );
    g.elementList.addAll(children);

    return g;
  }

  final List<SvgElement> elementList;

  /// Applies group's transform on every child element
  /// and sets group's transform to null
  void applyTransformOnChildren() {
    if (transform == null) {
      return;
    }

    for (final c in elementList) {
      c.transform ??= Matrix3.identity();
      c.transform!.multiply(transform!);
    }

    transform = null;
  }
}
