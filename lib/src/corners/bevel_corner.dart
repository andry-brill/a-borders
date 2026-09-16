import 'dart:math' as math;
import 'dart:ui';
import '../../any_utils.dart';
import '../geometry/core.dart';
import '../geometry/math.dart';
import 'corner_converter.dart';

/// A straight cut with endpoints p/n units along the previous/next edge rays.
class BevelCorner extends AnyCorner {
  final CornerConverter converter;
  const BevelCorner({double radius = 0, this.converter = CornerConverter.base})
      : super(p: radius, n: radius);
  const BevelCorner.elliptical(
      {super.p = 0, super.n = 0, this.converter = CornerConverter.base});
  @override
  AnyCornerGeometry get geometry => const BevelCornerGeometry();

  @override
  BevelCorner copyWith({double? p, double? n, CornerConverter? converter}) =>
      BevelCorner.elliptical(
          p: p ?? this.p,
          n: n ?? this.n,
          converter: converter ?? this.converter);
  @override
  BevelCorner lerpTo(covariant BevelCorner other, double t) => copyWith(
      p: lerpDouble(p, other.p, t),
      n: lerpDouble(n, other.n, t),
      converter: AnyUtils.pickLerp(converter, other.converter, t));
  @override
  bool operator ==(Object other) =>
      other is BevelCorner &&
      p == other.p &&
      n == other.n &&
      converter == other.converter;
  @override
  int get hashCode => Object.hash(runtimeType, p, n, converter);
}

/// Geometry implementation for [BevelCorner].
class BevelCornerGeometry extends AnyCornerGeometry {
  const BevelCornerGeometry();

  @override
  AnyCornerTransition? prepareTransition(
      AnyResolvedCorner from, AnyResolvedCorner to) {
    // Only exact built-in descriptors opt into this shortcut. Custom providers
    // can supply their own transition; derived non-descriptor curves use the
    // shared canonical segment route.
    final a = from.parameters, b = to.parameters;
    if (from.source.runtimeType != BevelCorner ||
        to.source.runtimeType != BevelCorner ||
        a?.runtimeType != BevelCorner ||
        b?.runtimeType != BevelCorner) return null;
    return parameterTransition(a!, b!);
  }

  @override
  double contactScale(AnyCorner corner, AnyCornerFrame frame) => 1;
  @override
  bool get retainsSingleZeroExtent => true;

  @override
  AnyCornerTraits traitsFor(
      AnyCorner source, AnyCorner? parameters, double? radius) {
    if (source.runtimeType != BevelCorner) return AnyCornerTraits.none;
    if (parameters?.runtimeType == BevelCorner) {
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
    final corner = settings as BevelCorner;
    final sharp = resolveDegenerate(corner, frame);
    if (sharp != null) return sharp;
    final u = frame.previousRay,
        v = frame.nextRay,
        p = math.max(0.0, corner.p),
        n = math.max(0.0, corner.n);
    return resolved(corner, frame,
        [AnyCornerSegment.line(frame.vertex + u * p, frame.vertex + v * n)],
        parameters: corner);
  }

  @override
  bool isRectangularDescriptor(AnyCorner corner) =>
      corner.runtimeType == BevelCorner;

  @override
  AnyResolvedCorner buildBoundary(AnyResolvedCorner source, AnyCorner settings,
      AnyCornerFrame shifted, double dp, double dn) {
    final corner = settings as BevelCorner;
    final frame = source.frame;
    if (corner.converter == CornerConverter.equal ||
        corner.p <= 0 ||
        corner.n <= 0) {
      return corner.geometry.resolve(corner, shifted);
    }
    final normal =
        geometryUnit(geometryLeft(source.end - source.start)) * frame.winding;
    final constant = geometryDot(normal, source.start - frame.vertex);
    var prevDistance = dp, nextDistance = dn;
    if (corner.converter == CornerConverter.preserveRatio) {
      prevDistance = nextDistance =
          (dp / corner.n + dn / corner.p) / (1 / corner.n + 1 / corner.p);
    }
    final origin = shifted.vertex - frame.vertex;
    final p = (constant + prevDistance - geometryDot(normal, origin)) /
        geometryDot(normal, frame.previousRay);
    final n = (constant + nextDistance - geometryDot(normal, origin)) /
        geometryDot(normal, frame.nextRay);
    final params = corner.copyWith(p: math.max(0, p), n: math.max(0, n));
    return resolved(
        source.source,
        shifted,
        [
          AnyCornerSegment.line(
              shifted.vertex + frame.previousRay * math.max(0, p),
              shifted.vertex + frame.nextRay * math.max(0, n))
        ],
        parameters: params);
  }
}
