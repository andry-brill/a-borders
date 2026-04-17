
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'any_fill.dart';
import 'any_shadow.dart';
import 'any_utils.dart';


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

  final double width;
  /// Align means align relative to the corresponding side, not the whole shape.
  final double align;

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
    this.align = alignInside,
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.isAntiAlias = true,
  })  : assert(width >= 0.0),
        assert(align >= alignInside && align <= alignOutside);

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


  static AnySide lerp(AnySide a, AnySide b, double t) {
    return AnySide(
      width: lerpDouble(a.width, b.width, t)!,
      align: lerpDouble(a.align, b.align, t)!,
      color: Color.lerp(a.color, b.color, t),
      gradient: AnyUtils.pickLerpNullable(a.gradient, b.gradient, t),
      image: AnyUtils.pickLerpNullable(a.image, b.image, t),
      blendMode: AnyUtils.pickLerpNullable(a.blendMode, b.blendMode, t),
      isAntiAlias: AnyUtils.pickLerp(a.isAntiAlias, b.isAntiAlias, t),
    );
  }
}


class AnyBackground with MAnyFill {

  final AnyShapeBase shapeBase;

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

  const AnyBackground({
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.isAntiAlias = true,
    this.shapeBase = AnyShapeBase.zeroBorder
  });

  AnyBackground copyWith({
    AnyShapeBase? shapeBase,
    Color? color,
    Gradient? gradient,
    DecorationImage? image,
    BlendMode? blendMode,
    bool? isAntiAlias,
  }) {
    return AnyBackground(
      shapeBase: shapeBase ?? this.shapeBase,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      image: image ?? this.image,
      blendMode: blendMode ?? this.blendMode,
      isAntiAlias: isAntiAlias ?? this.isAntiAlias,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AnyBackground &&
        other.shapeBase == shapeBase &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.isAntiAlias == isAntiAlias;
  }

  @override
  int get hashCode => Object.hash(
    shapeBase,
    color,
    gradient,
    image,
    blendMode,
    isAntiAlias,
  );


  static AnyBackground? lerp(
      AnyBackground? a,
      AnyBackground? b,
      double t,
      ) {
    if (a == null && b == null) return null;
    if (a == null || b == null) return AnyUtils.pickLerpNullable(a, b, t);

    return AnyBackground(
      color: Color.lerp(a.color, b.color, t),
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
      image: AnyUtils.pickLerpNullable(a.image, b.image, t),
      blendMode:AnyUtils. pickLerpNullable(a.blendMode, b.blendMode, t),
      isAntiAlias: AnyUtils.pickLerp(a.isAntiAlias, b.isAntiAlias, t),
      shapeBase: AnyUtils.pickLerp(a.shapeBase, b.shapeBase, t),
    );
  }
}


enum CornerConverter {
  preserveRatio,
  dynamicRatio,
  equal;

  static const base = CornerConverter.dynamicRatio;
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

  /// Creates the same corner but scaled.
  AnyCorner scale(double scale);

  /// Creates an auto-derived inner/outer corner for the provided adjacent side insets.
  /// [insetX] = inset on previous side
  /// [insetY] = inset on next side
  /// [inner]  = convex/inner turn conversion (same meaning as before)
  /// [angle]  = local corner angle in radians
  AnyCorner convert(
      double insetX,
      double insetY,
      bool inner,
      double angle,
  );

  static AnyCorner lerp(AnyCorner a, AnyCorner b, double t) {
    if (identical(a, b) || a == b) return a;

    if (t <= 0.0) return a;
    if (t >= 1.0) return b;

    if (a.runtimeType == b.runtimeType) {
      return a.lerpTo(b, t);
    }

    if (t < 0.5) {
      return a.scale((0.5 - t) / 0.5);
    }

    return b.scale((t - 0.5) / 0.5);
  }
}

/// Current rounded-corner implementation.
///
/// Negative values are ignored. Infinity is resolved against the adjacent side
/// lengths during contour preparation.
class RoundedCorner extends AnyCorner {

