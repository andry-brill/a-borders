
import 'dart:ui';

import 'package:any_borders/any_contour.dart';

class AnyBoxDecoration extends AnyDecoration {
  static const AnyCorner cornersBase = RoundedCorner();

  final AnySide? left;
  final AnySide? top;
  final AnySide? right;
  final AnySide? bottom;
  final AnySide? horizontal;
  final AnySide? vertical;

  final AnyCorner? topLeft;
  final AnyCorner? topRight;
  final AnyCorner? bottomRight;
  final AnyCorner? bottomLeft;

  final AnyCorner? innerTopLeft;
  final AnyCorner? innerTopRight;
  final AnyCorner? innerBottomRight;
  final AnyCorner? innerBottomLeft;

  const AnyBoxDecoration({
    double? ratio,
    bool circle = false,
    super.shadows,
    super.clipBase,
    super.shadowBase,
    super.background,
    super.enableCache,
    AnyCorner? corners,
    super.innerCorners,
    super.sides,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.horizontal,
    this.vertical,
    this.topLeft,
    this.topRight,
    this.bottomRight,
    this.bottomLeft,
    this.innerTopLeft,
    this.innerTopRight,
    this.innerBottomRight,
    this.innerBottomLeft,
  }) : super(
    corners: circle ? const RoundedCorner(radius: Radius.circular(double.infinity)) : corners,
    ratio: circle ? 1.0 : ratio,
  );

  @override
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection) => [
    point(
      bounds.topLeft,
      outer: topLeft,
      inner: innerTopLeft,
      side: top ?? horizontal,
    ),
    point(
      bounds.topRight,
      outer: topRight,
      inner: innerTopRight,
      side: right ?? vertical,
    ),
    point(
      bounds.bottomRight,
      outer: bottomRight,
      inner: innerBottomRight,
      side: bottom ?? horizontal,
    ),
    point(
      bounds.bottomLeft,
      outer: bottomLeft,
      inner: innerBottomLeft,
      side: left ?? vertical,
    ),
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyBoxDecoration &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
        other.horizontal == horizontal &&
        other.vertical == vertical &&
        other.topLeft == topLeft &&
        other.topRight == topRight &&
        other.bottomRight == bottomRight &&
        other.bottomLeft == bottomLeft &&
        other.innerTopLeft == innerTopLeft &&
        other.innerTopRight == innerTopRight &&
        other.innerBottomRight == innerBottomRight &&
        other.innerBottomLeft == innerBottomLeft &&
        super == other;
  }

  @override
  int get hashCode => Object.hash(
    super.hashCode,
    left,
    top,
    right,
    bottom,
    horizontal,
    vertical,
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
    innerTopLeft,
    innerTopRight,
    innerBottomRight,
    innerBottomLeft,
  );
}
