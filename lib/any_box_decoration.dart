import 'dart:ui';

import 'package:any_borders/any_contour.dart';

import 'src/utils.dart';

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
    super.offset,
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

  /// Whole-side fallbacks in top, right, bottom, left construction order.
  @override
  List<AnySide> get resolvedSides => List<AnySide>.unmodifiable([
        top ?? horizontal ?? sides,
        right ?? vertical ?? sides,
        bottom ?? horizontal ?? sides,
        left ?? vertical ?? sides,
      ]);

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
    super.offset,
  }) : super(border: border);

  const AnyBoxDecoration.multi({
    required List<AnyBoxBorder> borders,
    super.primaryBorderIndex,
    super.shadows,
    super.clipBase,
    super.shadowBase,
    super.background,
    super.enableCache,
    super.offset,
  }) : super.multi(borders: borders);

  @override
  List<AnyBoxBorder> get borders => super.borders.cast<AnyBoxBorder>();

  @override
  AnyBoxBorder get border => super.border as AnyBoxBorder;

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection,
      covariant AnyBoxBorder border, double offset, List<double> sideOffsets) {
    final resolved = border.resolvedSides;
    final sides = [
      for (var i = 0; i < resolved.length; i++)
        resolved[i].offset == sideOffsets[i]
            ? resolved[i]
            : resolved[i].copyWith(offset: sideOffsets[i]),
    ];
    bounds = AnyUtils.displaceBox(bounds, offset,
        top: sides[0].offset,
        right: sides[1].offset,
        bottom: sides[2].offset,
        left: sides[3].offset);
    if (bounds.isEmpty) return const [];
    return [
      point(
        bounds.topLeft,
        border: border,
        shape: border.topLeft,
        outer: border.outerTopLeft,
        inner: border.innerTopLeft,
        side: sides[0],
      ),
      point(
        bounds.topRight,
        border: border,
        shape: border.topRight,
        outer: border.outerTopRight,
        inner: border.innerTopRight,
        side: sides[1],
      ),
      point(
        bounds.bottomRight,
        border: border,
        shape: border.bottomRight,
        outer: border.outerBottomRight,
        inner: border.innerBottomRight,
        side: sides[2],
      ),
      point(
        bounds.bottomLeft,
        border: border,
        shape: border.bottomLeft,
        outer: border.outerBottomLeft,
        inner: border.innerBottomLeft,
        side: sides[3],
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
