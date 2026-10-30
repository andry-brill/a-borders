part of 'core.dart';

/// Internal immutable sample; points and effective boundary geometry are lazy.
/// Nested transitions retain this object, including its interpolation progress.
@internal
class AnyContourSample {
  final List<AnyPoint>? _points;
  final AnyContourTransition? _transition;
  final double _t;
  AnyContourSample(List<AnyPoint> points)
      : _points = List.unmodifiable(points),
        _transition = null,
        _t = 0;
  factory AnyContourSample.animated(
          AnyContourTransition transition, double t) =>
      transition.compatible
          ? AnyContourSample._animated(transition, t)
          : transition.endpoint(t);

  AnyContourSample._animated(AnyContourTransition transition, double t)
      : _points = null,
        _transition = transition,
        _t = t;

  late final List<AnyPoint> points = _points ?? _transition!.points(_t);
  bool get hasBoundaryTransitions => _transition?.changesBoundaries ?? false;
  late final AnyContour _geometry = contour(
      background: null,
      backgroundBase: AnyShapeBase.shapeBorder,
      clipBase: AnyShapeBase.shapeBorder,
      shadowBase: AnyShapeBase.shapeBorder);

  AnyContour contour(
          {required AnyFill? background,
          required AnyShapeBase backgroundBase,
          required AnyShapeBase clipBase,
          required AnyShapeBase shadowBase}) =>
      _transition != null
          ? _transition.build(_t,
              background: background,
              backgroundBase: backgroundBase,
              clipBase: clipBase,
              shadowBase: shadowBase)
          : AnyContour(
              points: points,
              background: background,
              backgroundBase: backgroundBase,
              clipBase: clipBase,
              shadowBase: shadowBase);
}

/// Internal bridge used by the decoration tween. Not exported by public facades.
/// One instance owns the preparation for one pair of point lists and layout.
@internal
class AnyContourTransition {
  final AnyContourSample fromSample, toSample;
  late final List<AnyPoint> from = fromSample.points, to = toSample.points;
  late final List<AnyPoint> _from = from.where((p) => !p.skip).toList();
  late final List<AnyPoint> _to = to.where((p) => !p.skip).toList();
  late final bool compatible = _matches((a, b) => a.skip == b.skip);
  late final bool fixedPoints =
      compatible && _matches((a, b) => a.skip || a.point == b.point);
  late final bool fixedSource =
      fixedPoints && _matches((a, b) => a.skip || a.shape == b.shape);
  late final bool changesBoundaries = compatible &&
      (fromSample.hasBoundaryTransitions ||
          toSample.hasBoundaryTransitions ||
          !_matches((a, b) =>
              a.skip ||
              ((a.outer == null) == (b.outer == null) &&
                  (a.inner == null) == (b.inner == null))));
  // A changing context cannot amortize source preparation. A subsequent cache
  // hit enables it again; boundary morphs still prepare whenever required.
  bool reusePointContext;
  List<AnyCornerFrame>? _frames;
  List<double>? _lengths;
  List<AnyCorner>? _normalizedFrom, _normalizedTo;
  List<AnyResolvedCorner>? _sourceCorners;
  late final _tracks = <(AnyShapeBase, int), AnyCornerTransition>{};
  late final _supported = <AnyShapeBase, bool>{};
  final _overridden = <(int, AnyShapeBase), bool>{};
  late final _begin = fromSample._geometry;
  late final _end = toSample._geometry;

  AnyContourTransition(this.fromSample, this.toSample,
      {this.reusePointContext = true});

  AnyContourSample endpoint(double t) => t < 0.5 ? fromSample : toSample;

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

  bool overridesCorner(int i, AnyShapeBase base) {
    if (!changesBoundaries) return false;
    if (base == AnyShapeBase.zeroBorder) base = AnyShapeBase.outerBorder;
    return _overridden.putIfAbsent((i, base), () => _overridesCorner(i, base));
  }

  bool _overridesCorner(int i, AnyShapeBase base) {
    final changes = switch (base) {
      AnyShapeBase.outerBorder =>
        (_from[i].outer == null) != (_to[i].outer == null),
      AnyShapeBase.innerBorder =>
        (_from[i].inner == null) != (_to[i].inner == null),
      _ => false,
    };
    bool sampledBoundary(AnyContourSample sample) =>
        sample.hasBoundaryTransitions &&
        (sample._geometry._boundaryFallback(base) != null ||
            (sample._geometry._transition?.overridesCorner(i, base) ?? false));
    return changes || sampledBoundary(fromSample) || sampledBoundary(toSample);
  }

  // A discrete boundary retains both its local curves and topology-correct
  // filled area. Selecting authored point descriptors would lose nested samples.
  // Zero boundaries follow the outer boundary's policy but keep their own curves.
  AnyContour? boundaryFallback(AnyShapeBase base, double t) {
    if (!changesBoundaries || base == AnyShapeBase.shapeBorder) return null;
    if (base == AnyShapeBase.zeroBorder) base = AnyShapeBase.outerBorder;
    final supported = _supported.putIfAbsent(base, () {
      if (!List.generate(_from.length, (i) => overridesCorner(i, base))
          .any((value) => value)) return true;
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
    return supported ? null : endpoint(t)._geometry;
  }

  AnyResolvedCorner? corner(
      int i, AnyShapeBase base, AnyCornerFrame frame, double t) {
    if (frame.backtracking || !overridesCorner(i, base)) return null;
    final track = _tracks.putIfAbsent((base, i), () {
      final a = _begin._corners(base)[i], b = _end._corners(base)[i];
      // A saved discrete boundary may be anchored to a different frame than
      // its sample's interpolated source/widths. Express its complete curves
      // in the current endpoint frame so a later retarget starts exactly there.
      if (_begin._boundaryFallback(base) != null ||
          _end._boundaryFallback(base) != null) {
        AnyCornerFrame reference(AnyContour c) => c.frames[i].shifted(
            c._offsetForBase(c._wrap(i - 1), base), c._offsetForBase(i, base));
        return _SegmentCornerTransition(a, b,
            fromFrame: reference(_begin), toFrame: reference(_end));
      }
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
  final AnyCornerFrame fromFrame, toFrame;
  late final List<(AnyCornerSegment, AnyCornerSegment)> pairs = _prepare();
  _SegmentCornerTransition(this.from, this.to,
      {AnyCornerFrame? fromFrame, AnyCornerFrame? toFrame})
      : fromFrame = fromFrame ?? from.frame,
        toFrame = toFrame ?? to.frame;

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
        piece(from.segments[ai], fromFrame),
        piece(to.segments[bi], toFrame)
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
        Offset.lerp(world(a, fromFrame), world(b, toFrame), t)!;
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
