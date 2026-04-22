import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'any_decoration_cache.dart';
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

/// Fill and geometry for one contour side.
///
/// Sides are assigned to [AnyPoint] entries and are painted between that point
/// and the next point in the contour.
class AnySide with MAnyFill {
  /// Places the full side width inside the source contour.
  static const double alignInside = -1;

  /// Centers the side width on the source contour.
  static const double alignCenter = 0;

  /// Places the full side width outside the source contour.
  static const double alignOutside = 1;

  /// Stroke width for this side.
  final double width;

  /// Align means align relative to the corresponding side, not the whole shape.
  final double align;

  /// Solid color used as the side base fill.
  @override
  final Color? color;

  /// Gradient used as the side base fill.
  @override
  final Gradient? gradient;

  /// Image painted into the side path.
  @override
  final DecorationImage? image;

  /// Blend mode applied to the side base fill.
  @override
  final BlendMode? blendMode;

  /// Whether side paths should be anti-aliased.
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
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
      image: AnyUtils.pickLerpNullable(a.image, b.image, t),
      blendMode: AnyUtils.pickLerpNullable(a.blendMode, b.blendMode, t),
      isAntiAlias: AnyUtils.pickLerp(a.isAntiAlias, b.isAntiAlias, t),
    );
  }
}

/// Fill painted behind the side regions of an [AnyDecoration].
class AnyBackground with MAnyFill {
  /// Contour band used to build the background path.
  final AnyShapeBase shapeBase;

  /// Solid color used as the background base fill.
  @override
  final Color? color;

  /// Gradient used as the background base fill.
  @override
  final Gradient? gradient;

  /// Image painted into the background path.
  @override
  final DecorationImage? image;

  /// Blend mode applied to the background base fill.
  @override
  final BlendMode? blendMode;

  /// Whether the background path should be anti-aliased.
  @override
  final bool isAntiAlias;

