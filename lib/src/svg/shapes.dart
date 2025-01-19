import 'dart:math' as math;

import 'package:icon_font/src/svg/element.dart';
import 'package:icon_font/src/svg/path.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:xml/xml.dart';

/// Element convertable to path.
abstract class PathConvertible {
  PathElement getPath();
}

class RectElement extends SvgElement implements PathConvertible {
  RectElement({
    required this.rectangle,
    required this.rx,
    required this.ry,
    required super.parent,
    required XmlElement element,
  }) : super(xmlElement: element);

  factory RectElement.fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
  }) {
    final rect = math.Rectangle(
      element.getScalarAttribute('x')!,
      element.getScalarAttribute('y')!,
      element.getScalarAttribute('width')!,
      element.getScalarAttribute('height')!,
    );

    var rx = element.getScalarAttribute('rx', zeroIfAbsent: false);
    var ry = element.getScalarAttribute('ry', zeroIfAbsent: false);

    ry ??= rx;
    rx ??= ry;

    return RectElement(
      rectangle: rect,
      rx: rx ?? 0,
      ry: ry ?? 0,
      parent: parent,
      element: element,
    );
  }

  final math.Rectangle rectangle;
  final num rx;
  final num ry;

  num get x => rectangle.left;

  num get y => rectangle.top;

  num get width => rectangle.width;

  num get height => rectangle.height;

  @override
  PathElement getPath() {
    final topRight = rx != 0 || ry != 0 ? 'a $rx $ry 0 0 1 $rx $ry' : '';
    final bottomRight = rx != 0 || ry != 0 ? 'a $rx $ry 0 0 1 ${-rx} $ry' : '';
    final bottomLeft =
        rx != 0 || ry != 0 ? 'a $rx $ry 0 0 1 ${-rx} ${-ry}' : '';
    final topLeft = rx != 0 || ry != 0 ? 'a $rx $ry 0 0 1 $rx ${-ry}' : '';

    final d = 'M${x + rx} ${y}h${width - rx * 2}${topRight}v${height - ry * 2}'
        '${bottomRight}h${-(width - rx * 2)}${bottomLeft}v'
        '${-(height - ry * 2)}${topLeft}z';

    return PathElement(
      fillRule: null,
      data: d,
      parent: parent,
      transform: transform,
    );
  }
}

class CircleElement extends SvgElement implements PathConvertible {
  CircleElement({
    required this.center,
    required this.r,
    required super.parent,
    required XmlElement element,
  }) : super(xmlElement: element);

  factory CircleElement.fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
  }) {
    final center = math.Point(
      element.getScalarAttribute('cx')!,
      element.getScalarAttribute('cy')!,
    );

    final r = element.getScalarAttribute('r')!;

    return CircleElement(
      center: center,
      r: r,
      parent: parent,
      element: element,
    );
  }

  final math.Point center;
  final num r;

  num get cx => center.x;

  num get cy => center.y;

  @override
  PathElement getPath() {
    final d =
        'M${cx - r},${cy}A$r,$r 0,0,0 ${cx + r},${cy}A$r,$r 0,0,0 ${cx - r},'
        '${cy}z';

    return PathElement(
      fillRule: null,
      data: d,
      parent: parent,
      transform: transform,
    );
  }
}

class PolylineElement extends SvgElement implements PathConvertible {
  PolylineElement({
    required this.points,
    required super.parent,
    required XmlElement element,
  }) : super(xmlElement: element);

  factory PolylineElement.fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
  }) {
    final points = element.getAttribute('points')!;

    return PolylineElement(points: points, parent: parent, element: element);
  }

  final String points;

  @override
  PathElement getPath() {
    final d = 'M${points}z';

    return PathElement(
      fillRule: null,
      data: d,
      parent: parent,
      transform: transform,
    );
  }
}

class PolygonElement extends SvgElement implements PathConvertible {
  PolygonElement({
    required this.points,
    required super.parent,
    required XmlElement element,
  }) : super(xmlElement: element);

  factory PolygonElement.fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
  }) {
    final points = element.getAttribute('points')!;

    return PolygonElement(points: points, parent: parent, element: element);
  }

  final String points;

  @override
  PathElement getPath() {
    final d = 'M${points}z';

    return PathElement(
      fillRule: null,
      data: d,
      parent: parent,
      transform: transform,
    );
  }
}

class LineElement extends SvgElement implements PathConvertible {
  LineElement({
    required this.p1,
    required this.p2,
    required super.parent,
    required XmlElement element,
  }) : super(xmlElement: element);

  factory LineElement.fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
  }) {
    final p1 = math.Point(
      element.getScalarAttribute('x1')!,
      element.getScalarAttribute('y1')!,
    );

    final p2 = math.Point(
      element.getScalarAttribute('x2')!,
      element.getScalarAttribute('y2')!,
    );

    return LineElement(p1: p1, p2: p2, parent: parent, element: element);
  }

  /// Line width
  static const _kW = 1;

  final math.Point p1;
  final math.Point p2;

  num get x1 => p1.x;

  num get y1 => p1.y;

  num get x2 => p2.x;

  num get y2 => p2.y;

  @override
  PathElement getPath() {
    final d =
        'M$x1 $y1 ${x1 + _kW} ${y1 + _kW} ${x2 + _kW} ${y2 + _kW} $x2 $y2 z';

    return PathElement(
      fillRule: null,
      data: d,
      parent: parent,
      transform: transform,
    );
  }
}
