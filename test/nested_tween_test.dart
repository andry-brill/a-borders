import 'dart:math' as math;
import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/extras/any_tab_decoration.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(200, 120);

List<AnyResolvedCorner> _corners(AnyContour contour, AnyShapeBase base) =>
    switch (base) {
      AnyShapeBase.shapeBorder => contour.shapeCorners,
      AnyShapeBase.outerBorder => contour.outerCorners,
      AnyShapeBase.innerBorder => contour.innerCorners,
      AnyShapeBase.zeroBorder => contour.zeroCorners,
    };

void _sameCurves(AnyContour actual, AnyContour expected,
    {double tolerance = 1e-5}) {
  for (final base in AnyShapeBase.values) {
    _sameBoundary(actual, expected, base, tolerance: tolerance);
  }
}

void _sameBoundary(AnyContour actual, AnyContour expected, AnyShapeBase base,
    {double tolerance = 1e-5}) {
  final a = _corners(actual, base), b = _corners(expected, base);
  expect(a.length, b.length);
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j <= 24; j++) {
      expect((a[i].pointAt(j / 24) - b[i].pointAt(j / 24)).distance,
          lessThan(tolerance),
          reason: '$base corner $i at $j/24');
    }
  }
}

void _sameArea(Path actual, Path expected) {
  expect(Path.combine(PathOperation.xor, actual, expected).computeMetrics(),
      isEmpty);
}

class _ProbeBox extends AnyBoxDecoration {
  static final discoveries = <(int, Rect, TextDirection?)>[];
  static final adjustments = <(int, double, List<double>)>[];
  static final builds = <int>[];
  final int id;
  const _ProbeBox(this.id, {super.border});
  static void reset() {
    discoveries.clear();
    adjustments.clear();
    builds.clear();
  }

  @override
  List<double> sideOffsetsForBorder(
      Rect bounds, TextDirection? direction, AnyBorder border) {
    discoveries.add((id, bounds, direction));
    return super.sideOffsetsForBorder(bounds, direction, border);
  }

  @override
  Rect adjustBounds(Rect bounds, TextDirection? direction,
      covariant AnyBoxBorder border, double offset, List<double> slots) {
    adjustments.add((id, offset, List.of(slots)));
    return super.adjustBounds(bounds, direction, border, offset, slots);
  }

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
      covariant AnyBoxBorder border, List<double> slots) {
    builds.add(id);
    return super.buildPoints(bounds, direction, border, slots);
  }

  @override
  bool operator ==(Object other) =>
      other is _ProbeBox && other.id == id && super == other;
  @override
  int get hashCode => Object.hash(super.hashCode, id);
}

class _SlotShape extends AnyDecoration {
  final List<double> slots;
  static final adjusted = <List<double>>[];
  const _SlotShape(this.slots);
  @override
  List<double> sideOffsetsForBorder(
          Rect bounds, TextDirection? direction, AnyBorder border) =>
      slots;
  @override
  Rect adjustBounds(Rect bounds, TextDirection? direction, AnyBorder border,
      double offset, List<double> slots) {
    adjusted.add(List.of(slots));
    return bounds.inflate(offset + slots.fold<double>(0, (a, b) => a + b));
  }

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
      AnyBorder border, List<double> slots) {
    final side =
        border.sides.copyWith(offset: slots.fold<double>(0, (a, b) => a + b));
    return [
      for (final point in [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomRight,
        bounds.bottomLeft
      ])
        AnyPoint(point: point, shape: border.corners, side: side)
    ];
  }

  @override
  bool operator ==(Object other) => identical(this, other);
  @override
  int get hashCode => identityHashCode(this);
}

class _CountingCorner extends RoundedCorner {
  const _CountingCorner(double radius) : super(radius: radius);
  @override
  AnyCornerGeometry get geometry => const _CountingGeometry();
  @override
  _CountingCorner copyWith(
          {double? p, double? n, CornerConverter? converter}) =>
      _CountingCorner(p ?? this.p);
}