  const AnyBackground({
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.isAntiAlias = true,
    this.shapeBase = AnyShapeBase.zeroBorder,
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
      blendMode: AnyUtils.pickLerpNullable(a.blendMode, b.blendMode, t),
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

abstract class AnyCorner {
  /// Corner extent along the previous side.
  final double p;

  /// Corner extent along the next side.
  final double n;

  const AnyCorner({
    this.p = 0.0,
    this.n = 0.0,
  });

  bool get isCircular => (p == n) || AnyUtils.nearZero(p - n);

  @protected
  bool canBuild(AnyContour contour, int cornerIndex) {
    return !contour.isCornerParallel(cornerIndex) &&
        p > AnyUtils.epsilon &&
        n > AnyUtils.epsilon &&
        contour.cornerSin[cornerIndex] > AnyUtils.epsilon;
  }

  @protected
  double turnSign(AnyContour contour, int cornerIndex) {
    return contour.cornerHandedness(cornerIndex);
  }

  @protected
  double resolvedPrevious(double maxPreviousExtent) {
    return p.isFinite ? math.max(0.0, p) : math.max(0.0, maxPreviousExtent);
  }

  @protected
  double resolvedNext(double maxNextExtent) {
    return n.isFinite ? math.max(0.0, n) : math.max(0.0, maxNextExtent);
  }

  AnyCorner resolveFinite(double maxPreviousExtent, double maxNextExtent);

  double consumptionForPreviousSide(AnyContour contour, int cornerIndex);

  double consumptionForNextSide(AnyContour contour, int cornerIndex);

  AnyCorner scaleForPreviousSide(double factor);

  AnyCorner scaleForNextSide(double factor);

  (double, double) pointAt(
    AnyContour contour,
    int cornerIndex,
    double dPrev,
    double dNext,
    double angle,
  );

  void appendArc(
    Path path,
    AnyContour contour,
    int cornerIndex,
    double dPrev,
    double dNext,
    double fromAngle,
    double toAngle,
  );

  AnyCorner lerpTo(AnyCorner other, double t);

  AnyCorner operator *(double factor);

  /// Creates an auto-derived inner/outer corner for the provided adjacent side insets.
  /// [insetP] = inset on previous side
  /// [insetN] = inset on next side
  /// [inner]  = convex/inner turn conversion
  /// [angle]  = local corner angle in radians
  AnyCorner convert(
    double insetP,
    double insetN,
    bool inner,
    double angle,
  );

  AnyCorner copyWith({double? p, double? n});

  static AnyCorner lerp(AnyCorner a, AnyCorner b, double t) {
    if (identical(a, b) || a == b) return a;
    if (t <= 0.0) return a;
    if (t >= 1.0) return b;
    return _LerpCorner(
      t: t,
      from: a,
      to: b,
    );
  }

  static AnyCorner lerpResolved(AnyCorner a, AnyCorner b, double t) {
    if (identical(a, b) || a == b) return a;

    if (t <= 0.0) return a;
    if (t >= 1.0) return b;

    if (a.runtimeType == b.runtimeType) {
      return a.lerpTo(b, t);
    }

    if (t < 0.5) {
      return a * ((0.5 - t) / 0.5);
    }

    return b * ((t - 0.5) / 0.5);
  }
}

class _LerpCorner extends AnyCorner {
  final double t;
  final AnyCorner from;
  final AnyCorner to;

  const _LerpCorner({
    required this.t,
    required this.from,
    required this.to,
  })  : assert(from is! _LerpCorner),
        assert(to is! _LerpCorner),
        super();

  Never _unsupported() {
    throw UnsupportedError(
      '_LerpCorner is a deferred corner and must be materialized in AnyContour._prepare().',
    );
  }

  @override
  AnyCorner resolveFinite(double maxPreviousExtent, double maxNextExtent) =>
      _unsupported();

  @override
  double consumptionForPreviousSide(AnyContour contour, int cornerIndex) =>
      _unsupported();

  @override
  double consumptionForNextSide(AnyContour contour, int cornerIndex) =>
      _unsupported();

  @override
  AnyCorner scaleForPreviousSide(double factor) => _unsupported();

  @override
  AnyCorner scaleForNextSide(double factor) => _unsupported();

  @override
  (double, double) pointAt(
    AnyContour contour,
    int cornerIndex,
    double dPrev,
    double dNext,
    double angle,
  ) =>
      _unsupported();

  @override
  void appendArc(
    Path path,
    AnyContour contour,
    int cornerIndex,
    double dPrev,
    double dNext,
    double fromAngle,
    double toAngle,
  ) =>
      _unsupported();

  @override
  AnyCorner lerpTo(AnyCorner other, double t) => _unsupported();

  @override
  AnyCorner operator *(double factor) => _unsupported();

  @override
  AnyCorner convert(
    double insetP,
    double insetN,
    bool inner,
    double angle,
  ) =>
      _unsupported();

  @override
  AnyCorner copyWith({double? p, double? n}) => _unsupported();

  @override
  bool operator ==(Object other) {
    return other is _LerpCorner &&
        other.t == t &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(runtimeType, t, from, to);
}

class RoundedCorner extends AnyCorner {
  final CornerConverter converter;

  const RoundedCorner({
    double radius = 0.0,
    this.converter = CornerConverter.base,
  }) : super(p: radius, n: radius);

  const RoundedCorner.elliptical({
    double p = 0.0,
    double n = 0.0,
    this.converter = CornerConverter.base,
  }) : super(p: p, n: n);

  const RoundedCorner.infinity({this.converter = CornerConverter.base})
      : super(p: double.infinity, n: double.infinity);

  @override
  RoundedCorner resolveFinite(double maxPreviousExtent, double maxNextExtent) {
    return copyWith(
      p: resolvedPrevious(maxPreviousExtent),
      n: resolvedNext(maxNextExtent),
    );
  }

  @override
  double consumptionForPreviousSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, p) / sinTurn;
  }

  @override
  double consumptionForNextSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, n) / sinTurn;
  }

  @override
  RoundedCorner scaleForPreviousSide(double factor) {
    return copyWith(p: p * factor);
  }

  @override
  RoundedCorner scaleForNextSide(double factor) {
    return copyWith(n: n * factor);
  }

