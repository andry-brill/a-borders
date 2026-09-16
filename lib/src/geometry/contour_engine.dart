part of 'core.dart';

extension _ContourGeometry on AnyContour {
  void _prepareGeometry(List<AnyPoint> points) {
    if (points.length < 3)
      throw ArgumentError('At least 3 active points are required.');
    count = points.length;
    for (final p in points) {
      if (!p.point.dx.isFinite ||
          !p.point.dy.isFinite ||
          !p.side.width.isFinite ||
          p.side.width < 0 ||
          !p.side.align.isFinite ||
          p.side.align.abs() > 1) {
        throw ArgumentError(
            'Points, widths and alignments must be finite; width >= 0 and -1 <= align <= 1.');
      }
    }
    sides = List.unmodifiable(points.map((p) => p.side));
    sideInsideOffset =
        List.unmodifiable(sides.map((s) => s.width * (1 - s.align) / 2));
    sideOutsideOffset =
        List.unmodifiable(sides.map((s) => s.width * (1 + s.align) / 2));
    final directions = <Offset>[], lengths = <double>[];
    var area = 0.0;
    final origin = points.first.point;
    for (var i = 0; i < count; i++) {
      final a = points[i].point, b = points[wrap(i + 1)].point;
      final delta = b - a, length = delta.distance;
      if (length <= 1e-12)
        throw ArgumentError('Side $i has zero length; skip duplicate points.');
      directions.add(delta / length);
      lengths.add(length);
      area += geometryCross(a - origin, b - origin);
    }
    if (area.abs() < 1e-12)
      throw ArgumentError('A contour must enclose a nonzero area.');
    final winding = area > 0 ? 1.0 : -1.0;
    sideLength = List.unmodifiable(lengths);
    frames = List.unmodifiable(List.generate(
        count,
        (i) => AnyCornerFrame(
            vertex: points[i].point,
            previousRay: -directions[wrap(i - 1)],
            nextRay: directions[i],
            previousNormal: geometryLeft(directions[wrap(i - 1)]) * winding,
            nextNormal: geometryLeft(directions[i]) * winding,
            winding: winding)));
    final source = _normalizeSettings(
        points.map((p) => p.shape).toList(), frames, lengths);
    var resolved = List.generate(
        count, (i) => source[i].geometry.resolve(source[i], frames[i]));
    if (!_simpleBoxBand(resolved) && _sourceCrosses(resolved)) {
      // Source corners must fit together, including diagonally opposed scoops.
      final sharp = List.generate(count, (i) {
        final c = source[i].copyWith(p: 0, n: 0);
        return c.geometry.resolve(c, frames[i]);
      });
      if (_sourceCrosses(sharp))
        throw ArgumentError(
            'Self-intersecting source outlines are unsupported.');
      var lo = 0.0, hi = 1.0;
      for (var step = 0; step < 28; step++) {
        final mid = (lo + hi) / 2;
        final candidate = List.generate(count, (i) {
          final c = source[i] * mid;
          return c.geometry.resolve(c, frames[i]);
        });
        if (_sourceCrosses(candidate)) {
          hi = mid;
        } else {
          lo = mid;
          resolved = candidate;
        }
      }
    }
    shapeCorners = List.unmodifiable(resolved);
    _explicitOuter = List.unmodifiable(List.generate(
        count, (i) => points[i].outer != null && !frames[i].backtracking));
    _explicitInner = List.unmodifiable(List.generate(
        count, (i) => points[i].inner != null && !frames[i].backtracking));
    _outerSettings = List.unmodifiable(points.map((p) => p.outer));
    _innerSettings = List.unmodifiable(points.map((p) => p.inner));
  }

  List<AnyResolvedCorner> _resolveZeroBand() =>
      List.unmodifiable(List.generate(count, (i) {
        final outer = outerCorners[i];
        return outer.source.geometry.resolveZeroBoundary(outer,
            previousDistance: sideOutsideOffset[wrap(i - 1)],
            nextDistance: sideOutsideOffset[i]);
      }));

