import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AnyUtils {
  static const double epsilon = 1.0e-6;
  static const double startAngle = math.pi;
  static const double midAngle = math.pi * 1.25;
  static const double endAngle = math.pi * 1.5;
  static const double quarterSweep = math.pi * 0.5;

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

  static double lerpDouble(double a, double b, double t) {
    return a + ((b - a) * t);
  }

  static T? pickLerpNullable<T>(T? a, T? b, double t) {
    return t < 0.5 ? a : b;
  }

  static T pickLerp<T>(T a, T b, double t) {
    return t < 0.5 ? a : b;
  }

  static AnyCorner lerpCorner(AnyCorner a, AnyCorner b, double t) {
    if (identical(a, b) || a == b) return a;
    if (a.runtimeType != b.runtimeType) {
      return t < 0.5 ? a : b;
    }
    return a.lerpTo(b, t);
  }

  static Rect fitRectToRatio(Rect rect, double? ratio) {
    if (ratio == null || ratio <= 0.0) {
      return rect;
    }

    var width = rect.width;
    var height = width / ratio;

    if (height > rect.height) {
      height = rect.height;
      width = height * ratio;
    }

    return Rect.fromLTWH(
      rect.left + (rect.width - width) / 2.0,
      rect.top + (rect.height - height) / 2.0,
      width,
      height,
    );
  }

  static AnySide lerpSide(AnySide a, AnySide b, double t) {
    return AnySide(
      width: lerpDouble(a.width, b.width, t),
      align: lerpDouble(a.align, b.align, t),
      color: Color.lerp(a.color, b.color, t),
      gradient: pickLerpNullable(a.gradient, b.gradient, t),
      image: pickLerpNullable(a.image, b.image, t),
      blendMode: pickLerpNullable(a.blendMode, b.blendMode, t),
      isAntiAlias: pickLerp(a.isAntiAlias, b.isAntiAlias, t),
    );
  }

  static AnyBackground? lerpBackground(
      AnyBackground? a,
      AnyBackground? b,
      double t,
      ) {
    if (a == null && b == null) return null;
    if (a == null || b == null) return pickLerpNullable(a, b, t);

    return AnyBackground(
      color: Color.lerp(a.color, b.color, t),
      gradient: pickLerpNullable(a.gradient, b.gradient, t),
      image: pickLerpNullable(a.image, b.image, t),
      blendMode: pickLerpNullable(a.blendMode, b.blendMode, t),
      isAntiAlias: pickLerp(a.isAntiAlias, b.isAntiAlias, t),
      shapeBase: pickLerp(a.shapeBase, b.shapeBase, t),
    );
  }

  static AnyShadow lerpShadow(AnyShadow a, AnyShadow b, double t) {
    return AnyShadow(
      color: Color.lerp(a.color, b.color, t),
      gradient: pickLerpNullable(a.gradient, b.gradient, t),
      image: pickLerpNullable(a.image, b.image, t),
      blendMode: pickLerpNullable(a.blendMode, b.blendMode, t),
      blurRadius: lerpDouble(a.blurRadius, b.blurRadius, t),
      offset: Offset.lerp(a.offset, b.offset, t) ?? pickLerp(a.offset, b.offset, t),
      spreadRadius: Offset.lerp(a.spreadRadius, b.spreadRadius, t) ??
          pickLerp(a.spreadRadius, b.spreadRadius, t),
      style: pickLerp(a.style, b.style, t),
      isAntiAlias: pickLerp(a.isAntiAlias, b.isAntiAlias, t),
    );
  }

  static List<AnyShadow> lerpShadowList(
      List<AnyShadow> a,
      List<AnyShadow> b,
      double t,
      ) {
    final count = math.max(a.length, b.length);
    return List<AnyShadow>.generate(count, (index) {
      if (index >= a.length) return b[index];
      if (index >= b.length) return a[index];
      return lerpShadow(a[index], b[index], t);
    }, growable: false);
  }
}

abstract class IAnyFill {
  Color? get color;
  Gradient? get gradient;
  DecorationImage? get image;
  BlendMode? get blendMode;
  bool get isAntiAlias;
  bool isSameAs(IAnyFill other);
}

mixin MAnyFill implements IAnyFill {
  @override
  bool isSameAs(IAnyFill? other) {
    if (other == null) return false;
    return color == other.color &&
        gradient == other.gradient &&
        image == other.image &&
        blendMode == other.blendMode &&
        isAntiAlias == other.isAntiAlias;
  }
}

extension EAnyFill on IAnyFill {
  bool get hasFill => color != null || gradient != null || image != null;
  bool get hasBaseFill => color != null || gradient != null;
}

enum AnyShapeBase {
  /// Shape of the element based on corner points only, ignoring side widths.
  zeroBorder,

  /// Contour built on the outer edge of side widths.
  outerBorder,

  /// Contour built on the inner edge of side widths.
  innerBorder,
}

class AnySide with MAnyFill {
  static const double alignInside = -1;
  static const double alignCenter = 0;
  static const double alignOutside = 1;

  static double alignBase = alignInside;

  final double width;
  final double? _align;

  /// Align means align relative to the corresponding side, not the whole shape.
  double get align => _align ?? alignBase;

  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;
  @override
  final bool isAntiAlias;

  const AnySide({
    this.width = 0.0,
    double? align,
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.isAntiAlias = true,
  })  : _align = align,
        assert(width >= 0.0),
        assert(align == null || (align >= -1.0 && align <= 1.0));

  AnySide copyWith({
    double? width,
    double? align,
    Color? color,
    Gradient? gradient,
    DecorationImage? image,
    BlendMode? blendMode,
    bool? isAntiAlias,
  }) {
    return AnySide(
      width: width ?? this.width,
      align: align ?? this.align,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      image: image ?? this.image,
      blendMode: blendMode ?? this.blendMode,
      isAntiAlias: isAntiAlias ?? this.isAntiAlias,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AnySide &&
        other.width == width &&
        other.align == align &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.isAntiAlias == isAntiAlias;
  }

  @override
  int get hashCode => Object.hash(
    width,
    align,
    color,
    gradient,
    image,
    blendMode,
    isAntiAlias,
  );
}

class AnyBackground extends AnySide {
  final AnyShapeBase shapeBase;

  const AnyBackground({
    super.color,
    super.gradient,
    super.image,
    super.blendMode,
    super.isAntiAlias,
    this.shapeBase = AnyShapeBase.zeroBorder,
  }) : super(width: double.infinity, align: AnySide.alignCenter);

  @override
  bool operator ==(Object other) {
    return other is AnyBackground &&
        super == other &&
        other.shapeBase == shapeBase;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, shapeBase);
}

/// Contract for a corner strategy.
///
/// The contour owns shared geometric caches such as side directions, normals,
/// offset-line transforms and side widths. A corner object owns the actual
/// corner semantics: how it resolves itself for finite bounds, how much side
/// length it consumes, how it scales during normalization, and how it emits
/// the corresponding geometry into a [Path].
abstract class AnyCorner {