  final Radius radius;
  final CornerConverter converter;

  const RoundedCorner({
    this.radius = Radius.zero,
    this.converter = CornerConverter.base
  });

  bool _canBuild(AnyContour contour, int cornerIndex) {
    return !contour.isCornerParallel(cornerIndex) &&
        radius.x > AnyUtils.epsilon &&
        radius.y > AnyUtils.epsilon &&
        contour.cornerSin[cornerIndex] > AnyUtils.epsilon;
  }

  double _turnSign(AnyContour contour, int cornerIndex) {
    return contour.cornerHandedness(cornerIndex);
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

    return copyWith(radius: Radius.elliptical(rx, ry));
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
    return copyWith(radius: Radius.elliptical(radius.x * factor, radius.y));
  }

  @override
  RoundedCorner scaleForNextSide(double factor) {
    return copyWith(radius: Radius.elliptical(radius.x, radius.y * factor));
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

    final sign = _turnSign(contour, cornerIndex);
    final rx = sign * radius.x;
    final ry = sign * radius.y;
    final localX = dPrev + rx + rx * math.cos(angle);
    final localY = dNext + ry + ry * math.sin(angle);
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

    final fraction = delta.abs() / AnyUtils.quarterSweepPi0d5;
    final baseSegments = contour.cornerSegments[cornerIndex];
    final segmentCount = math.max(1, (baseSegments * fraction).ceil());

    final sign = _turnSign(contour, cornerIndex);
    final rx = sign * radius.x;
    final ry = sign * radius.y;
    final centerX = dPrev + rx;
    final centerY = dNext + ry;

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

      final p1x = centerX + rx * cos0 - alpha * rx * sin0;
      final p1y = centerY + ry * sin0 + alpha * ry * cos0;
      final p2x = centerX + rx * cos1 + alpha * rx * sin1;
      final p2y = centerY + ry * sin1 - alpha * ry * cos1;
      final p3x = centerX + rx * cos1;
      final p3y = centerY + ry * sin1;

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
      throw 'Not the same runtime type: ${other.runtimeType}';
    }

    return RoundedCorner(
      radius: Radius.lerp(radius, other.radius, t)!,
      converter: AnyUtils.pickLerp(converter, other.converter, t),
    );
  }

  @override
  RoundedCorner scale(double scale) => copyWith(radius: radius * scale);

  @override
  RoundedCorner convert(double insetX, double insetY, bool inner, double angle) {
    if (converter == CornerConverter.equal) return this;
    if (radius.x <= 0.0 || radius.y <= 0.0) return const RoundedCorner();
    return RoundedCorner(radius: inner
        ? _innerRadius(radius, insetX, insetY)
        : _outerRadius(radius, insetX, insetY));
  }

  Radius _innerRadius(Radius outer, double insetX, double insetY) {

    final kx = AnyUtils.clamp01((outer.x - insetX) / outer.x);
    final ky = AnyUtils.clamp01((outer.y - insetY) / outer.y);
    var factor = math.min(kx, ky);

    return switch (converter) {
      CornerConverter.preserveRatio => outer * factor,
      CornerConverter.dynamicRatio => Radius.elliptical(outer.x * kx, outer.y * ky),
      CornerConverter.equal => outer,
    };
  }