  List<AnyResolvedCorner> _resolveBand(
      List<AnyCorner?> overrides, AnyShapeBase base) {
    if (overrides.every((c) => c == null)) {
      if (List.generate(count, (i) => offsetForBase(i, base))
          .every((d) => d == 0)) return shapeCorners;
      return List.unmodifiable(List.generate(count, (i) {
        final source = shapeCorners[i];
        return source.source.geometry.resolveBoundary(source,
            previousDistance: offsetForBase(wrap(i - 1), base),
            nextDistance: offsetForBase(i, base));
      }));
    }
    final shifted = List.generate(
        count,
        (i) => frames[i]
            .shifted(offsetForBase(wrap(i - 1), base), offsetForBase(i, base)));
    final lengths = List.generate(
        count,
        (i) => math.max(
            0.0,
            geometryDot(shifted[wrap(i + 1)].vertex - shifted[i].vertex,
                frames[i].nextRay)));
    final explicit = _normalizeSettings(
        List.generate(count, (i) => overrides[i] ?? shapeCorners[i].source),
        shifted,
        lengths);
    return List.unmodifiable(List.generate(count, (i) {
      // Reversing helpers retain two shifted contacts. An explicitly authored
      // straight vertex instead uses its single averaged boundary anchor.
      if (overrides[i] != null && !frames[i].backtracking)
        return explicit[i].geometry.resolve(explicit[i], shifted[i]);
      final source = shapeCorners[i];
      return source.source.geometry.resolveBoundary(source,
          previousDistance: offsetForBase(wrap(i - 1), base),
          nextDistance: offsetForBase(i, base));
    }));
  }

  List<AnyResolvedCorner> _corners(AnyShapeBase base) => switch (base) {
        AnyShapeBase.shapeBorder => shapeCorners,
        AnyShapeBase.outerBorder => outerCorners,
        AnyShapeBase.innerBorder => innerCorners,
        AnyShapeBase.zeroBorder => zeroCorners,
      };

  Path _areaFor(AnyShapeBase base) {
    final cached = _paths[base];
    if (cached != null) return cached;
    if (base == AnyShapeBase.shapeBorder || base == AnyShapeBase.zeroBorder) {
      return _paths[base] = _outline(_corners(base));
    }
    final source = _areaFor(AnyShapeBase.shapeBorder);
    if (base == AnyShapeBase.innerBorder && _emptySharpInner()) {
      return _paths[base] = Path();
    }
    final boundary = _corners(base);
    if (identical(boundary, shapeCorners)) return _paths[base] = source;
    final explicit =
        base == AnyShapeBase.outerBorder ? _explicitOuter : _explicitInner;
    if (explicit.any((e) => e)) {
      // Explicit boundary overrides are artistic controls; do not force nesting.
      return _paths[base] = _outline(boundary);
    }
    if (_directBand(base)) {
      return _paths[base] = _outline(boundary);
    }
    Path? swept;
    assert(diagnostics.record(diagnostics.GeometryWork.assembly));
    final sweeps = <Path>[];
    for (var i = 0; i < count; i++) {
      final sweep = _sideSweep(shapeCorners, boundary, i);
      sweeps.add(sweep);
      swept = swept == null
          ? sweep
          : _combinePaths(PathOperation.union, swept, sweep);
    }
    final operation = base == AnyShapeBase.outerBorder
        ? PathOperation.union
        : PathOperation.difference;
    try {
      return _paths[base] = _combinePaths(operation, source, swept!);
    } on StateError {
      // A - union(B,C) == (A-B)-C. Resolving each sweep against the source
      // avoids a rejected coincident compound without changing the geometry.
      var area = source;
      for (final sweep in sweeps) {
        area = _combinePaths(operation, area, sweep);
      }
      return _paths[base] = area;
    }
  }

  bool _simpleBoxBand(List<AnyResolvedCorner> boundary) {
    if (count != 4) return false;
    for (var i = 0; i < count; i++) {
      final f = frames[i];
      if (f.convexity < 0 ||
          geometryDot(f.previousRay, f.nextRay).abs() > 1e-10 ||
          !boundary[i].traits.rectangularBand) {
        return false;
      }
      final a = boundary[i], b = boundary[wrap(i + 1)];
      if (geometryDot(b.frame.vertex - a.frame.vertex, f.nextRay) <= 0 ||
          geometryDot(b.start - a.end, f.nextRay) < -1e-9) return false;
    }
    return true;
  }

  bool _emptySharpInner() {
    if (diagnostics.forceGeneralRegions ||
        count != 4 ||
        _explicitInner.any((e) => e)) return false;
    for (var i = 0; i < count; i++) {
      final c = shapeCorners[i], f = frames[i];
      if (!_directCorner(c) ||
          !c.traits.sharpSource ||
          f.convexity < 0 ||
          geometryDot(f.previousRay, f.nextRay).abs() > 1e-10) return false;
    }
    final shifted = List.generate(
        count,
        (i) => frames[i]
            .shiftedVertex(sideInsideOffset[wrap(i - 1)], sideInsideOffset[i]));
    return List.generate(
            count,
            (i) => geometryDot(
                shifted[wrap(i + 1)] - shifted[i], frames[i].nextRay))
        .any((span) => span <= 0);
  }

