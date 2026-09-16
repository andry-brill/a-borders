import 'dart:math' as math;
import 'dart:ui';
import '../geometry/core.dart';
import '../geometry/math.dart';

/// A scoop centered at the vertex; p/n are its radii along the incident rays.
/// Automatic boundaries offset the source curve along its material normal,
/// retaining the shape vertex as their reference center. Equal side distances
/// give concentric circular arcs: outside shrinks the radius; inside grows it.
/// Elliptical offsets need not be ellipses. Side contacts are trimmed or joined
/// by straight tangent extensions, without auxiliary rounded joins.
/// Explicit inner/outer descriptors instead resolve at their own side vertex.
class InverseRoundedCorner extends AnyCorner {
  const InverseRoundedCorner({double radius = 0}) : super(p: radius, n: radius);
  const InverseRoundedCorner.elliptical({super.p = 0, super.n = 0});
  @override
  AnyCornerGeometry get geometry => const InverseRoundedCornerGeometry();

  @override
  InverseRoundedCorner copyWith({double? p, double? n}) =>
      InverseRoundedCorner.elliptical(p: p ?? this.p, n: n ?? this.n);
  @override
  InverseRoundedCorner lerpTo(covariant InverseRoundedCorner other, double t) =>
      copyWith(p: lerpDouble(p, other.p, t), n: lerpDouble(n, other.n, t));
  @override
  bool operator ==(Object other) =>
      other is InverseRoundedCorner && p == other.p && n == other.n;
  @override
  int get hashCode => Object.hash(runtimeType, p, n);
}

/// Geometry implementation for [InverseRoundedCorner].
class InverseRoundedCornerGeometry extends AnyCornerGeometry {
  const InverseRoundedCornerGeometry();

  @override
  double contactScale(AnyCorner corner, AnyCornerFrame frame) => 1;
  @override
  bool get retainsSingleZeroExtent => false;

  @override
  AnyCornerTraits traitsFor(
      AnyCorner source, AnyCorner? parameters, double? radius) {
    if (source.runtimeType != InverseRoundedCorner) return AnyCornerTraits.none;
    final direct = parameters != null || radius != null && radius > 0;
    if (!direct) return AnyCornerTraits.none;
    final sharp = source.p == 0 && source.n == 0;
    return sharp ? AnyCornerTraits.sharpDirect : AnyCornerTraits.direct;
  }

  @override
  AnyResolvedCorner resolve(AnyCorner settings, AnyCornerFrame frame) {
    final corner = settings as InverseRoundedCorner;
    final sharp = resolveDegenerate(corner, frame);
    if (sharp != null) return sharp;
    final u = frame.previousRay,
        v = frame.nextRay,
        p = math.max(0.0, corner.p),
        n = math.max(0.0, corner.n);
    const centerUnit = Offset.zero;
    final startUnit = u;
    final endUnit = v;
    final startAngle = math.atan2(startUnit.dy, startUnit.dx);
    final sweep = geometryAngle(startUnit, endUnit);
    final center = frame.vertex + frame.affine(centerUnit, p, n);
    const contact = 1.0;
    final curve = AnyCornerCurve((t) {
      if (t == 0) return frame.vertex + u * (p * contact);
      if (t == 1) return frame.vertex + v * (n * contact);
      final a = startAngle + sweep * t;
      return center + frame.affine(Offset(math.cos(a), math.sin(a)), p, n);
    }, (t) {
      final a = startAngle + sweep * t;
      final derivative =
          frame.affine(Offset(-math.sin(a), math.cos(a)), p, n) * sweep;
      if (t == 0) return frame.affine(geometryLeft(u), p, n) * sweep;
      if (t == 1) return frame.affine(geometryLeft(v), p, n) * sweep;
      return derivative;
    });
    final extent = math.max(p, n) * math.max(1, frame.cotangentHalfAngle);
    final tolerance = math.max(0.001, 1e-7 * extent);
    return resolved(corner, frame,
        directArc(curve, sweep, frame.affineStretch(p, n), tolerance),
        parameters: corner,
        center: center,
        circleRadius: p == n ? p : null,
        geometryState: _ScoopOffset(corner, frame, 0, 0),
        tolerance: tolerance);
  }

  @override
  AnyResolvedCorner resolveZeroBoundary(AnyResolvedCorner outer,
      {required double previousDistance, required double nextDistance}) {
    if (outer.geometryState is _ScoopOffset) {
      return outer.source.geometry.resolveBoundary(outer,
          previousDistance: previousDistance, nextDistance: nextDistance);
    }
    return super.resolveZeroBoundary(outer,
        previousDistance: previousDistance, nextDistance: nextDistance);
  }

  @override
  AnyResolvedCorner buildBoundary(AnyResolvedCorner source, AnyCorner settings,
          AnyCornerFrame shifted, double dp, double dn) =>
      _resolveScoopBoundary(source, dp, dn);

