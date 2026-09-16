part of 'core.dart';

/// A vertex frame independent of traversal direction. Normals face material.
class AnyCornerFrame {
  final Offset vertex;
  final Offset previousRay;
  final Offset nextRay;
  final Offset previousNormal;
  final Offset nextNormal;
  final double winding;
  const AnyCornerFrame(
      {required this.vertex,
      required this.previousRay,
      required this.nextRay,
      required this.previousNormal,
      required this.nextNormal,
      required this.winding});
  double get angle => math.atan2(geometryCross(previousRay, nextRay).abs(),
      geometryDot(previousRay, nextRay));
  bool get parallel =>
      geometryCross(previousRay, nextRay).abs() < geometryAngleTolerance;

  /// Parallel rays in the same direction form a reversing helper vertex.
  /// Opposite rays form a straight vertex, which may have an authored anchor.
  bool get backtracking => parallel && geometryDot(previousRay, nextRay) > 0;
  double get convexity =>
      -geometryCross(previousRay, nextRay) * winding >= 0 ? 1 : -1;
  double get cotangentHalfAngle {
    final cross = geometryCross(previousRay, nextRay).abs();
    final dot = geometryDot(previousRay, nextRay);
    if (parallel) return 0;
    return dot > 0 ? (1 + dot) / cross : cross / (1 - dot);
  }

  Offset shiftedVertex(double previousDistance, double nextDistance) {
    final det = geometryCross(previousNormal, nextNormal);
    if (det.abs() < geometryAngleTolerance) {
      return vertex +
          (previousNormal * previousDistance + nextNormal * nextDistance) / 2;
    }
    return vertex +
        Offset(
            (previousDistance * nextNormal.dy -
                    previousNormal.dy * nextDistance) /
                det,
            (previousNormal.dx * nextDistance -
                    previousDistance * nextNormal.dx) /
                det);
  }

  AnyCornerFrame shifted(double previousDistance, double nextDistance) =>
      AnyCornerFrame(
          vertex: shiftedVertex(previousDistance, nextDistance),
          previousRay: previousRay,
          nextRay: nextRay,
          previousNormal: previousNormal,
          nextNormal: nextNormal,
          winding: winding);
  Offset affine(Offset value, double p, double n) {
    if (p == n) return value * p;
    final det = geometryCross(previousRay, nextRay);
    return previousRay * (geometryCross(value, nextRay) / det * p) +
        nextRay * (geometryCross(previousRay, value) / det * n);
  }

  // Largest singular value of the ray-basis map. Scaling first avoids squaring
  // large coordinates; the result is invariant under rotations/reflections.
  double affineStretch(double p, double n) {
    if (p == n) return p.abs();
    final x = affine(const Offset(1, 0), p, n);
    final y = affine(const Offset(0, 1), p, n);
    final scale = math.max(x.distance, y.distance);
    if (scale == 0) return 0;
    final a = x / scale, b = y / scale;
    final xx = geometryDot(a, a),
        yy = geometryDot(b, b),
        xy = geometryDot(a, b);
    return scale *
        math.sqrt(
            (xx + yy + math.sqrt((xx - yy) * (xx - yy) + 4 * xy * xy)) / 2);
  }
}

/// A canonical cubic (or exact line) with its interval in corner parameter space.
/// Subdivision preserves the original polynomial, including reversed traversal.
class AnyCornerSegment {
  final Offset start;
  final Offset control1;
  final Offset control2;
  final Offset end;
  final double from;
  final double to;
  final bool isLine;
  const AnyCornerSegment(this.start, this.control1, this.control2, this.end,
      {this.from = 0, this.to = 1, this.isLine = false});
  factory AnyCornerSegment.line(Offset a, Offset b,
          {double from = 0, double to = 1}) =>
      AnyCornerSegment(
          a, Offset.lerp(a, b, 1 / 3)!, Offset.lerp(a, b, 2 / 3)!, b,
          from: from, to: to, isLine: true);
  Offset pointAt(double t) {
    final u = 1 - t;
    return start * (u * u * u) +
        control1 * (3 * u * u * t) +
        control2 * (3 * u * t * t) +
        end * (t * t * t);
  }

  Offset derivativeAt(double t) =>
      (control1 - start) * (3 * (1 - t) * (1 - t)) +
      (control2 - control1) * (6 * t * (1 - t)) +
      (end - control2) * (3 * t * t);
  (AnyCornerSegment, AnyCornerSegment) split(double t) {
    final a = Offset.lerp(start, control1, t)!;
    final b = Offset.lerp(control1, control2, t)!;
    final c = Offset.lerp(control2, end, t)!;
    final d = Offset.lerp(a, b, t)!;
    final e = Offset.lerp(b, c, t)!;
    final f = Offset.lerp(d, e, t)!;
    final mid = from + (to - from) * t;
    return (
      AnyCornerSegment(start, a, d, f, from: from, to: mid, isLine: isLine),
      AnyCornerSegment(f, e, c, end, from: mid, to: to, isLine: isLine)
    );
  }