  bool _simpleBand(List<AnyResolvedCorner> band) =>
      _simpleBands.putIfAbsent(band, () {
        if (!band.every(_directCorner)) return false;
        for (var i = 0; i < count; i++) {
          final a = band[i], b = band[wrap(i + 1)], f = frames[i];
          if (f.parallel ||
              geometryDot(b.frame.vertex - a.frame.vertex, f.nextRay) <= 0 ||
              geometryDot(b.start - a.end, f.nextRay) < -1e-9) return false;
        }
        return _simpleBoxBand(band) || !_sourceCrosses(band);
      });

  bool _directBand(AnyShapeBase base) {
    if (diagnostics.forceGeneralRegions) return false;
    return _directBands.putIfAbsent(base, () {
      final band = _corners(base);
      if (!_simpleBand(band)) return false;
      final explicit =
          base == AnyShapeBase.outerBorder ? _explicitOuter : _explicitInner;
      if (explicit.any((e) => e) || identical(band, shapeCorners)) return true;
      // Convex box rounded/bevel policies preserve nesting while all directed
      // spans survive. No curve-pair search is needed to establish these strips.
      if (_simpleBoxBand(shapeCorners) && _simpleBoxBand(band)) return true;
      // Prove the actual swept strips as well as the resulting outline.
      return base == AnyShapeBase.outerBorder
          ? _certifyPartition(band, shapeCorners)
          : _certifyPartition(shapeCorners, band);
    });
  }

  bool _certifyPartition(
          List<AnyResolvedCorner> outer, List<AnyResolvedCorner> inner) =>
      _partitions.putIfAbsent((outer, inner), () {
        if (!_simpleBand(outer) || !_simpleBand(inner)) return false;
        if (identical(outer, inner)) return true;
        final segments = [
          ..._outlineSegments(outer),
          ..._outlineSegments(inner)
        ];
        final connectors = <AnyCornerSegment>[];
        for (var i = 0; i < count; i++) {
          final prev = sides[wrap(i - 1)].width > 0, next = sides[i].width > 0;
          final t = prev == next
              ? 0.5
              : prev
                  ? 1.0
                  : 0.0;
          final a = outer[i].pointAt(t), b = inner[i].pointAt(t);
          if ((a - b).distance > 1e-9)
            connectors.add(AnyCornerSegment.line(a, b));
        }
        final error = [...outer, ...inner]
            .map((c) => c.tolerance * 0.25)
            .reduce(math.min);
        if (_segmentsCross([...segments, ...connectors], error)) return false;
        final outerPath = _outline(outer), innerPath = _outline(inner);
        // With noncrossing simple loops, an interior witness establishes nesting.
        // A thin/ambiguous interior is left to the general route.
        var nested = false;
        for (final corner in inner) {
          final p = corner.pointAt(0.5) +
              geometryLeft(corner.tangentAt(0.5)) *
                  (frames.first.winding * corner.tolerance * 4);
          if (innerPath.contains(p)) {
            if (!outerPath.contains(p)) return false;
            nested = true;
            break;
          }
        }
        if (!nested) return false;
        for (final connector in connectors) {
          final p = (connector.start + connector.end) / 2;
          if (!outerPath.contains(p) || innerPath.contains(p)) return false;
        }
        return true;
      });

  bool _directRing() =>
      !diagnostics.forceGeneralRegions &&
      _directBand(AnyShapeBase.outerBorder) &&
      (_emptySharpInner() ||
          _directBand(AnyShapeBase.innerBorder) &&
              (!_explicitOuter.any((e) => e) && !_explicitInner.any((e) => e) ||
                  _certifyPartition(outerCorners, innerCorners)));

  Path _ring() {
    if (_directRing()) {
      final path = _outline(outerCorners, reverse: frames.first.winding < 0);
      if (!_emptySharpInner()) {
        path.addPath(_outline(innerCorners, reverse: frames.first.winding > 0),
            Offset.zero);
      }
      return path..fillType = PathFillType.nonZero;
    }
    final artistic =
        _explicitOuter.any((e) => e) || _explicitInner.any((e) => e);
    return _combinePaths(
        artistic ? PathOperation.xor : PathOperation.difference,
        _areaFor(AnyShapeBase.outerBorder),
        _areaFor(AnyShapeBase.innerBorder));
  }

