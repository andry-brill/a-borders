import 'dart:math' as math;
import 'dart:ui';
import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'corner_matrix_test.dart' show frame, closePoint;
import 'inverse_shape_corner_test.dart' show distanceToCorner;

void main() {
  for (final degrees in [30.0, 60.0, 90.0, 120.0, 150.0]) {
    for (final reflex in [false, true]) {
      test('single scoop reference at $degrees degrees, reflex=$reflex', () {
        final theta = degrees * math.pi / 180 * (reflex ? -1 : 1),
            f = frame(degrees, reflex: reflex);
        for (final dims in [(20.0, 20.0), (30.0, 20.0)]) {
          final p = dims.$1, n = dims.$2;
          final source = InverseRoundedCorner.elliptical(p: p, n: n).resolve(f);
          // Independent ray-basis coordinates of a unit sector, and its
          // derivative. No production conversion or normalization is used.
          Offset at(double phi) {
            final y = math.sin(phi) / math.sin(theta),
                x = math.cos(phi) - y * math.cos(theta);
            return Offset(
                n * x + p * y * math.cos(theta), p * y * math.sin(theta));
          }

          Offset derivative(double phi) {
            final y = math.cos(phi) / math.sin(theta),
                x = -math.sin(phi) - y * math.cos(theta);
            return Offset(
                    n * x + p * y * math.cos(theta), p * y * math.sin(theta)) *
                -theta;
          }

          for (final d in [-1.0, 1.0]) {
            final boundary = source.source
                .resolveBoundary(source, previousDistance: d, nextDistance: d);
            for (final t in [0.3, 0.5, 0.7]) {
              final phi = theta * (1 - t);
              final tangent = derivative(phi);
              final normal = Offset(-tangent.dy, tangent.dx) / tangent.distance;
              closePoint(source.pointAt(t), at(phi));
              closePoint(boundary.center!, Offset.zero);
              expect(distanceToCorner(boundary, at(phi) + normal * d),
                  lessThan(0.001));
            }
          }
        }
      });
    }
  }
  test('converter policies retain their documented geometric constraints', () {
    final f = frame(90);
    for (final converter in CornerConverter.values) {
      final rounded =
          RoundedCorner.elliptical(p: 40, n: 20, converter: converter)
              .resolve(f);
      final a = rounded.source
          .resolveBoundary(rounded, previousDistance: -3, nextDistance: -7);
      if (converter == CornerConverter.equal) {
        expect(a.parameters!.p, 40);
        expect(a.parameters!.n, 20);
      } else if (converter == CornerConverter.preserveRatio) {
        expect(a.parameters!.p / a.parameters!.n, 2);
      } else {
        expect(a.parameters!.p, 47);
        expect(a.parameters!.n, 23);
      }
      final bevel =
          BevelCorner.elliptical(p: 30, n: 10, converter: converter).resolve(f);
      final b = bevel.source
          .resolveBoundary(bevel, previousDistance: -4, nextDistance: -8);
      if (converter == CornerConverter.equal) {
        expect(b.parameters!.p, 30);
        expect(b.parameters!.n, 10);
      } else if (converter == CornerConverter.preserveRatio) {
        final direction = b.end - b.start,
            sourceDirection = bevel.end - bevel.start;
        expect(
            direction.dx * sourceDirection.dy -
                direction.dy * sourceDirection.dx,
            closeTo(0, 1e-8));
        final normal = Offset(-sourceDirection.dy, sourceDirection.dx) /
            sourceDirection.distance;
        final distance = (b.start - bevel.start).dx * normal.dx +
            (b.start - bevel.start).dy * normal.dy;
        expect(distance, closeTo(-5, 1e-8));
      }
    }
  });
  test('zero, one-zero and near-collinear source limits stay finite', () {
    for (final angle in [0.0, 1e-9, 1e-6, 179.999999, 180.0]) {
      for (final dims in [
        (0.0, 0.0),
        (0.0, 20.0),
        (20.0, 0.0),
        (1e-8, 1e-8),
        (20.0, 20.0)
      ]) {
        for (final c in [
          RoundedCorner.elliptical(p: dims.$1, n: dims.$2),
          InverseRoundedCorner.elliptical(p: dims.$1, n: dims.$2),
          BevelCorner.elliptical(p: dims.$1, n: dims.$2)
        ]) {
          final a = c.resolve(frame(angle));
          for (final d in [-3.0, 3.0]) {
            final b =
                c.resolveBoundary(a, previousDistance: d, nextDistance: d / 2);
            expect(
                b.segments.every((s) => [s.start, s.control1, s.control2, s.end]
                    .every((p) => p.dx.isFinite && p.dy.isFinite)),
                isTrue);
          }
        }
      }
    }
  });
  test('one-zero bevel retains its authored ray endpoints', () {
    final c = const BevelCorner.elliptical(p: 0, n: 20).resolve(frame(90));
    closePoint(c.start, Offset.zero);
    closePoint(c.end, const Offset(20, 0));
    expect(c.previousExtent, 0);
    expect(c.nextExtent, 20);
  });
  test('zero scoop stays sharp at the shifted side intersection', () {
    final source = const InverseRoundedCorner().resolve(frame(90));
    final equal = source.source
        .resolveBoundary(source, previousDistance: -4, nextDistance: -4);
    for (var i = 0; i <= 20; i++)
      closePoint(equal.pointAt(i / 20), const Offset(-4, -4));
    final unequal = source.source
        .resolveBoundary(source, previousDistance: -3, nextDistance: -7);
    closePoint(unequal.start, const Offset(-3, -7));
    closePoint(unequal.end, const Offset(-3, -7));
    closePoint(unequal.pointAt(0.5), const Offset(-3, -7));
  });
  test(
      'resolved geometry is immutable and rejects broken custom segment chains',
      () {
    final f = frame(90),
        segments = [
          AnyCornerSegment.line(const Offset(0, 10), const Offset(20, 0))
        ];
    final c = AnyResolvedCorner(
        source: const BevelCorner(radius: 10), frame: f, segments: segments);
    segments.clear();
    expect(c.segments, hasLength(1));
    expect(() => c.segments.clear(), throwsUnsupportedError);
    expect(
        () => AnyResolvedCorner(
            source: const RoundedCorner(), frame: f, segments: []),
        throwsArgumentError);
    expect(
        () => AnyResolvedCorner(
                source: const RoundedCorner(),
                frame: f,
                segments: [
                  AnyCornerSegment.line(Offset.zero, const Offset(1, 1),
                      to: 0.5),
                  AnyCornerSegment.line(const Offset(2, 2), const Offset(3, 3),
                      from: 0.5)
                ]),
        throwsArgumentError);
    final (a, b) = c.segments.single.split(0.371);
    for (var i = 0; i <= 100; i++) {
      final t = i / 100,
          actual = t <= 0.371
              ? a.pointAt(t / 0.371)
              : b.pointAt((t - 0.371) / 0.629);
      closePoint(actual, c.pointAt(t), 1e-10);
    }
  });
  test(
      'same-type animation crosses taper, normalization and scoop collapse continuously',
      () {
    for (final type in [0, 1, 2]) {
      AnyCorner corner(double r) => switch (type) {
            0 => RoundedCorner(radius: r),
            1 => InverseRoundedCorner(radius: r),
            _ => BevelCorner(radius: r)
          };
      for (final range in [
        (0.0, 8.0, 4.0, 4.0),
        (20.0, 20.0, 19.99, 20.01),
        (40.0, 60.0, 4.0, 4.0)
      ]) {
        AnyBoxDecoration decoration(double r, double width) => AnyBoxDecoration(
            border: AnyBoxBorder(
                corners: corner(r), sides: AnySide(width: width, align: 1)));
        final begin = decoration(range.$1, range.$3),
            end = decoration(range.$2, range.$4);
        final tween = AnyDecorationTween(begin: begin, end: end);
        expect(tween.lerp(0), same(begin));
        expect(tween.lerp(1), same(end));
        AnyResolvedCorner? previous;
        for (var i = 0; i <= 40; i++) {
          final d = tween.lerp(i / 40),
              c = d.buildContour(const Size(100, 100), TextDirection.ltr);
          expect(
              c.pathFor(AnyShapeBase.outerBorder).getBounds().isFinite, isTrue);
          if (i > 0 && i < 40) {
            expect(d.enableCache, isFalse);
            expect(d.buildContour(const Size(100, 100), TextDirection.ltr),
                isNot(same(c)));
          }
          if (previous != null) {
            // Hausdorff samples compare physical geometry, so repartitioning
            // the canonical parameter after an arc vanishes cannot hide jumps.
            for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
              expect(
                  distanceToCorner(c.outerCorners.first, previous.pointAt(t)),
                  lessThan(2));
            }
          }
          previous = c.outerCorners.first;
        }
      }
    }
  });
}