  const AnyCorner();

  /// Resolve infinities / other size-dependent values using the local side
  /// extents around this corner.
  ///
  /// `maxPreviousExtent` corresponds to the side before the corner, and
  /// `maxNextExtent` corresponds to the side after the corner.
  AnyCorner resolveFinite(double maxPreviousExtent, double maxNextExtent);

  /// Returns the consumption on the previous side of this corner.
  double consumptionForPreviousSide(AnyContour contour, int cornerIndex);

  /// Returns the consumption on the next side of this corner.
  double consumptionForNextSide(AnyContour contour, int cornerIndex);

  /// Scales only the part of this corner that affects the previous side.
  AnyCorner scaleForPreviousSide(double factor);

  /// Scales only the part of this corner that affects the next side.
  AnyCorner scaleForNextSide(double factor);

  /// Returns the world-space point for the requested local corner parameter.
  (double, double) pointAt(
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      double angle,
      );

  /// Emits the requested corner segment directly into [path].
  void appendArc(
      Path path,
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      double fromAngle,
      double toAngle,
      );

  /// Interpolates to another corner of the same type when possible.
  AnyCorner lerpTo(AnyCorner other, double t);
}

/// Current rounded-corner implementation.
///
/// Negative values are ignored. Infinity is resolved against the adjacent side
/// lengths during contour preparation.
class RoundedCorner extends AnyCorner {
  final Radius radius;

  const RoundedCorner([this.radius = Radius.zero]);

  bool _canBuild(AnyContour contour, int cornerIndex) {
    return !contour.isCornerParallel(cornerIndex) &&
        radius.x > AnyUtils.epsilon &&
        radius.y > AnyUtils.epsilon &&
        contour.cornerSin[cornerIndex] > AnyUtils.epsilon;
  }

  @override
  RoundedCorner resolveFinite(double maxPreviousExtent, double maxNextExtent) {
    final rawX = radius.x;
    final rawY = radius.y;

    final rx = rawX.isFinite
        ? math.max(0.0, rawX)
        : math.max(0.0, maxPreviousExtent);
    final ry = rawY.isFinite
        ? math.max(0.0, rawY)
        : math.max(0.0, maxNextExtent);

    return RoundedCorner(Radius.elliptical(rx, ry));
  }

