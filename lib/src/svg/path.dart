import 'package:icon_font/src/svg/element.dart';
import 'package:icon_font/src/utils/exceptions.dart';
import 'package:xml/xml.dart';

class PathElement extends SvgElement {
  PathElement({
    required this.fillRule,
    required this.data,
    super.parent,
    XmlElement? element,
    super.transform,
  }) : super(xmlElement: element);

  factory PathElement.fromXmlElement({
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

  final String? fillRule;
  final String data;
}
