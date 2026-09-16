part of 'core.dart';

/// Local guarantees for one resolved curve. Global contour checks still apply.
/// See README.md, Custom corners. Arbitrary geometry defaults to [none],
/// including geometry returned by a custom provider.
class AnyCornerTraits {
  final bool directCandidate;
  final bool rectangularBand;
  final bool sharpSource;
  const AnyCornerTraits(
      {this.directCandidate = false,
      this.rectangularBand = false,
      this.sharpSource = false});
  static const none = AnyCornerTraits();
  static const direct = AnyCornerTraits(directCandidate: true);
  static const sharpDirect =
      AnyCornerTraits(directCandidate: true, sharpSource: true);
  static const rectangle =
      AnyCornerTraits(directCandidate: true, rectangularBand: true);
  static const sharpRectangle = AnyCornerTraits(
      directCandidate: true, rectangularBand: true, sharpSource: true);
}

/// Stateless geometry policy selected by an [AnyCorner].
/// Providers own local construction; the engine owns allocation and topology.
abstract class AnyCornerGeometry {
  const AnyCornerGeometry();

  /// Converts p/n to incident-edge contact lengths. The shared allocator handles
  /// parallel frames, infinity and proportional scaling before construction.
  double contactScale(AnyCorner corner, AnyCornerFrame frame) => 1;
  bool get retainsSingleZeroExtent => false;
  AnyResolvedCorner resolve(AnyCorner corner, AnyCornerFrame frame);

  /// Optional specialization for a transition between resolved boundaries.
  /// Return null to use shared, exactly subdivided canonical curve interpolation.
  /// Preparation is lazy and reused while the endpoint point context is stable.
  AnyCornerTransition? prepareTransition(
          AnyResolvedCorner from, AnyResolvedCorner to) =>
      null;

  /// Use only when these descriptors fully represent the resolved endpoints.
  /// They are already fitted; evaluation must not allocate their contacts again.
  @protected
  AnyCornerTransition parameterTransition(AnyCorner from, AnyCorner to) =>
      _ParameterCornerTransition(from, to);

  /// Derive a boundary from normalized source geometry. Distances are signed
  /// along the material-facing normal (positive inward).
  /// Handles shared zero-distance and parallel-frame behavior.
  AnyResolvedCorner resolveBoundary(AnyResolvedCorner source,
      {required double previousDistance, required double nextDistance}) {
    final dp = previousDistance, dn = nextDistance;
    final frame = source.frame;
    final shifted = frame.shifted(dp, dn);
    final corner = source.parameters ?? source.source;
    if (dp == 0 && dn == 0) return source;
    if (frame.parallel) {
      return resolved(
          source.source,
          shifted,
          [
            AnyCornerSegment.line(frame.vertex + frame.previousNormal * dp,
                frame.vertex + frame.nextNormal * dn),
          ],
          parameters: corner);
    }
    return corner.geometry.buildBoundary(source, corner, shifted, dp, dn);
  }

  /// Nonparallel, nonzero boundary policy after the common early returns.
  @protected
  AnyResolvedCorner buildBoundary(
      AnyResolvedCorner source,
      AnyCorner parameters,
      AnyCornerFrame shifted,
      double previousDistance,
      double nextDistance);

  /// Providers may retain the actual reference in [AnyResolvedCorner.geometryState].
  AnyResolvedCorner resolveZeroBoundary(AnyResolvedCorner outer,
      {required double previousDistance, required double nextDistance}) {
    final descriptor = outer.parameters ?? outer.source;
    final source = descriptor.geometry.resolve(descriptor, outer.frame);
    return descriptor.geometry.resolveBoundary(source,
        previousDistance: previousDistance, nextDistance: nextDistance);
  }

  /// Descriptor support consulted by providers, never by the contour engine.
  bool isRectangularDescriptor(AnyCorner corner) => false;

  @protected
  AnyCornerTraits traitsFor(
          AnyCorner source, AnyCorner? parameters, double? radius) =>
      AnyCornerTraits.none;