  Path _sideSweep(
      List<AnyResolvedCorner> a, List<AnyResolvedCorner> b, int side,
      {bool simple = false}) {
    final next = wrap(side + 1), prev = wrap(side - 1);
    final from = sides[prev].width > 0 ? 0.5 : 0.0;
    final to = sides[next].width > 0 ? 0.5 : 1.0;
    Path strip(List<AnyResolvedCorner> a, List<AnyResolvedCorner> b) {
      final path = Path();
      a[side].appendTo(path, from: from, moveTo: true);
      path.lineTo(a[next].start.dx, a[next].start.dy);
      a[next].appendTo(path, to: to);
      final p = b[next].pointAt(to);
      path.lineTo(p.dx, p.dy);
      b[next].appendTo(path, from: to, to: 0);
      path.lineTo(b[side].end.dx, b[side].end.dy);
      b[side].appendTo(path, from: 1, to: from);
      return path..close();
    }

    if (simple) {
      final segments = _stripSegments([
        ...a[side]._range(from, 1),
        AnyCornerSegment.line(a[side].end, a[next].start),
        ...a[next]._range(0, to)
      ], [
        ...b[side]._range(from, 1),
        AnyCornerSegment.line(b[side].end, b[next].start),
        ...b[next]._range(0, to)
      ]);
      return _curveArea(segments) >= 0 ? strip(a, b) : strip(b, a);
    }
    final samples = [
      ..._cornerSamples(a[side], from, 1),
      ..._cornerSamples(a[next], 0, to),
      ..._cornerSamples(b[next], 0, to).reversed,
      ..._cornerSamples(b[side], from, 1).reversed
    ];
    if (!_pointsCross(samples))
      return _signedArea(samples) >= 0 ? strip(a, b) : strip(b, a);
    // A collapsed straight span can fold the side strip. Keep the exact curved
    // boundaries, and union the two straight-span triangles separately.
    final area = _SweepArea();
    _sweepCorner(area, a[side], b[side], from, 1);
    _sweepQuad(area, a[side].end, a[next].start, b[side].end, b[next].start);
    _sweepCorner(area, a[next], b[next], 0, to);
    return area.finish();
  }

  List<Path> _sideAreas() {
    if (_paintRegions != null) return _paintRegions!;
    if (_simpleSidePartition()) {
      return _paintRegions = List.unmodifiable(List.generate(
          count,
          (i) => sides[i].width == 0
              ? Path()
              : _sideSweep(outerCorners, innerCorners, i, simple: true)));
    }
    assert(diagnostics.record(diagnostics.GeometryWork.assembly));
    final outer = _areaFor(AnyShapeBase.outerBorder),
        inner = _areaFor(AnyShapeBase.innerBorder);
    // Oppositely authored explicit boundaries may intentionally cross.
    final artistic =
        _explicitOuter.any((e) => e) || _explicitInner.any((e) => e);
    final target = _combinePaths(
        artistic ? PathOperation.xor : PathOperation.difference, outer, inner);
    Path? claimed;
    final result = <Path>[];
    final previousSweeps = <Path>[];
    for (var i = 0; i < count; i++) {
      if (sides[i].width == 0) {
        result.add(Path());
        continue;
      }
      // Paint ownership connects the two boundary split points directly.
      // Routing that connector through the shape creates a kink under mixed
      // alignments and makes explicit border fills depend on the shape setting.
      final sweep = _sideSweep(outerCorners, innerCorners, i);
      var region = _combinePaths(PathOperation.intersect, sweep, target);
      if (claimed != null) {
        try {
          region = _combinePaths(PathOperation.difference, region, claimed);
        } on StateError {
          // A is already inside the target. Earlier sweeps claim precisely
          // their union inside that target, so subtracting the original sweeps
          // preserves ownership without reusing clipped, coincident edges.
          for (final previous in previousSweeps) {
            region = _combinePaths(PathOperation.difference, region, previous);
          }
        }
      }
      previousSweeps.add(sweep);
      result.add(region);
      claimed = claimed == null
          ? region
          : _combinePaths(PathOperation.union, claimed, region);
    }
    return _paintRegions = List.unmodifiable(result);
  }

  bool _simpleSidePartition() {
    return _directPartition ??= !diagnostics.forceGeneralRegions &&
        !_emptySharpInner() &&
        _directRing() &&
        _certifyPartition(outerCorners, innerCorners);
  }