  @override
  double consumptionForPreviousSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, radius.x) / sinTurn;
  }

  @override
  double consumptionForNextSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, radius.y) / sinTurn;
  }

  @override
  RoundedCorner scaleForPreviousSide(double factor) {
    return RoundedCorner(
      Radius.elliptical(radius.x * factor, radius.y),
    );
  }

  @override
  RoundedCorner scaleForNextSide(double factor) {
    return RoundedCorner(
      Radius.elliptical(radius.x, radius.y * factor),
    );
  }

  @override
  (double, double) pointAt(
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      double angle,
      ) {
    if (!_canBuild(contour, cornerIndex)) {
      return contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
    }

    final localX = dPrev + radius.x + radius.x * math.cos(angle);
    final localY = dNext + radius.y + radius.y * math.sin(angle);
    return contour.worldPointFromDistanceSpace(cornerIndex, localX, localY);
  }

  @override
  void appendArc(
      Path path,
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      double fromAngle,
      double toAngle,
      ) {
    final delta = toAngle - fromAngle;
    if (AnyUtils.nearZero(delta)) return;

    if (!_canBuild(contour, cornerIndex)) {
      final (x, y) = contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
      path.lineTo(x, y);
      return;
    }

    final fraction = delta.abs() / AnyUtils.quarterSweep;
    final baseSegments = contour.cornerSegments[cornerIndex];
    final segmentCount = math.max(1, (baseSegments * fraction).ceil());

    final centerX = dPrev + radius.x;
    final centerY = dNext + radius.y;

    for (var i = 0; i < segmentCount; i++) {
      final t0 = i / segmentCount;
      final t1 = (i + 1) / segmentCount;
      final a0 = fromAngle + delta * t0;
      final a1 = fromAngle + delta * t1;
      final da = a1 - a0;
      final alpha = (4.0 / 3.0) * math.tan(da / 4.0);

      final cos0 = math.cos(a0);
      final sin0 = math.sin(a0);
      final cos1 = math.cos(a1);
      final sin1 = math.sin(a1);

      final p1x = centerX + radius.x * cos0 - alpha * radius.x * sin0;
      final p1y = centerY + radius.y * sin0 + alpha * radius.y * cos0;
      final p2x = centerX + radius.x * cos1 + alpha * radius.x * sin1;
      final p2y = centerY + radius.y * sin1 - alpha * radius.y * cos1;
      final p3x = centerX + radius.x * cos1;
      final p3y = centerY + radius.y * sin1;

      final (c1x, c1y) =
      contour.worldPointFromDistanceSpace(cornerIndex, p1x, p1y);
      final (c2x, c2y) =
      contour.worldPointFromDistanceSpace(cornerIndex, p2x, p2y);
      final (ex, ey) =
      contour.worldPointFromDistanceSpace(cornerIndex, p3x, p3y);

      path.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
    }
  }

  @override
  RoundedCorner lerpTo(AnyCorner other, double t) {
    if (other is! RoundedCorner) {
      return t < 0.5 ? this : const RoundedCorner();
    }

    return RoundedCorner(
      Radius.elliptical(
        AnyUtils.lerpDouble(radius.x, other.radius.x, t),
        AnyUtils.lerpDouble(radius.y, other.radius.y, t),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RoundedCorner && other.radius == radius;
  }

  @override
  int get hashCode => radius.hashCode;
}

/// Concave rounded corner.
///
/// This keeps the same tangent points and side-consumption semantics as
/// [RoundedCorner], but the curve is traced on the opposite side of the local
/// quarter ellipse, producing an inward notch instead of an outward round.
///
/// Negative values are ignored. Infinity is resolved against the adjacent side
/// lengths during contour preparation.
class InverseRoundedCorner extends AnyCorner {
  final Radius radius;

  const InverseRoundedCorner([this.radius = Radius.zero]);

  bool _canBuild(AnyContour contour, int cornerIndex) {
    return !contour.isCornerParallel(cornerIndex) &&
        radius.x > AnyUtils.epsilon &&
        radius.y > AnyUtils.epsilon &&
        contour.cornerSin[cornerIndex] > AnyUtils.epsilon;
  }

  double _localAngleFromCommon(double angle) => AnyUtils.endAngle - angle;

  @override
  InverseRoundedCorner resolveFinite(
      double maxPreviousExtent,
      double maxNextExtent,
      ) {
    final rawX = radius.x;
    final rawY = radius.y;

    final rx = rawX.isFinite
        ? math.max(0.0, rawX)
        : math.max(0.0, maxPreviousExtent);
    final ry = rawY.isFinite
        ? math.max(0.0, rawY)
        : math.max(0.0, maxNextExtent);

    return InverseRoundedCorner(Radius.elliptical(rx, ry));
  }

  @override
  double consumptionForPreviousSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, radius.x) / sinTurn;
  }

  @override
  double consumptionForNextSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, radius.y) / sinTurn;
  }

  @override
  InverseRoundedCorner scaleForPreviousSide(double factor) {
    return InverseRoundedCorner(
      Radius.elliptical(radius.x * factor, radius.y),
    );
  }

  @override
  InverseRoundedCorner scaleForNextSide(double factor) {
    return InverseRoundedCorner(
      Radius.elliptical(radius.x, radius.y * factor),
    );
  }

  @override
  (double, double) pointAt(
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      double angle,
      ) {
    if (!_canBuild(contour, cornerIndex)) {
      return contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
    }

    final localAngle = _localAngleFromCommon(angle);
    final localX = dPrev + radius.x * math.cos(localAngle);
    final localY = dNext + radius.y * math.sin(localAngle);
    return contour.worldPointFromDistanceSpace(cornerIndex, localX, localY);
  }

  @override
  void appendArc(
      Path path,
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      double fromAngle,
      double toAngle,
      ) {
    final delta = toAngle - fromAngle;
    if (AnyUtils.nearZero(delta)) return;

    if (!_canBuild(contour, cornerIndex)) {
      final (x, y) = contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
      path.lineTo(x, y);
      return;
    }

    final fraction = delta.abs() / AnyUtils.quarterSweep;
    final baseSegments = contour.cornerSegments[cornerIndex];
    final segmentCount = math.max(1, (baseSegments * fraction).ceil());

    final centerX = dPrev;
    final centerY = dNext;
    final localFromAngle = _localAngleFromCommon(fromAngle);
    final localToAngle = _localAngleFromCommon(toAngle);
    final localDelta = localToAngle - localFromAngle;

    for (var i = 0; i < segmentCount; i++) {
      final t0 = i / segmentCount;
      final t1 = (i + 1) / segmentCount;
      final a0 = localFromAngle + localDelta * t0;
      final a1 = localFromAngle + localDelta * t1;
      final da = a1 - a0;
      final alpha = (4.0 / 3.0) * math.tan(da / 4.0);

      final cos0 = math.cos(a0);
      final sin0 = math.sin(a0);
      final cos1 = math.cos(a1);
      final sin1 = math.sin(a1);

      final p1x = centerX + radius.x * cos0 - alpha * radius.x * sin0;
      final p1y = centerY + radius.y * sin0 + alpha * radius.y * cos0;
      final p2x = centerX + radius.x * cos1 + alpha * radius.x * sin1;
      final p2y = centerY + radius.y * sin1 - alpha * radius.y * cos1;
      final p3x = centerX + radius.x * cos1;
      final p3y = centerY + radius.y * sin1;

      final (c1x, c1y) =
      contour.worldPointFromDistanceSpace(cornerIndex, p1x, p1y);
      final (c2x, c2y) =
      contour.worldPointFromDistanceSpace(cornerIndex, p2x, p2y);
      final (ex, ey) =
      contour.worldPointFromDistanceSpace(cornerIndex, p3x, p3y);

      path.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
    }
  }

  @override
  InverseRoundedCorner lerpTo(AnyCorner other, double t) {
    if (other is! InverseRoundedCorner) {
      return t < 0.5 ? this : const InverseRoundedCorner();
    }

    return InverseRoundedCorner(
      Radius.elliptical(
        AnyUtils.lerpDouble(radius.x, other.radius.x, t),
        AnyUtils.lerpDouble(radius.y, other.radius.y, t),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is InverseRoundedCorner && other.radius == radius;
  }

  @override
  int get hashCode => radius.hashCode;
}

/// Straight chamfer / bevel corner.
///
/// This uses the same side-consumption semantics as [RoundedCorner], but the
/// tangent points are connected by a straight segment instead of a curve.
///
/// The existing corner split logic in [AnyContour] can still request partial
/// segments using the shared angle parameter range. This implementation maps
/// that angle range linearly onto the bevel segment.
class BevelCorner extends AnyCorner {
  final Radius radius;

  const BevelCorner([this.radius = Radius.zero]);

  bool _canBuild(AnyContour contour, int cornerIndex) {
    return !contour.isCornerParallel(cornerIndex) &&
        radius.x > AnyUtils.epsilon &&
        radius.y > AnyUtils.epsilon &&
        contour.cornerSin[cornerIndex] > AnyUtils.epsilon;
  }

  double _tForAngle(double angle) {
    final span = AnyUtils.endAngle - AnyUtils.startAngle;
    if (span <= AnyUtils.epsilon) return 0.0;
    return AnyUtils.clamp01((angle - AnyUtils.startAngle) / span);
  }

  (double, double) _startPoint(
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      ) {
    return contour.worldPointFromDistanceSpace(
      cornerIndex,
      dPrev,
      dNext + radius.y,
    );
  }

  (double, double) _endPoint(
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      ) {
    return contour.worldPointFromDistanceSpace(
      cornerIndex,
      dPrev + radius.x,
      dNext,
    );
  }

  @override
  BevelCorner resolveFinite(double maxPreviousExtent, double maxNextExtent) {
    final rawX = radius.x;
    final rawY = radius.y;

    final rx = rawX.isFinite
        ? math.max(0.0, rawX)
        : math.max(0.0, maxPreviousExtent);
    final ry = rawY.isFinite
        ? math.max(0.0, rawY)
        : math.max(0.0, maxNextExtent);

    return BevelCorner(Radius.elliptical(rx, ry));
  }

  @override
  double consumptionForPreviousSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, radius.x) / sinTurn;
  }

  @override
  double consumptionForNextSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, radius.y) / sinTurn;
  }

  @override
  BevelCorner scaleForPreviousSide(double factor) {
    return BevelCorner(
      Radius.elliptical(radius.x * factor, radius.y),
    );
  }

  @override
  BevelCorner scaleForNextSide(double factor) {
    return BevelCorner(
      Radius.elliptical(radius.x, radius.y * factor),
    );
  }

  @override
  (double, double) pointAt(
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      double angle,
      ) {
    if (!_canBuild(contour, cornerIndex)) {
      return contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
    }

    final t = _tForAngle(angle);
    final (sx, sy) = _startPoint(contour, cornerIndex, dPrev, dNext);
    final (ex, ey) = _endPoint(contour, cornerIndex, dPrev, dNext);
    return (
    AnyUtils.lerpDouble(sx, ex, t),
    AnyUtils.lerpDouble(sy, ey, t),
    );
  }

  @override
  void appendArc(
      Path path,
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      double fromAngle,
      double toAngle,
      ) {
    if (AnyUtils.nearZero(toAngle - fromAngle)) return;

    if (!_canBuild(contour, cornerIndex)) {
      final (x, y) = contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
      path.lineTo(x, y);
      return;
    }

    final (x, y) = pointAt(contour, cornerIndex, dPrev, dNext, toAngle);
    path.lineTo(x, y);
  }

  @override
  BevelCorner lerpTo(AnyCorner other, double t) {
    if (other is! BevelCorner) {
      return t < 0.5 ? this : const BevelCorner();
    }

    return BevelCorner(
      Radius.elliptical(
        AnyUtils.lerpDouble(radius.x, other.radius.x, t),
        AnyUtils.lerpDouble(radius.y, other.radius.y, t),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BevelCorner && other.radius == radius;
  }

  @override
  int get hashCode => radius.hashCode;
}

class AnyPoint {
  final AnyCorner outer;
  final AnyCorner inner;

  final Offset point;
  final AnySide side;

  const AnyPoint({
    required this.outer,
    AnyCorner? inner,
    required this.point,
    required this.side,
  }) : inner = inner ?? outer;

  static List<AnyPoint>? lerp(List<AnyPoint>? a, List<AnyPoint>? b, double t) {
    if (a == null || b == null) return null;
    if (identical(a, b)) return a;
    if (a.length != b.length) return AnyUtils.pickLerpNullable(a, b, t);

    return List<AnyPoint>.generate(a.length, (index) {
      final pa = a[index];
      final pb = b[index];

      return AnyPoint(
        point: Offset(
          AnyUtils.lerpDouble(pa.point.dx, pb.point.dx, t),
          AnyUtils.lerpDouble(pa.point.dy, pb.point.dy, t),
        ),
        outer: AnyUtils.lerpCorner(pa.outer, pb.outer, t),
        inner: AnyUtils.lerpCorner(pa.inner, pb.inner, t),
        side: AnySide(
          width: AnyUtils.lerpDouble(pa.side.width, pb.side.width, t),
          align: AnyUtils.lerpDouble(pa.side.align, pb.side.align, t),
          color: AnyUtils.pickLerpNullable(pa.side.color, pb.side.color, t),
          gradient:
          AnyUtils.pickLerpNullable(pa.side.gradient, pb.side.gradient, t),
          image: AnyUtils.pickLerpNullable(pa.side.image, pb.side.image, t),
          blendMode:
          AnyUtils.pickLerpNullable(pa.side.blendMode, pb.side.blendMode, t),
          isAntiAlias:
          AnyUtils.pickLerp(pa.side.isAntiAlias, pb.side.isAntiAlias, t),
        ),
      );
    }, growable: false);
  }
}

class AnyRegions {
  final (IAnyFill, Path)? background;
  final List<(IAnyFill, Path)> regions;

  const AnyRegions({
    this.background,
    this.regions = const [],
  });
}

/// Small shared cache for contours.
///
/// Keyed by decoration instance. The cached contour is reusable only if its
/// local size and text direction still match.
class IDecorationCache {
  static int limit = 1000;

  static final LinkedHashMap<AnyDecoration, AnyContour> _contours =
  LinkedHashMap<AnyDecoration, AnyContour>();

  static AnyContour? get(
      AnyDecoration decoration,
      Size size,
      TextDirection? textDirection,
      ) {
    final contour = _contours[decoration];
    if (contour == null) return null;
    if (!contour.canReuseFor(size, textDirection)) return null;

    _contours.remove(decoration);
    _contours[decoration] = contour;
    return contour;
  }

  static void put(AnyDecoration decoration, AnyContour contour) {
    _contours.remove(decoration);
    _contours[decoration] = contour;

    while (_contours.length > limit) {
      _contours.remove(_contours.keys.first);
    }
  }

  static void clear() {
    _contours.clear();
  }
}

class AnyContour {
  final Size size;
  final TextDirection? textDirection;
  final AnyShapeBase shadowBase;
  final AnyShapeBase clipBase;
  final AnyShapeBase backgroundBase;
  final IAnyFill? background;

  AnyContour({
    required this.size,
    required this.textDirection,
    required this.background,
    required this.backgroundBase,
    required this.clipBase,
    required this.shadowBase,
    required List<AnyPoint> points,
  }) {
    if (points.length < 3) {
      throw ArgumentError('At least 3 points are required to build a contour.');
    }
    _prepare(points);
  }

  bool canReuseFor(Size otherSize, TextDirection? otherTextDirection) {
    return size == otherSize && textDirection == otherTextDirection;
  }

  int count = 0;

  late final Float64List pointX;
  late final Float64List pointY;

  late final Float64List sideDirectionX;
  late final Float64List sideDirectionY;
  late final Float64List sideLength;

  late final Float64List sideInsideNormalX;
  late final Float64List sideInsideNormalY;

  late final Float64List sideInsideOffset;
  late final Float64List sideOutsideOffset;

  late final Float64List cornerMatrix00;
  late final Float64List cornerMatrix01;
  late final Float64List cornerMatrix10;
  late final Float64List cornerMatrix11;

  late final Float64List cornerSin;
  late final Int32List cornerSegments;
  late final Uint8List cornerParallel;
  late final Uint8List sideHasWidth;
  late final Uint8List sidePainted;

  late final List<AnySide> sides;
  late List<AnyCorner> outerCorners;
  late List<AnyCorner> innerCorners;

  Path? _clipPath;
  Path get clipPath => _clipPath ??= _buildContourPath(clipBase);

  Path? _shadowPath;
  Path get shadowPath => _shadowPath ??= _buildContourPath(shadowBase);

  Path? _backgroundPath;
  Path? get backgroundPath {
    final backgroundFill = background;
    if (backgroundFill == null || !backgroundFill.hasFill) return null;
    return _backgroundPath ??= _buildContourPath(backgroundBase);
  }

  AnyRegions? _regionsMerged;
  AnyRegions? _regionsSeparate;

  AnyRegions regions({required bool backgroundMerge}) {
    if (backgroundMerge) {
      return _regionsMerged ??= _buildRegions(true);
    }
    return _regionsSeparate ??= _buildRegions(false);
  }

  Path shiftedClipPath(Offset offset) =>
      offset == Offset.zero ? clipPath : clipPath.shift(offset);

  Path shiftedShadowPath(Offset offset) =>
      offset == Offset.zero ? shadowPath : shadowPath.shift(offset);

  AnyRegions shiftedRegions({
    required Offset offset,
    required bool backgroundMerge,
  }) {
    if (offset == Offset.zero) {
      return regions(backgroundMerge: backgroundMerge);
    }

    final source = regions(backgroundMerge: backgroundMerge);
    return AnyRegions(
      background: source.background == null
          ? null
          : (source.background!.$1, source.background!.$2.shift(offset)),
      regions: List<(IAnyFill, Path)>.generate(
        source.regions.length,
            (index) => (
        source.regions[index].$1,
        source.regions[index].$2.shift(offset),
        ),
        growable: false,
      ),
    );
  }

  int wrap(int index) {
    final mod = index % count;
    return mod < 0 ? mod + count : mod;
  }

  bool isCornerParallel(int cornerIndex) => cornerParallel[cornerIndex] != 0;

  double offsetForBase(int sideIndex, AnyShapeBase base) {
    return switch (base) {
      AnyShapeBase.zeroBorder => 0.0,
      AnyShapeBase.outerBorder => -sideOutsideOffset[sideIndex],
      AnyShapeBase.innerBorder => sideInsideOffset[sideIndex],
    };
  }

  (double, double) sharpCornerPoint(int cornerIndex, double dPrev, double dNext) {
    if (!isCornerParallel(cornerIndex)) {
      return worldPointFromDistanceSpace(cornerIndex, dPrev, dNext);
    }

    final prev = wrap(cornerIndex - 1);
    final x1 = pointX[cornerIndex] + sideInsideNormalX[prev] * dPrev;
    final y1 = pointY[cornerIndex] + sideInsideNormalY[prev] * dPrev;
    final x2 = pointX[cornerIndex] + sideInsideNormalX[cornerIndex] * dNext;
    final y2 = pointY[cornerIndex] + sideInsideNormalY[cornerIndex] * dNext;
    return ((x1 + x2) * 0.5, (y1 + y2) * 0.5);
  }

  (double, double) worldPointFromDistanceSpace(
      int cornerIndex,
      double dPrev,
      double dNext,
      ) {
    return (
    pointX[cornerIndex] +
        (cornerMatrix00[cornerIndex] * dPrev) +
        (cornerMatrix01[cornerIndex] * dNext),
    pointY[cornerIndex] +
        (cornerMatrix10[cornerIndex] * dPrev) +
        (cornerMatrix11[cornerIndex] * dNext),
    );
  }

  void _prepare(List<AnyPoint> points) {
    count = points.length;

    pointX = Float64List(count);
    pointY = Float64List(count);
    sideDirectionX = Float64List(count);
    sideDirectionY = Float64List(count);
    sideLength = Float64List(count);
    sideInsideNormalX = Float64List(count);
    sideInsideNormalY = Float64List(count);
    sideInsideOffset = Float64List(count);
    sideOutsideOffset = Float64List(count);
    cornerMatrix00 = Float64List(count);
    cornerMatrix01 = Float64List(count);
    cornerMatrix10 = Float64List(count);
    cornerMatrix11 = Float64List(count);
    cornerSin = Float64List(count);
    cornerSegments = Int32List(count);
    cornerParallel = Uint8List(count);
    sideHasWidth = Uint8List(count);
    sidePainted = Uint8List(count);
    sides = List<AnySide>.generate(
      count,
          (index) => points[index].side,
      growable: false,
    );
    outerCorners = List<AnyCorner>.generate(
      count,
          (index) => points[index].outer,
      growable: false,
    );
    innerCorners = List<AnyCorner>.generate(
      count,
          (index) => points[index].inner,
      growable: false,
    );

    var signedAreaTwice = 0.0;

    for (var i = 0; i < count; i++) {
      final point = points[i];
      final next = points[(i + 1) % count];
      final side = point.side;

      pointX[i] = point.point.dx;
      pointY[i] = point.point.dy;

      final inside = side.width * (1.0 - side.align) / 2.0;
      final outside = side.width * (1.0 + side.align) / 2.0;
      sideInsideOffset[i] = inside;
      sideOutsideOffset[i] = outside;
      sideHasWidth[i] = side.width > AnyUtils.epsilon ? 1 : 0;
      sidePainted[i] = side.width > AnyUtils.epsilon && side.hasFill ? 1 : 0;

      signedAreaTwice +=
          (point.point.dx * next.point.dy) - (point.point.dy * next.point.dx);
    }

    final isClockwise = signedAreaTwice > 0.0;

    for (var i = 0; i < count; i++) {
      final next = (i + 1) % count;
      final dx = pointX[next] - pointX[i];
      final dy = pointY[next] - pointY[i];
      final length = math.sqrt(dx * dx + dy * dy);
      if (length <= AnyUtils.epsilon) {
        throw ArgumentError('Side $i has zero length.');
      }

      final ux = dx / length;
      final uy = dy / length;
      sideDirectionX[i] = ux;
      sideDirectionY[i] = uy;
      sideLength[i] = length;

      if (isClockwise) {
        sideInsideNormalX[i] = -uy;
        sideInsideNormalY[i] = ux;
      } else {
        sideInsideNormalX[i] = uy;
        sideInsideNormalY[i] = -ux;
      }
    }

    for (var corner = 0; corner < count; corner++) {
      final prev = wrap(corner - 1);

      final npx = sideInsideNormalX[prev];
      final npy = sideInsideNormalY[prev];
      final nnx = sideInsideNormalX[corner];
      final nny = sideInsideNormalY[corner];

      final det = (npx * nny) - (npy * nnx);
      if (AnyUtils.nearZero(det)) {
        cornerParallel[corner] = 1;
        cornerMatrix00[corner] = 0.0;
        cornerMatrix01[corner] = 0.0;
        cornerMatrix10[corner] = 0.0;
        cornerMatrix11[corner] = 0.0;
      } else {
        cornerParallel[corner] = 0;
        cornerMatrix00[corner] = nny / det;
        cornerMatrix01[corner] = -npy / det;
        cornerMatrix10[corner] = -nnx / det;
        cornerMatrix11[corner] = npx / det;
      }

      final cross = (sideDirectionX[prev] * sideDirectionY[corner]) -
          (sideDirectionY[prev] * sideDirectionX[corner]);
      final sinTurn = cross.abs();
      cornerSin[corner] = sinTurn;

      final ux = -sideDirectionX[prev];
      final uy = -sideDirectionY[prev];
      final vx = sideDirectionX[corner];
      final vy = sideDirectionY[corner];
      final dot = AnyUtils.clampDouble((ux * vx) + (uy * vy), -1.0, 1.0);
      final angle = math.acos(dot);
      cornerSegments[corner] = math.max(1, (angle / (math.pi / 2.0)).ceil());
    }

    for (var corner = 0; corner < count; corner++) {
      final prev = wrap(corner - 1);
      outerCorners[corner] =
          outerCorners[corner].resolveFinite(sideLength[prev], sideLength[corner]);
      innerCorners[corner] =
          innerCorners[corner].resolveFinite(sideLength[prev], sideLength[corner]);
    }

    _normalizeBand(outerCorners);
    _normalizeBand(innerCorners);
  }

  void _normalizeBand(List<AnyCorner> corners) {
    for (var side = 0; side < count; side++) {
      final startCorner = side;
      final endCorner = wrap(side + 1);

      final startConsumption =
      corners[startCorner].consumptionForNextSide(this, startCorner);
      final endConsumption =
      corners[endCorner].consumptionForPreviousSide(this, endCorner);
      final total = startConsumption + endConsumption;

      if (total <= sideLength[side] + AnyUtils.epsilon ||
          total <= AnyUtils.epsilon) {
        continue;
      }

      final scale = sideLength[side] / total;
      corners[startCorner] = corners[startCorner].scaleForNextSide(scale);
      corners[endCorner] = corners[endCorner].scaleForPreviousSide(scale);
    }
  }

  Path _buildContourPath(AnyShapeBase base) {
    final path = Path();
    final corners =
    base == AnyShapeBase.innerBorder ? innerCorners : outerCorners;

    final prev0 = wrap(-1);
    final dPrev0 = offsetForBase(prev0, base);
    final dNext0 = offsetForBase(0, base);

    _moveToCornerPoint(
      path,
      corners[0],
      0,
      dPrev0,
      dNext0,
      AnyUtils.startAngle,
    );
    corners[0].appendArc(
      path,
      this,
      0,
      dPrev0,
      dNext0,
      AnyUtils.startAngle,
      AnyUtils.endAngle,
    );

    for (var corner = 1; corner < count; corner++) {
      final prev = wrap(corner - 1);
      final dPrev = offsetForBase(prev, base);
      final dNext = offsetForBase(corner, base);

      _lineToCornerPoint(
        path,
        corners[corner],
        corner,
        dPrev,
        dNext,
        AnyUtils.startAngle,
      );
      corners[corner].appendArc(
        path,
        this,
        corner,
        dPrev,
        dNext,
        AnyUtils.startAngle,
        AnyUtils.endAngle,
      );
    }

    path.close();
    return path;
  }

  void _appendSidePolygon(Path path, int sideIndex) {
    final prevSide = wrap(sideIndex - 1);
    final nextSide = wrap(sideIndex + 1);
    final startCorner = sideIndex;
    final endCorner = wrap(sideIndex + 1);

    final startOuterCorner = outerCorners[startCorner];
    final endOuterCorner = outerCorners[endCorner];
    final startInnerCorner = innerCorners[startCorner];
    final endInnerCorner = innerCorners[endCorner];

    final prevHasWidth = sideHasWidth[prevSide] != 0;
    final nextHasWidth = sideHasWidth[nextSide] != 0;

    final startOuterFrom = prevHasWidth ? AnyUtils.midAngle : AnyUtils.startAngle;
    final endOuterTo = nextHasWidth ? AnyUtils.midAngle : AnyUtils.endAngle;
    final endInnerFrom = nextHasWidth ? AnyUtils.midAngle : AnyUtils.endAngle;
    final startInnerTo = prevHasWidth ? AnyUtils.midAngle : AnyUtils.startAngle;

    final startOuterPrev = -sideOutsideOffset[prevSide];
    final startOuterNext = -sideOutsideOffset[sideIndex];
    final endOuterPrev = -sideOutsideOffset[sideIndex];
    final endOuterNext = -sideOutsideOffset[nextSide];

    final startInnerPrev = sideInsideOffset[prevSide];
    final startInnerNext = sideInsideOffset[sideIndex];
    final endInnerPrev = sideInsideOffset[sideIndex];
    final endInnerNext = sideInsideOffset[nextSide];

    _moveToCornerPoint(
      path,
      startOuterCorner,
      startCorner,
      startOuterPrev,
      startOuterNext,
      startOuterFrom,
    );

    startOuterCorner.appendArc(
      path,
      this,
      startCorner,
      startOuterPrev,
      startOuterNext,
      startOuterFrom,
      AnyUtils.endAngle,
    );

    _lineToCornerPoint(
      path,
      endOuterCorner,
      endCorner,
      endOuterPrev,
      endOuterNext,
      AnyUtils.startAngle,
    );

    endOuterCorner.appendArc(
      path,
      this,
      endCorner,
      endOuterPrev,
      endOuterNext,
      AnyUtils.startAngle,
      endOuterTo,
    );

    _lineToCornerPoint(
      path,
      endInnerCorner,
      endCorner,
      endInnerPrev,
      endInnerNext,
      endInnerFrom,
    );

    endInnerCorner.appendArc(
      path,
      this,
      endCorner,
      endInnerPrev,
      endInnerNext,
      endInnerFrom,
      AnyUtils.startAngle,
    );

    _lineToCornerPoint(
      path,
      startInnerCorner,
      startCorner,
      startInnerPrev,
      startInnerNext,
      AnyUtils.endAngle,
    );

    startInnerCorner.appendArc(
      path,
      this,
      startCorner,
      startInnerPrev,
      startInnerNext,
      AnyUtils.endAngle,
      startInnerTo,
    );

    path.close();
  }

  void _moveToCornerPoint(
      Path path,
      AnyCorner corner,
      int cornerIndex,
      double dPrev,
      double dNext,
      double angle,
      ) {
    final (x, y) = corner.pointAt(this, cornerIndex, dPrev, dNext, angle);
    path.moveTo(x, y);
  }

  void _lineToCornerPoint(
      Path path,
      AnyCorner corner,
      int cornerIndex,
      double dPrev,
      double dNext,
      double angle,
      ) {
    final (x, y) = corner.pointAt(this, cornerIndex, dPrev, dNext, angle);
    path.lineTo(x, y);
  }

  AnyRegions _buildRegions(bool backgroundMerge) {
    final backgroundFill = background;
    final backgroundSource = backgroundPath;
    final backgroundTarget =
    backgroundSource == null ? null : Path.from(backgroundSource);

    final regionFills = <IAnyFill>[];
    final regionPaths = <Path>[];

    for (var sideIndex = 0; sideIndex < count; sideIndex++) {
      if (sidePainted[sideIndex] == 0) continue;

      final side = sides[sideIndex];
      if (backgroundTarget != null &&
          backgroundMerge &&
          backgroundFill != null &&
          side.isSameAs(backgroundFill)) {
        _appendSidePolygon(backgroundTarget, sideIndex);
        continue;
      }

      var targetIndex = -1;
      for (var i = 0; i < regionFills.length; i++) {
        if (regionFills[i].isSameAs(side)) {
          targetIndex = i;
          break;
        }
      }

      if (targetIndex < 0) {
        targetIndex = regionFills.length;
        regionFills.add(side);
        regionPaths.add(Path());
      }

      _appendSidePolygon(regionPaths[targetIndex], sideIndex);
    }

    final regions = <(IAnyFill, Path)>[];
    for (var i = 0; i < regionFills.length; i++) {
      regions.add((regionFills[i], regionPaths[i]));
    }

    return AnyRegions(
      background: backgroundTarget != null && backgroundFill != null
          ? (backgroundFill, backgroundTarget)
          : null,
      regions: regions,
    );
  }
}

class AnyShadow with MAnyFill {
  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;
  @override
  final bool isAntiAlias;

  final double blurRadius;
  final Offset spreadRadius;
  final Offset offset;
  final BlurStyle style;

  const AnyShadow({
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.blurRadius = 0.0,
    this.offset = Offset.zero,
    this.spreadRadius = Offset.zero,
    this.style = BlurStyle.normal,
    this.isAntiAlias = true,
  });

  double get blurSigma => Shadow.convertRadiusToSigma(blurRadius);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyShadow &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.blurRadius == blurRadius &&
        other.offset == offset &&
        other.spreadRadius == spreadRadius &&
        other.style == style &&
        other.isAntiAlias == isAntiAlias;
  }

  @override
  int get hashCode => Object.hash(
    color,
    gradient,
    image,
    blendMode,
    blurRadius,
    offset,
    spreadRadius,
    style,
    isAntiAlias,
  );
}

