import 'dart:math' as math;
import 'dart:ui';
import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'corner_matrix_test.dart' show frame;

AnyContour scoop(
  double width,
  double align, {
  AnyCorner corner = const InverseRoundedCorner(radius: 20),
  double? nextWidth,
  Size size = const Size(200, 120),
}) =>
    AnyBoxDecoration(
            enableCache: false,
            border: AnyBoxBorder(
                corners: corner,
                sides: AnySide(width: width, align: align),
                top: nextWidth == null
                    ? null
                    : AnySide(width: nextWidth, align: align)))
        .buildContour(size, TextDirection.ltr);

void near(Offset a, Offset b, [double tolerance = 0.001]) {
  expect(a.dx, closeTo(b.dx, tolerance));
  expect(a.dy, closeTo(b.dy, tolerance));
}

// Independent normal of x^2/n^2 + y^2/p^2 = 1 at the top-left scoop.
Offset ellipse(double p, double n, double angle) =>
    Offset(n * math.cos(angle), p * math.sin(angle));
Offset ellipseNormal(double p, double n, double angle) {
  final g = Offset(math.cos(angle) / n, math.sin(angle) / p);
  return g / g.distance;
}

double distanceToCorner(AnyResolvedCorner corner, Offset point) {
  var best = double.infinity;
  // Independent closest-point search over the actual cubic segments.
  for (final segment in corner.segments) {
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 45; i++) {
      final a = lo + (hi - lo) / 3, b = hi - (hi - lo) / 3;
      if ((segment.pointAt(a) - point).distanceSquared <
          (segment.pointAt(b) - point).distanceSquared) {
        hi = b;
      } else {
        lo = a;
      }
    }
    best = math.min(best, (segment.pointAt((lo + hi) / 2) - point).distance);
    best = math.min(
        best,
        math.min(
            (segment.start - point).distance, (segment.end - point).distance));
  }
  return best;
}

