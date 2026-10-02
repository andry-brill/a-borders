import 'dart:ui';
import 'package:any_borders/any_borders.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import '../example/lib/main.dart' as gallery;
import '../example/lib/custom_corner.dart';
import 'support/transition_regressions.dart';

const size = Size(200, 100);
const side = AnySide(width: 6, align: 0, color: Color(0xff123456));

class _CountingBox extends AnyBoxDecoration {
  static int builds = 0;
  const _CountingBox({super.border, super.offset});
  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
      covariant AnyBoxBorder border, double offset, List<double> sideOffsets) {
    builds++;
    return super.buildPoints(bounds, direction, border, offset, sideOffsets);
  }
}

class _CountingCorner extends RoundedCorner {
  const _CountingCorner({super.p = 12, super.n = 12}) : super.elliptical();
  @override
  AnyCornerGeometry get geometry => const _CountingGeometry();
  @override
  _CountingCorner copyWith(
          {double? p, double? n, CornerConverter? converter}) =>
      _CountingCorner(p: p ?? this.p, n: n ?? this.n);
}

class _CountingGeometry extends RoundedCornerGeometry {
  static int sources = 0, boundaries = 0, preparations = 0;
  const _CountingGeometry();
  @override
  AnyResolvedCorner resolve(AnyCorner c, AnyCornerFrame f) {
    sources++;
    return super.resolve(c, f);
  }

  @override
  AnyResolvedCorner resolveBoundary(AnyResolvedCorner c,
      {required double previousDistance, required double nextDistance}) {
    boundaries++;
    return super.resolveBoundary(c,
        previousDistance: previousDistance, nextDistance: nextDistance);
  }

  @override
  AnyCornerTransition? prepareTransition(
      AnyResolvedCorner a, AnyResolvedCorner b) {
    preparations++;
    return parameterTransition(a.parameters!, b.parameters!);
  }
}

