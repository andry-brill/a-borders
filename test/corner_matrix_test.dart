import 'dart:math' as math;
import 'dart:ui';
import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';

AnyCornerFrame frame(double degrees, {bool reflex = false}) {
  final angle = degrees * math.pi / 180 * (reflex ? -1 : 1);
  final u = Offset(math.cos(angle), math.sin(angle)), v = const Offset(1, 0);
  return AnyCornerFrame(
      vertex: Offset.zero,
      previousRay: u,
      nextRay: v,
      previousNormal: Offset(u.dy, -u.dx),
      nextNormal: const Offset(0, 1),
      winding: 1);
}

double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
void closePoint(Offset a, Offset b, [double tolerance = 0.001]) {
  expect((a - b).distance, lessThanOrEqualTo(tolerance), reason: '$a vs $b');
}

AnyContour contour(List<AnyPoint> points) => AnyContour(
    points: points,
    background: null,
    backgroundBase: AnyShapeBase.shapeBorder,
    clipBase: AnyShapeBase.shapeBorder,
    shadowBase: AnyShapeBase.shapeBorder);

void main() {
  for (final angle in [30.0, 60.0, 90.0, 120.0, 150.0]) {
    for (final reflex in [false, true]) {
      test(
          'circular construction and signed distances angle=$angle reflex=$reflex',
          () {
        final f = frame(angle, reflex: reflex), sign = reflex ? -1 : 1;
        final source = const RoundedCorner(radius: 20).resolve(f);
        final center =
            Offset(20 / math.tan(angle * math.pi / 360), sign * 20.0);
        closePoint(source.center!, center, 1e-8);
        expect(source.previousExtent,
            closeTo(20 / math.tan(angle * math.pi / 360), 1e-8));
        for (var i = 0; i <= 40; i++) {
          expect(
              (source.pointAt(i / 40) - center).distance, closeTo(20, 0.001));
        }
        for (final d in [-4.0, 4.0]) {
          final b = source.source
              .resolveBoundary(source, previousDistance: d, nextDistance: d);
          closePoint(b.center!, center, 1e-8);
          expect(b.circleRadius, 20 - sign * d);
          expect(dot(f.previousNormal, b.start), closeTo(d, 1e-8));
          expect(dot(f.nextNormal, b.end), closeTo(d, 1e-8));
          expect(dot(f.previousNormal, b.tangentAt(0)).abs(), lessThan(1e-8));
          expect(dot(f.nextNormal, b.tangentAt(1)).abs(), lessThan(1e-8));
        }
      });
      test('bevel world-space offsets angle=$angle reflex=$reflex', () {
        final f = frame(angle, reflex: reflex);
        final source = const BevelCorner.elliptical(p: 30, n: 20).resolve(f);
        final edge = source.end - source.start;
        final normal = Offset(-edge.dy, edge.dx) / edge.distance;
        for (final sign in [-1.0, 1.0]) {
          final b = source.source.resolveBoundary(source,
              previousDistance: sign * 2, nextDistance: sign * 4);
          expect(dot(normal, b.start - source.start), closeTo(sign * 2, 1e-8));
          expect(dot(normal, b.end - source.start), closeTo(sign * 4, 1e-8));
          expect(dot(f.previousNormal, b.start), closeTo(sign * 2, 1e-8));
          expect(dot(f.nextNormal, b.end), closeTo(sign * 4, 1e-8));
        }
      });
    }
  }
  test('rounded sharp limit is continuous and has the specified taper', () {
    final f = frame(90);
    for (final r in [0.0, 1e-8, 0.001, 0.1, 1.0, 3.9999, 4.0, 4.0001, 20.0]) {
      final source = RoundedCorner(radius: r).resolve(f);
      final b = source.source
          .resolveBoundary(source, previousDistance: -4, nextDistance: -4);
      final q = r / 4 - 1;
      final expected = r >= 4 ? r + 4 : r + 4 * (1 + q * q * q);
      expect(b.parameters!.p, closeTo(expected, 1e-12));
      expect(b.parameters!.n, closeTo(expected, 1e-12));
      if (r < 0.001)
        expect((b.start - const Offset(-4, -4)).distance, lessThan(0.004));
    }
  });
  test(
      'source normalization preserves proportions and prevents opposite scoop overlap',
      () {
    final points = const [
      Offset(0, 0),
      Offset(100, 0),
      Offset(100, 100),
      Offset(0, 100)
    ];
    final c = contour([
      for (var i = 0; i < 4; i++)
        AnyPoint(
            point: points[i],
            shape: i.isEven
                ? const InverseRoundedCorner(radius: 80)
                : const RoundedCorner(),
            side: const AnySide())
    ]);
    expect(c.shapeCorners[0].parameters!.p, lessThan(71));
    expect(c.shapeCorners[0].parameters!.p, greaterThan(70));
    expect(c.shapeCorners[0].parameters!.p, c.shapeCorners[0].parameters!.n);
    expect(c.pathFor(AnyShapeBase.shapeBorder).getBounds().isFinite, isTrue);
  });
  test(
      'geometry rejects non-finite points and widths while accepting infinite corner dimensions',
      () {
    for (final corner in [
      const RoundedCorner.infinity(),
      const InverseRoundedCorner.elliptical(p: double.infinity, n: 20),
      const BevelCorner.elliptical(p: 20, n: double.infinity)
    ]) {
      final c = AnyBoxDecoration(border: AnyBoxBorder(corners: corner))
          .buildContour(const Size(100, 60), TextDirection.ltr);
      expect(
          c.shapeCorners
              .expand((c) => c.segments)
              .every((s) => s.start.dx.isFinite && s.end.dy.isFinite),
          isTrue);
    }
    expect(
        () => AnyBoxDecoration(
                border: const AnyBoxBorder(
                    corners: RoundedCorner(radius: double.nan)))
            .buildContour(const Size(100, 100), TextDirection.ltr),
        throwsArgumentError);
    expect(
        () => AnyBoxDecoration(
                border:
                    const AnyBoxBorder(sides: AnySide(width: double.infinity)))
            .buildContour(const Size(100, 100), TextDirection.ltr),
        throwsArgumentError);
  });
  test(
      '1000 generated outlines preserve geometry under reversal and rigid transforms',
      () {
    const seed = 20260915;
    final random = math.Random(seed);
    for (var index = 0; index < 1000; index++) {
      final count = 4 + 2 * random.nextInt(4), concave = index.isOdd;
      final rotation = random.nextDouble() * math.pi * 2;
      final vertices = List.generate(count, (i) {
        final radius = concave && i.isOdd ? 55.0 : 120.0;
        final a = rotation + i * 2 * math.pi / count;
        return Offset(150 + radius * math.cos(a), 150 + radius * math.sin(a));
      });
      final points = List.generate(count, (i) {
        final p = 2 + random.nextDouble() * 26,
            n = index % 3 == 0 ? p : 2 + random.nextDouble() * 26;
        final corner = switch ((index + i) % 3) {
          0 => RoundedCorner.elliptical(p: p, n: n),
          1 => InverseRoundedCorner.elliptical(p: p, n: n),
          _ => BevelCorner.elliptical(p: p, n: n),
        };
        return AnyPoint(
            point: vertices[i],
            shape: corner,
            side: AnySide(
                width: random.nextDouble() * 12,
                align: [-1.0, -0.5, 0.0, 0.5, 1.0][random.nextInt(5)]));
      });
      final reproduction =
          'seed=$seed case=$index points=${points.map((p) => '${p.point.dx},${p.point.dy}:${p.shape.runtimeType}(${p.shape.p},${p.shape.n}):${p.side.width},${p.side.align}').join(';')}';
      try {
        final c = contour(points);
        final reverse = contour(List.generate(count, (i) {
          final old = count - 1 - i, point = points[old];
          return AnyPoint(
              point: point.point,
              shape: point.shape.copyWith(p: point.shape.n, n: point.shape.p),
              side: points[(old - 1) % count].side);
        }));
        for (var i = 0; i < count; i++) {
          final a = c.shapeCorners[i], b = reverse.shapeCorners[count - 1 - i];
          for (final t in [0.0, 0.17, 0.5, 0.83, 1.0])
            closePoint(a.pointAt(t), b.pointAt(1 - t), 0.003);
          for (final corner in [a, c.innerCorners[i], c.outerCorners[i]]) {
            for (final s in corner.segments) {
              expect(
                  [s.start, s.control1, s.control2, s.end]
                      .every((p) => p.dx.isFinite && p.dy.isFinite),
                  isTrue);
            }
          }
          final current = c.frames[i].nextRay;
          final end = c.shapeCorners[(i + 1) % count].start;
          expect(dot(current, end - a.end), greaterThanOrEqualTo(-0.001));
        }
        if (index % 20 == 0) {
          final theta = 0.731, translation = const Offset(31.25, -17.5);
          Offset transform(Offset p) =>
              Offset(p.dx * math.cos(theta) - p.dy * math.sin(theta),
                  p.dx * math.sin(theta) + p.dy * math.cos(theta)) +
              translation;
          final moved = contour(points
              .map((p) => AnyPoint(
                  point: transform(p.point), shape: p.shape, side: p.side))
              .toList());
          for (var i = 0; i < count; i++)
            closePoint(transform(c.shapeCorners[i].pointAt(0.371)),
                moved.shapeCorners[i].pointAt(0.371), 0.003);
          final reflected = contour(points
              .map((p) => AnyPoint(
                  point: Offset(300 - p.point.dx, p.point.dy),
                  shape: p.shape,
                  side: p.side))
              .toList());
          final cyclic = contour([...points.skip(2), ...points.take(2)]);
          for (var i = 0; i < count; i++) {
            final p = c.shapeCorners[i].pointAt(0.371);
            closePoint(Offset(300 - p.dx, p.dy),
                reflected.shapeCorners[i].pointAt(0.371), 0.003);
            closePoint(
                p, cyclic.shapeCorners[(i - 2) % count].pointAt(0.371), 0.003);
          }
          final inner = c.pathFor(AnyShapeBase.innerBorder),
              outer = c.pathFor(AnyShapeBase.outerBorder),
              shape = c.clipPath;
          final reverseInner = reverse.pathFor(AnyShapeBase.innerBorder),
              reverseOuter = reverse.pathFor(AnyShapeBase.outerBorder);
          for (var k = 0; k < 30; k++) {
            final p =
                Offset(random.nextDouble() * 300, random.nextDouble() * 300);
            expect(inner.contains(p), reverseInner.contains(p),
                reason: 'inner winding point=${p.dx},${p.dy}');
            expect(outer.contains(p), reverseOuter.contains(p),
                reason: 'outer winding point=${p.dx},${p.dy}');
            if (inner.contains(p)) expect(shape.contains(p), isTrue);
            if (shape.contains(p)) expect(outer.contains(p), isTrue);
          }
        }
      } catch (error, stack) {
        fail('$reproduction\n$error\n$stack');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