  AnyRegions _buildRegions(bool backgroundMerge) {
    final backgroundFill = background;
    var backgroundTarget = backgroundPath;
    if (!sides.any((s) => s.width > 0 && s.hasFill)) {
      return AnyRegions(
          background: backgroundTarget != null && backgroundFill != null
              ? (backgroundFill, backgroundTarget)
              : null,
          regions: const []);
    }
    // A complete, uniformly filled border does not need side ownership at all.
    // Build its final area once instead of splitting it and unioning it again.
    final fill = sides.first;
    if (sides.every((s) => s.width > 0 && s.isSameAs(fill))) {
      final ring = _ring();
      if (backgroundMerge &&
          backgroundTarget != null &&
          backgroundFill != null &&
          fill.isSameAs(backgroundFill) &&
          sides.every((s) => s.align == AnySide.alignOutside)) {
        return AnyRegions(background: (
          backgroundFill,
          _mergeBackground(backgroundTarget, ring, certified: _directRing())
        ), regions: const []);
      }
      return AnyRegions(
          background: backgroundTarget != null && backgroundFill != null
              ? (backgroundFill, backgroundTarget)
              : null,
          regions: List.unmodifiable([(fill, ring)]));
    }
    final paths = _sideAreas();
    final fills = <AnyFill>[], regions = <Path>[];
    for (var i = 0; i < count; i++) {
      final side = sides[i];
      if (side.width == 0 || !side.hasFill) continue;
      if (backgroundMerge &&
          backgroundTarget != null &&
          backgroundFill != null &&
          side.align == AnySide.alignOutside &&
          side.isSameAs(backgroundFill)) {
        backgroundTarget = _mergeBackground(backgroundTarget, paths[i],
            certified: _simpleSidePartition());
        continue;
      }
      var index = fills.indexWhere((f) => f.isSameAs(side));
      if (index < 0) {
        index = fills.length;
        fills.add(side);
        regions.add(Path.from(paths[i]));
      } else if (_simpleSidePartition()) {
        regions[index].addPath(paths[i], Offset.zero);
      } else {
        regions[index] =
            _combinePaths(PathOperation.union, regions[index], paths[i]);
      }
    }
    return AnyRegions(
        background: backgroundTarget != null && backgroundFill != null
            ? (backgroundFill, backgroundTarget)
            : null,
        regions: List.unmodifiable(
            List.generate(fills.length, (i) => (fills[i], regions[i]))));
  }

  Path _mergeBackground(Path background, Path region,
      {required bool certified}) {
    // These sources are simple, consistently oriented filled outlines. Both
    // operands have nonnegative winding, so concatenation is their union.
    if (certified &&
        frames.first.winding > 0 &&
        (backgroundBase == AnyShapeBase.shapeBorder &&
                _simpleBand(shapeCorners) ||
            backgroundBase == AnyShapeBase.outerBorder ||
            backgroundBase == AnyShapeBase.innerBorder)) {
      return Path.from(background)..addPath(region, Offset.zero);
    }
    return _combinePaths(PathOperation.union, background, region);
  }
}

bool _directCorner(AnyResolvedCorner c) => c.traits.directCandidate;

List<AnyCornerSegment> _outlineSegments(List<AnyResolvedCorner> corners) => [
      for (var i = 0; i < corners.length; i++) ...[
        ...corners[i].segments,
        AnyCornerSegment.line(
            corners[i].end, corners[(i + 1) % corners.length].start),
      ],
    ];

List<AnyCorner> _normalizeSettings(
    List<AnyCorner> input, List<AnyCornerFrame> frames, List<double> lengths) {
  final count = input.length;
  if (input.any((c) => c is _LerpCorner)) {
    final from = _normalizeSettings(
        input.map((c) => c is _LerpCorner ? c.from : c).toList(),
        frames,
        lengths);
    final to = _normalizeSettings(
        input.map((c) => c is _LerpCorner ? c.to : c).toList(),
        frames,
        lengths);
    return _normalizeSettings(
        List.generate(
            count,
            (i) => input[i] is _LerpCorner
                ? AnyCorner.lerpResolved(
                    from[i], to[i], (input[i] as _LerpCorner).t)
                : from[i]),
        frames,
        lengths);
  }
  double factor(int i) => frames[i].parallel
      ? 0
      : input[i].geometry.contactScale(input[i], frames[i]);
  for (final c in input) {
    if (c.p.isNaN ||
        c.n.isNaN ||
        c.p == double.negativeInfinity ||
        c.n == double.negativeInfinity) {
      throw ArgumentError(
          'Corner dimensions cannot be NaN or negative infinity.');
    }
  }
  final p = input.map((c) => math.max(0.0, c.p)).toList();
  final n = input.map((c) => math.max(0.0, c.n)).toList();
  for (var side = 0; side < count; side++) {
    final next = (side + 1) % count, f1 = factor(side), f2 = factor(next);
    if (f1 == 0) {
      if (!n[side].isFinite) n[side] = 0;
    }
    if (f2 == 0) {
      if (!p[next].isFinite) p[next] = 0;
    }
    final a = n[side] * f1, b = p[next] * f2, available = lengths[side];
    if (!a.isFinite && !b.isFinite) {
      n[side] = available / (2 * f1);
      p[next] = available / (2 * f2);
    } else if (!a.isFinite) {
      n[side] = math.max(0, available - b) / f1;
    } else if (!b.isFinite) {
      p[next] = math.max(0, available - a) / f2;
    }
  }
  for (var i = 0; i < count; i++) {
    if (!input[i].p.isFinite && !input[i].n.isFinite)
      p[i] = n[i] = math.min(p[i], n[i]);
  }
  final scales = List.filled(count, 1.0);
  for (var side = 0; side < count; side++) {
    final next = (side + 1) % count;
    final a = input[side].geometry.retainsSingleZeroExtent ||
            p[side] > 0 && n[side] > 0
        ? n[side] * factor(side)
        : 0.0;
    final b = input[next].geometry.retainsSingleZeroExtent ||
            p[next] > 0 && n[next] > 0
        ? p[next] * factor(next)
        : 0.0;
    if (a + b > lengths[side] && a + b > 0) {
      final scale = lengths[side] / (a + b);
      scales[side] = math.min(scales[side], scale);
      scales[next] = math.min(scales[next], scale);
    }
  }
  return List.generate(count,
      (i) => input[i].copyWith(p: p[i] * scales[i], n: n[i] * scales[i]));
}