abstract class AnyDecoration extends Decoration {
  /// Build final contour points in local coordinates for this size.
  ///
  /// Each [AnyPoint.side] belongs to the segment that starts at this point and
  /// goes to the next point.
  List<AnyPoint> points(Size size, TextDirection? textDirection);

  final AnyBackground? background;
  final List<AnyShadow> shadows;
  final AnyShapeBase clipBase;
  final AnyShapeBase? _shadowBase;
  final bool enableCache;

  AnyShapeBase get backgroundShapeBase =>
      background?.shapeBase ?? AnyShapeBase.zeroBorder;

  AnyShapeBase get shadowBase =>
      _shadowBase ?? background?.shapeBase ?? clipBase;

  const AnyDecoration({
    this.shadows = const [],
    this.background,
    this.clipBase = AnyShapeBase.zeroBorder,
    AnyShapeBase? shadowBase,
    this.enableCache = true,
  }) : _shadowBase = shadowBase;

  AnyContour buildContour(Size size, TextDirection? textDirection) {

    if (enableCache) {
      final cached = IDecorationCache.get(this, size, textDirection);
      if (cached != null) {
        return cached;
      }
    }

    final contour = AnyContour(
      size: size,
      textDirection: textDirection,
      points: points(size, textDirection),
      background: background,
      backgroundBase: backgroundShapeBase,
      clipBase: clipBase,
      shadowBase: shadowBase,
    );

    if (enableCache) {
      IDecorationCache.put(this, contour);
    }
    return contour;
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _AnyDecorationPainter(this, onChanged);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    final contour = buildContour(rect.size, textDirection);
    return contour.shiftedClipPath(rect.topLeft);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyDecoration &&
        other.shadowBase == shadowBase &&
        other.clipBase == clipBase &&
        other.enableCache == enableCache &&
        other.background == background &&
        listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode =>
      Object.hash(
        clipBase,
        shadowBase,
        enableCache,
        background,
        Object.hashAll(shadows),
      );
}

class AnyDecorationTween extends Tween<AnyDecoration> {

