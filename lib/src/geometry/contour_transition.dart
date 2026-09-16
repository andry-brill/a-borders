part of 'core.dart';

/// Internal bridge used by the decoration tween. Not exported by public facades.
/// One instance owns the preparation for one pair of point lists and layout.
@internal
class AnyContourTransition {
  final List<AnyPoint> from, to;
  late final List<AnyPoint> _from = from.where((p) => !p.skip).toList();
  late final List<AnyPoint> _to = to.where((p) => !p.skip).toList();
  late final bool compatible = _matches((a, b) => a.skip == b.skip);
  late final bool fixedPoints =
      compatible && _matches((a, b) => a.skip || a.point == b.point);
  late final bool fixedSource =
      fixedPoints && _matches((a, b) => a.skip || a.shape == b.shape);
  late final bool changesBoundaries = compatible &&
      !_matches((a, b) =>
          a.skip ||
          ((a.outer == null) == (b.outer == null) &&
              (a.inner == null) == (b.inner == null)));
  // A changing context cannot amortize source preparation. A subsequent cache
  // hit enables it again; boundary morphs still prepare whenever required.
  bool reusePointContext;
  List<AnyCornerFrame>? _frames;
  List<double>? _lengths;
  List<AnyCorner>? _normalizedFrom, _normalizedTo;
  List<AnyResolvedCorner>? _sourceCorners;
  late final _tracks = <(AnyShapeBase, int), AnyCornerTransition>{};
  late final _supported = <AnyShapeBase, bool>{};
  late final _begin = _endpoint(from);
  late final _end = _endpoint(to);

  AnyContourTransition(List<AnyPoint> from, List<AnyPoint> to,
      {this.reusePointContext = true})
      : from = List.unmodifiable(from),
        to = List.unmodifiable(to);

  bool _matches(bool Function(AnyPoint, AnyPoint) predicate) {
    if (from.length != to.length) return false;
    for (var i = 0; i < from.length; i++) {
      if (!predicate(from[i], to[i])) return false;
    }
    return true;
  }

  List<AnyPoint> points(double t) => AnyPoint.lerp(from, to, t)!;

  AnyContour build(double t,
          {required AnyFill? background,
          required AnyShapeBase backgroundBase,
          required AnyShapeBase clipBase,
          required AnyShapeBase shadowBase}) =>
      AnyContour._animated(this, t,
          background: background,
          backgroundBase: backgroundBase,
          clipBase: clipBase,
          shadowBase: shadowBase);

  AnyContour _endpoint(List<AnyPoint> points) => AnyContour(
      points: points,
      background: null,
      backgroundBase: AnyShapeBase.shapeBorder,
      clipBase: AnyShapeBase.shapeBorder,
      shadowBase: AnyShapeBase.shapeBorder);

  List<AnyCorner> normalizeSources(
      List<AnyCornerFrame> frames, List<double> lengths, double t) {
    _normalizedFrom ??=
        _normalizeSettings(_from.map((p) => p.shape).toList(), frames, lengths);
    if (fixedSource) return _normalizedFrom!;
    _normalizedTo ??=
        _normalizeSettings(_to.map((p) => p.shape).toList(), frames, lengths);
    return _normalizeSettings(
        List.generate(
            _from.length,
            (i) => AnyCorner._lerpResolved(
                _normalizedFrom![i], _normalizedTo![i], t)),
        frames,
        lengths);
  }

  bool morphs(int i, AnyShapeBase base) {
    if (!changesBoundaries) return false;
    if (base == AnyShapeBase.zeroBorder) base = AnyShapeBase.outerBorder;
    final changes = switch (base) {
      AnyShapeBase.outerBorder =>
        (_from[i].outer == null) != (_to[i].outer == null),
      AnyShapeBase.innerBorder =>
        (_from[i].inner == null) != (_to[i].inner == null),
      _ => false,
    };
    if (!changes) return false;
    return _supported.putIfAbsent(base, () {
      // Interpolating local curves cannot reproduce an endpoint's split or
      // exhausted filled area if it differs from that band's raw outline.
      // Keep the existing discrete policy for that incompatible topology.
      bool representedByOutline(AnyContour c) {
        final corners = c._corners(base);
        final explicit = base == AnyShapeBase.outerBorder
            ? c._explicitOuter
            : c._explicitInner;
        if (explicit.any((v) => v) || c._directBand(base)) return true;
        try {
          return _combinePaths(
                  PathOperation.xor, c._areaFor(base), _outline(corners))
              .computeMetrics()
              .isEmpty;
        } on StateError {
          return false;
        }
      }

      return representedByOutline(_begin) && representedByOutline(_end);
    });
  }

