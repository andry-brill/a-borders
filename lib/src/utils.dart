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
    return Rect.fromLTRB(
        bounds.left - l, bounds.top - t, bounds.right + r, bounds.bottom + b);
  }

  static Rect fitRatio(Size size, double? ratio) {
    if (ratio == null || ratio <= 0.0) {
      return Offset.zero & size;
    }

    var width = size.width;
    var height = width / ratio;

    if (height > size.height) {
      height = size.height;
      width = height * ratio;
    }

    return Rect.fromLTWH(
      (size.width - width) / 2.0,
      (size.height - height) / 2.0,
      width,
      height,
    );
  }
}
