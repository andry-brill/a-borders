import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/any_extras.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/custom_corner.dart';

const _size = Size(100, 60);
const _blue = Color(0xff0000ff);
const _red = Color(0xffff0000);

AnyBoxBorder _border(List<double> offsets,
        {AnyCorner corner = const RoundedCorner(), double width = 6}) =>
    AnyBoxBorder(
      corners: corner,
      top: AnySide(offset: offsets[0], width: width, align: 0, color: _blue),
      right: AnySide(offset: offsets[1], width: width, align: 0, color: _blue),
      bottom: AnySide(offset: offsets[2], width: width, align: 0, color: _blue),
      left: AnySide(offset: offsets[3], width: width, align: 0, color: _blue),
    );

AnyBoxDecoration _box(List<double> offsets,
        {double offset = 0, AnyCorner corner = const RoundedCorner()}) =>
    AnyBoxDecoration(
        offset: offset,
        enableCache: false,
        border: _border(offsets, corner: corner));

void _sameArea(Path a, Path b) {
  for (var x = -15.37; x < 120; x += 2.71) {
    for (var y = -15.61; y < 80; y += 2.83) {
      expect(a.contains(Offset(x, y)), b.contains(Offset(x, y)),
          reason: 'at ($x, $y)');
    }
  }
}

class _CountingBox extends AnyBoxDecoration {
  static int calls = 0;
  const _CountingBox({super.border});

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
      covariant AnyBoxBorder border, double offset, List<double> sideOffsets) {
    calls++;
    return super.buildPoints(bounds, direction, border, offset, sideOffsets);
  }
}

// A custom shape consumes the standard shared-side slot without discovery code.
class _CustomRect extends AnyDecoration {
  static final contexts = <(double, List<double>)>[];
  const _CustomRect({super.border, super.offset});

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
      AnyBorder border, double offset, List<double> sideOffsets) {
    contexts.add((offset, List.unmodifiable(sideOffsets)));
    return _build(bounds, border, offset,
        sideOffsets.isEmpty ? 0 : sideOffsets.reduce((a, b) => a + b));
  }

  List<AnyPoint> _build(
      Rect bounds, AnyBorder border, double offset, double sideOffset) {
    bounds = bounds.inflate(offset + sideOffset);
    if (bounds.isEmpty) return const [];
    final side = border.sides.copyWith(offset: sideOffset);
    return [
      for (final vertex in [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomRight,
        bounds.bottomLeft
      ])
        point(vertex, border: border, side: side)
    ];
  }
}

// Custom layouts: zero slots has no side displacement; multiple slots add up.
class _CustomSlotRect extends _CustomRect {
  final int slotCount;
  const _CustomSlotRect({super.border, required this.slotCount});

  @override
  List<double> sideOffsetsForBorder(
          Rect bounds, TextDirection? direction, AnyBorder border) =>
      List.filled(slotCount, border.sides.offset);

  @override
  bool operator ==(Object other) =>
      other is _CustomSlotRect &&
      other.slotCount == slotCount &&
      super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, slotCount);
}