  AnyDecorationTween({
    required AnyDecoration super.begin,
    required AnyDecoration super.end,
  });

  @override
  AnyDecoration lerp(double t) {
    if (t <= 0.0) return begin!;
    if (t >= 1.0) return end!;

    return _TweenDecoration(
      beginDecoration: begin!,
      endDecoration: end!,
      t: t,
    );
  }
}

class _TweenDecoration extends AnyDecoration {

  final AnyDecoration beginDecoration;
  final AnyDecoration endDecoration;
  final double t;

  _TweenDecoration({
    required this.beginDecoration,
    required this.endDecoration,
    required this.t,
  }) : super(
    background: AnyUtils.lerpBackground(
      beginDecoration.background,
      endDecoration.background,
      t,
    ),
    shadows: AnyUtils.lerpShadowList(
      beginDecoration.shadows,
      endDecoration.shadows,
      t,
    ),
    clipBase: AnyUtils.pickLerp(
      beginDecoration.clipBase,
      endDecoration.clipBase,
      t,
    ),
    shadowBase: AnyUtils.pickLerp(
      beginDecoration.shadowBase,
      endDecoration.shadowBase,
      t,
    ),
    enableCache: false
  );

  @override
  List<AnyPoint> points(Size size, TextDirection? textDirection) {
    final a = beginDecoration.points(size, textDirection);
    final b = endDecoration.points(size, textDirection);
    return AnyPoint.lerp(a, b, t)!;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is _TweenDecoration &&
        other.beginDecoration == beginDecoration &&
        other.endDecoration == endDecoration &&
        other.t == t &&
        super == other;
  }