  Radius _outerRadius(Radius inner, double insetX, double insetY) {
    var factor = math.max(
      (inner.x + insetX) / inner.x,
      (inner.y + insetY) / inner.y,
    );
    return switch (converter) {
      CornerConverter.dynamicRatio => Radius.elliptical(inner.x + insetX, inner.y + insetY),
      CornerConverter.preserveRatio => inner * factor,
      CornerConverter.equal => inner,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RoundedCorner &&
        other.radius == radius &&
        other.converter == converter;
  }

  @override
  int get hashCode => Object.hash(runtimeType, radius, converter);

  RoundedCorner copyWith({Radius? radius, CornerConverter? innerCorner}) =>
      RoundedCorner(
        radius: radius ?? this.radius,
        converter: innerCorner ?? this.converter,
      );
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
  const InverseRoundedCorner({
    this.radius = Radius.zero,
  });

  bool _canBuild(AnyContour contour, int cornerIndex) {
    return !contour.isCornerParallel(cornerIndex) &&
        radius.x > AnyUtils.epsilon &&
        radius.y > AnyUtils.epsilon &&
        contour.cornerSin[cornerIndex] > AnyUtils.epsilon;
  }

  double _turnSign(AnyContour contour, int cornerIndex) {
    return contour.cornerHandedness(cornerIndex);
  }

  double _localAngleFromCommon(double angle) => AnyUtils.endAnglePi1d5 - angle;

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

    return copyWith(radius: Radius.elliptical(rx, ry));
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
    return copyWith(radius: Radius.elliptical(radius.x * factor, radius.y));
  }

  @override
  InverseRoundedCorner scaleForNextSide(double factor) {
    return copyWith(radius: Radius.elliptical(radius.x, radius.y * factor));
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

    final sign = _turnSign(contour, cornerIndex);
    final rx = sign * radius.x;
    final ry = sign * radius.y;
    final localAngle = _localAngleFromCommon(angle);
    final localX = dPrev + rx * math.cos(localAngle);
    final localY = dNext + ry * math.sin(localAngle);
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

    final fraction = delta.abs() / AnyUtils.quarterSweepPi0d5;
    final baseSegments = contour.cornerSegments[cornerIndex];
    final segmentCount = math.max(1, (baseSegments * fraction).ceil());

    final sign = _turnSign(contour, cornerIndex);
    final rx = sign * radius.x;
    final ry = sign * radius.y;
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

      final p1x = centerX + rx * cos0 - alpha * rx * sin0;
      final p1y = centerY + ry * sin0 + alpha * ry * cos0;
      final p2x = centerX + rx * cos1 + alpha * rx * sin1;
      final p2y = centerY + ry * sin1 - alpha * ry * cos1;
      final p3x = centerX + rx * cos1;
      final p3y = centerY + ry * sin1;

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
      throw 'Not the same runtime type: ${other.runtimeType}';
    }

