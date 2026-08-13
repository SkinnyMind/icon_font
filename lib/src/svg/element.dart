import 'package:icon_font/src/svg/path.dart';
import 'package:icon_font/src/svg/shapes.dart';
import 'package:icon_font/src/svg/unknown_element.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:vector_math/vector_math.dart';
import 'package:xml/xml.dart';

abstract class SvgElement({
  required var SvgElement? parent,
  required final XmlElement? xmlElement,
  Matrix3? transform,
}) {
  this : transform = transform ?? xmlElement?.parseTransformMatrix();

  factory fromXmlElement({
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

  Matrix3? transform;

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

class GroupElement({
  required final List<SvgElement> elementList,
  required XmlElement element,
  super.parent,
}) extends SvgElement {
  this : super(xmlElement: element);

  factory fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
    required bool ignoreShapes,
  }) {
    final g = GroupElement(elementList: [], parent: parent, element: element);

    final children = element.parseSvgElements(
      parent: g,
      ignoreShapes: ignoreShapes,
    );
    g.elementList.addAll(children);

    return g;
  }

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
