import 'dart:ui';

import 'package:any_borders/any_contour.dart';

/// Rectangular [AnyDecoration] with independent side and corner overrides.
class AnyBoxDecoration extends AnyDecoration {
  /// Default corner used by boxes when no corner is supplied.
  static const AnyCorner cornersBase = RoundedCorner();

  /// Side used for the left edge.
  final AnySide? left;

  /// Side used for the top edge.
  final AnySide? top;

  /// Side used for the right edge.
  final AnySide? right;

  /// Side used for the bottom edge.
  final AnySide? bottom;

  /// Fallback side used by the top and bottom edges.
  final AnySide? horizontal;

  /// Fallback side used by the left and right edges.
  final AnySide? vertical;

  /// Outer corner used at the top-left point.
  final AnyCorner? topLeft;

  /// Outer corner used at the top-right point.
  final AnyCorner? topRight;

  /// Outer corner used at the bottom-right point.
  final AnyCorner? bottomRight;

  /// Outer corner used at the bottom-left point.
  final AnyCorner? bottomLeft;

  /// Inner corner used at the top-left point.
  final AnyCorner? innerTopLeft;

  /// Inner corner used at the top-right point.
  final AnyCorner? innerTopRight;

  /// Inner corner used at the bottom-right point.
  final AnyCorner? innerBottomRight;

  /// Inner corner used at the bottom-left point.
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
          corners: circle ? const RoundedCorner.infinity() : corners,
          ratio: circle ? 1.0 : ratio,
        );

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection) => [
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
