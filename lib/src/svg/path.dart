import 'package:icon_font/src/svg/element.dart';
import 'package:icon_font/src/utils/exceptions.dart';
import 'package:xml/xml.dart';

class PathElement({
  required final String? fillRule,
  required final String data,
  super.parent,
  XmlElement? element,
  super.transform,
}) extends SvgElement {
  this : super(xmlElement: element);

  factory fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
  }) {
    final dAttr = element.getAttribute('d');

    if (dAttr == null) {
      throw SvgParserException(
        message: 'Path element must contain "d" attribute',
      );
    }

    final fillRule = element.getAttribute('fill-rule');

    return PathElement(
      fillRule: fillRule,
      data: dAttr,
      parent: parent,
      element: element,
    );
  }
}
