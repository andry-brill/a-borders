import 'dart:ui';

import 'package:any_borders/any_contour.dart';

enum AnyBoxShape {
  rectangle,
  square,
  circle,
  pill,
}

/// Rectangular border with independent side and corner overrides.
class AnyBoxBorder extends AnyBorder {
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

  /// Shape corner used at the top-left point.
  final AnyCorner? topLeft;

  /// Shape corner used at the top-right point.
  final AnyCorner? topRight;

  /// Shape corner used at the bottom-right point.
  final AnyCorner? bottomRight;

  /// Shape corner used at the bottom-left point.
  final AnyCorner? bottomLeft;

  /// Explicit outer corner overrides; null derives them from the shape.
  final AnyCorner? outerTopLeft;
  final AnyCorner? outerTopRight;
  final AnyCorner? outerBottomRight;
  final AnyCorner? outerBottomLeft;

  /// Inner corner used at the top-left point.
  final AnyCorner? innerTopLeft;

  /// Inner corner used at the top-right point.
  final AnyCorner? innerTopRight;

  /// Inner corner used at the bottom-right point.
  final AnyCorner? innerBottomRight;

  /// Inner corner used at the bottom-left point.
  final AnyCorner? innerBottomLeft;

  const AnyBoxBorder({
    double? ratio,
    AnyBoxShape shape = AnyBoxShape.rectangle,
    AnyCorner? corners,
    super.outerCorners,
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
    this.outerTopLeft,
    this.outerTopRight,
    this.outerBottomRight,
    this.outerBottomLeft,
    this.innerTopLeft,
    this.innerTopRight,
    this.innerBottomRight,
    this.innerBottomLeft,
  }) : super(
          corners: shape == AnyBoxShape.circle || shape == AnyBoxShape.pill
              ? const RoundedCorner.infinity()
              : corners,
          ratio: shape == AnyBoxShape.circle || shape == AnyBoxShape.square
              ? 1.0
              : ratio,
        );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyBoxBorder &&
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
        other.outerTopLeft == outerTopLeft &&
        other.outerTopRight == outerTopRight &&
        other.outerBottomRight == outerBottomRight &&
        other.outerBottomLeft == outerBottomLeft &&
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
        outerTopLeft,
        outerTopRight,
        outerBottomRight,
        outerBottomLeft,
        innerTopLeft,
        innerTopRight,
        innerBottomRight,
        innerBottomLeft,
      );
}

/// Rectangular [AnyDecoration] with independent side and corner overrides.
class AnyBoxDecoration extends AnyDecoration {
  const AnyBoxDecoration({
    AnyBoxBorder border = const AnyBoxBorder(),
    super.shadows,
    super.clipBase,
    super.shadowBase,
    super.background,
    super.enableCache,
  }) : super(border: border);

  const AnyBoxDecoration.multi({
    required List<AnyBoxBorder> borders,
    super.primaryBorderIndex,
    super.shadows,
    super.clipBase,
    super.shadowBase,
    super.background,
    super.enableCache,
  }) : super.multi(borders: borders);

  @override
  List<AnyBoxBorder> get borders => super.borders.cast<AnyBoxBorder>();

  @override
  AnyBoxBorder get border => super.border as AnyBoxBorder;

  @override
  List<AnyPoint> buildPoints(
      Rect bounds, TextDirection? textDirection, int borderIndex) {
    final border = borders[borderIndex];
    return [
      point(
        bounds.topLeft,
        borderIndex: borderIndex,
        shape: border.topLeft,
        outer: border.outerTopLeft,
        inner: border.innerTopLeft,
        side: border.top ?? border.horizontal,
      ),
      point(
        bounds.topRight,
        borderIndex: borderIndex,
        shape: border.topRight,
        outer: border.outerTopRight,
        inner: border.innerTopRight,
        side: border.right ?? border.vertical,
      ),
      point(
        bounds.bottomRight,
        borderIndex: borderIndex,
        shape: border.bottomRight,
        outer: border.outerBottomRight,
        inner: border.innerBottomRight,
        side: border.bottom ?? border.horizontal,
      ),
      point(
        bounds.bottomLeft,
        borderIndex: borderIndex,
        shape: border.bottomLeft,
        outer: border.outerBottomLeft,
        inner: border.innerBottomLeft,
        side: border.left ?? border.vertical,
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyBoxDecoration && super == other;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, AnyBoxDecoration);
}