  AnyCornerSegment range(double a, double b) {
    var result = b < 1 ? split(b).$1 : this;
    if (a > 0) result = result.split(a / b).$2;
    return result;
  }

  void appendTo(Path path, {bool reverse = false}) {
    final a = reverse ? control2 : control1;
    final b = reverse ? control1 : control2;
    final c = reverse ? start : end;
    if (isLine) {
      path.lineTo(c.dx, c.dy);
    } else {
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }
  }
}

/// Immutable, inspectable corner geometry. [source] is the normalized source
/// setting. [parameters] exists only when one descriptor represents this curve.
/// Extents measure actual distances from the boundary's shifted vertex.
class AnyResolvedCorner {
  final AnyCorner source;
  final AnyCorner? parameters;
  final AnyCornerFrame frame;
  final List<AnyCornerSegment> segments;
  final double previousExtent;
  final double nextExtent;

  /// Circle/ellipse center, or the source reference center for an offset scoop
  /// that is no longer itself circular or elliptical.
  final Offset? center;
  final double? circleRadius;
  final double tolerance;

  /// Immutable state owned by the source's geometry provider. The engine never
  /// interprets it; a provider can use it to continue boundary derivation.
  final Object? geometryState;
  final AnyCornerTraits? _declaredTraits;
  // Classification is only needed for requested areas. Intermediate boundary
  // curves and shape-only requests must not eagerly classify unused results.
  late final AnyCornerTraits traits = _declaredTraits ??
      source.geometry.traitsFor(source, parameters, circleRadius);
  // Local memoization lives only as long as this immutable resolved corner.
  // Tween contours still bypass the decoration LRU cache.
  final Map<double, List<(double, Offset)>> _flattened = {};

  /// Build custom resolved geometry with canonical segment intervals covering
  /// [0, 1]. Custom geometry providers can use this in their resolve method.
  factory AnyResolvedCorner(
      {required AnyCorner source,
      required AnyCornerFrame frame,
      required List<AnyCornerSegment> segments,
      AnyCorner? parameters,
      Offset? center,
      double? circleRadius,
      double tolerance = 0.001,
      Object? geometryState,
      AnyCornerTraits traits = AnyCornerTraits.none}) {
    if (segments.isEmpty ||
        segments.first.from != 0 ||
        segments.last.to != 1 ||
        tolerance <= 0 ||
        !tolerance.isFinite) {
      throw ArgumentError(
          'Segments must cover [0,1] and tolerance must be positive and finite.');
    }
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s.to <= s.from ||
          ![s.start, s.control1, s.control2, s.end]
              .every((p) => p.dx.isFinite && p.dy.isFinite) ||
          (i > 0 &&
              (s.from != segments[i - 1].to ||
                  (s.start - segments[i - 1].end).distance > tolerance))) {
        throw ArgumentError(
            'Corner segments must be finite, contiguous and ordered.');
      }
    }
    return _resolved(source, frame, segments,
        parameters: parameters,
        center: center,
        circleRadius: circleRadius,
        tolerance: tolerance,
        geometryState: geometryState,
        traits: traits);
  }
  AnyResolvedCorner._(
      {required this.source,
      required this.frame,
      required List<AnyCornerSegment> segments,
      required this.previousExtent,
      required this.nextExtent,
      this.parameters,
      this.center,
      this.circleRadius,
      this.tolerance = 0.001,
      this.geometryState,
      AnyCornerTraits? traits})
      : _declaredTraits = traits,
        segments = List.unmodifiable(segments);

  Offset get start => segments.first.start;
  Offset get end => segments.last.end;
  AnyCornerSegment _segmentAt(double t) =>
      segments.firstWhere((s) => t <= s.to, orElse: () => segments.last);
  Offset pointAt(double t) {
    t = t.clamp(0.0, 1.0);
    final s = _segmentAt(t);
    return s.pointAt(((t - s.from) / (s.to - s.from)).clamp(0.0, 1.0));
  }

  Offset tangentAt(double t) {
    t = t.clamp(0.0, 1.0);
    final s = _segmentAt(t);
    return geometryUnit(
        s.derivativeAt(((t - s.from) / (s.to - s.from)).clamp(0.0, 1.0)));
  }

  void appendTo(Path path,
      {double from = 0, double to = 1, bool moveTo = false}) {
    final p = pointAt(from);
    if (moveTo) path.moveTo(p.dx, p.dy);
    final low = math.min(from, to).clamp(0.0, 1.0);
    final high = math.max(from, to).clamp(0.0, 1.0);
    if (low == high) return;
    final list = to < from ? segments.reversed : segments;
    for (final s in list) {
      final a = math.max(low, s.from), b = math.min(high, s.to);
      if (b <= a) continue;
      s
          .range((a - s.from) / (s.to - s.from), (b - s.from) / (s.to - s.from))
          .appendTo(path, reverse: to < from);
    }
  }

  Iterable<AnyCornerSegment> _range(double from, double to) sync* {
    for (final s in segments) {
      final a = math.max(from, s.from), b = math.min(to, s.to);
      if (b > a) {
        yield s.range(
            (a - s.from) / (s.to - s.from), (b - s.from) / (s.to - s.from));
      }
    }
  }

  List<(double, Offset)> _flatten({double? error}) {
    final precision = error ?? tolerance;
    final cached = _flattened[precision];
    if (cached != null) return cached;
    assert(diagnostics.record(diagnostics.GeometryWork.flatten));
    final result = <(double, Offset)>[(0, start)];
    void visit(AnyCornerSegment s, int depth) {
      final chord = s.end - s.start;
      final length = chord.distance;
      final flatness = length == 0
          ? math.max(
              (s.control1 - s.start).distance, (s.control2 - s.start).distance)
          : math.max(geometryCross(chord, s.control1 - s.start).abs() / length,
              geometryCross(chord, s.control2 - s.start).abs() / length);
      if (s.isLine || flatness <= (error ?? tolerance) || depth >= 24) {
        if (depth >= 24 && flatness > (error ?? tolerance)) {
          throw StateError('Corner flattening exceeded subdivision limit.');
        }
        result.add((s.to, s.end));
        return;
      }
      final (a, b) = s.split(0.5);
      visit(a, depth + 1);
      visit(b, depth + 1);
    }

    for (final s in segments) {
      visit(s, 0);
    }
    return _flattened[precision] = List.unmodifiable(result);
  }
}