  @override
  int get hashCode => Object.hash(
    super.hashCode,
    beginDecoration,
    endDecoration,
    t,
  );
}

class _AnyDecorationPainter extends BoxPainter {
  _AnyDecorationPainter(this.decoration, super.onChanged);

  final AnyDecoration decoration;
  final Map<DecorationImage, DecorationImagePainter> _imagePainters =
  <DecorationImage, DecorationImagePainter>{};

  @override
  void paint(Canvas canvas, Offset topLeft, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    final innerShadows = <AnyShadow>[];
    final otherShadows = <AnyShadow>[];
    for (final shadow in decoration.shadows) {
      if (!shadow.hasFill) continue;
      if (shadow.style == BlurStyle.inner) {
        innerShadows.add(shadow);
      } else {
        otherShadows.add(shadow);
      }
    }

    final contour = decoration.buildContour(size, configuration.textDirection);
    final regions = contour.shiftedRegions(
      offset: topLeft,
      backgroundMerge: innerShadows.isEmpty,
    );

    final backgroundRegion = regions.background;

    Path? shadowPath;
    if (innerShadows.isNotEmpty || otherShadows.isNotEmpty) {
      shadowPath = contour.shiftedShadowPath(topLeft);
    }

    for (final shadow in otherShadows) {
      _paintShadow(canvas, shadow, shadowPath!, configuration);
    }

    if (backgroundRegion != null && backgroundRegion.$1.hasFill) {
      _paintRegion(
        canvas,
        backgroundRegion.$1,
        backgroundRegion.$2,
        configuration,
      );
    }

    for (final shadow in innerShadows) {
      _paintShadow(canvas, shadow, shadowPath!, configuration);
    }

    for (final region in regions.regions) {
      if (!region.$1.hasFill) continue;
      _paintRegion(canvas, region.$1, region.$2, configuration);
    }
  }

