import 'dart:math' as math;
import 'dart:ui';
import '../../any_utils.dart';
import '../geometry/core.dart';
import '../geometry/math.dart';
import 'corner_converter.dart';

/// A circular fillet when p == n, including at non-right-angle vertices.
/// Elliptical settings scale the two rays of the unit circular fillet.
class RoundedCorner extends AnyCorner {
  final CornerConverter converter;
  const RoundedCorner(
      {double radius = 0, this.converter = CornerConverter.base})
      : super(p: radius, n: radius);
  const RoundedCorner.elliptical(
      {super.p = 0, super.n = 0, this.converter = CornerConverter.base});
  const RoundedCorner.infinity({this.converter = CornerConverter.base})
      : super(p: double.infinity, n: double.infinity);
  @override
  AnyCornerGeometry get geometry => const RoundedCornerGeometry();

  @override
  RoundedCorner copyWith({double? p, double? n, CornerConverter? converter}) =>
      RoundedCorner.elliptical(
          p: p ?? this.p,
          n: n ?? this.n,
          converter: converter ?? this.converter);
  @override
  RoundedCorner lerpTo(covariant RoundedCorner other, double t) => copyWith(
      p: lerpDouble(p, other.p, t),
      n: lerpDouble(n, other.n, t),
      converter: AnyUtils.pickLerp(converter, other.converter, t));
  @override
  bool operator ==(Object other) =>
      other is RoundedCorner &&
      p == other.p &&
      n == other.n &&
      converter == other.converter;
  @override
  int get hashCode => Object.hash(runtimeType, p, n, converter);
}

/// Geometry implementation for [RoundedCorner].
class RoundedCornerGeometry extends AnyCornerGeometry {
  const RoundedCornerGeometry();

  @override
  AnyCornerTransition? prepareTransition(
      AnyResolvedCorner from, AnyResolvedCorner to) {
    // Only exact built-in descriptors opt into this shortcut. Custom providers
    // can supply their own transition; derived non-descriptor curves use the
    // shared canonical segment route.
    final a = from.parameters, b = to.parameters;
    if (from.source.runtimeType != RoundedCorner ||
        to.source.runtimeType != RoundedCorner ||
        a?.runtimeType != RoundedCorner ||
        b?.runtimeType != RoundedCorner) return null;
    return parameterTransition(a!, b!);
  }

  @override
  double contactScale(AnyCorner corner, AnyCornerFrame frame) =>
      frame.cotangentHalfAngle;
  @override
  bool get retainsSingleZeroExtent => false;

  @override
  AnyCornerTraits traitsFor(
      AnyCorner source, AnyCorner? parameters, double? radius) {
    if (source.runtimeType != RoundedCorner) return AnyCornerTraits.none;
    // The usual source/parameter pair is owned by this provider. Keep that
    // constant result local, without another provider dispatch per curve.
    if (parameters?.runtimeType == RoundedCorner) {
      return source.p == 0 && source.n == 0
          ? AnyCornerTraits.sharpRectangle
          : AnyCornerTraits.rectangle;
    }
    final direct = parameters != null || radius != null && radius > 0;
    if (!direct) return AnyCornerTraits.none;
    final sharp = source.p == 0 && source.n == 0;
    final rectangle = parameters != null &&
        parameters.geometry.isRectangularDescriptor(parameters);
    return rectangle
        ? (sharp ? AnyCornerTraits.sharpRectangle : AnyCornerTraits.rectangle)
        : (sharp ? AnyCornerTraits.sharpDirect : AnyCornerTraits.direct);
  }

  @override
  AnyResolvedCorner resolve(AnyCorner settings, AnyCornerFrame frame) {
    final corner = settings as RoundedCorner;
    final sharp = resolveDegenerate(corner, frame);
    if (sharp != null) return sharp;
    final u = frame.previousRay,
        v = frame.nextRay,
        p = math.max(0.0, corner.p),
        n = math.max(0.0, corner.n);
    final centerUnit = (u + v) / geometryCross(u, v).abs();
    final startUnit = u * frame.cotangentHalfAngle - centerUnit;
    final endUnit = v * frame.cotangentHalfAngle - centerUnit;
    final startAngle = math.atan2(startUnit.dy, startUnit.dx);
    final sweep = geometryAngle(startUnit, endUnit);
    final center = frame.vertex + frame.affine(centerUnit, p, n);
    final contact = frame.cotangentHalfAngle;
    final curve = AnyCornerCurve((t) {
      if (t == 0) return frame.vertex + u * (p * contact);
      if (t == 1) return frame.vertex + v * (n * contact);
      final a = startAngle + sweep * t;
      return center + frame.affine(Offset(math.cos(a), math.sin(a)), p, n);
    }, (t) {
      final a = startAngle + sweep * t;
      final derivative =
          frame.affine(Offset(-math.sin(a), math.cos(a)), p, n) * sweep;
      if (t == 0) return -u * derivative.distance;
      if (t == 1) return v * derivative.distance;
      return derivative;
    });
    final extent = math.max(p, n) * math.max(1, frame.cotangentHalfAngle);
    final tolerance = math.max(0.001, 1e-7 * extent);
    return resolved(corner, frame,
        directArc(curve, sweep, frame.affineStretch(p, n), tolerance),
        parameters: corner,
        center: center,
        circleRadius: p == n ? p : null,
        geometryState: null,
        tolerance: tolerance);
  }

  @override
  bool isRectangularDescriptor(AnyCorner corner) =>
      corner.runtimeType == RoundedCorner;

  @override
  AnyResolvedCorner buildBoundary(AnyResolvedCorner source, AnyCorner settings,
      AnyCornerFrame shifted, double dp, double dn) {
    final corner = settings as RoundedCorner;
    final frame = source.frame;
    final converter = corner.converter;
    var p = _grow(corner.p, -frame.convexity * dn);
    var n = _grow(corner.n, -frame.convexity * dp);
    if (converter == CornerConverter.equal) {
      p = corner.p;
      n = corner.n;
    }
    if (converter == CornerConverter.preserveRatio &&
        corner.p > 0 &&
        corner.n > 0) {
      final kp = p / corner.p, kn = n / corner.n;
      final k = frame.convexity * (dp + dn) >= 0
          ? math.min(kp, kn)
          : math.max(kp, kn);
      p = corner.p * k;
      n = corner.n * k;
    }
    final c = corner.copyWith(p: p, n: n);
    final boundary = c.geometry.resolve(c, shifted);
    return resolved(source.source, shifted, boundary.segments,
        parameters: boundary.parameters,
        center: boundary.center,
        circleRadius: boundary.circleRadius,
        tolerance: boundary.tolerance);
  }
}

double _grow(double r, double distance) {
  if (distance <= 0) return math.max(0, r + distance);
  if (r >= distance) return r + distance;
  final q = r / distance - 1;
  return r + distance * (1 + q * q * q);
}