Path _outline(List<AnyResolvedCorner> corners, {bool reverse = false}) {
  final path = Path();
  if (reverse) {
    corners.last.appendTo(path, from: 1, to: 0, moveTo: true);
    for (final corner in corners.reversed.skip(1)) {
      path.lineTo(corner.end.dx, corner.end.dy);
      corner.appendTo(path, from: 1, to: 0);
    }
    return path..close();
  }
  corners.first.appendTo(path, moveTo: true);
  for (final corner in corners.skip(1)) {
    path.lineTo(corner.start.dx, corner.start.dy);
    corner.appendTo(path);
  }
  return path..close();
}

bool _sourceCrosses(List<AnyResolvedCorner> corners) {
  final segments = <AnyCornerSegment>[];
  for (var i = 0; i < corners.length; i++) {
    final corner = corners[i], next = corners[(i + 1) % corners.length];
    segments.addAll(corner.segments);
    segments.add(AnyCornerSegment.line(corner.end, next.start));
  }
  return _segmentsCross(
      segments, corners.map((c) => c.tolerance * 0.25).reduce(math.min));
}

List<AnyCornerSegment> _stripSegments(
        List<AnyCornerSegment> a, List<AnyCornerSegment> b) =>
    [
      ...a,
      AnyCornerSegment.line(a.last.end, b.last.end),
      for (final s in b.reversed)
        AnyCornerSegment(s.end, s.control2, s.control1, s.start,
            isLine: s.isLine),
      AnyCornerSegment.line(b.first.start, a.first.start)
    ];

double _curveArea(List<AnyCornerSegment> segments) {
  // Three-point Gauss integration is exact for the degree-five cubic area
  // integrand. Rebase first so translation does not amplify round-off.
  const delta = 0.3872983346207417;
  final origin = segments.first.start;
  var area = 0.0;
  for (final s in segments) {
    double f(double t) =>
        geometryCross(s.pointAt(t) - origin, s.derivativeAt(t));
    area += (5 * f(0.5 - delta) + 8 * f(0.5) + 5 * f(0.5 + delta)) / 18;
  }
  return area;
}

// Test the small canonical curve collection first. Bounding boxes reject most
// pairs without flattening; only intersecting boxes need adaptive subdivision.
// In particular, a normal rounded box must not allocate thousands of samples
// merely to discover that its four corner regions are far apart.
class _CurvePiece {
  final AnyCornerSegment segment;
  late final Rect bounds = Rect.fromLTRB(
      math.min(math.min(segment.start.dx, segment.end.dx),
          math.min(segment.control1.dx, segment.control2.dx)),
      math.min(math.min(segment.start.dy, segment.end.dy),
          math.min(segment.control1.dy, segment.control2.dy)),
      math.max(math.max(segment.start.dx, segment.end.dx),
          math.max(segment.control1.dx, segment.control2.dx)),
      math.max(math.max(segment.start.dy, segment.end.dy),
          math.max(segment.control1.dy, segment.control2.dy)));
  late final double flatness = _flatness();
  late final (_CurvePiece, _CurvePiece) halves = _split();
  _CurvePiece(this.segment);
  double _flatness() {
    if (segment.isLine) return 0;
    final chord = segment.end - segment.start, length = chord.distance;
    return length == 0
        ? math.max((segment.control1 - segment.start).distance,
            (segment.control2 - segment.start).distance)
        : math.max(geometryCross(chord, segment.control1 - segment.start).abs(),
                geometryCross(chord, segment.control2 - segment.start).abs()) /
            length;
  }

  (_CurvePiece, _CurvePiece) _split() {
    final (a, b) = segment.split(0.5);
    return (_CurvePiece(a), _CurvePiece(b));
  }

  bool get monotone {
    bool ordered(double a, double b, double c, double d) =>
        a <= b && b <= c && c <= d || a >= b && b >= c && c >= d;
    final s = segment;
    return ordered(s.start.dx, s.control1.dx, s.control2.dx, s.end.dx) ||
        ordered(s.start.dy, s.control1.dy, s.control2.dy, s.end.dy);
  }
}

