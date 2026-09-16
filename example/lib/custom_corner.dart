import 'dart:ui';
import 'package:any_borders/any_borders.dart';

/// A two-segment corner. p/n are edge contact lengths; bend controls the
/// intermediate point, with 0.5 producing a straight bevel.
class NotchCorner extends AnyCorner {
  final double bend;
  const NotchCorner({super.p = 20, super.n = 20, this.bend = 1 / 3})
      : assert(bend > 0 && bend <= 0.5);

  @override
  AnyCornerGeometry get geometry => const NotchCornerGeometry();

  @override
  NotchCorner copyWith({double? p, double? n, double? bend}) =>
      NotchCorner(p: p ?? this.p, n: n ?? this.n, bend: bend ?? this.bend);

  @override
  NotchCorner lerpTo(covariant NotchCorner other, double t) => copyWith(
      p: lerpDouble(p, other.p, t),
      n: lerpDouble(n, other.n, t),
      bend: lerpDouble(bend, other.bend, t));

  @override
  bool operator ==(Object other) =>
      other is NotchCorner &&
      other.runtimeType == runtimeType &&
      other.p == p &&
      other.n == n &&
      other.bend == bend;
  @override
  int get hashCode => Object.hash(runtimeType, p, n, bend);
}

/// Uses only public contracts. No engine registration or changes are needed.
class NotchCornerGeometry extends AnyCornerGeometry {
  const NotchCornerGeometry();

  @override
  AnyCornerTraits traitsFor(
          AnyCorner source, AnyCorner? parameters, double? radius) =>
      source.p == 0 && source.n == 0
          ? AnyCornerTraits.sharpDirect
          : AnyCornerTraits.direct;

  @override
  AnyResolvedCorner resolve(AnyCorner settings, AnyCornerFrame frame) {
    final corner = settings as NotchCorner;
    final sharp = resolveDegenerate(corner, frame);
    if (sharp != null) return sharp;
    final previous = frame.previousRay * corner.p;
    final next = frame.nextRay * corner.n;
    final middle = frame.vertex + (previous + next) * corner.bend;
    return resolved(
        corner,
        frame,
        [
          AnyCornerSegment.line(frame.vertex + previous, middle, to: 0.5),
          AnyCornerSegment.line(middle, frame.vertex + next, from: 0.5),
        ],
        parameters: corner);
  }

  /// This example keeps cut lengths at the shifted side intersection. It is an
  /// authored boundary policy, not a constant-distance offset of the notch.
  @override
  AnyResolvedCorner buildBoundary(
          AnyResolvedCorner source,
          AnyCorner parameters,
          AnyCornerFrame shifted,
          double previousDistance,
          double nextDistance) =>
      parameters.geometry.resolve(parameters, shifted);
}
