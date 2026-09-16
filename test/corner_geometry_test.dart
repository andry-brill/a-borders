import 'dart:math' as math;
import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';

AnyContour box(AnyCorner corner,
        {double previous = 3, double next = 7, double align = 1}) =>
    AnyBoxDecoration(
            enableCache: false,
            border: AnyBoxBorder(
                corners: corner,
                left: AnySide(width: previous, align: align),
                top: AnySide(width: next, align: align)))
        .buildContour(const Size(240, 160), TextDirection.ltr);

AnyContour polygon(List<Offset> vertices, AnyCorner corner,
        {double width = 0,
        double align = 1,
        AnyShapeBase base = AnyShapeBase.shapeBorder}) =>
    AnyContour(
        points: [
          for (final v in vertices)
            AnyPoint(
                point: v,
                shape: corner,
                side: AnySide(width: width, align: align))
        ],
        background: null,
        backgroundBase: base,
        clipBase: base,
        shadowBase: base);

Offset at(AnyContour contour, AnyResolvedCorner corner, double t,
        {double previous = 0, double next = 0}) =>
    corner.pointAt(t);

void near(Offset actual, Offset expected, [double tolerance = 1e-6]) {
  expect(actual.dx, closeTo(expected.dx, tolerance));
  expect(actual.dy, closeTo(expected.dy, tolerance));
}

void main() {
  test('reported mixed-alignment demo uses correct axes and sharp-limit taper',
      () {
    final c = const AnyBoxDecoration(
            border: AnyBoxBorder(
                corners: RoundedCorner(radius: 10),
                innerCorners: RoundedCorner(radius: 10),
                left: AnySide(width: 10, align: -1),
                top: AnySide(width: 20, align: 0),
                right: AnySide(width: 30, align: 1),
                bottom: AnySide(width: 40, align: 0)))
        .buildContour(const Size(200, 100), TextDirection.ltr);
    const pairs = [
      (20.0, 10.0),
      (280 / 9, 20.0),
      (27.5, 280 / 9),
      (10.0, 27.5)
    ];
    const centers = [
      Offset(10, 10),
      Offset(1790 / 9, 10),
      Offset(1790 / 9, 92.5),
      Offset(10, 92.5)
    ];
    for (var i = 0; i < 4; i++) {
      expect(c.outerCorners[i].parameters!.p, closeTo(pairs[i].$1, 1e-8));
      expect(c.outerCorners[i].parameters!.n, closeTo(pairs[i].$2, 1e-8));
      near(c.outerCorners[i].center!, centers[i]);
      expect(c.innerCorners[i].parameters, const RoundedCorner(radius: 10));
      expect(c.shapeCorners[i].parameters, const RoundedCorner(radius: 10));
    }
  });

  test('rounded offsets act on the corresponding physical axes', () {
    const shape = RoundedCorner.elliptical(p: 40, n: 20);
    final outside = box(shape);
    final inside = box(shape, align: -1);
    expect(outside.outerCorners.first.parameters!.p, 47);
    expect(outside.outerCorners.first.parameters!.n, 23);
    expect(inside.innerCorners.first.parameters!.p, 33);
    expect(inside.innerCorners.first.parameters!.n, 17);
  });

  test('bevel endpoints have independently specified signed line distances',
      () {
    final c =
        box(const BevelCorner.elliptical(p: 30, n: 10), previous: 4, next: 8);
    final a = at(c, c.outerCorners.first, 0, previous: -4, next: -8);
    final b = at(c, c.outerCorners.first, 1, previous: -4, next: -8);
    // Source line is 3x+y=30, from endpoints (0,30) and (10,0).
    expect((3 * a.dx + a.dy - 30) / math.sqrt(10), closeTo(-4, 1e-8));
    expect((3 * b.dx + b.dy - 30) / math.sqrt(10), closeTo(-8, 1e-8));
    expect(a.dx, -4);
    expect(b.dy, -8);
  });

  test('sixty degree rounded source has a genuine circular radius', () {
    final c = polygon(
        [Offset.zero, const Offset(200, 0), Offset(100, 100 * math.sqrt(3))],
        const RoundedCorner(radius: 20));
    final center = Offset(20 * math.sqrt(3), 20);
    for (var i = 0; i <= 20; i++) {
      expect((at(c, c.shapeCorners.first, i / 20) - center).distance,
          closeTo(20, 0.001));
    }
  });

  test('reversing contour winding preserves circular shape coverage', () {
    const vertices = [
      Offset.zero,
      Offset(200, 0),
      Offset(200, 100),
      Offset(0, 100)
    ];
    final a = polygon(vertices, const RoundedCorner(radius: 20)).clipPath;
    final b =
        polygon(vertices.reversed.toList(), const RoundedCorner(radius: 20))
            .clipPath;
    for (var x = -25.25; x < 225; x += 2) {
      for (var y = -25.25; y < 125; y += 2) {
        expect(a.contains(Offset(x, y)), b.contains(Offset(x, y)),
            reason: 'winding changed coverage at ($x,$y)');
      }
    }
  });
}