void main() {
  test('circular automatic boundaries share shape centers and offset radii',
      () {
    for (final align in [-1.0, 0.0, 0.4, 1.0]) {
      final c = scoop(8, align);
      final inside = 4 * (1 - align), outside = 4 * (1 + align);
      for (var i = 0; i < 4; i++) {
        final shape = c.shapeCorners[i],
            outer = c.outerCorners[i],
            inner = c.innerCorners[i];
        for (final pair in [(outer, 20 - outside), (inner, 20 + inside)]) {
          final b = pair.$1, radius = pair.$2;
          near(b.center!, shape.center!);
          expect(b.circleRadius, radius);
          // Numeric circle equation for every curved segment; the sharp side
          // joins are straight and intentionally not part of the circle.
          for (final segment in b.segments.where((s) => !s.isLine)) {
            for (var j = 0; j <= 20; j++) {
              expect((segment.pointAt(j / 20) - shape.center!).distance,
                  closeTo(radius, 0.001));
            }
          }
        }
      }
    }
  });
  test('outer sharp joins and inward trimming have analytic contacts', () {
    final outer = scoop(4, 1).outerCorners.first;
    near(outer.start, const Offset(-4, 16));
    near(outer.end, const Offset(16, -4));
    expect(outer.segments.first.isLine, isTrue);
    expect(outer.segments.last.isLine, isTrue);
    near(outer.segments.first.end, const Offset(0, 16));
    near(outer.segments.last.start, const Offset(16, 0));
    final inner = scoop(4, -1).innerCorners.first;
    final contact = math.sqrt(24 * 24 - 4 * 4);
    near(inner.start, Offset(4, contact));
    near(inner.end, Offset(contact, 4));
    expect(inner.segments.every((s) => !s.isLine), isTrue);
  });
  test('stacked scoops have the requested radial spacing throughout the arc',
      () {
    final layers = const AnyBoxDecoration.multi(borders: [
      AnyBoxBorder(
          corners: InverseRoundedCorner(radius: 20),
          sides: AnySide(width: 8, align: 1)),
      AnyBoxBorder(
          corners: InverseRoundedCorner(radius: 20),
          sides: AnySide(width: 3, align: 1)),
    ]).buildContours(const Size(200, 120), TextDirection.ltr);
    final outer = layers[0].outerCorners.first,
        middle = layers[1].outerCorners.first;
    expect(outer.circleRadius, 12);
    expect(middle.circleRadius, 17);
    near(outer.center!, Offset.zero);
    near(middle.center!, Offset.zero);
    for (var i = 0; i <= 20; i++) {
      final phi = i * math.pi / 40;
      final onMiddle = Offset(math.cos(phi), math.sin(phi)) * 17;
      expect(distanceToCorner(outer, onMiddle), closeTo(5, 0.001));
      expect(distanceToCorner(middle, onMiddle), lessThan(0.001));
    }
  });
  test(
      'elliptical boundaries follow source normals without translating the origin',
      () {
    for (final widths in [(3.0, 3.0), (3.0, 7.0)]) {
      for (final align in [-1.0, 0.0, 0.4, 1.0]) {
        final c = scoop(widths.$1, align,
            nextWidth: widths.$2,
            corner: const InverseRoundedCorner.elliptical(p: 30, n: 20));
        for (final outside in [false, true]) {
          final factor = outside ? -(1 + align) / 2 : (1 - align) / 2;
          final b = outside ? c.outerCorners.first : c.innerCorners.first;
          near(b.center!, Offset.zero);
          for (final t in [0.3, 0.5, 0.7]) {
            final angle = math.pi / 2 * (1 - t);
            final d = (widths.$1 * (1 - t) + widths.$2 * t) * factor;
            final expected =
                ellipse(30, 20, angle) + ellipseNormal(30, 20, angle) * d;
            expect(distanceToCorner(b, expected), lessThan(0.001));
          }
        }
      }
    }
  });
  test('every explicit override keeps its own shifted origin independently',
      () {
    for (final hasOuter in [false, true]) {
      for (final hasInner in [false, true]) {
        final c = AnyBoxDecoration(
                border: AnyBoxBorder(
                    corners: const InverseRoundedCorner(radius: 20),
                    outerCorners: hasOuter
                        ? const InverseRoundedCorner(radius: 30)
                        : null,
                    innerCorners: hasInner
                        ? const InverseRoundedCorner(radius: 10)
                        : null,
                    sides: const AnySide(width: 8, align: 0)))
            .buildContour(const Size(200, 120), TextDirection.ltr);
        near(c.shapeCorners.first.center!, Offset.zero);
        near(c.outerCorners.first.center!,
            hasOuter ? const Offset(-4, -4) : Offset.zero);
        near(c.innerCorners.first.center!,
            hasInner ? const Offset(4, 4) : Offset.zero);
        expect(c.outerCorners.first.circleRadius, hasOuter ? 30 : 16);
        expect(c.innerCorners.first.circleRadius, hasInner ? 10 : 24);
        near(c.zeroCorners.first.center!,
            hasOuter ? const Offset(-4, -4) : Offset.zero);
        expect(c.zeroCorners.first.circleRadius, hasOuter ? 34 : 20);
      }
    }
  });
  test('shrinking scoop arc disappears continuously through radius zero', () {
    AnyResolvedCorner? previous;
    for (final width in [19.99, 19.999, 20.0, 20.001, 20.01, 25.0, 40.0]) {
      final c = scoop(width, 1), outer = c.outerCorners.first;
      expect(outer.circleRadius, math.max(0, 20 - width));
      near(outer.center!, Offset.zero);
      if (width >= 20) expect(outer.segments.every((s) => s.isLine), isTrue);
      expect(c.pathFor(AnyShapeBase.outerBorder).getBounds().isFinite, isTrue);
      if (previous != null && width <= 20.01) {
        expect((outer.pointAt(0.5) - previous.pointAt(0.5)).distance,
            lessThan(0.02));
      }
      previous = outer;
    }
  });
  test('elliptical cusp thresholds keep finite filled boundaries', () {
    for (final width in [3.332, 3.333333, 3.335, 10.0, 20.0, 30.0, 40.0]) {
      final c = scoop(width, 1,
          corner: const InverseRoundedCorner.elliptical(p: 30, n: 10));
      near(c.outerCorners.first.center!, Offset.zero);
      expect(c.pathFor(AnyShapeBase.outerBorder).getBounds().isFinite, isTrue);
      expect(
          c.pathFor(AnyShapeBase.outerBorder).contains(const Offset(100, 60)),
          isTrue);
    }
  });
  test('inward circular trimming retains tiny arcs until the exact side limit',
      () {
    for (final angle in [30.0, 60.0, 90.0, 120.0, 150.0]) {
      final sourceSettings = const InverseRoundedCorner(radius: 20);
      final source =
          sourceSettings.geometry.resolve(sourceSettings, frame(angle));
      final sine = math.sin(angle * math.pi / 360);
      final limit = 20 * sine / (1 - sine);
      final before = source.source.geometry.resolveBoundary(source,
          previousDistance: limit * (1 - 1e-8),
          nextDistance: limit * (1 - 1e-8));
      final after = source.source.geometry.resolveBoundary(source,
          previousDistance: limit * (1 + 1e-8),
          nextDistance: limit * (1 + 1e-8));
      expect(before.segments.any((s) => !s.isLine), isTrue,
          reason: 'angle=$angle');
      expect(after.segments.every((s) => s.isLine), isTrue,
          reason: 'angle=$angle');
      near(before.center!, Offset.zero);
      near(after.center!, Offset.zero);
      near(before.pointAt(0.5), after.pointAt(0.5), 0.001);
    }
  });
  test('source normalization remains independent of border width', () {
    final c = scoop(8, -1, size: const Size(50, 50));
    expect(c.shapeCorners.first.parameters,
        const InverseRoundedCorner(radius: 20));
    expect(c.innerCorners.first.circleRadius, 28);
    near(c.innerCorners.first.center!, Offset.zero);
  });
  test(
      'elliptical inward trimming keeps narrow arcs between sampling positions',
      () {
    for (final axes in [(30.0, 20.0), (50.0, 8.0)]) {
      final p = axes.$1, n = axes.$2;
      // Independently solve P + d*N = (d,d), where the two shifted sides
      // meet the parallel ellipse. The normal comes from its implicit equation.
      var lo = 0.0, hi = math.pi / 2;
      for (var i = 0; i < 60; i++) {
        final angle = (lo + hi) / 2;
        final point = ellipse(p, n, angle), normal = ellipseNormal(p, n, angle);
        final balance = point.dx * (1 - normal.dy) - point.dy * (1 - normal.dx);
        if (balance > 0) {
          lo = angle;
        } else {
          hi = angle;
        }
      }
      final angle = (lo + hi) / 2;
      final limit =
          ellipse(p, n, angle).dx / (1 - ellipseNormal(p, n, angle).dx);
      final sourceSettings = InverseRoundedCorner.elliptical(p: p, n: n);
      final source = sourceSettings.geometry.resolve(sourceSettings, frame(90));
      final before = source.source.geometry.resolveBoundary(source,
          previousDistance: limit * (1 - 1e-8),
          nextDistance: limit * (1 - 1e-8));
      final after = source.source.geometry.resolveBoundary(source,
          previousDistance: limit * (1 + 1e-8),
          nextDistance: limit * (1 + 1e-8));
      expect(before.segments.any((s) => !s.isLine), isTrue,
          reason: 'p=$p n=$n');
      expect(after.segments.every((s) => s.isLine), isTrue,
          reason: 'p=$p n=$n');
    }
  });
}
