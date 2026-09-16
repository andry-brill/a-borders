import 'dart:math' as math;
import 'dart:ui';
import 'package:any_borders/any_borders.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/direct_geometry_fixtures.dart';

// Descriptor dimensions and type do not describe this provider's outline.
class _CustomRounded extends RoundedCorner {
  const _CustomRounded({super.p = 20, super.n = 20}) : super.elliptical();
  @override
  _CustomRounded copyWith({double? p, double? n, CornerConverter? converter}) =>
      _CustomRounded(p: p ?? this.p, n: n ?? this.n);
  @override
  AnyCornerGeometry get geometry => const _CustomRoundedGeometry();
}

class _CustomRoundedGeometry extends RoundedCornerGeometry {
  const _CustomRoundedGeometry();
  @override
  AnyResolvedCorner resolve(AnyCorner corner, AnyCornerFrame frame) =>
      AnyResolvedCorner(
          source: corner,
          frame: frame,
          parameters: corner,
          segments: [
            AnyCornerSegment.line(frame.vertex + frame.previousRay * corner.p,
                frame.vertex + frame.nextRay * corner.n)
          ]);
}

void main() {
  test('custom geometry providers retain their actual curves and fallback', () {
    final work = GeometryDiagnostics();
    work.run(() {
      final c = const AnyBoxDecoration(
              enableCache: false,
              border: AnyBoxBorder(
                  corners: _CustomRounded(),
                  sides: AnySide(width: 4, color: Color(0xff123456))))
          .buildContour(const Size(200, 120), TextDirection.ltr);
      expect(c.shapeCorners.every((c) => c.segments.single.isLine), true);
      // (9,9) is inside a radius-20 fillet, outside this custom straight cut.
      expect(c.pathFor(AnyShapeBase.shapeBorder).contains(const Offset(9, 9)),
          false);
      c.regions(backgroundMerge: false);
      expect(c.innerCorners.every((c) => c.segments.single.isLine), true);
    });
    expect(work[GeometryWork.assembly], greaterThan(0));
  });
  test('affine arc sources keep their analytic parameter and never fit', () {
    final work = GeometryDiagnostics();
    work.run(() {
      for (final degrees in [30, 60, 90, 120, 150]) {
        for (final sign in [-1.0, 1.0]) {
          final angle = sign * degrees * math.pi / 180;
          final u = Offset(math.cos(angle), math.sin(angle));
          const v = Offset(1, 0);
          final f = AnyCornerFrame(
              vertex: const Offset(17, -31),
              previousRay: u,
              nextRay: v,
              previousNormal: Offset(u.dy, -u.dx),
              nextNormal: const Offset(0, 1),
              winding: 1);
          for (final radii in [
            (20.0, 20.0),
            (0.001, 1000.0),
            (1000.0, 0.001)
          ]) {
            Offset affine(Offset p) =>
                u * (p.dy / u.dy * radii.$1) +
                v * ((p.dx - p.dy * u.dx / u.dy) * radii.$2);
            for (final rounded in [false, true]) {
              final AnyCorner descriptor = rounded
                  ? RoundedCorner.elliptical(p: radii.$1, n: radii.$2)
                  : InverseRoundedCorner.elliptical(p: radii.$1, n: radii.$2);
              final c = descriptor.resolve(f);
              final center = rounded ? (u + v) / u.dy.abs() : Offset.zero;
              final a = rounded ? u * f.cotangentHalfAngle - center : u;
              final b = rounded ? v * f.cotangentHalfAngle - center : v;
              final start = math.atan2(a.dy, a.dx);
              final sweep = math.atan2(
                  a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy);
              for (var i = 0; i <= 100; i++) {
                final phi = start + sweep * i / 100;
                final expected = f.vertex +
                    affine(center + Offset(math.cos(phi), math.sin(phi)));
                expect((c.pointAt(i / 100) - expected).distance,
                    lessThanOrEqualTo(c.tolerance * 0.25));
              }
              final n = c.segments.length;
              expect(n & (n - 1), 0, reason: 'power-of-two segment count');
            }
          }
        }
      }
    });
    expect(work[GeometryWork.fit], 0);
  });

  test('multiple borders and an exhausted sharp inner use direct areas', () {
    final work = GeometryDiagnostics();
    work.run(() {
      final contours = const AnyBoxDecoration.multi(
          enableCache: false,
          primaryBorderIndex: 1,
          borders: [
            AnyBoxBorder(
                corners: RoundedCorner(radius: 24),
                sides: AnySide(width: 4, color: Color(0xff123456))),
            AnyBoxBorder(
                corners: BevelCorner(radius: 16),
                sides: AnySide(width: 8, color: Color(0xff654321)))
          ]).buildContours(const Size(200, 120), TextDirection.ltr);
      for (final c in contours) {
        expect(c.regions(backgroundMerge: false).regions, hasLength(1));
      }
      final sharp = const AnyBoxDecoration(
              enableCache: false,
              border: AnyBoxBorder(sides: AnySide(width: 70)))
          .buildContour(const Size(100, 100), TextDirection.ltr);
      expect(
          sharp
              .pathFor(AnyShapeBase.innerBorder)
              .contains(const Offset(50, 50)),
          false);
    });
    expect(work[GeometryWork.boolean], 0);
    expect(work[GeometryWork.flatten], 0);
    expect(work[GeometryWork.assembly], 0);
  });

  test('non-right direct inner curves match general area to analytic tolerance',
      () {
    for (final corner in [
      const RoundedCorner.elliptical(p: 30, n: 20),
      const BevelCorner.elliptical(p: 30, n: 20)
    ]) {
      AnyContour build() => AnyContour(
              background: null,
              backgroundBase: AnyShapeBase.shapeBorder,
              clipBase: AnyShapeBase.shapeBorder,
              shadowBase: AnyShapeBase.shapeBorder,
              points: [
                for (final p in const [
                  Offset(0, 0),
                  Offset(150, 0),
                  Offset(75, 129.9038105676658)
                ])
                  AnyPoint(
                      point: p, shape: corner, side: const AnySide(width: 10))
              ]);
      final direct = build();
      final general = GeometryDiagnostics(forceGeneralRegions: true)
          .run(() => build().pathFor(AnyShapeBase.innerBorder));
      for (final c in direct.innerCorners) {
        for (var i = 1; i < 100; i++) {
          final t = i / 100, p = c.pointAt(t), tangent = c.tangentAt(t);
          final normal = Offset(-tangent.dy, tangent.dx);
          expect(general.contains(p + normal * 0.001), isTrue);
          expect(general.contains(p - normal * 0.001), isFalse);
        }
      }
    }
  });
  test(
      'seeded mixed corners, authored bands and polygons match general assembly',
      () {
    final random = math.Random(20260917);
    for (var caseIndex = 0; caseIndex < 180; caseIndex++) {
      final count = caseIndex % 3 == 0 ? 4 : 5 + caseIndex % 4;
      final vertices = count == 4
          ? const [
              Offset(0, 0),
              Offset(200, 0),
              Offset(200, 120),
              Offset(0, 120)
            ]
          : List.generate(count, (i) {
              final angle = 2 * math.pi * i / count;
              final r = i.isEven ? 90.0 : 50 + random.nextDouble() * 40;
              return Offset(
                  100 + r * math.cos(angle), 100 + r * math.sin(angle));
            });
      AnyCorner corner() {
        final p = random.nextDouble() * 45,
            n = random.nextBool() ? p : random.nextDouble() * 45;
        return switch (random.nextInt(3)) {
          0 => RoundedCorner.elliptical(p: p, n: n),
          1 => BevelCorner.elliptical(p: p, n: n),
          _ => InverseRoundedCorner.elliptical(p: p, n: n),
        };
      }

      final points = [
        for (var i = 0; i < count; i++)
          AnyPoint(
              point: vertices[i],
              shape: corner(),
              outer: caseIndex % 4 == 0 ? corner() : null,
              inner: caseIndex % 5 == 0 ? corner() : null,
              side: AnySide(
                  width: caseIndex % 9 == i ? 0 : random.nextDouble() * 45,
                  align: random.nextDouble() * 2 - 1,
                  color: Color(0xff224466 + i * 0x110011)))
      ];
      List<Path> paths(bool general) =>
          GeometryDiagnostics(forceGeneralRegions: general).run(() {
            try {
              final c = AnyContour(
                  points: points,
                  background: null,
                  backgroundBase: AnyShapeBase.shapeBorder,
                  clipBase: AnyShapeBase.shapeBorder,
                  shadowBase: AnyShapeBase.shapeBorder);
              return [
                c.pathFor(AnyShapeBase.outerBorder),
                c.pathFor(AnyShapeBase.innerBorder),
                ...c.regions(backgroundMerge: false).regions.map((r) => r.$2)
              ];
            } catch (error, stack) {
              String describe(AnyCorner? c) =>
                  c == null ? 'null' : '${c.runtimeType}(${c.p},${c.n})';
              fail('seed=20260917 case=$caseIndex general=$general inputs=${points.map((p) => '${p.point.dx},${p.point.dy}: shape=${describe(p.shape)} outer=${describe(p.outer)} '
                  'inner=${describe(p.inner)} width=${p.side.width} align=${p.side.align}').join('; ')}\n$error\n$stack');
            }
          });
      final a = paths(false), b = paths(true);
      expect(a.length, b.length);
      for (var i = 0; i < 250; i++) {
        final p = Offset(
            random.nextDouble() * 320 - 60, random.nextDouble() * 280 - 60);
        for (var j = 0; j < a.length; j++) {
          expect(a[j].contains(p), b[j].contains(p),
              reason: 'seed=20260917 case=$caseIndex path=$j point=$p inputs=${points.map((p) => '${p.point} ${p.shape.runtimeType}(${p.shape.p},${p.shape.n}) '
                  'outer=${p.outer} inner=${p.inner} width=${p.side.width} align=${p.side.align}')}');
        }
      }
    }
  });

  test('tween frames retain coverage when directed spans collapse', () {
    for (final corner in [
      const RoundedCorner(),
      const RoundedCorner(radius: 20),
      const BevelCorner(radius: 20),
      const InverseRoundedCorner(radius: 20)
    ]) {
      final tween = AnyDecorationTween(
          begin: AnyBoxDecoration(
              border: AnyBoxBorder(
                  corners: corner,
                  sides: const AnySide(width: 0, color: Color(0xff112233)))),
          end: AnyBoxDecoration(
              border: AnyBoxBorder(
                  corners: corner,
                  sides: const AnySide(width: 100, color: Color(0xff112233)))));
      for (final t in [0.199999, 0.2, 0.200001, 0.499999, 0.5, 0.500001, 0.9]) {
        Path path(bool general) =>
            GeometryDiagnostics(forceGeneralRegions: general).run(() => tween
                .lerp(t)
                .buildContour(const Size(100, 100), TextDirection.ltr)
                .regions(backgroundMerge: false)
                .regions
                .single
                .$2);
        final a = path(false), b = path(true);
        for (var x = 0.713; x < 100; x += 4) {
          for (var y = 0.317; y < 100; y += 4) {
            expect(a.contains(Offset(x, y)), b.contains(Offset(x, y)),
                reason: '${corner.runtimeType} t=$t point=($x,$y)');
          }
        }
      }
    }
  });

  for (final fixture in directGeometryFixtures()) {
    test('${fixture.name}: direct and general filled areas agree', () {
      List<Path> paths(bool general) =>
          GeometryDiagnostics(forceGeneralRegions: general).run(() {
            final contour = fixture.build();
            return [
              contour.pathFor(AnyShapeBase.outerBorder),
              contour.pathFor(AnyShapeBase.innerBorder),
              ...contour
                  .regions(backgroundMerge: false)
                  .regions
                  .map((r) => r.$2)
            ];
          });
      final a = paths(false), b = paths(true);
      expect(a.length, b.length);
      final random = math.Random(20260916);
      for (var i = 0; i < 1200; i++) {
        final p = Offset(
            random.nextDouble() * 360 - 80, random.nextDouble() * 280 - 80);
        for (var j = 0; j < a.length; j++) {
          expect(a[j].contains(p), b[j].contains(p),
              reason: 'path=$j point=$p');
        }
      }
    });
    test('${fixture.name}: construction work follows eligibility', () {
      final work = GeometryDiagnostics();
      work.run(() => fixture.build().regions(backgroundMerge: false));
      if (fixture.ordinary) {
        expect(work[GeometryWork.fit], 0);
        expect(work[GeometryWork.boolean], 0);
        expect(work[GeometryWork.flatten], 0);
        expect(work[GeometryWork.assembly], 0);
      } else {
        expect(work[GeometryWork.assembly], greaterThan(0));
      }
    });
  }

  test('diagnostic scopes restore and isolate work counters', () {
    final a = GeometryDiagnostics(),
        b = GeometryDiagnostics(forceGeneralRegions: true);
    a.run(() {
      expect(forceGeneralRegions, isFalse);
      b.run(() {
        expect(forceGeneralRegions, isTrue);
        assert(record(GeometryWork.boolean));
      });
      expect(forceGeneralRegions, isFalse);
    });
    expect(a[GeometryWork.boolean], 0);
    expect(b[GeometryWork.boolean], 1);
    expect(forceGeneralRegions, isFalse);
  });
}