  void _paintRegion(
      Canvas canvas,
      IAnyFill fill,
      Path path,
      ImageConfiguration configuration,
      ) {
    if (fill.image != null) {
      final imagePainter = _imagePainters.putIfAbsent(
        fill.image!,
            () => fill.image!.createPainter(onChanged ?? () {}),
      );

      imagePainter.paint(canvas, path.getBounds(), path, configuration);
    }

    if (fill.hasBaseFill) {
      final paint = createBasePaint(fill, path, configuration);
      canvas.drawPath(path, paint);
    }
  }

  Paint createBasePaint(
      IAnyFill fill,
      Path path,
      ImageConfiguration configuration,
      ) {
    final paint = Paint()..isAntiAlias = fill.isAntiAlias;

    if (fill.blendMode != null) {
      paint.blendMode = fill.blendMode!;
    }

    if (fill.gradient != null) {
      paint.shader = fill.gradient!.createShader(
        path.getBounds(),
        textDirection: configuration.textDirection,
      );
    } else if (fill.color != null) {
      paint.color = fill.color!;
    }

    return paint;
  }

  void _paintShadow(
      Canvas canvas,
      AnyShadow shadow,
      Path path,
      ImageConfiguration configuration,
      ) {
    var targetPath = path;

    if (shadow.spreadRadius != Offset.zero) {
      final bounds = targetPath.getBounds();
      final width = bounds.width;
      final height = bounds.height;
      if (width > AnyUtils.epsilon && height > AnyUtils.epsilon) {
        final scaleX = (width + shadow.spreadRadius.dx) / width;
        final scaleY = (height + shadow.spreadRadius.dy) / height;
        final cx = bounds.center.dx;
        final cy = bounds.center.dy;

        final matrix = Matrix4.identity()
          ..translateByDouble(cx, cy, 0, 1.0)
          ..scaleByDouble(scaleX, scaleY, 1.0, 1.0)
          ..translateByDouble(-cx, -cy, 0, 1.0);

        targetPath = targetPath.transform(matrix.storage);
      }
    }

    if (shadow.offset != Offset.zero) {
      targetPath = targetPath.shift(shadow.offset);
    }

    if (shadow.image != null) {
      final imagePainter = _imagePainters.putIfAbsent(
        shadow.image!,
            () => shadow.image!.createPainter(onChanged ?? () {}),
      );

      void paintImageSource() {
        imagePainter.paint(
          canvas,
          targetPath.getBounds(),
          targetPath,
          configuration,
        );
      }

      final layerBounds = targetPath.getBounds().inflate(
        shadow.blurRadius > 0 ? shadow.blurRadius * 2.0 + 1.0 : 1.0,
      );

      final compositePaint = Paint()..isAntiAlias = shadow.isAntiAlias;
      if (shadow.blendMode != null) {
        compositePaint.blendMode = shadow.blendMode!;
      }

      final blurPaint = Paint();
      if (shadow.blurSigma > 0.0) {
        blurPaint.imageFilter = ImageFilter.blur(
          sigmaX: shadow.blurSigma,
          sigmaY: shadow.blurSigma,
          tileMode: TileMode.decal,
        );
      }

      canvas.saveLayer(layerBounds, compositePaint);

      switch (shadow.style) {
        case BlurStyle.normal:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();
          break;
        case BlurStyle.inner:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();

          canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstIn);
          paintImageSource();
          canvas.restore();
          break;
        case BlurStyle.outer:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();

          canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstOut);
          paintImageSource();
          canvas.restore();
          break;
        case BlurStyle.solid:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();

          canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstOut);
          paintImageSource();
          canvas.restore();