void main() {
  setUp(() {
    AnyDecorationCache.clear();
    _CountingBox.calls = 0;
    _CustomRect.contexts.clear();
  });

  test('side offset participates in value semantics and interpolation', () {
    const zero = AnySide();
    const a = AnySide(offset: -8, width: 4, align: 0, color: _blue);
    const b = AnySide(offset: 12, width: 8, align: 1, color: _red);
    expect(zero, const AnySide(offset: 0));
    expect(a.copyWith(width: 0).offset, -8);
    expect(a.copyWith(offset: 0).offset, 0);
    expect(a.copyWith(), a);
    expect({a, a.copyWith(), a.copyWith(offset: -7)}, hasLength(2));
    final middle = AnySide.lerp(a, b, .25);
    expect(middle.offset, -3);
    expect(middle.width, 5);
    expect(middle.align, .25);
    expect(middle.color, Color.lerp(_blue, _red, .25));
  });

  test('each box edge moves independently in either direction', () {
    for (final (offsets, expected) in <(List<double>, Rect)>[
      ([8, 0, 0, 0], const Rect.fromLTRB(0, -8, 100, 60)),
      ([0, -6, 0, 0], const Rect.fromLTRB(0, 0, 94, 60)),
      ([0, 0, 4, 0], const Rect.fromLTRB(0, 0, 100, 64)),
      ([0, 0, 0, -3], const Rect.fromLTRB(3, 0, 100, 60)),
      ([-8, 6, -4, 3], const Rect.fromLTRB(-3, 8, 106, 56)),
    ]) {
      final contour = _box(offsets).buildContour(_size, null);
      expect(contour.clipPath.getBounds(), expected);
      _sameArea(contour.clipPath, Path()..addRect(expected));
      expect(contour.sides.map((s) => s.offset), offsets);
    }
  });

  test('whole-side fallbacks govern displacement and painted settings', () {
    const d = AnyBoxDecoration(
        offset: 2,
        border: AnyBoxBorder(
            offset: 3,
            sides: AnySide(offset: 8, width: 9),
            horizontal: AnySide(offset: -2, width: 7),
            vertical: AnySide(offset: 4, width: 5),
            top: AnySide(width: 2),
            right: AnySide(offset: -5, width: 3)));
    final points = d.points(Offset.zero & _size, null);
    expect(points.map((p) => p.point), const [
      Offset(-9, -5),
      Offset(100, -5),
      Offset(100, 63),
      Offset(-9, 63)
    ]);
    expect(points.map((p) => p.side.offset), [0, -5, -2, 4]);
    expect(points.map((p) => p.side.width), [2, 3, 7, 5]);
    const fallback = AnyBoxDecoration(
        border: AnyBoxBorder(sides: AnySide(offset: 8), top: AnySide()));
    expect(fallback.buildContour(_size, null).clipPath.getBounds(),
        const Rect.fromLTRB(-8, 0, 108, 68));
    expect(
        _box([-5, -5, -5, -5], offset: 5)
            .buildContour(_size, null)
            .clipPath
            .getBounds(),
        Offset.zero & _size);
  });

  test('collapse is checked after all scalar and side contributions', () {
    for (final offsets in <List<double>>[
      [0, -100, 0, 0],
      [0, -120, 0, 0],
      [-60, 0, 0, 0],
      [-80, 0, 0, 0]
    ]) {
      final c = _box(offsets).buildContour(_size, null);
      expect(c.count, 0);
      for (final base in AnyShapeBase.values) {
        expect(c.pathFor(base).computeMetrics(), isEmpty);
      }
      expect(c.regions(backgroundMerge: false).regions, isEmpty);
    }
    expect(
        _box([30, 0, 30, 10], offset: -40)
            .buildContour(_size, null)
            .clipPath
            .getBounds(),
        const Rect.fromLTRB(30, 10, 60, 50));
  });

  test('ratios precede offsets and primary layer effects follow its outline',
      () {
    const d = AnyBoxDecoration.multi(
        offset: 3,
        primaryBorderIndex: 1,
        borders: [
          AnyBoxBorder(sides: AnySide(offset: 4)),
          AnyBoxBorder(
              offset: -5,
              ratio: 1,
              top: AnySide(offset: 4),
              right: AnySide(offset: 7),
              bottom: AnySide(offset: -3),
              left: AnySide(offset: -6))
        ],
        background: AnyBackground(color: _blue));
    final contours = d.buildContours(const Size(200, 120), TextDirection.ltr);
    expect(contours[0].clipPath.getBounds(),
        const Rect.fromLTRB(-7, -7, 207, 127));
    const expected = Rect.fromLTRB(48, -2, 165, 115);
    expect(contours[1].clipPath.getBounds(), expected);
    expect(contours[1].shadowPath.getBounds(), expected);
    expect(contours[1].backgroundPath!.getBounds(), expected);
    expect(contours[0].backgroundPath, isNull);
    expect(
        d
            .getClipPath(
                const Offset(10, 20) & const Size(200, 120), TextDirection.ltr)
            .getBounds(),
        expected.shift(const Offset(10, 20)));
  });

  test('corner profiles translate with independent vertices before resolution',
      () {
    for (final corner in <AnyCorner>[
      const RoundedCorner(radius: 14),
      const BevelCorner(radius: 14),
      const InverseRoundedCorner(radius: 14),
      const NotchCorner(p: 14, n: 14)
    ]) {
      final reference =
          _box([0, 0, 0, 0], corner: corner).buildContour(_size, null);
      final shifted =
          _box([8, -6, -4, 3], corner: corner).buildContour(_size, null);
      const deltas = [
        Offset(-3, -8),
        Offset(-6, -8),
        Offset(-6, -4),
        Offset(-3, -4)
      ];
      for (final base in AnyShapeBase.values) {
        final a = switch (base) {
          AnyShapeBase.shapeBorder => reference.shapeCorners,
          AnyShapeBase.outerBorder => reference.outerCorners,
          AnyShapeBase.innerBorder => reference.innerCorners,
          AnyShapeBase.zeroBorder => reference.zeroCorners,
        };
        final b = switch (base) {
          AnyShapeBase.shapeBorder => shifted.shapeCorners,
          AnyShapeBase.outerBorder => shifted.outerCorners,
          AnyShapeBase.innerBorder => shifted.innerCorners,
          AnyShapeBase.zeroBorder => shifted.zeroCorners,
        };
        for (var i = 0; i < 4; i++) {
          expect((b[i].pointAt(.37) - a[i].pointAt(.37) - deltas[i]).distance,
              lessThan(1e-8));
        }
      }
      final general = GeometryDiagnostics(forceGeneralRegions: true).run(() =>
          _box([8, -6, -4, 3], corner: corner)
              .buildContour(_size, null)
              .regions(backgroundMerge: false));
      final direct = shifted.regions(backgroundMerge: false);
      expect(direct.regions.length, general.regions.length);
      for (var i = 0; i < direct.regions.length; i++) {
        _sameArea(direct.regions[i].$2, general.regions[i].$2);
      }
    }
    final fitted = _box([0, -90, 0, 0], corner: const RoundedCorner(radius: 20))
        .buildContour(_size, null);
    expect(fitted.shapeCorners.first.parameters!.p, 5);
  });

  test('authored corners and mixed widths retain side ownership', () {
    const d = AnyBoxDecoration(
        enableCache: false,
        border: AnyBoxBorder(
            corners: RoundedCorner(radius: 12),
            outerTopLeft: BevelCorner(radius: 16),
            innerBottomRight: RoundedCorner(radius: 6),
            top: AnySide(offset: 8, width: 13, color: _blue),
            right: AnySide(offset: -6, width: 2, align: 1, color: _red),
            bottom: AnySide(offset: -4, width: 8, align: 0, color: _blue),
            left: AnySide(offset: 3)));
    final direct = d.buildContour(_size, null);
    expect(direct.outerCorners.first.source, const BevelCorner(radius: 16));
    expect(direct.innerCorners[2].source, const RoundedCorner(radius: 6));
    final regions = direct.regions(backgroundMerge: false).regions;
    final general = GeometryDiagnostics(forceGeneralRegions: true).run(() =>
        d.buildContour(_size, null).regions(backgroundMerge: false).regions);
    expect(regions.length, general.length);
    for (var i = 0; i < regions.length; i++) {
      _sameArea(regions[i].$2, general[i].$2);
    }
    for (var x = -10.3; x < 110; x += 3.17) {
      for (var y = -15.7; y < 75; y += 3.29) {
        expect(regions.where((r) => r.$2.contains(Offset(x, y))).length,
            lessThanOrEqualTo(1));
      }
    }
  });

  test('direct contours do not apply side-offset metadata again', () {
    final points = _box([8, -6, -4, 3]).points(Offset.zero & _size, null);
    AnyContour build(bool changeMetadata) => AnyContour(
            background: null,
            backgroundBase: AnyShapeBase.shapeBorder,
            clipBase: AnyShapeBase.shapeBorder,
            shadowBase: AnyShapeBase.shapeBorder,
            points: [
              for (final p in points)
                AnyPoint(
                    point: p.point,
                    shape: p.shape,
                    outer: p.outer,
                    inner: p.inner,
                    side:
                        changeMetadata ? p.side.copyWith(offset: 1000) : p.side)
            ]);
    for (final base in AnyShapeBase.values) {
      _sameArea(build(false).pathFor(base), build(true).pathFor(base));
    }
  });

  test('tab helpers follow asymmetric construction edges in both modes', () {
    for (final outward in [true, false]) {
      final d = AnyTabDecoration(
          offsetOutward: outward,
          border:
              _border([8, -6, -4, 3], corner: const RoundedCorner(radius: 12)));
      final points = d.points(Offset.zero & _size, null);
      expect(
          points.map((p) => p.point),
          outward
              ? const [
                  Offset(-15, 56),
                  Offset(-3, 56),
                  Offset(-3, -8),
                  Offset(94, -8),
                  Offset(94, 56),
                  Offset(106, 56)
                ]
              : const [
                  Offset(-3, 56),
                  Offset(9, 56),
                  Offset(9, -8),
                  Offset(82, -8),
                  Offset(82, 56),
                  Offset(94, 56)
                ]);
      expect(points.map((p) => p.side.offset), [-4, 3, 8, -6, -4, -4]);
      final zero = AnyTabDecoration(
          offsetOutward: outward,
          border: _border([8, -6, -4, 3])).points(Offset.zero & _size, null);
      expect(zero.first.skip, isTrue);
      expect(zero.last.skip, isTrue);
      final layers = AnyTabDecoration.multi(offsetOutward: outward, borders: [
        _border([0, 0, 0, 0]),
        _border([8, -6, -4, 3]),
      ]).buildContours(_size, null);
      expect(layers[0].clipPath.getBounds(), Offset.zero & _size);
      expect(
          layers[1].clipPath.getBounds(), const Rect.fromLTRB(-3, -8, 94, 56));
    }
  });

  test('box and tab side animations collapse at the geometric threshold', () {
    for (final tab in [false, true]) {
      for (final outward in tab ? [false, true] : [true]) {
        AnyDecoration endpoint(double right) => tab
            ? AnyTabDecoration(
                offsetOutward: outward, border: _border([0, right, 0, 0]))
            : _box([0, right, 0, 0]);
        for (final reverse in [false, true]) {
          final a = endpoint(0), b = endpoint(-120);
          final tween =
              AnyDecorationTween(begin: reverse ? b : a, end: reverse ? a : b);
          for (final u in [
            0.0,
            .2,
            .5,
            5 / 6 - .00001,
            5 / 6,
            5 / 6 + .00001,
            .99,
            1.0
          ]) {
            final c = tween.lerp(reverse ? 1 - u : u).buildContour(_size, null);
            if (u < 5 / 6) {
              expect(c.count, 4, reason: 'tab=$tab reverse=$reverse u=$u');
              expect(
                  c.clipPath.getBounds().right, closeTo(100 - 120 * u, 1e-8));
              expect(c.sides[tab ? 2 : 1].offset, closeTo(-120 * u, 1e-8));
            } else {
              expect(c.count, 0, reason: 'tab=$tab reverse=$reverse u=$u');
              expect(c.clipPath.computeMetrics(), isEmpty);
            }
          }
        }
      }
    }
  });

  test('scalar offsets and side settings interpolate together before building',
      () {
    const a = AnyBoxDecoration(
        offset: -6,
        border: AnyBoxBorder(
            offset: 2,
            top: AnySide(offset: 0, width: 6, color: _blue),
            right: AnySide(offset: 4),
            bottom: AnySide(offset: -2),
            left: AnySide(offset: 6)));
    const b = AnyBoxDecoration(
        offset: 10,
        border: AnyBoxBorder(
            offset: -2,
            top: AnySide(offset: 8, width: 10, color: _red),
            right: AnySide(offset: -4),
            bottom: AnySide(offset: 2),
            left: AnySide(offset: -6)));
    final d = AnyDecorationTween(begin: a, end: b).lerp(.25);
    final points = d.points(Offset.zero & _size, null);
    expect(d.offset, -2);
    expect(d.border.offset, 1);
    expect(points.map((p) => p.point), const [
      Offset(-2, -1),
      Offset(101, -1),
      Offset(101, 58),
      Offset(-2, 58)
    ]);
    expect(points.map((p) => p.side.offset), [2, 2, -1, 3]);
    expect(points.first.side.width, 7);
    expect(points.first.side.color, Color.lerp(_blue, _red, .25));
  });

  test('inserted and removed layers keep endpoint offsets while widths fade',
      () {
    const a = AnyBoxDecoration();
    const b = AnyBoxDecoration.multi(borders: [
      AnyBoxBorder(),
      AnyBoxBorder(right: AnySide(offset: 5, width: 4, color: _blue))
    ]);
    for (final reverse in [false, true]) {
      final tween =
          AnyDecorationTween(begin: reverse ? b : a, end: reverse ? a : b);
      for (final t in [.1, .5, .9]) {
        final points =
            tween.lerp(t).points(Offset.zero & _size, null, borderIndex: 1);
        expect(points[1].point, const Offset(105, 0));
        expect(points[1].side.offset, 5);
        expect(points[1].side.width, closeTo(4 * (reverse ? 1 - t : t), 1e-8));
      }
    }
  });

  test('unchanged offset contexts reuse preparation and builder overrides', () {
    const a = _CountingBox(
        border: AnyBoxBorder(
            corners: RoundedCorner(radius: 12), sides: AnySide(offset: 3)));
    const b = _CountingBox(
        border: AnyBoxBorder(
            corners: RoundedCorner(radius: 20), sides: AnySide(offset: 3)));
    final tween = AnyDecorationTween(begin: a, end: b);
    tween.lerp(.25).buildContour(_size, null);
    tween.lerp(.75).buildContour(_size, null);
    expect(_CountingBox.calls, 2);
  });

  test('builder overrides execute for ordinary and changing offset contexts',
      () {
    const a = _CountingBox();
    const b = _CountingBox(border: AnyBoxBorder(right: AnySide(offset: -120)));
    a.points(Offset.zero & _size, null);
    expect(_CountingBox.calls, 1);
    final tween = AnyDecorationTween(begin: a, end: b);
    expect(tween.lerp(.5).buildContour(_size, null).clipPath.getBounds(),
        const Rect.fromLTRB(0, 0, 40, 60));
    expect(_CountingBox.calls, 3);
    expect(tween.lerp(.9).buildContour(_size, null).count, 0);
    expect(_CountingBox.calls, 5);
  });

  test(
      'custom builders receive current offsets and invalidate preparation by value',
      () {
    const a = _CustomRect(offset: 2);
    const b = _CustomRect(border: AnyBorder(sides: AnySide(offset: -50)));
    final tween = AnyDecorationTween(begin: a, end: b);
    final saved = tween.lerp(.5);
    expect(saved.buildContour(_size, null).clipPath.getBounds(),
        const Rect.fromLTRB(24, 24, 76, 36));
    expect(_CustomRect.contexts.map((c) => c.$2.single), [-25, -25]);
    expect(_CustomRect.contexts.map((c) => c.$1), [1, 1]);
    saved.buildContour(_size, null);
    expect(_CustomRect.contexts, hasLength(2));
    tween.lerp(.4).buildContour(_size, null);
    expect(_CustomRect.contexts.map((c) => c.$2.single), [-25, -25, -20, -20]);
    expect(tween.lerp(.7).buildContour(_size, null).count, 0);
    tween.end =
        const _CustomRect(border: AnyBorder(sides: AnySide(offset: 10)));
    expect(tween.lerp(.5).buildContour(_size, null).clipPath.getBounds(),
        const Rect.fromLTRB(-6, -6, 106, 66));
    expect(saved.buildContour(_size, null).clipPath.getBounds(),
        const Rect.fromLTRB(24, 24, 76, 36));
  });

  test('ordinary custom construction receives the resolved side slots', () {
    const d = _CustomRect(border: AnyBorder(sides: AnySide(offset: 5)));
    final points = d.points(Offset.zero & _size, null);
    expect(_CustomRect.contexts.single.$2, [5]);
    expect(points.first.point, const Offset(-5, -5));
    expect(points.map((p) => p.side.offset), everyElement(5));
  });

  test('empty slot layouts use the same builder with no side displacement', () {
    final tween = AnyDecorationTween(
        begin: const _CustomSlotRect(slotCount: 0),
        end: const _CustomSlotRect(
            slotCount: 0, border: AnyBorder(sides: AnySide(offset: -50))));
    for (final t in [.25, .75]) {
      expect(tween.lerp(t).buildContour(_size, null).clipPath.getBounds(),
          Offset.zero & _size);
    }
    expect(_CustomRect.contexts.map((c) => c.$2), [[], []]);
  });

  test('different slot layouts reach their respective endpoint builders', () {
    final tween = AnyDecorationTween(
        begin: const _CustomSlotRect(
            slotCount: 1, border: AnyBorder(sides: AnySide(offset: 3))),
        end: const _CustomSlotRect(
            slotCount: 2, border: AnyBorder(sides: AnySide(offset: -25))));
    expect(tween.lerp(.49).buildContour(_size, null).count, 4);
    expect(tween.lerp(.51).buildContour(_size, null).count, 0);
    expect(_CustomRect.contexts.map((c) => c.$2), [
      [3],
      [-25, -25]
    ]);
  });

  test('saved tween samples consume supplied offsets when retargeted', () {
    final first = AnyDecorationTween(
        begin: _box([0, 0, 0, 0]), end: _box([0, -120, 0, 0]));
    final saved = first.lerp(.5);
    final retargeted =
        AnyDecorationTween(begin: saved, end: _box([0, 20, 0, 0]));
    final middle = retargeted.lerp(.5);
    expect(middle.buildContour(_size, null).clipPath.getBounds(),
        const Rect.fromLTRB(0, 0, 80, 60));
    expect(middle.points(Offset.zero & _size, null)[1].side.offset, -20);
    expect(saved.buildContour(_size, null).clipPath.getBounds(),
        const Rect.fromLTRB(0, 0, 40, 60));
  });

  test(
      'decoration cache identity includes side offsets through nested equality',
      () {
    const a = AnyBoxDecoration(border: AnyBoxBorder(sides: AnySide(offset: 3)));
    const b = AnyBoxDecoration.multi(
        borders: [AnyBoxBorder(sides: AnySide(offset: 3))]);
    const c = AnyBoxDecoration(border: AnyBoxBorder(sides: AnySide(offset: 4)));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect({a, b, c}, hasLength(2));
    final first = a.buildContours(_size, null);
    expect(b.buildContours(_size, null), same(first));
    expect(c.buildContours(_size, null), isNot(same(first)));
  });

  test('only consumed effective side offsets need finite values', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity
    ]) {
      for (final tab in [false, true]) {
        final border = AnyBoxBorder(top: AnySide(offset: value));
        final AnyDecoration d = tab
            ? AnyTabDecoration(border: border)
            : AnyBoxDecoration(border: border);
        expect(() => d.buildContour(_size, null), throwsArgumentError);
      }
    }
    expect(
        () => const AnyBoxDecoration(
                offset: 1e308,
                border: AnyBoxBorder(top: AnySide(offset: 1e308)))
            .buildContour(_size, null),
        throwsArgumentError);
    const unused = AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(offset: double.infinity),
            horizontal: AnySide(),
            vertical: AnySide()));
    expect(unused.buildContour(_size, null).clipPath.getBounds(),
        Offset.zero & _size);
  });
}
