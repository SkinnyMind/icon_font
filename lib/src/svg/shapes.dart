import 'dart:math' as math;

import 'package:icon_font/src/svg/element.dart';
import 'package:icon_font/src/svg/path.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:xml/xml.dart';

/// Element convertable to path.
abstract class const PathConvertible() {
  PathElement getPath();
}

class RectElement({
  required final math.Rectangle rectangle,
  required final num rx,
  required final num ry,
  required super.parent,
  required XmlElement element,
}) extends SvgElement implements PathConvertible {
  this : super(xmlElement: element);

  factory fromXmlElement({
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

  num get x => rectangle.left;

  num get y => rectangle.top;

  num get width => rectangle.width;

  num get height => rectangle.height;

  @override
  PathElement getPath() {
    final topRight = rx != 0 || ry != 0 ? 'a $rx $ry 0 0 1 $rx $ry' : '';
    final bottomRight = rx != 0 || ry != 0 ? 'a $rx $ry 0 0 1 ${-rx} $ry' : '';
    final bottomLeft = rx != 0 || ry != 0
        ? 'a $rx $ry 0 0 1 ${-rx} ${-ry}'
        : '';
    final topLeft = rx != 0 || ry != 0 ? 'a $rx $ry 0 0 1 $rx ${-ry}' : '';

    final d =
        'M${x + rx} ${y}h${width - rx * 2}${topRight}v${height - ry * 2}'
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

class CircleElement({
  required final math.Point center,
  required final num r,
  required super.parent,
  required XmlElement element,
}) extends SvgElement implements PathConvertible {
  this : super(xmlElement: element);

  factory fromXmlElement({
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

class PolylineElement({
  required final String points,
  required super.parent,
  required XmlElement element,
}) extends SvgElement implements PathConvertible {
  this : super(xmlElement: element);

  factory fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
  }) {
    final points = element.getAttribute('points')!;

    return PolylineElement(points: points, parent: parent, element: element);
  }

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

class PolygonElement({
  required final String points,
  required super.parent,
  required XmlElement element,
}) extends SvgElement implements PathConvertible {
  this : super(xmlElement: element);

  factory fromXmlElement({
    required SvgElement? parent,
    required XmlElement element,
  }) {
    final points = element.getAttribute('points')!;

    return PolygonElement(points: points, parent: parent, element: element);
  }

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

class LineElement({
  required final math.Point p1,
  required final math.Point p2,
  required super.parent,
  required XmlElement element,
}) extends SvgElement implements PathConvertible {
  this : super(xmlElement: element);

  factory fromXmlElement({
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

  num get x1 => p1.x;

  num get y1 => p1.y;

  num get x2 => p2.x;

  num get y2 => p2.y;

  @override
  PathElement getPath() {
    // line width is 1
    final d = 'M$x1 $y1 ${x1 + 1} ${y1 + 1} ${x2 + 1} ${y2 + 1} $x2 $y2 z';

    return PathElement(
      fillRule: null,
      data: d,
      parent: parent,
      transform: transform,
    );
  }
}