          paintImageSource();
          break;
      }

      canvas.restore();
    }

    if (shadow.hasBaseFill) {
      final paint = createBasePaint(shadow, targetPath, configuration)
        ..maskFilter = MaskFilter.blur(shadow.style, shadow.blurSigma);

      canvas.drawPath(targetPath, paint);
    }
  }
}

class AnyBoxDecoration extends AnyDecoration {
  static const AnySide zeroSide = AnySide();
  static const AnyCorner cornersBase = RoundedCorner();

  final AnySide? _left;
  AnySide get left => _left ?? sides;

  final AnySide? _top;
  AnySide get top => _top ?? sides;

  final AnySide? _right;
  AnySide get right => _right ?? sides;

  final AnySide? _bottom;
  AnySide get bottom => _bottom ?? sides;

  final AnySide? _sides;
  AnySide get sides => _sides ?? zeroSide;

  final AnyCorner? _topLeft;
  AnyCorner get topLeft => _topLeft ?? corners;

  final AnyCorner? _topRight;
  AnyCorner get topRight => _topRight ?? corners;

  final AnyCorner? _bottomRight;
  AnyCorner get bottomRight => _bottomRight ?? corners;

  final AnyCorner? _bottomLeft;
  AnyCorner get bottomLeft => _bottomLeft ?? corners;

  final AnyCorner? _corners;
  AnyCorner get corners => _corners ?? cornersBase;

  final AnyCorner? _innerTopLeft;
  AnyCorner get innerTopLeft => _innerTopLeft ?? innerCorners ?? topLeft;

  final AnyCorner? _innerTopRight;
  AnyCorner get innerTopRight => _innerTopRight ?? innerCorners ?? topRight;

  final AnyCorner? _innerBottomRight;
  AnyCorner get innerBottomRight =>
      _innerBottomRight ?? innerCorners ?? bottomRight;

  final AnyCorner? _innerBottomLeft;
  AnyCorner get innerBottomLeft =>
      _innerBottomLeft ?? innerCorners ?? bottomLeft;

  final AnyCorner? innerCorners;

  /// Width / Height.
  final double? ratio;

  const AnyBoxDecoration({
    double? ratio,
    bool circle = false,
    super.shadows,
    super.clipBase,
    super.shadowBase,
    super.background,
    super.enableCache,
    AnySide? left,
    AnySide? top,
    AnySide? right,
    AnySide? bottom,
    AnySide? sides,
    AnyCorner? topLeft,
    AnyCorner? topRight,
    AnyCorner? bottomRight,
    AnyCorner? bottomLeft,
    AnyCorner? corners,
    AnyCorner? innerTopLeft,
    AnyCorner? innerTopRight,
    AnyCorner? innerBottomRight,
    AnyCorner? innerBottomLeft,
    this.innerCorners,
  })  : ratio = circle ? 1.0 : ratio,
        _corners = circle
            ? const RoundedCorner(Radius.circular(double.infinity))
            : corners,
        _sides = sides,
        _left = left,
        _top = top,
        _right = right,
        _bottom = bottom,
        _topLeft = topLeft,
        _topRight = topRight,
        _bottomRight = bottomRight,
        _bottomLeft = bottomLeft,
        _innerTopLeft = innerTopLeft,
        _innerTopRight = innerTopRight,
        _innerBottomRight = innerBottomRight,
        _innerBottomLeft = innerBottomLeft;

  @override
  List<AnyPoint> points(Size size, TextDirection? textDirection) {
    final fitted = AnyUtils.fitRectToRatio(Offset.zero & size, ratio);

    return <AnyPoint>[
      AnyPoint(
        point: fitted.topLeft,
        outer: topLeft,
        inner: innerTopLeft,
        side: top,
      ),
      AnyPoint(
        point: fitted.topRight,
        outer: topRight,
        inner: innerTopRight,
        side: right,
      ),
      AnyPoint(
        point: fitted.bottomRight,
        outer: bottomRight,
        inner: innerBottomRight,
        side: bottom,
      ),
      AnyPoint(
        point: fitted.bottomLeft,
        outer: bottomLeft,
        inner: innerBottomLeft,
        side: left,
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyBoxDecoration &&
        other.ratio == ratio &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
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
    ratio,
    left,
    top,
    right,
    bottom,
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