    return InverseRoundedCorner(
      radius: Radius.lerp(radius, other.radius, t)!,
    );
  }

  @override
  InverseRoundedCorner scale(double scale) => copyWith(radius: radius * scale);

  @override
  InverseRoundedCorner convert(double insetX, double insetY, bool inner, double angle) => this;

  @override
  bool operator ==(Object other) {
    return other is InverseRoundedCorner &&
        other.radius == radius;
  }

  @override
  int get hashCode => Object.hash(runtimeType, radius);

  InverseRoundedCorner copyWith({
    Radius? radius,
    CornerConverter? innerCorner,
  }) =>
      InverseRoundedCorner(
        radius: radius ?? this.radius,
      );
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
  final CornerConverter converter;

  const BevelCorner({
    this.radius = Radius.zero,
    this.converter = CornerConverter.base
  });

  bool _canBuild(AnyContour contour, int cornerIndex) {
    return !contour.isCornerParallel(cornerIndex) &&
        radius.x > AnyUtils.epsilon &&
        radius.y > AnyUtils.epsilon &&
        contour.cornerSin[cornerIndex] > AnyUtils.epsilon;
  }

  double _turnSign(AnyContour contour, int cornerIndex) {
    return contour.cornerHandedness(cornerIndex);
  }

  double _tForAngle(double angle) {
    final span = AnyUtils.endAnglePi1d5 - AnyUtils.startAnglePi1d;
    if (span <= AnyUtils.epsilon) return 0.0;
    return AnyUtils.clamp01((angle - AnyUtils.startAnglePi1d) / span);
  }

  (double, double) _startPoint(
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      ) {
    final sign = _turnSign(contour, cornerIndex);
    return contour.worldPointFromDistanceSpace(
      cornerIndex,
      dPrev,
      dNext + sign * radius.y,
    );
  }

  (double, double) _endPoint(
      AnyContour contour,
      int cornerIndex,
      double dPrev,
      double dNext,
      ) {
    final sign = _turnSign(contour, cornerIndex);
    return contour.worldPointFromDistanceSpace(
      cornerIndex,
      dPrev + sign * radius.x,
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

    return copyWith(radius: Radius.elliptical(rx, ry));
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
    return copyWith(radius: Radius.elliptical(radius.x * factor, radius.y));
  }

  @override
  BevelCorner scaleForNextSide(double factor) {
    return copyWith(radius: Radius.elliptical(radius.x, radius.y * factor));
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
      lerpDouble(sx, ex, t)!,
      lerpDouble(sy, ey, t)!,
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
      throw 'Not the same runtime type: ${other.runtimeType}';
    }

    return BevelCorner(
      radius: Radius.lerp(radius, other.radius, t)!,
    );
  }

  @override
  BevelCorner scale(double scale) => copyWith(radius: radius * scale);

  @override
  BevelCorner convert(double insetX, double insetY, bool inner, double angle) {
    if (converter == CornerConverter.equal) return this;
    if (radius.x <= 0.0 || radius.y <= 0.0) {
      return const BevelCorner();
    }

    final convertedRadius = switch (converter) {
      CornerConverter.dynamicRatio =>
          _convertedRadius(insetX, insetY, inner, angle, fixedRatio: false),

      CornerConverter.preserveRatio =>
          _convertedRadius(insetX, insetY, inner, angle, fixedRatio: true),

      CornerConverter.equal => radius,
    };

    return copyWith(
      radius: convertedRadius,
      converter: converter,
    );
  }

  Radius _convertedRadius(
      double insetX,
      double insetY,
      bool inner,
      double angle,
      {required bool fixedRatio}
      ) {
    final rx = radius.x;
    final ry = radius.y;

    if (rx <= AnyUtils.epsilon || ry <= AnyUtils.epsilon) {
      return Radius.zero;
    }

    final safeAngle = AnyUtils.clampDouble(
      angle.isFinite ? angle : math.pi / 2.0,
      AnyUtils.epsilon,
      math.pi - AnyUtils.epsilon,
    );

    final chordMetric = math.sqrt(
      math.max(
        0.0,
        rx * rx + ry * ry - 2.0 * rx * ry * math.cos(safeAngle),
      ),
    );

    if (chordMetric <= AnyUtils.epsilon) {
      return Radius.zero;
    }

    final bevelNormalScale = chordMetric / (rx * ry);

    if (fixedRatio) {

      // Weighted inset along bevel normal.
      // Equal insets => same value. Unequal insets bias by bevel proportions.
      final blendedInset =
          ((insetX / rx) + (insetY / ry)) / ((1.0 / rx) + (1.0 / ry));

      final linearInset = (insetX / rx) + (insetY / ry);
      final normalShift = bevelNormalScale * blendedInset;

      final factor = inner
          ? (1.0 + normalShift - linearInset)
          : (1.0 - normalShift + linearInset);

      final safeFactor = math.max(0.0, factor);

      return Radius.elliptical(
        rx * safeFactor,
        ry * safeFactor,
      );
    }

    final linearInset = (insetX / rx) + (insetY / ry);

    // radius.y controls the bevel endpoint on the previous side
    final factorY = inner
        ? (1.0 + bevelNormalScale * insetX - linearInset)
        : (1.0 - bevelNormalScale * insetX + linearInset);

    // radius.x controls the bevel endpoint on the next side
    final factorX = inner
        ? (1.0 + bevelNormalScale * insetY - linearInset)
        : (1.0 - bevelNormalScale * insetY + linearInset);

    return Radius.elliptical(
      math.max(0.0, rx * factorX),
      math.max(0.0, ry * factorY),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BevelCorner &&
        other.radius == radius &&
        other.converter == converter;
  }

  @override
  int get hashCode => Object.hash(runtimeType, radius, converter);

  BevelCorner copyWith({
    Radius? radius,
    CornerConverter? converter,
  }) =>
      BevelCorner(
        radius: radius ?? this.radius,
        converter: converter ?? this.converter,
      );
}