  AnyResolvedCorner? corner(
      int i, AnyShapeBase base, AnyCornerFrame frame, double t) {
    if (frame.backtracking || !morphs(i, base)) return null;
    final track = _tracks.putIfAbsent((base, i), () {
      final a = _begin._corners(base)[i], b = _end._corners(base)[i];
      final first = a.source.geometry, second = b.source.geometry;
      return first.prepareTransition(a, b) ??
          (identical(first, second) ? null : second.prepareTransition(a, b)) ??
          _SegmentCornerTransition(a, b);
    });
    return track.resolve(frame, t);
  }
}

// Match the union of canonical intervals exactly; never flatten/refit endpoints.
// Work in the incident-ray basis so moving vertices/angles retain side tangents.
class _SegmentCornerTransition extends AnyCornerTransition {
  final AnyResolvedCorner from, to;
  late final List<(AnyCornerSegment, AnyCornerSegment)> pairs = _prepare();
  _SegmentCornerTransition(this.from, this.to);

  List<(AnyCornerSegment, AnyCornerSegment)> _prepare() {
    final breaks = {
      0.0,
      1.0,
      ...from.segments.map((s) => s.to),
      ...to.segments.map((s) => s.to)
    }.toList()
      ..sort();
    var ai = 0, bi = 0;
    final result = <(AnyCornerSegment, AnyCornerSegment)>[];
    for (var i = 0; i + 1 < breaks.length; i++) {
      final low = breaks[i], high = breaks[i + 1];
      while (from.segments[ai].to <= low) {
        ai++;
      }
      while (to.segments[bi].to <= low) {
        bi++;
      }
      AnyCornerSegment piece(AnyCornerSegment s, AnyCornerFrame frame) {
        final part = s.range((low - s.from) / (s.to - s.from),
            (high - s.from) / (s.to - s.from));
        Offset local(Offset p) {
          final delta = p - frame.vertex;
          if (frame.parallel) return delta;
          final det = geometryCross(frame.previousRay, frame.nextRay);
          return Offset(geometryCross(delta, frame.nextRay) / det,
              geometryCross(frame.previousRay, delta) / det);
        }

        return AnyCornerSegment(local(part.start), local(part.control1),
            local(part.control2), local(part.end),
            from: low, to: high, isLine: part.isLine);
      }

      result.add((
        piece(from.segments[ai], from.frame),
        piece(to.segments[bi], to.frame)
      ));
    }
    return result;
  }

  @override
  AnyResolvedCorner resolve(AnyCornerFrame frame, double t) {
    Offset world(Offset p, AnyCornerFrame endpoint) => endpoint.parallel
        ? frame.vertex + p
        : frame.vertex + frame.previousRay * p.dx + frame.nextRay * p.dy;
    Offset point(Offset a, Offset b) =>
        Offset.lerp(world(a, from.frame), world(b, to.frame), t)!;
    final segments = [
      for (final (a, b) in pairs)
        AnyCornerSegment(point(a.start, b.start), point(a.control1, b.control1),
            point(a.control2, b.control2), point(a.end, b.end),
            from: a.from, to: a.to, isLine: a.isLine && b.isLine)
    ];
    return _resolved(t < 0.5 ? from.source : to.source, frame, segments,
        tolerance: math.max(from.tolerance, to.tolerance),
        traits: from.traits.directCandidate && to.traits.directCandidate
            ? AnyCornerTraits.direct
            : AnyCornerTraits.none);
  }
}
