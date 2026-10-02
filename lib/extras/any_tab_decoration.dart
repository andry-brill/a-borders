import 'dart:math' as math;
import 'dart:ui';

import 'package:any_borders/any_box_decoration.dart';
import 'package:any_borders/any_contour.dart';

import '../src/utils.dart';

/// Tab-shaped [AnyDecoration] configured through an [AnyBoxBorder].
///
/// The lower tab offsets are derived from [AnyBoxBorder.bottomLeft] and
/// [AnyBoxBorder.bottomRight]. The left offset uses the bottom-left corner's
/// previous-side extent, and the right offset uses the bottom-right corner's
/// next-side extent.
///
/// When [offsetOutward] is false, the tab is inset inward:
///   L, L + offset, R - offset, R
///
/// When [offsetOutward] is true, the tab expands outward:
///   L - offset, L, R, R + offset
class AnyTabDecoration extends AnyDecoration {
  final bool offsetOutward;
  const AnyTabDecoration({
    this.offsetOutward = true,
    AnyBoxBorder border = const AnyBoxBorder(),
    super.shadows,
    super.clipBase,
    super.shadowBase,
    super.background,
    super.enableCache,
    super.offset,
  }) : super(border: border);

  const AnyTabDecoration.multi({
    this.offsetOutward = true,
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
    // Offset the tab's construction rectangle, then rebuild its lower helpers
    // from the unchanged corner extents. The helpers are not polygon edges to
    // miter independently: the first/last vertices reverse along the baseline.
    bounds = AnyUtils.displaceBox(bounds, offset,
        top: sides[0].offset,
        right: sides[1].offset,
        bottom: sides[2].offset,
        left: sides[3].offset);
    if (bounds.isEmpty) return const [];
    final bottomLeftCorner = border.bottomLeft ?? border.corners;
    final bottomRightCorner = border.bottomRight ?? border.corners;

    final (leftOffset, rightOffset) = _offsets(
      bounds.width,
      bottomLeftCorner,
      bottomRightCorner,
    );

    final double firstX;
    final double leftX;
    final double rightX;
    final double lastX;

    if (offsetOutward) {
      firstX = bounds.left - leftOffset;
      leftX = bounds.left;
      rightX = bounds.right;
      lastX = bounds.right + rightOffset;
    } else {
      firstX = bounds.left;
      leftX = bounds.left + leftOffset;
      rightX = bounds.right - rightOffset;
      lastX = bounds.right;
    }

    final firstPoint = Offset(firstX, bounds.bottom);
    final leftBottomPoint = Offset(leftX, bounds.bottom);
    final leftTopPoint = Offset(leftX, bounds.top);
    final rightTopPoint = Offset(rightX, bounds.top);
    final rightBottomPoint = Offset(rightX, bounds.bottom);
    final lastPoint = Offset(lastX, bounds.bottom);

    const zero = RoundedCorner();

    return [
      point(
        firstPoint,
        border: border,
        shape: zero,
        outer: zero,
        inner: zero,
        skip: firstPoint == leftBottomPoint,
        side: sides[2],
      ),
      point(
        leftBottomPoint,
        border: border,
        shape: border.bottomLeft,
        outer: border.outerBottomLeft,
        inner: border.innerBottomLeft,
        side: sides[3],
      ),
      point(
        leftTopPoint,
        border: border,
        shape: border.topLeft,
        outer: border.outerTopLeft,
        inner: border.innerTopLeft,
        side: sides[0],
      ),
      point(
        rightTopPoint,
        border: border,
        shape: border.topRight,
        outer: border.outerTopRight,
        inner: border.innerTopRight,
        side: sides[1],
      ),
      point(
        rightBottomPoint,
        border: border,
        shape: border.bottomRight,
        outer: border.outerBottomRight,
        inner: border.innerBottomRight,
        side: sides[2],
      ),
      point(
        lastPoint,
        border: border,
        shape: zero,
        outer: zero,
        inner: zero,
        skip: rightBottomPoint == lastPoint,
        side: sides[2],
      ),
    ];
  }

  (double, double) _offsets(
    double width,
    AnyCorner bottomLeft,
    AnyCorner bottomRight,
  ) {
    final safeWidth = math.max(0.0, width);
    final left = _safeExtent(bottomLeft.p);
    final right = _safeExtent(bottomRight.n);

    if (!left.isFinite && !right.isFinite) {
      final half = safeWidth / 2.0;
      return (half, half);
    }

    if (left.isFinite && !right.isFinite) {
      return (left, math.max(0.0, safeWidth - left));
    }

    if (!left.isFinite && right.isFinite) {
      return (math.max(0.0, safeWidth - right), right);
    }

    final total = left + right;
    if (total > safeWidth && total > 0.0) {
      final factor = safeWidth / total;
      return (left * factor, right * factor);
    }

    return (left, right);
  }

  double _safeExtent(double extent) {
    if (!extent.isFinite) return double.infinity;
    return math.max(0.0, extent);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyTabDecoration &&
        other.offsetOutward == offsetOutward &&
        super == other;
  }

  @override
  int get hashCode =>
      Object.hash(super.hashCode, AnyTabDecoration, offsetOutward);
}
