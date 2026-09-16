import 'dart:math' as math;
import 'dart:ui';
import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';

const dark = Color(0xff2e685f), light = Color(0xff85aea8);
AnyBoxDecoration authoredBox(AnyCorner shape) => AnyBoxDecoration(
    enableCache: false,
    border: AnyBoxBorder(
        corners: shape,
        outerCorners: const RoundedCorner(radius: 50),
        innerTopLeft: const RoundedCorner.elliptical(p: 20, n: 30),
        innerTopRight: const RoundedCorner.elliptical(p: 30, n: 20),
        innerBottomRight: const RoundedCorner.elliptical(p: 20, n: 30),
        innerBottomLeft: const RoundedCorner.elliptical(p: 30, n: 20),
        vertical: const AnySide(width: 30, align: -1, color: dark),
        horizontal: const AnySide(width: 20, align: 1, color: light)));
AnyContour build(AnyDecoration d) =>
    d.buildContour(const Size(200, 100), TextDirection.ltr);
Path darkRegion(AnyContour c) => c
    .regions(backgroundMerge: false)
    .regions
    .singleWhere((r) => r.$1.color == dark)
    .$2;
void main() {
  test(
      'a zero-width neighbor leaves the entire authored corner to the painted side',
      () {
    final c = build(const AnyBoxDecoration(
        border: AnyBoxBorder(
            corners: InverseRoundedCorner(radius: 5),
            outerCorners: RoundedCorner(radius: 20),
            innerCorners: RoundedCorner(radius: 10),
            left: AnySide(width: 20, align: -1, color: dark))));
    final region = darkRegion(c);
    for (final t in [0.25, 0.5, 0.75, 0.9]) {
      final angle = math.pi + t * math.pi / 2,
          direction = Offset(math.cos(angle), math.sin(angle));
      final outer = const Offset(20, 20) + direction * 20;
      final inner = const Offset(30, 10) + direction * 10;
      expect(region.contains(Offset.lerp(outer, inner, 0.5)!), isTrue);
    }
  });
  test('authored fill ownership survives winding reversal with remapped sides',
      () {
    final d = authoredBox(const BevelCorner(radius: 30));
    final original = build(d),
        points =
            d.points(Offset.zero & const Size(200, 100), TextDirection.ltr);
    final reversed = AnyContour(
        points: List.generate(points.length, (i) {
          final old = points.length - 1 - i, p = points[old];
          AnyCorner swap(AnyCorner c) => c.copyWith(p: c.n, n: c.p);
          return AnyPoint(
              point: p.point,
              shape: swap(p.shape),
              outer: swap(p.outer!),
              inner: swap(p.inner!),
              side: points[(old - 1) % points.length].side);
        }),
        background: null,
        backgroundBase: AnyShapeBase.shapeBorder,
        clipBase: AnyShapeBase.shapeBorder,
        shadowBase: AnyShapeBase.shapeBorder);
    final a = darkRegion(original), b = darkRegion(reversed);
    for (var x = -20.31; x < 220; x += 3) {
      for (var y = -25.73; y < 125; y += 3)
        expect(a.contains(Offset(x, y)), b.contains(Offset(x, y)));
    }
  });

  test('explicit boundary fills do not depend on an unrelated shape corner',
      () {
    final reference = darkRegion(build(authoredBox(const RoundedCorner())));
    for (final shape in [
      const RoundedCorner(radius: 50),
      const BevelCorner(radius: 30),
      const InverseRoundedCorner(radius: 20)
    ]) {
      expect(
          Path.combine(PathOperation.xor, reference,
                  darkRegion(build(authoredBox(shape))))
              .computeMetrics(),
          isEmpty);
    }
  });
  test('mixed alignment side split is the straight outer-to-inner connector',
      () {
    final c = build(authoredBox(const RoundedCorner(radius: 50))),
        darkPath = darkRegion(c);
    // Independent ellipse midpoint equations at the top-left boundary corner.
    final outer = Offset(50 - 50 / math.sqrt(2), 30 - 50 / math.sqrt(2));
    final inner = Offset(60 - 30 / math.sqrt(2), 20 - 20 / math.sqrt(2));
    final along = inner - outer,
        normal = Offset(-along.dy, along.dx) / along.distance;
    for (final t in [0.2, 0.4, 0.6, 0.8]) {
      final midpoint = Offset.lerp(outer, inner, t)!;
      expect(darkPath.contains(midpoint + normal * 0.25), isTrue);
      expect(darkPath.contains(midpoint - normal * 0.25), isFalse);
    }
  });
  test('authored straight-vertex corners retain one averaged boundary anchor',
      () {
    final points = const [
      Offset(0, 0),
      Offset(200, 0),
      Offset(200, 100),
      Offset(100, 100),
      Offset(0, 100)
    ];
    final c = AnyContour(
        points: [
          for (var i = 0; i < points.length; i++)
            AnyPoint(
                point: points[i],
                shape: const BevelCorner(radius: 20),
                outer: const BevelCorner(radius: 20),
                inner: const BevelCorner(radius: 8),
                side: AnySide(width: 20, align: i == 3 ? -1 : 1, color: dark))
        ],
        background: null,
        backgroundBase: AnyShapeBase.shapeBorder,
        clipBase: AnyShapeBase.shapeBorder,
        shadowBase: AnyShapeBase.shapeBorder);
    expect(c.outerCorners[3].start, const Offset(100, 110));
    expect(c.outerCorners[3].end, const Offset(100, 110));
    expect(c.innerCorners[3].start, const Offset(100, 90));
    expect(c.innerCorners[3].end, const Offset(100, 90));
  });
}
