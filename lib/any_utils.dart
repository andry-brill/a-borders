
import 'dart:math' as math;

abstract class AnyUtils {

  static const double epsilon = 1.0e-6;
  static const double startAnglePi1d = math.pi;
  static const double midAngle1d25 = math.pi * 1.25;
  static const double endAnglePi1d5 = math.pi * 1.5;
  static const double quarterSweepPi0d5 = math.pi * 0.5;

  static bool nearZero(double value, [double epsilon = AnyUtils.epsilon]) {
    return value.abs() <= epsilon;
  }

  static double clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double clamp01(double value) {
    if (value <= 0.0) return 0.0;
    if (value >= 1.0) return 1.0;
    return value;
  }

  static T? pickLerpNullable<T>(T? a, T? b, double t) {
    return t < 0.5 ? a : b;
  }

  static T pickLerp<T>(T a, T b, double t) {
    return t < 0.5 ? a : b;
  }

}