  @override
  (double, double) pointAt(
    AnyContour contour,
    int cornerIndex,
    double dPrev,
    double dNext,
    double angle,
  ) {
    if (!canBuild(contour, cornerIndex)) {
      return contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
    }

    final sign = turnSign(contour, cornerIndex);
    final localN = sign * n;
    final localP = sign * p;

    final localX = dPrev + localN + localN * math.cos(angle);
    final localY = dNext + localP + localP * math.sin(angle);

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

    if (!canBuild(contour, cornerIndex)) {
      final (x, y) = contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
      path.lineTo(x, y);
      return;
    }

    final fraction = delta.abs() / AnyUtils.quarterSweepPi0d5;
    final baseSegments = contour.cornerSegments[cornerIndex];
    final segmentCount = math.max(1, (baseSegments * fraction).ceil());

    final sign = turnSign(contour, cornerIndex);
    final localN = sign * n;
    final localP = sign * p;

    final centerX = dPrev + localN;
    final centerY = dNext + localP;

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

      final p1x = centerX + localN * cos0 - alpha * localN * sin0;
      final p1y = centerY + localP * sin0 + alpha * localP * cos0;
      final p2x = centerX + localN * cos1 + alpha * localN * sin1;
      final p2y = centerY + localP * sin1 - alpha * localP * cos1;
      final p3x = centerX + localN * cos1;
      final p3y = centerY + localP * sin1;

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

    return RoundedCorner.elliptical(
      p: lerpDouble(p, other.p, t)!,
      n: lerpDouble(n, other.n, t)!,
      converter: AnyUtils.pickLerp(converter, other.converter, t),
    );
  }

  @override
  RoundedCorner operator *(double factor) {
    return copyWith(
      p: p * factor,
      n: n * factor,
    );
  }

  @override
  RoundedCorner convert(
      double insetP, double insetN, bool inner, double angle) {
    if (converter == CornerConverter.equal) return this;
    if (p <= 0.0 || n <= 0.0) return const RoundedCorner();

    return inner ? _innerCorner(insetP, insetN) : _outerCorner(insetP, insetN);
  }

  RoundedCorner _innerCorner(double insetP, double insetN) {
    final kp = AnyUtils.clamp01((p - insetP) / p);
    final kn = AnyUtils.clamp01((n - insetN) / n);
    final factor = math.min(kp, kn);

    return switch (converter) {
      CornerConverter.preserveRatio => copyWith(
          p: p * factor,
          n: n * factor,
        ),
      CornerConverter.dynamicRatio => copyWith(
          p: p * kp,
          n: n * kn,
        ),
      CornerConverter.equal => this,
    };
  }

  RoundedCorner _outerCorner(double insetP, double insetN) {
    final factor = math.max(
      (p + insetP) / p,
      (n + insetN) / n,
    );

    return switch (converter) {
      CornerConverter.dynamicRatio => copyWith(
          p: p + insetP,
          n: n + insetN,
        ),
      CornerConverter.preserveRatio => copyWith(
          p: p * factor,
          n: n * factor,
        ),
      CornerConverter.equal => this,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RoundedCorner &&
        other.p == p &&
        other.n == n &&
        other.converter == converter;
  }

  @override
  int get hashCode => Object.hash(runtimeType, p, n, converter);

  @override
  RoundedCorner copyWith({
    double? p,
    double? n,
    CornerConverter? converter,
  }) {
    return RoundedCorner.elliptical(
      p: p ?? this.p,
      n: n ?? this.n,
      converter: converter ?? this.converter,
    );
  }
}

class InverseRoundedCorner extends AnyCorner {
  const InverseRoundedCorner({
    double radius = 0.0,
  }) : super(p: radius, n: radius);

  const InverseRoundedCorner.elliptical({
    double p = 0.0,
    double n = 0.0,
  }) : super(p: p, n: n);

  double _localAngleFromCommon(double angle) => AnyUtils.endAnglePi1d5 - angle;

  @override
  InverseRoundedCorner resolveFinite(
    double maxPreviousExtent,
    double maxNextExtent,
  ) {
    return copyWith(
      p: resolvedPrevious(maxPreviousExtent),
      n: resolvedNext(maxNextExtent),
    );
  }

