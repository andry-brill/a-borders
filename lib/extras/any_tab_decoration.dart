import 'dart:math' as math;
import 'dart:ui';

import 'package:any_borders/any_box_decoration.dart';
import 'package:any_borders/any_contour.dart';

/// Tab-shaped [AnyDecoration] configured through an [AnyBoxBorder].
///
/// The lower tab insets are derived from [AnyBoxBorder.bottomLeft] and
/// [AnyBoxBorder.bottomRight]. The left inset uses the bottom-left corner's
/// previous-side extent, and the right inset uses the bottom-right corner's
/// next-side extent.
class AnyTabDecoration extends AnyDecoration {
  const AnyTabDecoration({
    AnyBoxBorder border = const AnyBoxBorder(),
    super.shadows,
    super.clipBase,
    super.shadowBase,
    super.background,
    super.enableCache,
  }) : super(border: border);

  @override
  AnyBoxBorder get border => super.border as AnyBoxBorder;

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection) {
    final bottomLeftCorner = border.bottomLeft ?? border.corners;
    final bottomRightCorner = border.bottomRight ?? border.corners;

    final (leftInset, rightInset) = _bottomInsets(
      bounds.width,
      bottomLeftCorner,
      bottomRightCorner,
    );

    final xL = bounds.left + leftInset;
    final xR = bounds.right - rightInset;
    final bottomLeftOffset = Offset(xL, bounds.bottom);
    final bottomRightOffset = Offset(xR, bounds.bottom);

    const zero = RoundedCorner();
    return [
      point(
        bounds.bottomLeft,
        outer: zero,
        inner: zero,
        skip: bottomLeftOffset == bounds.bottomLeft,
        side: border.bottom ?? border.horizontal,
      ),
      point(
        bottomLeftOffset,
        outer: border.bottomLeft,
        inner: border.innerBottomLeft,
        side: border.left ?? border.vertical,
      ),
      point(
        Offset(xL, bounds.top),
        outer: border.topLeft,
        inner: border.innerTopLeft,
        side: border.top ?? border.horizontal,
      ),
      point(
        Offset(xR, bounds.top),
        outer: border.topRight,
        inner: border.innerTopRight,
        side: border.right ?? border.vertical,
      ),
      point(
        bottomRightOffset,
        outer: border.bottomRight,
        inner: border.innerBottomRight,
        side: border.bottom ?? border.horizontal,
      ),
      point(
        bounds.bottomRight,
        outer: zero,
        inner: zero,
        side: border.bottom ?? border.horizontal,
        skip: bottomRightOffset == bounds.bottomRight,
      ),
    ];
  }

  (double, double) _bottomInsets(
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

    return other is AnyTabDecoration && super == other;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, AnyTabDecoration);
}