bool _piecesCross(_CurvePiece a, _CurvePiece b, double error, [int depth = 0]) {
  final x = a.bounds, y = b.bounds;
  if (x.left > y.right ||
      y.left > x.right ||
      x.top > y.bottom ||
      y.top > x.bottom) return false;
  // Positive-width boxes touching at an extremum cannot cross in their
  // interiors. Keep degenerate line boxes, which can cross another curve.
  if (x.width > 0 && y.width > 0 && (x.left == y.right || y.left == x.right))
    return false;
  if (x.height > 0 && y.height > 0 && (x.top == y.bottom || y.top == x.bottom))
    return false;
  if (a.flatness <= error && b.flatness <= error) {
    return geometryIntersection(
            a.segment.start, a.segment.end, b.segment.start, b.segment.end) !=
        null;
  }
  if (depth >= 48)
    throw StateError('Curve intersection exceeded subdivision limit.');
  if (a.flatness >= b.flatness) {
    final (first, last) = a.halves;
    return _piecesCross(first, b, error, depth + 1) ||
        _piecesCross(last, b, error, depth + 1);
  }
  final (first, last) = b.halves;
  return _piecesCross(a, first, error, depth + 1) ||
      _piecesCross(a, last, error, depth + 1);
}

bool _pieceLoops(_CurvePiece piece, double error, [int depth = 0]) {
  if (piece.monotone || piece.flatness <= error) return false;
  if (depth >= 24)
    throw StateError('Curve loop check exceeded subdivision limit.');
  final (a, b) = piece.halves;
  return _piecesCross(a, b, error) ||
      _pieceLoops(a, error, depth + 1) ||
      _pieceLoops(b, error, depth + 1);
}

bool _segmentsCross(List<AnyCornerSegment> segments, double error) {
  final pieces = segments.map(_CurvePiece.new).toList()
    ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
  for (var i = 0; i < pieces.length; i++) {
    final a = pieces[i];
    if (_pieceLoops(a, error)) return true;
    for (var j = i + 1; j < pieces.length; j++) {
      final b = pieces[j];
      if (b.bounds.left > a.bounds.right) break;
      if (_piecesCross(a, b, error)) return true;
    }
  }
  return false;
}

void _triangle(_SweepArea area, Offset a, Offset b, Offset c) {
  // Quantize only the exceptional tessellated fold, below its 0.001-unit error
  // budget. Ordinary strips retain the original canonical curves unchanged.
  Offset snap(Offset p) =>
      Offset((p.dx * 4096).round() / 4096, (p.dy * 4096).round() / 4096);
  a = snap(a);
  b = snap(b);
  c = snap(c);
  final cross = geometryCross(b - a, c - a);
  if (cross.abs() < 1e-12) return;
  if (cross < 0) {
    final tmp = b;
    b = c;
    c = tmp;
  }
  final path = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..close();
  area.add(path);
}

void _sweepQuad(_SweepArea path, Offset a, Offset b, Offset c, Offset d) {
  _triangle(path, a, b, d);
  _triangle(path, a, d, c);
}

void _sweepCorner(_SweepArea area, AnyResolvedCorner a, AnyResolvedCorner b,
    double from, double to) {
  final samples = [
    ..._cornerSamples(a, from, to),
    ..._cornerSamples(b, from, to).reversed
  ];
  if (!_pointsCross(samples)) {
    Path strip(AnyResolvedCorner a, AnyResolvedCorner b) {
      final path = Path();
      a.appendTo(path, from: from, to: to, moveTo: true);
      final p = b.pointAt(to);
      path.lineTo(p.dx, p.dy);
      b.appendTo(path, from: to, to: from);
      return path..close();
    }

    area.add(_signedArea(samples) >= 0 ? strip(a, b) : strip(b, a));
    return;
  }
  final breaks = <double>{from, to};
  for (final corner in [a, b]) {
    for (final sample in corner._flatten()) {
      if (sample.$1 > from && sample.$1 < to) breaks.add(sample.$1);
    }
  }
  final sorted = breaks.toList()..sort();
  for (var i = 1; i < sorted.length; i++) {
    _sweepQuad(area, a.pointAt(sorted[i - 1]), a.pointAt(sorted[i]),
        b.pointAt(sorted[i - 1]), b.pointAt(sorted[i]));
  }
}

List<Offset> _cornerSamples(AnyResolvedCorner c, double from, double to) => [
      c.pointAt(from),
      ...c
          ._flatten(error: 0.01)
          .where((p) => p.$1 > from && p.$1 < to)
          .map((p) => p.$2),
      c.pointAt(to)
    ];