  @override
  double consumptionForPreviousSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, p) / sinTurn;
  }

  @override
  double consumptionForNextSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, n) / sinTurn;
  }

  @override
  InverseRoundedCorner scaleForPreviousSide(double factor) {
    return copyWith(p: p * factor);
  }

  @override
  InverseRoundedCorner scaleForNextSide(double factor) {
    return copyWith(n: n * factor);
  }

  @override
  (double, double) pointAt(
    AnyContour contour,
    int cornerIndex,
    double dPrev,
    double dNext,
    double angle,
  ) {
    if (!canBuild(contour, cornerIndex)) {
      return contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
    }

    final sign = turnSign(contour, cornerIndex);
    final localN = sign * n;
    final localP = sign * p;
    final localAngle = _localAngleFromCommon(angle);

    final localX = dPrev + localN * math.cos(localAngle);
    final localY = dNext + localP * math.sin(localAngle);

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

    if (!canBuild(contour, cornerIndex)) {
      final (x, y) = contour.sharpCornerPoint(cornerIndex, dPrev, dNext);
      path.lineTo(x, y);
      return;
    }

    final fraction = delta.abs() / AnyUtils.quarterSweepPi0d5;
    final baseSegments = contour.cornerSegments[cornerIndex];
    final segmentCount = math.max(1, (baseSegments * fraction).ceil());

    final sign = turnSign(contour, cornerIndex);
    final localN = sign * n;
    final localP = sign * p;

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

      final p1x = centerX + localN * cos0 - alpha * localN * sin0;
      final p1y = centerY + localP * sin0 + alpha * localP * cos0;
      final p2x = centerX + localN * cos1 + alpha * localN * sin1;
      final p2y = centerY + localP * sin1 - alpha * localP * cos1;
      final p3x = centerX + localN * cos1;
      final p3y = centerY + localP * sin1;

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

    return InverseRoundedCorner.elliptical(
      p: lerpDouble(p, other.p, t)!,
      n: lerpDouble(n, other.n, t)!,
    );
  }

  @override
  InverseRoundedCorner operator *(double factor) {
    return copyWith(
      p: p * factor,
      n: n * factor,
    );
  }

  @override
  InverseRoundedCorner convert(
    double insetP,
    double insetN,
    bool inner,
    double angle,
  ) {
    return this;
  }

  @override
  bool operator ==(Object other) {
    return other is InverseRoundedCorner && other.p == p && other.n == n;
  }

  @override
  int get hashCode => Object.hash(runtimeType, p, n);

  @override
  InverseRoundedCorner copyWith({
    double? p,
    double? n,
  }) {
    return InverseRoundedCorner.elliptical(
      p: p ?? this.p,
      n: n ?? this.n,
    );
  }
}

class BevelCorner extends AnyCorner {
  final CornerConverter converter;

  const BevelCorner({
    double radius = 0.0,
    this.converter = CornerConverter.base,
  }) : super(p: radius, n: radius);