class AnyCornerCurve {
  final Offset Function(double) at;
  final Offset Function(double) derivative;
  const AnyCornerCurve(this.at, this.derivative);
}

// Cubic Hermite interpolation has error <= B * deltaAngle^4 / 384 for
// an affine circular arc with maximum stretch B. Use the same quarter-budget
// and angular parameter as _fit, without constructing/rejecting candidates.
List<AnyCornerSegment> _directArc(
    AnyCornerCurve curve, double sweep, double stretch, double tolerance) {
  var count = 1;
  while (true) {
    final angle = sweep.abs() / count, squared = angle * angle;
    if (stretch * squared * squared / 384 <= tolerance * 0.25) break;
    if (count >= 4096) {
      throw StateError(
          'Corner approximation exceeded its error/segment budget.');
    }
    count *= 2;
  }
  final result = <AnyCornerSegment>[];
  var p = curve.at(0), velocity = curve.derivative(0);
  for (var i = 1; i <= count; i++) {
    final t = i / count, q = curve.at(t), nextVelocity = curve.derivative(t);
    final s = AnyCornerSegment(
        p, p + velocity / (3.0 * count), q - nextVelocity / (3.0 * count), q,
        from: (i - 1) / count, to: t);
    if (![s.start, s.control1, s.control2, s.end]
        .every((v) => v.dx.isFinite && v.dy.isFinite)) {
      throw StateError('Corner calculation produced non-finite geometry.');
    }
    result.add(s);
    p = q;
    velocity = nextVelocity;
  }
  return result;
}

List<AnyCornerSegment> _fit(AnyCornerCurve curve, double tolerance,
    {double from = 0, double to = 1}) {
  assert(diagnostics.record(diagnostics.GeometryWork.fit));
  final result = <AnyCornerSegment>[];
  void fit(double a, double b, int depth) {
    final p = curve.at(a), q = curve.at(b);
    final s = AnyCornerSegment(p, p + curve.derivative(a) * ((b - a) / 3),
        q - curve.derivative(b) * ((b - a) / 3), q,
        from: a, to: b);
    if (![s.start, s.control1, s.control2, s.end]
        .every((v) => v.dx.isFinite && v.dy.isFinite)) {
      throw StateError('Corner calculation produced non-finite geometry.');
    }
    var error = 0.0;
    for (var i = 1; i < 8; i++) {
      error = math.max(
          error, (s.pointAt(i / 8) - curve.at(a + (b - a) * i / 8)).distance);
    }
    if (error <= tolerance * 0.25) {
      result.add(s);
      return;
    }
    if (depth >= 20 || result.length >= 4096) {
      throw StateError(
          'Corner approximation exceeded its error/segment budget.');
    }
    fit(a, (a + b) / 2, depth + 1);
    fit((a + b) / 2, b, depth + 1);
  }

  fit(from, to, 0);
  return result;
}

AnyResolvedCorner _resolved(
    AnyCorner source, AnyCornerFrame frame, List<AnyCornerSegment> segments,
    {AnyCorner? parameters,
    Offset? center,
    double? circleRadius,
    double tolerance = 0.001,
    Object? geometryState,
    AnyCornerTraits? traits}) {
  return AnyResolvedCorner._(
      source: source,
      frame: frame,
      segments: segments,
      parameters: parameters,
      center: center,
      circleRadius: circleRadius,
      tolerance: tolerance,
      geometryState: geometryState,
      traits: traits,
      previousExtent:
          geometryDot(segments.first.start - frame.vertex, frame.previousRay),
      nextExtent: geometryDot(segments.last.end - frame.vertex, frame.nextRay));
}