class AnyPoint {

  final AnyCorner outer;
  final AnyCorner? inner;

  final Offset point;
  final AnySide side;

  const AnyPoint({
    required this.outer,
    this.inner,
    required this.point,
    required this.side,
  });

  static List<AnyPoint>? lerp(List<AnyPoint>? a, List<AnyPoint>? b, double t) {

    if (a == null || b == null) return null;
    if (identical(a, b)) return a;
    if (a.length != b.length) return AnyUtils.pickLerp(a, b, t);

    AnyCorner? lerpInner(AnyCorner? a, AnyCorner? b) {
      if (a == null && b == null) return null;
      if (a == null || b == null) return AnyUtils.pickLerpNullable(a, b, t);
      return AnyCorner.lerp(a, b, t);
    }

    return List<AnyPoint>.generate(a.length, (index) {
      final pa = a[index];
      final pb = b[index];

      return AnyPoint(
        point: Offset.lerp(pa.point, pb.point, t)!,
        outer: AnyCorner.lerp(pa.outer, pb.outer, t),
        inner: lerpInner(pa.inner, pb.inner),
        side: AnySide.lerp(pa.side, pb.side, t),
      );
    }, growable: false);
  }
}

class AnyRegions {
  final (AnyFill, Path)? background;
  final List<(AnyFill, Path)> regions;

  const AnyRegions({
    this.background,
    this.regions = const [],
  });

  AnyRegions withOffset(Offset offset) {
    return AnyRegions(
      background: background == null ? null : (background!.$1, background!.$2.shift(offset)),
      regions: regions.map((el) => (el.$1, el.$2.shift(offset))).toList(growable: false),
    );
  }
}

/// Small shared cache for contours.
///
/// Keyed by decoration instance. The cached contour is reusable only if its
/// local size and text direction still match.
class IDecorationCache {
  static int limit = 1000;

  static final LinkedHashMap<AnyDecoration, AnyContour> _contours = LinkedHashMap<AnyDecoration, AnyContour>();

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
  // Options that uses in cache to check that contour could be re-used
  final Size size;
  final TextDirection? textDirection;

  // Decoration options
  final AnyShapeBase shadowBase;
  final AnyShapeBase clipBase;
  final AnyShapeBase backgroundBase;
  final AnyFill? background;

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

  late final Float64List cornerAngle;
  late final Float64List cornerSin;
  late final Int32List cornerSegments;
  late final Int8List cornerTurnSign;
  late final Uint8List cornerParallel;
  late final Uint8List sideHasWidth;
  late final Uint8List sidePainted;

  late final List<AnySide> sides;
  late List<AnyCorner> outerCorners;
  late List<AnyCorner> zeroCorners;
  late List<AnyCorner> innerCorners;

  List<AnyCorner> _cornersForBase(AnyShapeBase base) {
    return switch (base) {
      AnyShapeBase.outerBorder => outerCorners,
      AnyShapeBase.zeroBorder => zeroCorners,
      AnyShapeBase.innerBorder => innerCorners,
    };
  }

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

  Path shiftedClipPath(Offset offset) => clipPath.shift(offset);

  Path shiftedShadowPath(Offset offset) => shadowPath.shift(offset);

  AnyRegions shiftedRegions({
    required Offset offset,
    required bool backgroundMerge,
  }) {
    final source = regions(backgroundMerge: backgroundMerge);
    return source.withOffset(offset);
  }

  int wrap(int index) {
    final mod = index % count;
    return mod < 0 ? mod + count : mod;
  }

  bool isCornerParallel(int cornerIndex) => cornerParallel[cornerIndex] != 0;