  /// Trusted builder shared with built-ins. Supply finite, contiguous canonical
  /// segments. Use [AnyResolvedCorner] to validate arbitrary segment data.
  @protected
  AnyResolvedCorner resolved(AnyCorner source, AnyCornerFrame frame,
          List<AnyCornerSegment> segments,
          {AnyCorner? parameters,
          Offset? center,
          double? circleRadius,
          double tolerance = 0.001,
          Object? geometryState}) =>
      _resolved(source, frame, segments,
          parameters: parameters,
          center: center,
          circleRadius: circleRadius,
          tolerance: tolerance,
          geometryState: geometryState);

  @protected
  AnyResolvedCorner? resolveDegenerate(AnyCorner corner, AnyCornerFrame frame) {
    if (!corner.p.isFinite || !corner.n.isFinite) {
      throw ArgumentError(
          'Resolve finite corner dimensions before constructing geometry.');
    }
    if (frame.parallel ||
        (!retainsSingleZeroExtent && (corner.p <= 0 || corner.n <= 0))) {
      return resolved(
          corner, frame, [AnyCornerSegment.line(frame.vertex, frame.vertex)],
          parameters: corner);
    }
    return null;
  }

  @protected
  List<AnyCornerSegment> directArc(AnyCornerCurve curve, double sweep,
          double stretch, double tolerance) =>
      _directArc(curve, sweep, stretch, tolerance);

  @protected
  List<AnyCornerSegment> fitCurve(AnyCornerCurve curve, double tolerance,
          {double from = 0, double to = 1}) =>
      _fit(curve, tolerance, from: from, to: to);
}

/// Prepared local interpolation selected by a geometry provider. Implementations
/// must preserve endpoint geometry and return valid curves in the current frame.
abstract class AnyCornerTransition {
  const AnyCornerTransition();
  AnyResolvedCorner resolve(AnyCornerFrame frame, double t);
}

class _ParameterCornerTransition extends AnyCornerTransition {
  final AnyCorner from, to;
  const _ParameterCornerTransition(this.from, this.to);
  @override
  AnyResolvedCorner resolve(AnyCornerFrame frame, double t) {
    final corner = AnyCorner._lerpResolved(from, to, t);
    return corner.geometry.resolve(corner, frame);
  }
}

/// Immutable corner settings. Geometry is available through [geometry] and
/// [AnyResolvedCorner], never by interpreting these settings as path extents.
abstract class AnyCorner {
  /// Previous-ray radius for rounded/scoop corners; ray cut length for bevels.
  final double p;

  /// Next-ray radius for rounded/scoop corners; ray cut length for bevels.
  final double n;
  const AnyCorner({this.p = 0, this.n = 0});

  /// Required geometry implementation; custom corners select their provider here.
  AnyCornerGeometry get geometry;

  AnyCorner copyWith({double? p, double? n});
  AnyCorner operator *(double factor) => copyWith(p: p * factor, n: n * factor);
  AnyCorner lerpTo(AnyCorner other, double t);

  static AnyCorner lerp(AnyCorner a, AnyCorner b, double t) {
    if (a == b || t <= 0) return a;
    if (t >= 1) return b;
    return _LerpCorner(t: t, from: a, to: b);
  }

  static AnyCorner _lerpResolved(AnyCorner a, AnyCorner b, double t) {
    if (a == b || t <= 0) return a;
    if (t >= 1) return b;
    if (a.runtimeType == b.runtimeType) return a.lerpTo(b, t);
    return t < 0.5 ? a * (1 - 2 * t) : b * (2 * t - 1);
  }
}

class _LerpCorner extends AnyCorner {
  @override
  AnyCornerGeometry get geometry =>
      throw StateError('Resolve interpolation before geometry.');
  final double t;
  final AnyCorner from;
  final AnyCorner to;
  const _LerpCorner({required this.t, required this.from, required this.to})
      : assert(from is! _LerpCorner),
        assert(to is! _LerpCorner);
  @override
  AnyCorner copyWith({double? p, double? n}) =>
      throw StateError('Resolve interpolation before geometry.');
  @override
  AnyCorner lerpTo(AnyCorner other, double t) =>
      throw StateError('Resolve interpolation before geometry.');
  @override
  bool operator ==(Object other) =>
      other is _LerpCorner &&
      t == other.t &&
      from == other.from &&
      to == other.to;
  @override
  int get hashCode => Object.hash(t, from, to);
}