  AnyResolvedCorner _resolveScoopBoundary(
      AnyResolvedCorner source, double dp, double dn) {
    final corner = source.source as InverseRoundedCorner;
    final shifted = source.frame.shifted(dp, dn);
    if (corner.p <= 0 || corner.n <= 0)
      return corner.geometry.resolve(corner, shifted);
    final previous = (source.geometryState as _ScoopOffset?) ??
        _ScoopOffset(corner, source.frame, 0, 0);
    final offset = _ScoopOffset(previous.corner, previous.frame,
        previous.previousDistance + dp, previous.nextDistance + dn);
    if (offset.previousDistance == 0 && offset.nextDistance == 0) {
      return offset.corner.geometry.resolve(offset.corner, offset.frame);
    }
    final f = offset.frame;
    final circle = offset.corner.p == offset.corner.n &&
        offset.previousDistance == offset.nextDistance;
    final radius =
        circle ? offset.corner.p + f.convexity * offset.previousDistance : null;
    final extent = math.max(offset.corner.p, offset.corner.n) +
        math.max(offset.previousDistance.abs(), offset.nextDistance.abs());
    final tolerance = math.max(0.001, 1e-7 * extent);

    // Restrict the arc to the shifted side wedge and to forward-moving portions
    // of its normal offset. Negative speed is a folded offset beyond a cusp.
    double validity(double t) {
      final (point, _, forward) = offset.at(t);
      return math.min(
          forward,
          math.min(
              f.convexity *
                  geometryDot(point - shifted.vertex, f.previousNormal) /
                  extent,
              f.convexity *
                  geometryDot(point - shifted.vertex, f.nextNormal) /
                  extent));
    }

    final intervals = <(double, double)>[];
    if (radius != null && radius > 0) {
      // Analytic line/circle intersections avoid sampling away a tiny surviving
      // arc immediately before the shifted sides meet it at the bisector.
      final ratio = f.convexity * offset.previousDistance / radius;
      if (ratio <= 0) {
        intervals.add((0, 1));
      } else if (ratio < 1) {
        final margin = math.asin(ratio) / f.angle;
        if (margin < 0.5) intervals.add((margin, 1 - margin));
      }
    } else if (radius == null) {
      // Elliptical/variable-width offsets can develop endpoint cusps;
      // bracket and bisect those separately.
      const samples = 64;
      final probes = [for (var i = 0; i <= samples; i++) i / samples];
      // Near inward disappearance the surviving interval surrounds the point
      // equidistant from the shifted sides, which need not be on the sample grid.
      // Locate that point explicitly so a thin valid arc is not discarded.
      double balance(double t) => geometryDot(
          offset.at(t).$1 - shifted.vertex, f.previousNormal - f.nextNormal);
      var previousBalance = balance(0);
      for (var i = 1; i <= samples; i++) {
        final nextBalance = balance(i / samples);
        if (previousBalance * nextBalance < 0) {
          var lo = (i - 1) / samples, hi = i / samples;
          for (var step = 0; step < 42; step++) {
            final mid = (lo + hi) / 2;
            if (balance(mid) * previousBalance > 0) {
              lo = mid;
            } else {
              hi = mid;
            }
          }
          probes.add((lo + hi) / 2);
        }
        previousBalance = nextBalance;
      }
      probes.sort();
      var start = validity(0) >= -1e-12 ? 0.0 : null;
      var lastValid = start != null;
      for (var i = 1; i < probes.length; i++) {
        final t = probes[i], valid = validity(t) >= -1e-12;
        if (valid != lastValid) {
          var lo = probes[i - 1], hi = t;
          for (var step = 0; step < 42; step++) {
            final mid = (lo + hi) / 2;
            if ((validity(mid) >= -1e-12) == lastValid) {
              lo = mid;
            } else {
              hi = mid;
            }
          }
          final root = (lo + hi) / 2;
          if (valid) {
            start = root;
          } else if (start != null) {
            intervals.add((start, root));
            start = null;
          }
        }
        lastValid = valid;
      }
      if (start != null) intervals.add((start, 1));
    }
    final pieces = <AnyCornerSegment>[];
    for (final (a, b) in intervals) {
      if (b - a <= 1e-10) continue;
      final curve = AnyCornerCurve((t) => offset.at(a + (b - a) * t).$1,
          (t) => offset.at(a + (b - a) * t).$2 * (b - a));
      final arc = radius == null
          ? fitCurve(curve, tolerance)
          : directArc(curve, offset.sweep * (b - a), radius.abs(), tolerance);
      if (pieces.isNotEmpty)
        pieces.add(AnyCornerSegment.line(pieces.last.end, arc.first.start));
      pieces.addAll(arc);
    }
    if (pieces.isNotEmpty) {
      final a = pieces.first.start, b = pieces.last.end;
      final aTangent = offset.sourceAt(intervals.first.$1).$2;
      final bTangent = offset.sourceAt(intervals.last.$2).$2;
      final first =
          geometryLineMeeting(shifted.vertex, f.previousRay, a, aTangent, a);
      final last =
          geometryLineMeeting(shifted.vertex, f.nextRay, b, bTangent, b);
      if ((first - a).distance > tolerance * 0.001) {
        pieces.insert(0, AnyCornerSegment.line(first, a));
      }
      if ((last - b).distance > tolerance * 0.001) {
        pieces.add(AnyCornerSegment.line(b, last));
      }
    } else if (f.convexity * offset.previousDistance > 0 &&
        f.convexity * offset.nextDistance > 0) {
      // The shifted sides already lie beyond the entire scoop cutout.
      pieces.add(AnyCornerSegment.line(shifted.vertex, shifted.vertex));
    } else {
      // An exhausted shrinking arc becomes the intersection of its endpoint
      // tangents. Keep the sharp joins continuous through radius zero.
      final a = offset.at(0).$1, b = offset.at(1).$1;
      final u = offset.sourceAt(0).$2, v = offset.sourceAt(1).$2;
      final meeting = geometryLineMeeting(a, u, b, v, shifted.vertex);
      final first =
          geometryLineMeeting(shifted.vertex, f.previousRay, a, u, meeting);
      final last =
          geometryLineMeeting(shifted.vertex, f.nextRay, b, v, meeting);
      pieces.addAll([
        AnyCornerSegment.line(first, meeting),
        AnyCornerSegment.line(meeting, last)
      ]);
    }
    return resolved(offset.corner, shifted, _packScoop(pieces, shifted.vertex),
        center: f.vertex,
        circleRadius: radius == null ? null : math.max(0, radius),
        tolerance: tolerance,
        geometryState: offset);
  }
}