  double cornerHandedness(int cornerIndex) {
    return cornerTurnSign[cornerIndex] < 0 ? -1.0 : 1.0;
  }

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
    cornerAngle = Float64List(count);
    cornerSegments = Int32List(count);
    cornerTurnSign = Int8List(count);
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
    final explicitInnerCorners = List<AnyCorner?>.generate(
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
      cornerTurnSign[corner] = cross < -AnyUtils.epsilon ? -1 : 1;

      final ux = -sideDirectionX[prev];
      final uy = -sideDirectionY[prev];
      final vx = sideDirectionX[corner];
      final vy = sideDirectionY[corner];
      final dot = AnyUtils.clampDouble((ux * vx) + (uy * vy), -1.0, 1.0);
      final angle = math.acos(dot);
      cornerAngle[corner] = angle;
      cornerSegments[corner] = math.max(1, (angle / (math.pi / 2.0)).ceil());
    }

    for (var corner = 0; corner < count; corner++) {
      final prev = wrap(corner - 1);
      outerCorners[corner] =
          outerCorners[corner].resolveFinite(sideLength[prev], sideLength[corner]);
    }

    _normalizeBand(outerCorners);

    zeroCorners = List<AnyCorner>.generate(count, (corner) {
      final prev = wrap(corner - 1);

      return outerCorners[corner].convert(
        sideOutsideOffset[prev],
        sideOutsideOffset[corner],
        cornerTurnSign[corner] > 0,
        cornerAngle[corner],
      );
    }, growable: false);

    _normalizeBand(zeroCorners);

    innerCorners = List<AnyCorner>.generate(count, (corner) {

      final prev = wrap(corner - 1);
      final explicitInner = explicitInnerCorners[corner];
      if (explicitInner != null) {
        return explicitInner.resolveFinite(sideLength[prev], sideLength[corner]);
      }

      return outerCorners[corner].convert(
        sideInsideOffset[prev] + sideOutsideOffset[prev],
        sideInsideOffset[corner] + sideOutsideOffset[corner],
        cornerTurnSign[corner] > 0,
        cornerAngle[corner],
      );
    }, growable: false);

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
    final corners = _cornersForBase(base);

    final prev0 = wrap(-1);
    final dPrev0 = offsetForBase(prev0, base);
    final dNext0 = offsetForBase(0, base);

    _moveToCornerPoint(
      path,
      corners[0],
      0,
      dPrev0,
      dNext0,
      AnyUtils.startAnglePi1d,
    );
    corners[0].appendArc(
      path,
      this,
      0,
      dPrev0,
      dNext0,
      AnyUtils.startAnglePi1d,
      AnyUtils.endAnglePi1d5,
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
        AnyUtils.startAnglePi1d,
      );
      corners[corner].appendArc(
        path,
        this,
        corner,
        dPrev,
        dNext,
        AnyUtils.startAnglePi1d,
        AnyUtils.endAnglePi1d5,
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

    final startOuterFrom = prevHasWidth ? AnyUtils.midAngle1d25 : AnyUtils.startAnglePi1d;
    final endOuterTo = nextHasWidth ? AnyUtils.midAngle1d25 : AnyUtils.endAnglePi1d5;
    final endInnerFrom = nextHasWidth ? AnyUtils.midAngle1d25 : AnyUtils.endAnglePi1d5;
    final startInnerTo = prevHasWidth ? AnyUtils.midAngle1d25 : AnyUtils.startAnglePi1d;

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
      AnyUtils.endAnglePi1d5,
    );

    _lineToCornerPoint(
      path,
      endOuterCorner,
      endCorner,
      endOuterPrev,
      endOuterNext,
      AnyUtils.startAnglePi1d,
    );

    endOuterCorner.appendArc(
      path,
      this,
      endCorner,
      endOuterPrev,
      endOuterNext,
      AnyUtils.startAnglePi1d,
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
      AnyUtils.startAnglePi1d,
    );

    _lineToCornerPoint(
      path,
      startInnerCorner,
      startCorner,
      startInnerPrev,
      startInnerNext,
      AnyUtils.endAnglePi1d5,
    );