class _CountingGeometry extends RoundedCornerGeometry {
  static int contacts = 0, boundaries = 0;
  const _CountingGeometry();
  @override
  double contactScale(AnyCorner corner, AnyCornerFrame frame) {
    contacts++;
    return super.contactScale(corner, frame);
  }

  @override
  AnyResolvedCorner resolveBoundary(AnyResolvedCorner source,
      {required double previousDistance, required double nextDistance}) {
    boundaries++;
    return super.resolveBoundary(source,
        previousDistance: previousDistance, nextDistance: nextDistance);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    AnyDecorationCache.clear();
    _ProbeBox.reset();
    _SlotShape.adjusted.clear();
    _CountingGeometry.contacts = _CountingGeometry.boundaries = 0;
  });

  test(
      'saved changing source corners retarget without assertions and refit at each size',
      () {
    const a = AnyBoxDecoration(
        border: AnyBoxBorder(corners: RoundedCorner(radius: 0)));
    const b = AnyBoxDecoration(
        border: AnyBoxBorder(corners: RoundedCorner(radius: 20)));
    const c = AnyBoxDecoration(
        border: AnyBoxBorder(corners: RoundedCorner(radius: 40)));
    final first = AnyDecorationTween(begin: a, end: b);
    final saved = first.lerp(.25);
    final second = AnyDecorationTween(begin: saved, end: c);
    final nested = second.lerp(.5);
    first.end = a;
    for (final size in [_size, const Size(40, 20)]) {
      final limit = size.shortestSide / 2;
      final expected =
          (.25 * math.min(20.0, limit) + math.min(40.0, limit)) / 2;
      final actual = nested.buildContour(size, null);
      expect(actual.shapeCorners.first.parameters!.p, closeTo(expected, 1e-9));
      _sameCurves(second.lerp(1e-8).buildContour(size, null),
          saved.buildContour(size, null));
      _sameCurves(second.lerp(1 - 1e-8).buildContour(size, null),
          c.buildContour(size, null));
    }
    final deeper = AnyDecorationTween(begin: nested, end: saved).lerp(.5);
    expect(deeper.buildContour(_size, null).shapeCorners.first.parameters!.p,
        closeTo(13.75, 1e-9));
  });

  test('nested mixed corner types and infinite corners normalize before use',
      () {
    for (final corner in const <AnyCorner>[
      RoundedCorner.infinity(),
      BevelCorner(radius: 20),
      InverseRoundedCorner(radius: 12)
    ]) {
      const a = AnyBoxDecoration(
          border: AnyBoxBorder(corners: RoundedCorner(radius: 6)));
      final b = AnyBoxDecoration(border: AnyBoxBorder(corners: corner));
      final saved = AnyDecorationTween(begin: a, end: b).lerp(.3);
      final next = AnyDecorationTween(begin: saved, end: a);
      _sameCurves(next.lerp(1e-8).buildContour(_size, null),
          saved.buildContour(_size, null));
      for (final t in [.1, .5, .9]) {
        final c = next.lerp(t).buildContour(_size, null);
        expect(c.clipPath.getBounds().isFinite, isTrue);
      }
    }
  });

  test(
      'nested samples preserve automatic/explicit outer inner and zero boundaries',
      () {
    const a = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: RoundedCorner(radius: 20),
            outerCorners: RoundedCorner(radius: 40),
            innerCorners: RoundedCorner(radius: 5),
            sides: AnySide(width: 10, align: 1)));
    const b = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: RoundedCorner(radius: 20),
            sides: AnySide(width: 10, align: 1)));
    for (final reverse in [false, true]) {
      final first =
          AnyDecorationTween(begin: reverse ? b : a, end: reverse ? a : b);
      for (final progress in [.25, .75]) {
        final saved = first.lerp(progress);
        final expected = saved.buildContour(_size, null);
        final next = AnyDecorationTween(begin: saved, end: b);
        _sameCurves(next.lerp(1e-8).buildContour(_size, null), expected);
        final middle = next.lerp(.5).buildContour(_size, null);
        final target = b.buildContour(_size, null);
        for (final base in AnyShapeBase.values) {
          final e = _corners(expected, base).first.parameters!.p;
          final t = _corners(target, base).first.parameters!.p;
          expect(_corners(middle, base).first.parameters!.p,
              closeTo((e + t) / 2, 1e-8));
        }
        final third = AnyDecorationTween(begin: next.lerp(.5), end: a);
        _sameCurves(third.lerp(1e-8).buildContour(_size, null), middle);
        _sameCurves(next.lerp(1 - 1e-8).buildContour(_size, null), target);
      }
    }
  });

  test(
      'nested canonical boundary curves stay continuous with layout and offset changes',
      () {
    const a = AnyBoxDecoration(
        offset: 2,
        border: AnyBoxBorder(
            corners: InverseRoundedCorner.elliptical(p: 24, n: 16),
            outerCorners: InverseRoundedCorner.elliptical(p: 18, n: 12),
            sides: AnySide(width: 6, align: 0)));
    const b = AnyBoxDecoration(
        offset: 2,
        border: AnyBoxBorder(
            corners: InverseRoundedCorner.elliptical(p: 24, n: 16),
            sides: AnySide(width: 6, align: 0)));
    const target = AnyBoxDecoration(
        offset: 7,
        border: AnyBoxBorder(
            corners: InverseRoundedCorner.elliptical(p: 24, n: 16),
            sides: AnySide(width: 6, align: 0)));
    final saved = AnyDecorationTween(begin: a, end: b).lerp(.25);
    final next = AnyDecorationTween(begin: saved, end: target);
    for (final size in [_size, const Size(260, 180)]) {
      _sameCurves(next.lerp(1e-8).buildContour(size, null),
          saved.buildContour(size, null));
      _sameCurves(next.lerp(1 - 1e-8).buildContour(size, null),
          target.buildContour(size, null));
      final sample = next.lerp(.5);
      final ordinary =
          sample.buildContour(size, null).regions(backgroundMerge: false);
      final general = GeometryDiagnostics(forceGeneralRegions: true).run(() =>
          sample.buildContour(size, null).regions(backgroundMerge: false));
      for (var i = 0; i < ordinary.regions.length; i++) {
        for (var x = -8.3; x < size.width + 8; x += 3.17) {
          for (var y = -8.7; y < size.height + 8; y += 3.29) {
            expect(ordinary.regions[i].$2.contains(Offset(x, y)),
                general.regions[i].$2.contains(Offset(x, y)));
          }
        }
      }
    }
  });

  for (final reverse in [false, true]) {
    test(
        'point topology fallback preserves complete samples (reverse=$reverse)',
        () {
      const side = AnySide(width: 6, align: 0, color: Color(0xff123456));
      const a = AnyBoxDecoration(
          border: AnyBoxBorder(
              corners: RoundedCorner(radius: 20),
              outerCorners: RoundedCorner(radius: 40),
              sides: side));
      const b = AnyBoxDecoration(
          border:
              AnyBoxBorder(corners: RoundedCorner(radius: 20), sides: side));
      const target = AnyTabDecoration(
          border:
              AnyBoxBorder(corners: RoundedCorner(radius: 20), sides: side));
      final saved = AnyDecorationTween(begin: a, end: b).lerp(.25);
      final tween = AnyDecorationTween(
          begin: reverse ? target : saved, end: reverse ? saved : target);
      const size = Size(200, 100);
      expect(saved.buildContour(size, null).outerCorners.first.parameters!.p,
          35.75);
      for (final t in [1e-9, .25, .499999, .5, .75, 1 - 1e-9]) {
        final sample = tween.lerp(t);
        final expected = (t < .5 ? tween.begin! : tween.end!)
            .buildContour(size, TextDirection.ltr);
        final actual = sample.buildContour(size, TextDirection.ltr);
        // Replacing the tween's prepared context must not mutate this sample.
        tween.lerp(.6).buildContour(const Size(240, 140), TextDirection.rtl);
        _sameCurves(actual, expected);
        for (final base in AnyShapeBase.values) {
          _sameArea(actual.pathFor(base), expected.pathFor(base));
        }
        _sameArea(actual.regions(backgroundMerge: false).regions.single.$2,
            expected.regions(backgroundMerge: false).regions.single.$2);
        final nested = AnyDecorationTween(begin: sample, end: b);
        _sameCurves(
            nested.lerp(1e-9).buildContour(size, TextDirection.ltr), expected);
      }
    });

    test(
        'exhausted boundary fallback preserves curves and area (reverse=$reverse)',
        () {
      const side = AnySide(width: 6, align: 0, color: Color(0xff123456));
      const a = AnyBoxDecoration(
          border: AnyBoxBorder(
              corners: RoundedCorner(radius: 20),
              innerCorners: RoundedCorner(radius: 12),
              sides: side));
      const b = AnyBoxDecoration(
          border:
              AnyBoxBorder(corners: RoundedCorner(radius: 20), sides: side));
      const target = AnyBoxDecoration(
          border: AnyBoxBorder(
              corners: RoundedCorner(radius: 20),
              sides: AnySide(width: 80, color: Color(0xff123456))));
      final saved = AnyDecorationTween(begin: a, end: b).lerp(.25);
      final tween = AnyDecorationTween(
          begin: reverse ? target : saved, end: reverse ? saved : target);
      const size = Size(200, 100);
      expect(saved.buildContour(size, null).innerCorners.first.parameters!.p,
          13.25);
      for (final t in [1e-9, .25, .499999, .5, .75, 1 - 1e-9]) {
        final sample = tween.lerp(t);
        final selected = t < .5 ? tween.begin! : tween.end!;
        final expected = selected.buildContour(size, null);
        final actual = sample.buildContour(size, null);
        tween.lerp(.6).buildContour(const Size(240, 140), TextDirection.rtl);
        _sameBoundary(actual, expected, AnyShapeBase.innerBorder);
        _sameArea(actual.pathFor(AnyShapeBase.innerBorder),
            expected.pathFor(AnyShapeBase.innerBorder));
        // Other bands and side metadata continue interpolating.
        final progress = reverse ? 1 - t : t;
        expect(actual.sides.first.width, closeTo(6 + 74 * progress, 1e-9));
        expect(actual.pathFor(AnyShapeBase.outerBorder).getBounds().left,
            closeTo(-(6 + 74 * progress) * (1 - progress) / 2, 1e-5));
        if (t < 1e-8 || t > 1 - 1e-8) _sameCurves(actual, expected);
        final general = GeometryDiagnostics(forceGeneralRegions: true).run(() {
          // Resolve lazy paths inside the diagnostic scope as well.
          final contour =
              AnyDecorationTween(begin: tween.begin!, end: tween.end!)
                  .lerp(t)
                  .buildContour(size, null);
          return (
            contour.pathFor(AnyShapeBase.innerBorder),
            contour.regions(backgroundMerge: false).regions.single.$2
          );
        });
        _sameArea(actual.pathFor(AnyShapeBase.innerBorder), general.$1);
        _sameArea(actual.regions(backgroundMerge: false).regions.single.$2,
            general.$2);
        // Retarget a saved fallback again, including the endpoint whose local
        // corner outline differs from its exhausted filled area.
        for (final againReverse in [false, true]) {
          final nested = AnyDecorationTween(
              begin: againReverse ? b : sample, end: againReverse ? sample : b);
          _sameCurves(
              nested
                  .lerp(againReverse ? 1 - 1e-9 : 1e-9)
                  .buildContour(size, null),
              actual);
        }
      }
    });
  }

  test('identity tweens return their endpoint and do not grow the sample graph',
      () {
    final saved = AnyDecorationTween(
            begin: const _ProbeBox(0),
            end: const _ProbeBox(1,
                border: AnyBoxBorder(corners: RoundedCorner(radius: 20))))
        .lerp(.25);
    AnyDecoration d = saved;
    for (var i = 0; i < 40; i++) {
      d = AnyDecorationTween(begin: d, end: d).lerp(.5);
    }
    expect(d, same(saved));
    d.buildContour(_size, null);
    expect(_ProbeBox.discoveries, hasLength(2));
    expect(_ProbeBox.adjustments, hasLength(2));
  });

  test(
      'shared nonidentical sample nodes evaluate once per layout and input context',
      () {
    AnyDecoration older = const _ProbeBox(0);
    AnyDecoration newer = AnyDecorationTween(
            begin: older,
            end: const _ProbeBox(1,
                border: AnyBoxBorder(sides: AnySide(width: 2))))
        .lerp(.3);
    for (var i = 0; i < 18; i++) {
      final next = AnyDecorationTween(begin: newer, end: older).lerp(.4);
      older = newer;
      newer = next;
    }
    for (final (size, direction, builds) in [
      (_size, TextDirection.ltr, 2),
      (_size, TextDirection.ltr, 0),
      (_size, TextDirection.rtl, 2),
      (const Size(240, 140), TextDirection.rtl, 2)
    ]) {
      _ProbeBox.reset();
      newer.buildContour(size, direction).clipPath;
      expect(_ProbeBox.discoveries, [
        (0, Offset.zero & size, direction),
        (1, Offset.zero & size, direction)
      ]);
      expect(_ProbeBox.adjustments, hasLength(2));
      expect(_ProbeBox.builds, hasLength(builds));
    }
  });

  test('shared nodes keep distinct offset contexts separate', () {
    const a = _SlotShape([0]), b = _SlotShape([10, 20, 30]);
    final left = AnyDecorationTween(begin: a, end: b).lerp(.5);
    final right = AnyDecorationTween(begin: b, end: a).lerp(.25);
    final root = AnyDecorationTween(begin: left, end: right).lerp(.5);
    final contour = root.buildContour(const Size(100, 60), null);
    expect(_SlotShape.adjusted, [
      [5],
      [15, 25, 15],
      [5, 15, 25],
      [15]
    ]);
    expect(contour.clipPath.getBounds(),
        const Rect.fromLTRB(-33.75, -33.75, 133.75, 93.75));
    expect(contour.sides.first.offset, 33.75);
  });

  test('shared changing corner expressions normalize with bounded work', () {
    AnyDecoration older = const AnyBoxDecoration(
        border: AnyBoxBorder(corners: _CountingCorner(4)));
    AnyDecoration newer = AnyDecorationTween(
            begin: older,
            end: const AnyBoxDecoration(
                border: AnyBoxBorder(corners: _CountingCorner(20))))
        .lerp(.3);
    for (var i = 0; i < 16; i++) {
      final next = AnyDecorationTween(begin: newer, end: older).lerp(.4);
      older = newer;
      newer = next;
    }
    newer.buildContour(_size, null).clipPath;
    expect(_CountingGeometry.contacts, lessThan(2500));
    expect(_CountingGeometry.boundaries, 0);
  });

  test('nested boundary evaluation remains lazy for a source-only request', () {
    const a = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: _CountingCorner(20),
            outerCorners: RoundedCorner(radius: 40),
            sides: AnySide(width: 6, align: 1)));
    const b = AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: _CountingCorner(20), sides: AnySide(width: 6, align: 1)));
    final saved = AnyDecorationTween(begin: a, end: b).lerp(.25);
    final next = AnyDecorationTween(begin: saved, end: b).lerp(.5);
    final contour = next.buildContour(_size, null);
    contour.clipPath;
    expect(_CountingGeometry.boundaries, 0);
    contour.outerCorners;
    expect(_CountingGeometry.boundaries, greaterThan(0));
    final prior = _CountingGeometry.boundaries;
    contour.outerCorners;
    expect(_CountingGeometry.boundaries, prior);
  });
}