/// Normal offsets of the source sector, anchored to its original center.
/// Equal distances give concentric circles and parallel elliptical curves.
class _ScoopOffset {
  final InverseRoundedCorner corner;
  final AnyCornerFrame frame;
  final double previousDistance, nextDistance;
  late final double startAngle =
      math.atan2(frame.previousRay.dy, frame.previousRay.dx);
  late final double sweep = geometryAngle(frame.previousRay, frame.nextRay);
  _ScoopOffset(
      this.corner, this.frame, this.previousDistance, this.nextDistance);

  (Offset, Offset, Offset) sourceAt(double t) {
    final angle = startAngle + sweep * t;
    final radial = Offset(math.cos(angle), math.sin(angle));
    final point = frame.affine(radial, corner.p, corner.n);
    final velocity =
        frame.affine(geometryLeft(radial), corner.p, corner.n) * sweep;
    final acceleration = -point * (sweep * sweep);
    return (frame.vertex + point, velocity, acceleration);
  }

  (Offset, Offset, double) at(double t) {
    if (corner.p == corner.n && previousDistance == nextDistance) {
      final angle = startAngle + sweep * t;
      final radial = Offset(math.cos(angle), math.sin(angle));
      final radius = corner.p + frame.convexity * previousDistance;
      return (
        frame.vertex + radial * radius,
        geometryLeft(radial) * (radius * sweep),
        radius / corner.p
      );
    }
    final (point, velocity, acceleration) = sourceAt(t);
    final speed = velocity.distance;
    final normal = geometryLeft(velocity) * (frame.winding / speed);
    final normalDerivative =
        geometryLeft(acceleration) * (frame.winding / speed) -
            normal * (geometryDot(velocity, acceleration) / (speed * speed));
    final distance = previousDistance * (1 - t) + nextDistance * t;
    final derivative = velocity +
        normalDerivative * distance +
        normal * (nextDistance - previousDistance);
    return (
      point + normal * distance,
      derivative,
      geometryDot(derivative, velocity) / (speed * speed)
    );
  }
}

// Give every piece an interval while preserving its exact polynomial. Length
// weights keep half-corner ownership symmetric under reversed traversal.
List<AnyCornerSegment> _packScoop(
    List<AnyCornerSegment> pieces, Offset fallback) {
  final lengths = pieces
      .map((s) => s.isLine
          ? (s.end - s.start).distance
          : ((s.control1 - s.start).distance +
                  (s.control2 - s.control1).distance +
                  (s.end - s.control2).distance +
                  (s.end - s.start).distance) /
              2)
      .toList();
  final total = lengths.fold(0.0, (a, b) => a + b);
  if (total <= 1e-12) return [AnyCornerSegment.line(fallback, fallback)];
  final result = <AnyCornerSegment>[];
  var position = 0.0;
  for (var i = 0; i < pieces.length; i++) {
    if (lengths[i] <= 0) continue;
    final s = pieces[i], end = position + lengths[i] / total;
    result.add(AnyCornerSegment(s.start, s.control1, s.control2, s.end,
        from: position, to: end, isLine: s.isLine));
    position = end;
  }
  final last = result.removeLast();
  result.add(AnyCornerSegment(
      last.start, last.control1, last.control2, last.end,
      from: last.from, to: 1, isLine: last.isLine));
  return result;
}