    startInnerCorner.appendArc(
      path,
      this,
      startCorner,
      startInnerPrev,
      startInnerNext,
      AnyUtils.endAnglePi1d5,
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

    final regionFills = <AnyFill>[];
    final regionPaths = <Path>[];

    for (var sideIndex = 0; sideIndex < count; sideIndex++) {
      if (sidePainted[sideIndex] == 0) continue;

      final side = sides[sideIndex];
      if (backgroundTarget != null &&
          backgroundMerge &&
          backgroundFill != null &&
          side.align == AnySide.alignOutside &&
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

    final regions = <(AnyFill, Path)>[];
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


/// NB! Operator == and hashCode() for children must be overridden! Or caching will break rendering.
abstract class AnyDecoration extends Decoration {

  /// Build final contour points in local coordinates for this size.
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection);

  final AnyBackground? background;
  final AnySide sides;
  final AnyCorner corners;
  final AnyCorner? innerCorners;

  final List<AnyShadow> shadows;
  final AnyShapeBase clipBase;
  final AnyShapeBase shadowBase;
  final bool enableCache;
  final double? ratio;

  const AnyDecoration({
    this.shadows = const [],
    this.background,
    this.clipBase = AnyShapeBase.zeroBorder,
    this.shadowBase = AnyShapeBase.zeroBorder,
    this.enableCache = true,
    this.ratio,
    AnySide? sides,
    AnyCorner? corners,
    this.innerCorners,
  })  : sides = sides ?? const AnySide(),
        corners = corners ?? const RoundedCorner();

  AnyPoint point(
      Offset point, {
        AnyCorner? outer,
        AnyCorner? inner,
        AnySide? side,
      }) {
    return AnyPoint(
      point: point,
      outer: outer ?? corners,
      inner: inner ?? innerCorners,
      side: side ?? sides,
    );
  }

  Rect fitRatio(Size size, double? ratio) {
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

  AnyContour buildContour(Size size, TextDirection? textDirection) {
    if (enableCache) {
      final cached = IDecorationCache.get(this, size, textDirection);
      if (cached != null) {
        return cached;
      }
    }

    final bounds = fitRatio(size, ratio);

    final contour = AnyContour(
      size: size,
      textDirection: textDirection,
      points: points(bounds, textDirection),
      background: background,
      backgroundBase: background?.shapeBase ?? AnyShapeBase.zeroBorder,
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
        other.ratio == ratio &&
        other.sides == sides &&
        other.corners == corners &&
        other.innerCorners == innerCorners &&
        listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode => Object.hash(
    clipBase,
    shadowBase,
    enableCache,
    background,
    ratio,
    sides,
    corners,
    innerCorners,
    Object.hashAll(shadows),
  );
}


class _AnyDecorationPainter extends BoxPainter {

  _AnyDecorationPainter(this.decoration, super.onChanged);

  final AnyDecoration decoration;
  final Map<DecorationImage, DecorationImagePainter> _imagePainters = <DecorationImage, DecorationImagePainter>{};

  DecorationImagePainter? painterOf(AnyFill fill) {
    if (fill.image == null) return null;
    return _imagePainters.putIfAbsent(fill.image!, () => fill.image!.createPainter(onChanged!));
  }

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
      shadow.paint(canvas, shadowPath!, configuration, painterOf);
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
      shadow.paint(canvas, shadowPath!, configuration, painterOf);
    }

    for (final region in regions.regions) {
      if (!region.$1.hasFill) continue;
      _paintRegion(canvas, region.$1, region.$2, configuration);
    }
  }

  void _paintRegion(
      Canvas canvas,
      AnyFill fill,
      Path path,
      ImageConfiguration configuration,
      ) {

    final imagePainter = this.painterOf(fill);
    if (imagePainter != null) {
      imagePainter.paint(canvas, path.getBounds(), path, configuration);
    }

    final paint = fill.createBasePaint(path, configuration);
    if (paint != null) {
      canvas.drawPath(path, paint);
    }
  }

}