  const BevelCorner.elliptical({
    double p = 0.0,
    double n = 0.0,
    this.converter = CornerConverter.base,
  }) : super(p: p, n: n);

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
    final sign = turnSign(contour, cornerIndex);
    return contour.worldPointFromDistanceSpace(
      cornerIndex,
      dPrev,
      dNext + sign * p,
    );
  }

  (double, double) _endPoint(
    AnyContour contour,
    int cornerIndex,
    double dPrev,
    double dNext,
  ) {
    final sign = turnSign(contour, cornerIndex);
    return contour.worldPointFromDistanceSpace(
      cornerIndex,
      dPrev + sign * n,
      dNext,
    );
  }

  @override
  BevelCorner resolveFinite(double maxPreviousExtent, double maxNextExtent) {
    return copyWith(
      p: resolvedPrevious(maxPreviousExtent),
      n: resolvedNext(maxNextExtent),
    );
  }

  @override
  double consumptionForPreviousSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, p) / sinTurn;
  }

  @override
  double consumptionForNextSide(AnyContour contour, int cornerIndex) {
    final sinTurn = contour.cornerSin[cornerIndex];
    if (sinTurn <= AnyUtils.epsilon) return 0.0;
    return math.max(0.0, n) / sinTurn;
  }

  @override
  BevelCorner scaleForPreviousSide(double factor) {
    return copyWith(p: p * factor);
  }

  @override
  BevelCorner scaleForNextSide(double factor) {
    return copyWith(n: n * factor);
  }

  @override
  (double, double) pointAt(
    AnyContour contour,
    int cornerIndex,
    double dPrev,
    double dNext,
    double angle,
  ) {
    if (!canBuild(contour, cornerIndex)) {
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

    if (!canBuild(contour, cornerIndex)) {
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

    return BevelCorner.elliptical(
      p: lerpDouble(p, other.p, t)!,
      n: lerpDouble(n, other.n, t)!,
      converter: AnyUtils.pickLerp(converter, other.converter, t),
    );
  }

  @override
  BevelCorner operator *(double factor) {
    return copyWith(
      p: p * factor,
      n: n * factor,
    );
  }

  @override
  BevelCorner convert(double insetP, double insetN, bool inner, double angle) {
    if (converter == CornerConverter.equal) return this;
    if (p <= 0.0 || n <= 0.0) return const BevelCorner();

    return switch (converter) {
      CornerConverter.dynamicRatio =>
        _convertedCorner(insetP, insetN, inner, angle, fixedRatio: false),
      CornerConverter.preserveRatio =>
        _convertedCorner(insetP, insetN, inner, angle, fixedRatio: true),
      CornerConverter.equal => this,
    };
  }

  BevelCorner _convertedCorner(
    double insetP,
    double insetN,
    bool inner,
    double angle, {
    required bool fixedRatio,
  }) {
    if (p <= AnyUtils.epsilon || n <= AnyUtils.epsilon) {
      return const BevelCorner();
    }

    final safeAngle = AnyUtils.clampDouble(
      angle.isFinite ? angle : math.pi / 2.0,
      AnyUtils.epsilon,
      math.pi - AnyUtils.epsilon,
    );

    final chordMetric = math.sqrt(
      math.max(
        0.0,
        n * n + p * p - 2.0 * n * p * math.cos(safeAngle),
      ),
    );

    if (chordMetric <= AnyUtils.epsilon) {
      return const BevelCorner();
    }

    final bevelNormalScale = chordMetric / (n * p);

    if (fixedRatio) {
      final blendedInset =
          ((insetP / p) + (insetN / n)) / ((1.0 / p) + (1.0 / n));

      final linearInset = (insetP / p) + (insetN / n);
      final normalShift = bevelNormalScale * blendedInset;

      final factor = inner
          ? (1.0 + normalShift - linearInset)
          : (1.0 - normalShift + linearInset);

      final safeFactor = math.max(0.0, factor);

      return copyWith(
        p: p * safeFactor,
        n: n * safeFactor,
      );
    }

    final linearInset = (insetP / p) + (insetN / n);

    final factorP = inner
        ? (1.0 + bevelNormalScale * insetP - linearInset)
        : (1.0 - bevelNormalScale * insetP + linearInset);

    final factorN = inner
        ? (1.0 + bevelNormalScale * insetN - linearInset)
        : (1.0 - bevelNormalScale * insetN + linearInset);

    return copyWith(
      p: math.max(0.0, p * factorP),
      n: math.max(0.0, n * factorN),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BevelCorner &&
        other.p == p &&
        other.n == n &&
        other.converter == converter;
  }

  @override
  int get hashCode => Object.hash(runtimeType, p, n, converter);

  @override
  BevelCorner copyWith({
    double? p,
    double? n,
    CornerConverter? converter,
  }) {
    return BevelCorner.elliptical(
      p: p ?? this.p,
      n: n ?? this.n,
      converter: converter ?? this.converter,
    );
  }
}

/// One source point in an [AnyDecoration] contour.
///
/// The point defines a vertex of the contour. Its [outer] and optional [inner]
/// corners describe how the contour bends at this point, while [side] describes
/// the border segment painted from this point to the next point.
class AnyPoint {
  /// Corner used for the outer contour band at this point.
  final AnyCorner outer;

  /// Optional corner used for the inner contour band at this point.
  ///
  /// When null, the decoration or contour derives an inner corner from [outer]
  /// and the adjacent side widths.
  final AnyCorner? inner;

  /// Vertex position in local decoration coordinates.
  final Offset point;

  /// Side painted from this point to the next contour point.
  final AnySide side;

  /// Creates a contour point with explicit geometry and side data.
  const AnyPoint({
    required this.outer,
    this.inner,
    required this.point,
    required this.side,
  });

  /// Linearly interpolates two point lists for [AnyDecorationTween].
  ///
  /// If the lists have different lengths, one list is picked based on [t]
  /// because point-by-point interpolation is not possible.
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
      background: background == null
          ? null
          : (background!.$1, background!.$2.shift(offset)),
      regions: regions
          .map((el) => (el.$1, el.$2.shift(offset)))
          .toList(growable: false),
    );
  }
}

class AnyContour {
  // Decoration options
  final AnyShapeBase shadowBase;
  final AnyShapeBase clipBase;
  final AnyShapeBase backgroundBase;
  final AnyFill? background;

