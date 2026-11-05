part of '../../any_edge_profile.dart';

// A fully rounded zigzag repeat occupies a straight contour vertex. Its fitted
// circular arcs and normal offsets use the existing corner-provider API.
class _FittedZigZagCorner extends AnyCorner {
  final double depth;
  const _FittedZigZagCorner(
      {required super.p, required super.n, required this.depth});

  @override
  AnyCornerGeometry get geometry => const _FittedZigZagGeometry();

  @override
  AnyCorner copyWith({double? p, double? n}) =>
      _FittedZigZagCorner(p: p ?? this.p, n: n ?? this.n, depth: depth);

  @override
  AnyCorner operator *(double factor) =>
      _FittedZigZagCorner(p: p * factor, n: n * factor, depth: depth * factor);

  @override
  AnyCorner lerpTo(covariant _FittedZigZagCorner other, double t) =>
      _FittedZigZagCorner(
          p: lerpDouble(p, other.p, t)!,
          n: lerpDouble(n, other.n, t)!,
          depth: lerpDouble(depth, other.depth, t)!);

  @override
  bool operator ==(Object other) =>
      other is _FittedZigZagCorner &&
      p == other.p &&
      n == other.n &&
      depth == other.depth;

  @override
  int get hashCode => Object.hash(p, n, depth);
}

class _FittedZigZagState {
  final _FittedZigZagCorner corner;
  final AnyCornerFrame frame;
  final double previousDistance, nextDistance;
  const _FittedZigZagState(this.corner, this.frame,
      [this.previousDistance = 0, this.nextDistance = 0]);

  // Four alternating circular fillets form a fully rounded zigzag. Each pair
  // spans one half-repeat and meets the adjacent pair with the same tangent.
  // For depth > half-width, stretch the 90-degree fillets vertically instead of
  // allowing circular arcs to fold backwards beyond the construction envelope.
  (Offset, Offset, Offset) sample(double t, int quarter) {
    final first = quarter < 2;
    final u = (4 * t - quarter).clamp(0.0, 1.0);
    final width = first ? corner.p : corner.n;
    final depth = corner.depth.abs();
    final tangent = frame.nextRay, inward = frame.nextNormal;
    if (depth == 0) {
      return (
        frame.vertex + tangent * (-corner.p + (corner.p + corner.n) * t),
        tangent * (corner.p + corner.n),
        Offset.zero
      );
    }
    final circularDepth = math.min(depth, width);
    final theta = 2 * math.atan2(circularDepth, width);
    final radius =
        (width * width + circularDepth * circularDepth) / (4 * circularDepth);
    final stretch = corner.depth / circularDepth;
    final forward = quarter.isEven;
    final angle = theta * (forward ? u : 1 - u);
    final sign = first ? 1.0 : -1.0;
    final heading = sign * angle;
    final localX = forward
        ? radius * math.sin(angle)
        : width / 2 + radius * (math.sin(theta) - math.sin(angle));
    final localY = forward
        ? radius * (1 - math.cos(angle))
        : circularDepth / 2 + radius * (math.cos(angle) - math.cos(theta));
    // Exact quarter endpoints keep the crest/depth contacts independent of
    // floating-point trigonometric roundoff.
    final x = (first ? -corner.p : 0.0) +
        (u == 0
            ? (forward ? 0.0 : width / 2)
            : u == 1
                ? (forward ? width / 2 : width)
                : localX);
    final halfY = u == 0
        ? (forward ? 0.0 : circularDepth / 2)
        : u == 1
            ? (forward ? circularDepth / 2 : circularDepth)
            : localY;
    final y = (first ? halfY : circularDepth - halfY) * stretch;
    final speed = radius * theta * 4;
    final angularSpeed = sign * (forward ? 1 : -1) * theta * 4;
    return (
      frame.vertex + tangent * x + inward * y,
      tangent * (speed * math.cos(heading)) +
          inward * (speed * math.sin(heading) * stretch),
      tangent * (-speed * angularSpeed * math.sin(heading)) +
          inward * (speed * angularSpeed * math.cos(heading) * stretch),
    );
  }

  AnyCornerCurve offsetCurve(int quarter) => AnyCornerCurve((t) {
        final (point, velocity, _) = sample(t, quarter);
        final normal = Offset(-velocity.dy, velocity.dx) *
            (frame.winding / velocity.distance);
        return point + normal * lerpDouble(previousDistance, nextDistance, t)!;
      }, (t) {
        final (_, velocity, acceleration) = sample(t, quarter);
        final speed = velocity.distance;
        final left = Offset(-velocity.dy, velocity.dx);
        final normal = left * (frame.winding / speed);
        final dot =
            velocity.dx * acceleration.dx + velocity.dy * acceleration.dy;
        final normalDerivative =
            (Offset(-acceleration.dy, acceleration.dx) / speed -
                    left * (dot / (speed * speed * speed))) *
                frame.winding;
        return velocity +
            normal * (nextDistance - previousDistance) +
            normalDerivative * lerpDouble(previousDistance, nextDistance, t)!;
      });
}

class _FittedZigZagGeometry extends AnyCornerGeometry {
  const _FittedZigZagGeometry();

  @override
  AnyResolvedCorner resolve(AnyCorner settings, AnyCornerFrame frame) {
    final corner = settings as _FittedZigZagCorner;
    if (corner.p <= 0 || corner.n <= 0) {
      return resolved(
          corner, frame, [AnyCornerSegment.line(frame.vertex, frame.vertex)],
          parameters: corner);
    }
    final state = _FittedZigZagState(corner, frame);
    return resolved(
        corner,
        frame,
        [
          for (var q = 0; q < 4; q++)
            ...fitCurve(state.offsetCurve(q), .001,
                from: q / 4, to: (q + 1) / 4),
        ],
        parameters: corner,
        geometryState: state);
  }

  @override
  AnyResolvedCorner resolveBoundary(AnyResolvedCorner source,
      {required double previousDistance, required double nextDistance}) {
    if (previousDistance == 0 && nextDistance == 0) return source;
    final shifted = source.frame.shifted(previousDistance, nextDistance);
    final state = source.geometryState as _FittedZigZagState?;
    if (state == null) return resolve(source.source, shifted);
    final next = _FittedZigZagState(
        state.corner,
        state.frame,
        state.previousDistance + previousDistance,
        state.nextDistance + nextDistance);
    return resolved(
        source.source,
        shifted,
        [
          for (var q = 0; q < 4; q++)
            ...fitCurve(next.offsetCurve(q), .001,
                from: q / 4, to: (q + 1) / 4),
        ],
        geometryState: next);
  }

  @override
  AnyResolvedCorner buildBoundary(
          AnyResolvedCorner source,
          AnyCorner parameters,
          AnyCornerFrame shifted,
          double previousDistance,
          double nextDistance) =>
      resolveBoundary(source,
          previousDistance: previousDistance, nextDistance: nextDistance);

  @override
  AnyResolvedCorner resolveZeroBoundary(AnyResolvedCorner outer,
          {required double previousDistance, required double nextDistance}) =>
      resolveBoundary(outer,
          previousDistance: previousDistance, nextDistance: nextDistance);
}
