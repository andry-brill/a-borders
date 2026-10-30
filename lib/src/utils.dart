import 'dart:ui';

// Shared implementation utilities; not part of the package's public API.
abstract class AnyUtils {
  static const double epsilon = 1.0e-6;

  static T? pickLerpNullable<T>(T? a, T? b, double t) => t < 0.5 ? a : b;

  static T pickLerp<T>(T a, T b, double t) => t < 0.5 ? a : b;

  /// Move the box's straight edges before assigning corner descriptors.
  static Rect displaceBox(Rect bounds, double offset,
      {required double top,
      required double right,
      required double bottom,
      required double left}) {
    final t = offset + top, r = offset + right;
    final b = offset + bottom, l = offset + left;
    if (!t.isFinite || !r.isFinite || !b.isFinite || !l.isFinite) {
      throw ArgumentError('Effective side offsets must be finite.');
    }
    final result = Rect.fromLTRB(
        bounds.left - l, bounds.top - t, bounds.right + r, bounds.bottom + b);
    validateBounds(result);
    return result;
  }

  static void validateBounds(Rect bounds) {
    if (!bounds.left.isFinite ||
        !bounds.top.isFinite ||
        !bounds.right.isFinite ||
        !bounds.bottom.isFinite ||
        !bounds.width.isFinite ||
        !bounds.height.isFinite) {
      throw ArgumentError('Construction bounds must be finite.');
    }
  }

  static Rect fitRatio(Rect bounds, double? ratio) {
    if (ratio == null || ratio <= 0.0) {
      return bounds;
    }

    if (!ratio.isFinite) {
      throw ArgumentError.value(ratio, 'ratio', 'Must be finite');
    }
    var width = bounds.width;
    var height = width / ratio;

    if (height > bounds.height) {
      height = bounds.height;
      width = height * ratio;
    }

    return Rect.fromLTWH(
      bounds.left / 2.0 + bounds.right / 2.0 - width / 2.0,
      bounds.top / 2.0 + bounds.bottom / 2.0 - height / 2.0,
      width,
      height,
    );
  }
}