void sameCurve(AnyResolvedCorner a, AnyResolvedCorner b,
    {double tolerance = 1e-7}) {
  for (var i = 0; i <= 50; i++) {
    expect(
        (a.pointAt(i / 50) - b.pointAt(i / 50)).distance, lessThan(tolerance));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    AnyDecorationCache.clear();
    _CountingBox.builds = 0;
    _CountingGeometry.sources =
        _CountingGeometry.boundaries = _CountingGeometry.preparations = 0;
  });

  test('No horizontal has continuous analytic radii and exact endpoints', () {
    final e = gallery
        .examples()
        .whereType<gallery.E>()
        .singleWhere((e) => e.title == 'No horizontal');
    for (final reverse in [false, true]) {
      final tween = AnyDecorationTween(
          begin: reverse ? e.end : e.begin, end: reverse ? e.begin : e.end);
      expect(tween.lerp(0), same(tween.begin));
      expect(tween.lerp(1), same(tween.end));
      for (final t in [1e-8, .1, .4999, .5, .5001, .9, 1 - 1e-8]) {
        final u = reverse ? 1 - t : t;
        final c = tween.lerp(t).buildContour(size, null);
        final outer = c.outerCorners.first;
        expect(outer.parameters!.p, closeTo(30 - 10 * u, 1e-8));
        expect(outer.parameters!.n, closeTo(30, 1e-8));
        expect(outer.start.dy, closeTo(30 - 10 * u, 1e-8));
        expect(outer.frame.vertex.dx, closeTo(-30 + 20 * u, 1e-8));
        expect(c.innerCorners.first.parameters!.p, closeTo(30 - 10 * u, 1e-8));
      }
    }
  });

  test('simple prepared boundaries retain direct construction', () {
    final e = gallery
        .examples()
        .whereType<gallery.E>()
        .singleWhere((e) => e.title == 'No horizontal');
    final tween = AnyDecorationTween(begin: e.begin, end: e.end);
    final work = GeometryDiagnostics();
    work.run(() {
      for (final t in [.2, .4999, .5, .5001, .8]) {
        tween.lerp(t).buildContour(size, null).regions(backgroundMerge: false);
      }
    });
    expect(work[GeometryWork.fit], 0);
    expect(work[GeometryWork.flatten], 0);
    expect(work[GeometryWork.boolean], 0);
  });

  test('boundary transitions remain continuous with changing layout and offset',
      () {
    final e = gallery
        .examples()
        .whereType<gallery.E>()
        .singleWhere((e) => e.title == 'No horizontal');
    final tween = AnyDecorationTween(
        begin: AnyBoxDecoration(
            border: e.begin.borders.single as AnyBoxBorder, offset: -2),
        end: AnyBoxDecoration(
            border: e.end.borders.single as AnyBoxBorder, offset: 6));
    for (final t in [.1, .4999, .5, .5001, .9]) {
      final c = tween.lerp(t).buildContour(Size(200 + 20 * t, 100), null);
      final outer = c.outerCorners.first;
      expect(outer.parameters!.p, closeTo(30 - 10 * t, 1e-8));
      expect(outer.parameters!.n, closeTo(30, 1e-8));
      expect(outer.frame.vertex.dx, closeTo(-28 + 12 * t, 1e-8));
    }
  });

  test('preparation is lazy, reusable and custom-provider controlled', () {
    const a = _CountingBox(
        border: AnyBoxBorder(
            corners: _CountingCorner(),
            outerCorners: _CountingCorner(p: 16, n: 16),
            sides: side));
    const b = _CountingBox(
        border: AnyBoxBorder(corners: _CountingCorner(), sides: side));
    final tween = AnyDecorationTween(begin: a, end: b);
    final first = tween.lerp(.2).buildContour(size, null);
    first.clipPath;
    expect(_CountingBox.builds, 2);
    expect(_CountingGeometry.sources, 4);
    expect(_CountingGeometry.boundaries, 0);
    expect(_CountingGeometry.preparations, 0);
    final second = tween.lerp(.4).buildContour(size, null);
    expect(second.frames, same(first.frames));
    expect(second.shapeCorners, same(first.shapeCorners));
    second.outerCorners;
    expect(_CountingGeometry.preparations, 4);
    final calls = _CountingGeometry.boundaries;
    final third = tween.lerp(.7).buildContour(size, null);
    third.outerCorners;
    expect(_CountingGeometry.preparations, 4);
    expect(_CountingGeometry.boundaries, calls);
    expect(_CountingBox.builds, 2);
    third.zeroCorners;
    expect(_CountingGeometry.preparations, 8);
    tween.lerp(.8).buildContour(size, null).zeroCorners;
    expect(_CountingGeometry.preparations, 8);
  });

  test(
      'layout, direction, offset and retargeting invalidate relevant preparation',
      () {
    const a =
        _CountingBox(border: AnyBoxBorder(corners: RoundedCorner(radius: 12)));
    const b =
        _CountingBox(border: AnyBoxBorder(corners: RoundedCorner(radius: 20)));
    final tween = AnyDecorationTween(begin: a, end: b);
    final saved = tween.lerp(.5);
    saved.buildContour(size, TextDirection.ltr);
    tween.lerp(.7).buildContour(size, TextDirection.ltr);
    expect(_CountingBox.builds, 2);
    saved.buildContour(const Size(300, 100), TextDirection.ltr);
    saved.buildContour(size, TextDirection.rtl);
    expect(_CountingBox.builds, 6);
    tween.end = const _CountingBox(
        offset: 5, border: AnyBoxBorder(corners: RoundedCorner(radius: 28)));
    final changed = tween.lerp(.5).buildContour(size, TextDirection.ltr);
    expect(changed.frames.first.vertex, const Offset(-2.5, -2.5));
    expect(changed.shapeCorners.first.parameters!.p, 20);
    final original = saved.buildContour(size, TextDirection.ltr);
    expect(original.frames.first.vertex, Offset.zero);
    expect(original.shapeCorners.first.parameters!.p, 16);
    final prior = _CountingBox.builds;
    tween.lerp(.6).buildContour(size, TextDirection.ltr);
    expect(_CountingBox.builds, prior + 2);
  });

  test(
      'canonical fallback matches endpoint curves without repeated scoop fitting',
      () {
    const a = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: InverseRoundedCorner.elliptical(p: 24, n: 16),
            outerCorners: InverseRoundedCorner.elliptical(p: 18, n: 12),
            sides: side));
    const b = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: InverseRoundedCorner.elliptical(p: 24, n: 16),
            sides: side));
    final tween = AnyDecorationTween(begin: a, end: b);
    final from = a.buildContour(size, null).outerCorners;
    final to = b.buildContour(size, null).outerCorners;
    final first = GeometryDiagnostics();
    first.run(() => tween.lerp(.2).buildContour(size, null).outerCorners);
    expect(first[GeometryWork.fit], greaterThan(0));
    final steady = GeometryDiagnostics();
    steady.run(() {
      for (final t in [1e-7, .25, .4999, .5, .5001, .75, 1 - 1e-7]) {
        final c = tween.lerp(t).buildContour(size, null);
        for (var i = 0; i < c.count; i++) {
          for (var j = 0; j <= 32; j++) {
            final expected =
                Offset.lerp(from[i].pointAt(j / 32), to[i].pointAt(j / 32), t)!;
            expect((c.outerCorners[i].pointAt(j / 32) - expected).distance,
                lessThan(1e-7));
          }
        }
      }
    });
    expect(steady[GeometryWork.fit], 0);
  });

  test('generic custom transition and zero boundary reach both endpoint limits',
      () {
    const a = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: NotchCorner(),
            outerCorners: RoundedCorner(radius: 18),
            sides: side));
    const b = AnyBoxDecoration(
        border: AnyBoxBorder(corners: NotchCorner(), sides: side));
    final tween = AnyDecorationTween(begin: a, end: b);
    for (final (t, endpoint) in [(1e-8, a), (1 - 1e-8, b)]) {
      final actual = tween.lerp(t).buildContour(size, null);
      final expected = endpoint.buildContour(size, null);
      sameCurve(actual.outerCorners.first, expected.outerCorners.first,
          tolerance: 1e-5);
      sameCurve(actual.zeroCorners.first, expected.zeroCorners.first,
          tolerance: 1e-5);
    }
    final before =
        tween.lerp(.499999).buildContour(size, null).outerCorners.first;
    final after =
        tween.lerp(.500001).buildContour(size, null).outerCorners.first;
    sameCurve(before, after, tolerance: .001);
  });

  test(
      'inner transitions preserve sampled side ownership and forced-general areas',
      () {
    const a = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: RoundedCorner(radius: 20),
            innerCorners: BevelCorner(radius: 10),
            sides: side));
    const b = AnyBoxDecoration(
        border: AnyBoxBorder(corners: RoundedCorner(radius: 20), sides: side));
    final tween = AnyDecorationTween(begin: a, end: b);
    for (final t in [.1, .4999, .5, .5001, .9]) {
      final c = tween.lerp(t).buildContour(size, null);
      final actual = c.regions(backgroundMerge: false).regions.single.$2;
      final expected = GeometryDiagnostics(forceGeneralRegions: true).run(() =>
          AnyDecorationTween(begin: a, end: b)
              .lerp(t)
              .buildContour(size, null)
              .regions(backgroundMerge: false)
              .regions
              .single
              .$2);
      for (var y = -4.37; y < 105; y += 3.17) {
        for (var x = -4.61; x < 205; x += 3.29) {
          expect(
              actual.contains(Offset(x, y)), expected.contains(Offset(x, y)));
        }
      }
    }
  });

  test('exhausted automatic interiors retain their existing topology fallback',
      () {
    const a = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: RoundedCorner(radius: 12),
            innerCorners: RoundedCorner(radius: 8),
            sides: AnySide(width: 4, color: Color(0xff123456))));
    const b = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: RoundedCorner(radius: 12),
            sides: AnySide(width: 80, color: Color(0xff123456))));
    final tween = AnyDecorationTween(begin: a, end: b);
    for (final t in [.8, .99, 1 - 1e-8, 1.0]) {
      expect(
          tween
              .lerp(t)
              .buildContour(size, null)
              .pathFor(AnyShapeBase.innerBorder)
              .computeMetrics(),
          isEmpty);
    }
  });

  test('prepared transition pixels at DPR 1/2/3', () async {
    expect(await checkTransitionRegressions(), greaterThan(0));
  });
}