double _signedArea(List<Offset> points) {
  var result = 0.0;
  final origin = points.first;
  for (var i = 0; i < points.length; i++) {
    result += geometryCross(
        points[i] - origin, points[(i + 1) % points.length] - origin);
  }
  return result;
}

bool _pointsCross(List<Offset> points, {bool closed = true}) {
  final count = closed ? points.length : points.length - 1;
  final edges = List.generate(count, (i) {
    final a = points[i], b = points[(i + 1) % points.length];
    return (
      index: i,
      a: a,
      b: b,
      minX: math.min(a.dx, b.dx),
      maxX: math.max(a.dx, b.dx),
      minY: math.min(a.dy, b.dy),
      maxY: math.max(a.dy, b.dy)
    );
  })
    ..sort((a, b) => a.minX.compareTo(b.minX));
  // Sweep interval bounds before exact segment predicates. Fine flattening
  // must not turn every contour preparation into a quadratic all-pairs scan.
  for (var i = 0; i < edges.length; i++) {
    final a = edges[i];
    for (var j = i + 1; j < edges.length; j++) {
      final b = edges[j];
      if (b.minX > a.maxX) break;
      final apart = (a.index - b.index).abs();
      if (apart == 1 ||
          closed && apart == count - 1 ||
          a.minY > b.maxY ||
          b.minY > a.maxY) continue;
      if (geometryIntersection(a.a, a.b, b.a, b.b) != null) return true;
    }
  }
  return false;
}

// Simplify small batches before combining the complete sweep. Feeding thousands
// of overlapping subpaths directly to PathOps can exhaust its winding resolver.
class _SweepArea {
  final List<Path?> _levels = [];
  Path _batch = Path();
  final List<Path> _batchParts = [];
  int _count = 0;
  void add(Path path) {
    _batch.addPath(path, Offset.zero);
    _batchParts.add(path);
    if (++_count == 8) _flush();
  }

  void _flush() {
    if (_count == 0) return;
    Path path;
    try {
      path = _combinePaths(PathOperation.union, _batch, Path());
    } on StateError {
      // PathOps can reject a compound batch with coincident curved edges.
      // Union the same finite regions pairwise; retain the exact geometry and
      // propagate any failure of that operation instead of dropping a piece.
      path = Path.from(_batchParts.first);
      for (final part in _batchParts.skip(1)) {
        path = _combinePaths(PathOperation.union, path, part);
      }
    }
    _batch = Path();
    _batchParts.clear();
    _count = 0;
    var level = 0;
    while (level < _levels.length && _levels[level] != null) {
      path = _combinePaths(PathOperation.union, _levels[level]!, path);
      _levels[level] = null;
      level++;
    }
    if (level == _levels.length) _levels.add(null);
    _levels[level] = path;
  }

  Path finish() {
    _flush();
    Path? path;
    for (final level in _levels) {
      if (level != null)
        path = path == null
            // This is deliberate normalization of a folded compound, not an
            // empty accumulator shortcut. PathOps can otherwise return an
            // incorrect later subtraction without throwing (regression 280).
            ? _combinePaths(PathOperation.union, Path(), level)
            : _combinePaths(PathOperation.union, path, level);
    }
    return path ?? Path();
  }
}

// PathOps produces disjoint result contours. Explicit parity preserves holes
// on CanvasKit versions that incorrectly copy the first operand's fill rule.
Path _combinePaths(PathOperation operation, Path a, Path b) {
  Path combine(PathOperation op, Path a, Path b) {
    assert(diagnostics.record(diagnostics.GeometryWork.boolean));
    return Path.combine(op, a, b);
  }

  Path result;
  try {
    result = combine(operation, a, b);
  } on StateError {
    // Coincident-edge sorting in PathOps can be operand-order sensitive.
    // Retry the algebraically identical operation, preserving every curve.
    final reversed = switch (operation) {
      PathOperation.difference => PathOperation.reverseDifference,
      PathOperation.reverseDifference => PathOperation.difference,
      _ => operation,
    };
    try {
      result = combine(reversed, b, a);
    } on StateError {
      // Most operands do not need native normalization. On a rejected
      // coincident-edge batch, simplify the same filled operands and retry;
      // union with empty changes neither the area nor the ownership policy.
      final normalizedA = combine(PathOperation.union, Path(), a);
      final normalizedB = combine(PathOperation.union, Path(), b);
      if (kIsWeb) {
        normalizedA.fillType = PathFillType.evenOdd;
        normalizedB.fillType = PathFillType.evenOdd;
      }
      try {
        result = combine(operation, normalizedA, normalizedB);
      } on StateError {
        result = combine(reversed, normalizedB, normalizedA);
      }
    }
  }
  if (kIsWeb) result.fillType = PathFillType.evenOdd;
  return result;
}