  AnyContour({
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

  (double, double) sharpCornerPoint(
      int cornerIndex, double dPrev, double dNext) {
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

    final outerAvailableLengths =
        _availableLengthsForBase(AnyShapeBase.outerBorder);
    outerCorners = _resolveBand(outerCorners, outerAvailableLengths);
    _normalizeBand(outerCorners, outerAvailableLengths);

    zeroCorners = List<AnyCorner>.generate(count, (corner) {
      final prev = wrap(corner - 1);

      return outerCorners[corner].convert(
        sideOutsideOffset[prev],
        sideOutsideOffset[corner],
        cornerTurnSign[corner] > 0,
        cornerAngle[corner],
      );
    }, growable: false);
    final zeroAvailableLengths =
        _availableLengthsForBase(AnyShapeBase.zeroBorder);
    zeroCorners = _resolveBand(zeroCorners, zeroAvailableLengths);
    _normalizeBand(zeroCorners, zeroAvailableLengths);

    innerCorners = List<AnyCorner>.generate(count, (corner) {
      final prev = wrap(corner - 1);
      final explicitInner = explicitInnerCorners[corner];
      if (explicitInner != null) {
        return explicitInner;
      }

      return outerCorners[corner].convert(
        sideInsideOffset[prev] + sideOutsideOffset[prev],
        sideInsideOffset[corner] + sideOutsideOffset[corner],
        cornerTurnSign[corner] > 0,
        cornerAngle[corner],
      );
    }, growable: false);
    final innerAvailableLengths =
        _availableLengthsForBase(AnyShapeBase.innerBorder);
    innerCorners = _resolveBand(innerCorners, innerAvailableLengths);
    _normalizeBand(innerCorners, innerAvailableLengths);
  }

  List<double> _availableLengthsForBase(AnyShapeBase base) {
    return List<double>.generate(count, (side) {
      final startCorner = side;
      final endCorner = wrap(side + 1);

      final startPrev = offsetForBase(wrap(startCorner - 1), base);
      final startNext = offsetForBase(startCorner, base);
      final endPrev = offsetForBase(side, base);
      final endNext = offsetForBase(endCorner, base);

      final (sx, sy) = sharpCornerPoint(startCorner, startPrev, startNext);
      final (ex, ey) = sharpCornerPoint(endCorner, endPrev, endNext);

      return math.sqrt(
        ((ex - sx) * (ex - sx)) + ((ey - sy) * (ey - sy)),
      );
    }, growable: false);
  }

  List<AnyCorner> _resolveBand(
    List<AnyCorner> corners,
    List<double> availableSideLengths,
  ) {
    var hasLerpCorner = false;
    for (final corner in corners) {
      if (corner is _LerpCorner) {
        hasLerpCorner = true;
        break;
      }
    }

    if (!hasLerpCorner) {
      return _normalizeConcreteBand(corners, availableSideLengths);
    }

    final fromCorners = List<AnyCorner>.generate(count, (index) {
      final corner = corners[index];
      return corner is _LerpCorner ? corner.from : corner;
    }, growable: false);

    final toCorners = List<AnyCorner>.generate(count, (index) {
      final corner = corners[index];
      return corner is _LerpCorner ? corner.to : corner;
    }, growable: false);

    final resolvedFrom = _resolveBand(fromCorners, availableSideLengths);
    final resolvedTo = _resolveBand(toCorners, availableSideLengths);

    return List<AnyCorner>.generate(count, (index) {
      final source = corners[index];
      if (source is _LerpCorner) {
        return AnyCorner.lerpResolved(
          resolvedFrom[index],
          resolvedTo[index],
          source.t,
        );
      }
      return resolvedFrom[index];
    }, growable: false);
  }

  List<AnyCorner> _normalizeConcreteBand(
    List<AnyCorner> corners,
    List<double> availableSideLengths,
  ) {
    bool needsNormalization() {
      for (var side = 0; side < count; side++) {
        final start = corners[side];
        final end = corners[wrap(side + 1)];
        final available = availableSideLengths[side];

        final a = start.n;
        final b = end.p;

        if (!a.isFinite || !b.isFinite) return true;
        if (a < 0.0 || b < 0.0) return true;
        if (a + b > available + AnyUtils.epsilon) return true;
      }
      return false;
    }

    if (!needsNormalization()) {
      return corners;
    }

    (double, double)? ratioBasis(AnyCorner corner) {
      if (corner.isCircular) {
        return (1.0, 1.0);
      }

      final p = corner.p;
      final n = corner.n;
      if (p.isFinite && n.isFinite) {
        final safeP = math.max(0.0, p);
        final safeN = math.max(0.0, n);
        if (safeP > AnyUtils.epsilon && safeN > AnyUtils.epsilon) {
          return (safeP, safeN);
        }
      }

      return null;
    }

    final resolvedP = List<double>.generate(count, (index) => corners[index].p,
        growable: false);
    final resolvedN = List<double>.generate(count, (index) => corners[index].n,
        growable: false);

    for (var side = 0; side < count; side++) {
      final startCorner = side;
      final endCorner = wrap(side + 1);

      final (newStartN, newEndP) = _normalizeSharedSideValues(
        fromPreviousCorner: corners[startCorner].n,
        fromCurrentCorner: corners[endCorner].p,
        sideLength: availableSideLengths[side],
      );

      resolvedN[startCorner] = newStartN;
      resolvedP[endCorner] = newEndP;
    }

    return List<AnyCorner>.generate(count, (index) {
      final original = corners[index];

      final safeP = resolvedP[index].isFinite
          ? math.max(0.0, resolvedP[index])
          : resolvedP[index];
      final safeN = resolvedN[index].isFinite
          ? math.max(0.0, resolvedN[index])
          : resolvedN[index];

      final basis = ratioBasis(original);
      if (basis == null || !safeP.isFinite || !safeN.isFinite) {
        return original.copyWith(p: safeP, n: safeN);
      }

      final (basisP, basisN) = basis;
      if (basisP <= AnyUtils.epsilon || basisN <= AnyUtils.epsilon) {
        return original.copyWith(p: safeP, n: safeN);
      }

      final factor = math.min(safeP / basisP, safeN / basisN);
      if (!factor.isFinite || factor < 0.0) {
        return original.copyWith(p: safeP, n: safeN);
      }

      return original.copyWith(
        p: basisP * factor,
        n: basisN * factor,
      );
    }, growable: false);
  }

  (double, double) _normalizeSharedSideValues({
    required double fromPreviousCorner,
    required double fromCurrentCorner,
    required double sideLength,
  }) {
    final length = math.max(0.0, sideLength);

    final a = fromPreviousCorner.isFinite
        ? math.max(0.0, fromPreviousCorner)
        : double.infinity;

    final b = fromCurrentCorner.isFinite
        ? math.max(0.0, fromCurrentCorner)
        : double.infinity;

    if (!a.isFinite && !b.isFinite) {
      final half = length / 2.0;
      return (half, half);
    }

    if (a.isFinite && !b.isFinite) {
      return (a, math.max(0.0, length - a));
    }

    if (!a.isFinite && b.isFinite) {
      return (math.max(0.0, length - b), b);
    }

    final total = a + b;
    if (total > length + AnyUtils.epsilon && total > AnyUtils.epsilon) {
      final t = a / total;
      return (length * t, length * (1.0 - t));
    }

    return (a, b);
  }

  void _normalizeBand(
    List<AnyCorner> corners,
    List<double> availableSideLengths,
  ) {
    for (var side = 0; side < count; side++) {
      final startCorner = side;
      final endCorner = wrap(side + 1);

      final startConsumption =
          corners[startCorner].consumptionForNextSide(this, startCorner);
      final endConsumption =
          corners[endCorner].consumptionForPreviousSide(this, endCorner);
      final total = startConsumption + endConsumption;

      if (total <= availableSideLengths[side] + AnyUtils.epsilon ||
          total <= AnyUtils.epsilon) {
        continue;
      }

      final scale = availableSideLengths[side] / total;
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

    final startOuterFrom =
        prevHasWidth ? AnyUtils.midAngle1d25 : AnyUtils.startAnglePi1d;
    final endOuterTo =
        nextHasWidth ? AnyUtils.midAngle1d25 : AnyUtils.endAnglePi1d5;
    final endInnerFrom =
        nextHasWidth ? AnyUtils.midAngle1d25 : AnyUtils.endAnglePi1d5;
    final startInnerTo =
        prevHasWidth ? AnyUtils.midAngle1d25 : AnyUtils.startAnglePi1d;

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

/// Base class for borders built for [AnyDecoration].
class AnyBorder {
  /// Default side used by [point] when no point-specific side is provided.
  final AnySide sides;

  /// Default outer corner used by [point] when no point-specific corner is provided.
  final AnyCorner corners;

  /// Default inner corner used by [point] when no point-specific corner is provided.
  final AnyCorner? innerCorners;

  /// Optional width / height ratio used to fit the contour inside the paint size.
  final double? ratio;

  const AnyBorder({
    AnySide? sides,
    AnyCorner? corners,
    this.innerCorners,
    this.ratio,
  })  : sides = sides ?? const AnySide(),
        corners = corners ?? const RoundedCorner();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyBorder &&
        other.runtimeType == runtimeType &&
        other.ratio == ratio &&
        other.sides == sides &&
        other.corners == corners &&
        other.innerCorners == innerCorners;
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        ratio,
        sides,
        corners,
        innerCorners,
      );
}

/// Base class for decorations built from arbitrary contour points.
///
/// Subclasses define their geometry by overriding [buildPoints]. They must also
/// override [operator ==] and [hashCode] when they add fields, because contour
/// caching is keyed by decoration equality.
abstract class AnyDecoration extends Decoration {
  /// Build raw contour points in local coordinates for this size.
  @protected
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection);

  @nonVirtual
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection) {
    return buildPoints(bounds, textDirection);
  }

  /// Fill painted behind side regions.
  final AnyBackground? background;

  /// Border defaults used by [point] when no point-specific values are provided.
  final AnyBorder border;

  /// Shadows painted from [shadowBase].
  final List<AnyShadow> shadows;

  /// Contour band returned by [getClipPath].
  final AnyShapeBase clipBase;

  /// Contour band used as the source path for shadows.
  final AnyShapeBase shadowBase;

  /// Whether built contours should be cached by decoration, size, and text direction.
  final bool enableCache;

  const AnyDecoration({
    this.shadows = const [],
    this.background,
    this.clipBase = AnyShapeBase.zeroBorder,
    this.shadowBase = AnyShapeBase.zeroBorder,
    this.enableCache = true,
    this.border = const AnyBorder(),
  });

  /// Builds an [AnyPoint] using decoration defaults for missing values.
  AnyPoint point(
    Offset point, {
    AnyCorner? outer,
    AnyCorner? inner,
    AnySide? side,
  }) {
    return AnyPoint(
      point: point,
      outer: outer ?? border.corners,
      inner: inner ?? border.innerCorners,
      side: side ?? border.sides,
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
    late final AnyDecorationCacheKey key;
    if (enableCache) {
      key = (this, size, textDirection);
      final cached = AnyDecorationCache.get(key);
      if (cached != null) {
        return cached;
      }
    }

    final bounds = fitRatio(size, border.ratio);

    final contour = AnyContour(
      points: points(bounds, textDirection),
      background: background,
      backgroundBase: background?.shapeBase ?? AnyShapeBase.zeroBorder,
      clipBase: clipBase,
      shadowBase: shadowBase,
    );

    if (enableCache) {
      AnyDecorationCache.put(key, contour);
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
        other.runtimeType == runtimeType &&
        other.shadowBase == shadowBase &&
        other.clipBase == clipBase &&
        other.enableCache == enableCache &&
        other.background == background &&
        other.border == border &&
        listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        clipBase,
        shadowBase,
        enableCache,
        background,
        border,
        Object.hashAll(shadows),
      );
}

class _AnyDecorationPainter extends BoxPainter {
  _AnyDecorationPainter(this.decoration, super.onChanged);

  final AnyDecoration decoration;
  final Map<DecorationImage, DecorationImagePainter> _imagePainters =
      <DecorationImage, DecorationImagePainter>{};

  DecorationImagePainter? painterOf(AnyFill fill) {
    if (fill.image == null) return null;
    return _imagePainters.putIfAbsent(
      fill.image!,
      () => fill.image!.createPainter(onChanged!),
    );
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
    final imagePainter = painterOf(fill);
    if (imagePainter != null) {
      imagePainter.paint(canvas, path.getBounds(), path, configuration);
    }

    final paint = fill.createBasePaint(path, configuration);
    if (paint != null) {
      canvas.drawPath(path, paint);
    }
  }
}
