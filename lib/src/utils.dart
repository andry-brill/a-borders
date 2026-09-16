import 'dart:ui';

// Shared implementation utilities; not part of the package's public API.
abstract class AnyUtils {
  static const double epsilon = 1.0e-6;

  static T? pickLerpNullable<T>(T? a, T? b, double t) => t < 0.5 ? a : b;

  static T pickLerp<T>(T a, T b, double t) => t < 0.5 ? a : b;

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
