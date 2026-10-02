import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/any_extras.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/custom_corner.dart';
import '../example/lib/main.dart' as example;
import 'support/path_offset_regressions.dart';

const _size = Size(100, 60);
const _color = Color(0xff123456);

AnyContour _box(double offset,
        {double borderOffset = 0,
        double width = 8,
        double align = 0,
        AnyCorner corner = const RoundedCorner()}) =>
    AnyBoxDecoration(
            offset: offset,
            enableCache: false,
            border: AnyBoxBorder(
                offset: borderOffset,
                corners: corner,
                sides: AnySide(width: width, align: align, color: _color)))
        .buildContour(_size, TextDirection.ltr);

void _sameArea(Path actual, Path expected,
    {Rect bounds = const Rect.fromLTWH(-20, -20, 220, 150)}) {
  for (var x = bounds.left + 0.371; x < bounds.right; x += 3.17) {
    for (var y = bounds.top + 0.619; y < bounds.bottom; y += 3.29) {
      final p = Offset(x, y);
      expect(actual.contains(p), expected.contains(p), reason: 'at $p');
    }
  }
}

// A custom builder owns its shape-specific displacement. A diamond has an
// analytic construction and needs no general polygon-offset helper.
class _Diamond extends AnyDecoration {
  final bool reverse;
  const _Diamond({super.offset, super.border, this.reverse = false});

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
      AnyBorder border, double offset, List<double> sideOffsets) {
    if (bounds.isEmpty) return const [];
    final half = Offset(bounds.width / 2, bounds.height / 2);
    final scale =
        1 + (offset + sideOffsets.single) * half.distance / (half.dx * half.dy);
    if (scale <= 0) return const [];
    final vertices = [
      bounds.center + Offset(0, -half.dy * scale),
      bounds.center + Offset(half.dx * scale, 0),
      bounds.center + Offset(0, half.dy * scale),
      bounds.center + Offset(-half.dx * scale, 0),
    ];
    return [
      for (final vertex in reverse ? vertices.reversed : vertices)
        point(vertex,
            border: border,
            side: border.sides.copyWith(offset: sideOffsets.single)),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is _Diamond && other.reverse == reverse && super == other;
  @override
  int get hashCode => Object.hash(super.hashCode, reverse);
}

// Independent convex half-plane clipping oracle, without corner/provider APIs.
Path _convexArea(List<Offset> vertices, List<double> inwardDistances) {
  var area = <Offset>[
    const Offset(-1000, -1000),
    const Offset(1000, -1000),
    const Offset(1000, 1000),
    const Offset(-1000, 1000)
  ];
  var winding = 0.0;
  for (var i = 0; i < vertices.length; i++) {
    final a = vertices[i], b = vertices[(i + 1) % vertices.length];
    winding += a.dx * b.dy - a.dy * b.dx;
  }
  for (var i = 0; i < vertices.length && area.isNotEmpty; i++) {
    final edge = vertices[(i + 1) % vertices.length] - vertices[i];
    final normal = Offset(-edge.dy, edge.dx) * (winding.sign / edge.distance);
    double distance(Offset p) {
      final delta = p - vertices[i];
      return delta.dx * normal.dx + delta.dy * normal.dy - inwardDistances[i];
    }

    final clipped = <Offset>[];
    for (var j = 0; j < area.length; j++) {
      final a = area[j], b = area[(j + 1) % area.length];
      final da = distance(a), db = distance(b);
      if (da >= 0) clipped.add(a);
      if ((da >= 0) != (db >= 0)) clipped.add(a + (b - a) * (da / (da - db)));
    }
    area = clipped;
  }
  final path = Path();
  if (area.length >= 3) path.addPolygon(area, true);
  return path;
}

class _CountCorner extends RoundedCorner {
  final List<(double, double)> calls;
  _CountCorner(this.calls, {super.p = 12, super.n = 12}) : super.elliptical();
  @override
  AnyCornerGeometry get geometry => const _CountGeometry();
  @override
  _CountCorner copyWith({double? p, double? n, CornerConverter? converter}) =>
      _CountCorner(calls, p: p ?? this.p, n: n ?? this.n);
}

class _CountGeometry extends RoundedCornerGeometry {
  const _CountGeometry();
  @override
  AnyResolvedCorner resolveBoundary(AnyResolvedCorner source,
      {required double previousDistance, required double nextDistance}) {
    (source.source as _CountCorner).calls.add((previousDistance, nextDistance));
    return super.resolveBoundary(source,
        previousDistance: previousDistance, nextDistance: nextDistance);
  }
}

class _RecordingBox extends AnyBoxDecoration {
  static final calls = <(Rect, TextDirection?, AnyBorder, double)>[];
  const _RecordingBox({super.offset, super.border});
  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
      covariant AnyBoxBorder border, double offset, List<double> sideOffsets) {
    calls.add((bounds, direction, border, offset));
    return super.buildPoints(bounds, direction, border, offset, sideOffsets);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(AnyDecorationCache.clear);

  test('combined offsets are applied by point builders before resolution', () {
    expect(const AnyBorder().offset, 0);
    expect(const AnyBoxBorder().offset, 0);
    expect(const AnyBoxDecoration().offset, 0);
    expect(const AnyTabDecoration().offset, 0);
    const multi = AnyBoxDecoration.multi(
        offset: 5,
        borders: [AnyBoxBorder(offset: -2), AnyBoxBorder(offset: 4)]);
    expect(multi.points(Offset.zero & _size, null).first.point,
        const Offset(-3, -3));
    expect(multi.points(Offset.zero & _size, null, borderIndex: 1).first.point,
        const Offset(-9, -9));
    // Defaults choose settings; point() itself never changes coordinates.
    expect(multi.point(const Offset(7, 8), border: multi.borders[1]).point,
        const Offset(7, 8));
    const bounds = Rect.fromLTWH(13, 17, 100, 60);
    expect(multi.points(bounds, null).first.point, const Offset(10, 14));
  });

  test('sharp rectangles follow analytic distances through empty interiors',
      () {
    for (final general in [false, true]) {
      GeometryDiagnostics(forceGeneralRegions: general).run(() {
        for (final offset in [
          -80.0,
          -34.0,
          -30.0,
          -29.0,
          -7.0,
          0.0,
          9.0,
          70.0
        ]) {
          for (final align in [-1.0, 0.0, 1.0]) {
            final c = _box(offset, align: align);
            for (final base in AnyShapeBase.values) {
              final distance = offset +
                  switch (base) {
                    AnyShapeBase.outerBorder => 8 * (1 + align) / 2,
                    AnyShapeBase.innerBorder => -8 * (1 - align) / 2,
                    _ => 0.0,
                  };
              final rect = (Offset.zero & _size).inflate(distance);
              final expected = Path();
              if (!(Offset.zero & _size).inflate(offset).isEmpty &&
                  !rect.isEmpty) {
                expected.addRect(rect);
              }
              _sameArea(c.pathFor(base), expected,
                  bounds: const Rect.fromLTWH(-90, -90, 280, 240));
            }
          }
        }
      });
    }
  });

  test('rounded radius stays fixed while its center follows the new vertex',
      () {
    for (final offset in [-7.0, 6.0]) {
      final c = _box(offset,
          borderOffset: 2, corner: const RoundedCorner(radius: 20));
      final total = offset + 2;
      final center = Offset(20 - total, 20 - total);
      for (final (corners, borderDistance) in [
        (c.shapeCorners, 0.0),
        (c.outerCorners, 4.0),
        (c.innerCorners, -4.0),
        (c.zeroCorners, 0.0),
      ]) {
        final corner = corners.first;
        expect(corner.parameters!.p, closeTo(20 + borderDistance, 1e-10));
        expect((corner.center! - center).distance, lessThan(1e-10));
        expect(corner.frame.vertex,
            Offset(-total - borderDistance, -total - borderDistance));
        expect((corner.pointAt(0.37) - center).distance,
            closeTo(20 + borderDistance, corner.tolerance));
      }
      final expected = Path()
        ..addRRect(RRect.fromRectAndRadius(
            (Offset.zero & _size).inflate(total), const Radius.circular(20)));
      _sameArea(c.clipPath, expected);
    }
  });

  test('offset translates local geometry for every policy and custom provider',
      () {
    for (final corner in <AnyCorner>[
      for (final policy in CornerConverter.values) ...[
        RoundedCorner.elliptical(p: 20, n: 12, converter: policy),
        BevelCorner.elliptical(p: 20, n: 12, converter: policy),
      ],
      const InverseRoundedCorner(radius: 20),
      const InverseRoundedCorner.elliptical(p: 20, n: 12),
      const NotchCorner(p: 20, n: 12),
    ]) {
      final reference = _box(0, corner: corner);
      for (final offset in [-5.0, 5.0]) {
        final actual = _box(offset, corner: corner);
        for (final (a, b) in [
          (actual.shapeCorners, reference.shapeCorners),
          (actual.outerCorners, reference.outerCorners),
          (actual.innerCorners, reference.innerCorners),
          (actual.zeroCorners, reference.zeroCorners),
        ]) {
          for (var i = 0; i < a.length; i++) {
            final delta = actual.frames[i].vertex - reference.frames[i].vertex;
            expect(a[i].source, b[i].source);
            expect(a[i].parameters, b[i].parameters);
            expect(a[i].segments.length, b[i].segments.length);
            for (var j = 0; j < a[i].segments.length; j++) {
              final x = a[i].segments[j], y = b[i].segments[j];
              expect(x.from, closeTo(y.from, 1e-12));
              expect(x.to, closeTo(y.to, 1e-12));
              for (final (p, q) in [
                (x.start, y.start),
                (x.control1, y.control1),
                (x.control2, y.control2),
                (x.end, y.end)
              ]) {
                expect((p - q - delta).distance, lessThan(1e-9),
                    reason: '$corner offset=$offset vertex=$i segment=$j');
              }
            }
          }
        }
      }
    }
  });

  test('normalization uses available space after moving the points', () {
    for (final corner in [
      const RoundedCorner.infinity(),
      const RoundedCorner(radius: 1000)
    ]) {
      for (final offset in [-10.0, 5.0]) {
        final c = _box(offset, width: 0, corner: corner);
        expect(c.shapeCorners.first.parameters!.p, closeTo(30 + offset, 1e-9));
      }
    }
  });

  test(
      'scoop centers move with points and border continuation stays concentric',
      () {
    for (final offset in [-6.0, 5.0]) {
      final c = _box(offset, corner: const InverseRoundedCorner(radius: 20));
      for (final (corners, radius) in [
        (c.shapeCorners, 20.0),
        (c.zeroCorners, 20.0),
        (c.outerCorners, 16.0),
        (c.innerCorners, 24.0)
      ]) {
        expect(corners.first.center, Offset(-offset, -offset));
        expect(corners.first.circleRadius, closeTo(radius, 1e-9));
        expect(corners.first.source.p, 20);
      }
    }
  });

  test('authored boundaries use shifted frames and retain independent settings',
      () {
    final c = const AnyBoxDecoration(
            offset: 3,
            enableCache: false,
            border: AnyBoxBorder(
                offset: 2,
                corners: RoundedCorner(radius: 15),
                outerCorners: BevelCorner(radius: 10),
                innerCorners: InverseRoundedCorner(radius: 8),
                sides: AnySide(width: 4, align: 0)))
        .buildContour(_size, TextDirection.ltr);
    expect(c.shapeCorners.first.parameters!.p, 15);
    expect(c.outerCorners.first.parameters, const BevelCorner(radius: 10));
    expect(c.outerCorners.first.frame.vertex, const Offset(-7, -7));
    expect(
        c.innerCorners.first.parameters, const InverseRoundedCorner(radius: 8));
    expect(c.innerCorners.first.center, const Offset(-3, -3));
  });

  test('crossing authored boundaries retain XOR after path displacement', () {
    final work = GeometryDiagnostics();
    work.run(() {
      final contour = const AnyBoxDecoration(
              offset: 6,
              enableCache: false,
              border: AnyBoxBorder(
                  corners: RoundedCorner(radius: 12),
                  outerCorners: RoundedCorner(radius: 24),
                  innerCorners: BevelCorner(radius: 2),
                  sides: AnySide(width: 3, align: 0, color: _color)))
          .buildContour(_size, null);
      final expected = Path.combine(
          PathOperation.xor,
          contour.pathFor(AnyShapeBase.outerBorder),
          contour.pathFor(AnyShapeBase.innerBorder));
      final actual = contour.regions(backgroundMerge: false).regions.single.$2;
      _sameArea(actual, expected);
      expect(work[GeometryWork.boolean], greaterThan(0));
    });
  });

  test('custom builders receive the combined offset and retain corner settings',
      () {
    const bounds = Rect.fromLTWH(13, 17, 100, 60);
    for (final reverse in [false, true]) {
      final original = _Diamond(reverse: reverse).points(bounds, null);
      for (final offset in [-8.0, 9.0]) {
        const border = AnyBorder(
            offset: 2,
            corners: BevelCorner(radius: 7),
            outerCorners: RoundedCorner(radius: 3),
            innerCorners: NotchCorner(p: 2, n: 4),
            sides: AnySide(width: 2));
        final points =
            _Diamond(offset: offset, border: border, reverse: reverse)
                .points(bounds, null);
        for (var i = 0; i < points.length; i++) {
          final next = (i + 1) % points.length;
          final edge = original[next].point - original[i].point;
          final normal = Offset(-edge.dy, edge.dx) *
              ((reverse ? -1.0 : 1.0) / edge.distance);
          for (final p in [points[i], points[next]]) {
            final delta = p.point - original[i].point;
            expect(delta.dx * normal.dx + delta.dy * normal.dy,
                closeTo(-(offset + border.offset), 1e-10));
          }
          expect(points[i].shape, same(border.corners));
          expect(points[i].outer, same(border.outerCorners));
          expect(points[i].inner, same(border.innerCorners));
          expect(points[i].side, border.sides);
        }
      }
    }
  });

  test('custom diamond paths match independent half-plane clipping', () {
    const vertices = [
      Offset(50, 0),
      Offset(100, 30),
      Offset(50, 60),
      Offset(0, 30)
    ];
    for (final reverse in [false, true]) {
      for (final offset in [-80.0, -10.0, 0.0, 8.0, 50.0]) {
        final c = _Diamond(offset: offset, reverse: reverse)
            .buildContour(_size, null);
        _sameArea(c.clipPath, _convexArea(vertices, List.filled(4, -offset)));
      }
    }
  });

  test('crown example rejects nonzero effective offsets', () {
    for (final type in example.CrownType.values) {
      final reference =
          example.CrownDecoration(type: type).points(Offset.zero & _size, null);
      for (final (decorationOffset, borderOffset, sideOffset) in [
        (1.0, 0.0, 0.0),
        (-1.0, 0.0, 0.0),
        (0.0, 1.0, 0.0),
        (0.0, -1.0, 0.0),
        (2.0, -1.0, 0.0),
        (0.0, 0.0, 1.0),
        (0.0, 0.0, -1.0)
      ]) {
        final crown = example.CrownDecoration(
            type: type,
            offset: decorationOffset,
            border: AnyBorder(
                offset: borderOffset, sides: AnySide(offset: sideOffset)));
        expect(() => crown.buildContour(_size, null), throwsUnsupportedError);
      }
      final cancelled = example.CrownDecoration(
              type: type, offset: 2, border: const AnyBorder(offset: -2))
          .points(Offset.zero & _size, null);
      expect(cancelled.map((p) => p.point), reference.map((p) => p.point));
      final sideCancelled = example.CrownDecoration(
          type: type,
          offset: 2,
          border: const AnyBorder(sides: AnySide(offset: -2)));
      final points = sideCancelled.points(Offset.zero & _size, null);
      expect(points.map((p) => p.point), reference.map((p) => p.point));
      expect(points.map((p) => p.side.offset), everyElement(-2));
      final animated = AnyDecorationTween(
          begin: example.CrownDecoration(type: type), end: sideCancelled);
      expect(
          animated
              .lerp(.5)
              .points(Offset.zero & _size, null)
              .map((p) => p.point),
          reference.map((p) => p.point));
    }
  });

  test('exhausted point outlines produce empty geometry for every band', () {
    for (final offset in [-30.0, -34.0, -80.0]) {
      final c = _box(offset, width: 80, align: 1);
      expect(c.count, 0);
      for (final base in AnyShapeBase.values) {
        expect(c.pathFor(base).computeMetrics(), isEmpty);
      }
      expect(c.outerCorners, isEmpty);
      expect(c.innerCorners, isEmpty);
      expect(c.zeroCorners, isEmpty);
      expect(c.regions(backgroundMerge: true).regions, isEmpty);
    }
  });

  test(
      'offset points retain direct/general assembly and exactly-once ownership',
      () {
    for (final corner in <AnyCorner>[
      const RoundedCorner(radius: 14),
      const BevelCorner(radius: 14),
      const InverseRoundedCorner(radius: 14),
      const NotchCorner(p: 14, n: 14)
    ]) {
      for (final offset in [-4.0, 4.0, 9.0]) {
        final d = AnyBoxDecoration(
            offset: offset,
            enableCache: false,
            border: AnyBoxBorder(
                corners: corner,
                top: const AnySide(width: 13, color: Color(0xff110000)),
                right:
                    const AnySide(width: 2, align: 1, color: Color(0xff220000)),
                bottom:
                    const AnySide(width: 8, align: 0, color: Color(0xff330000)),
                left: const AnySide(width: 0)));
        final direct = d.buildContour(_size, null);
        final general = GeometryDiagnostics(forceGeneralRegions: true).run(() {
          final c = d.buildContour(_size, null);
          return (
            [for (final base in AnyShapeBase.values) c.pathFor(base)],
            c.regions(backgroundMerge: false)
          );
        });
        for (var i = 0; i < AnyShapeBase.values.length; i++) {
          _sameArea(direct.pathFor(AnyShapeBase.values[i]), general.$1[i]);
        }
        final a = direct.regions(backgroundMerge: false).regions;
        final b = general.$2.regions;
        expect(a.length, b.length);
        for (var i = 0; i < a.length; i++) {
          _sameArea(a[i].$2, b[i].$2);
        }
        for (var x = -15.3; x < 115; x += 2.71) {
          for (var y = -15.7; y < 75; y += 2.83) {
            final p = Offset(x, y);
            expect(
                a.where((r) => r.$2.contains(p)).length, lessThanOrEqualTo(1));
          }
        }
      }
    }
  });

  test('offset tab helpers retain all boundaries and side ownership', () {
    for (final offset in [-4.0, 5.0]) {
      final decoration = AnyTabDecoration(
          offset: offset,
          enableCache: false,
          border: const AnyBoxBorder(
              corners: RoundedCorner(radius: 12),
              sides: AnySide(width: 4, align: 0, color: _color)));
      final contour = decoration.buildContour(_size, null);
      final reference = GeometryDiagnostics(forceGeneralRegions: true).run(() {
        final c = decoration.buildContour(_size, null);
        return [for (final base in AnyShapeBase.values) c.pathFor(base)];
      });
      for (var i = 0; i < AnyShapeBase.values.length; i++) {
        _sameArea(contour.pathFor(AnyShapeBase.values[i]), reference[i]);
      }
      expect(contour.clipPath.contains(const Offset(50, 30)), true);
      expect(contour.regions(backgroundMerge: false).regions, isNotEmpty);
    }
  });

  test('tab offsets rebuild helper positions without changing corner extents',
      () {
    for (final outward in [false, true]) {
      final d = AnyTabDecoration(
          offset: 3,
          offsetOutward: outward,
          border: const AnyBoxBorder(
              offset: 2, corners: RoundedCorner(radius: 12)));
      final points = d.points(Offset.zero & _size, null);
      final expected = outward
          ? const [
              Offset(-17, 65),
              Offset(-5, 65),
              Offset(-5, -5),
              Offset(105, -5),
              Offset(105, 65),
              Offset(117, 65)
            ]
          : const [
              Offset(-5, 65),
              Offset(7, 65),
              Offset(7, -5),
              Offset(93, -5),
              Offset(93, 65),
              Offset(105, 65)
            ];
      expect(points.map((p) => p.point), expected);
      for (final i in [1, 2, 3, 4]) {
        expect(points[i].shape, const RoundedCorner(radius: 12));
      }
      expect(d.buildContour(_size, null).shapeCorners[1].parameters!.p, 12);
    }
  });

  test('ratio fitting precedes offsets and primary effects select the layer',
      () {
    const d = AnyBoxDecoration.multi(
        offset: 3,
        primaryBorderIndex: 1,
        borders: [AnyBoxBorder(offset: 4), AnyBoxBorder(offset: -8, ratio: 1)],
        background: AnyBackground(color: _color));
    final contours = d.buildContours(const Size(200, 120), TextDirection.ltr);
    expect(contours[0].clipPath.getBounds(),
        const Rect.fromLTRB(-7, -7, 207, 127));
    const expected = Rect.fromLTRB(45, 5, 155, 115);
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

  test(
      'cache identity includes both offsets and preserves equivalent constructors',
      () {
    const a = AnyBoxDecoration(offset: 3, border: AnyBoxBorder(offset: 4));
    const b =
        AnyBoxDecoration.multi(offset: 3, borders: [AnyBoxBorder(offset: 4)]);
    const c = AnyBoxDecoration(offset: 4, border: AnyBoxBorder(offset: 3));
    const d = AnyBoxDecoration(offset: 3, border: AnyBoxBorder(offset: 5));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(a, isNot(d));
    expect({a, b, c, d}, hasLength(3));
    final first = a.buildContours(_size, null);
    expect(b.buildContours(_size, null), same(first));
    expect(c.buildContours(_size, null), isNot(same(first)));
    expect(d.buildContours(_size, null), isNot(same(first)));
    _sameArea(first.first.clipPath, c.buildContour(_size, null).clipPath);
  });

  test('cache hits reuse already displaced points and misses pass the full sum',
      () {
    _RecordingBox.calls.clear();
    const a =
        _RecordingBox(offset: 3, border: AnyBoxBorder(offset: 4, ratio: 1));
    final first = a.buildContours(_size, TextDirection.ltr);
    expect(_RecordingBox.calls, [
      (const Rect.fromLTWH(20, 0, 60, 60), TextDirection.ltr, a.border, 7.0)
    ]);
    expect(a.buildContours(_size, TextDirection.ltr), same(first));
    expect(_RecordingBox.calls, hasLength(1));
    const _RecordingBox(offset: 5, border: AnyBoxBorder(offset: 4, ratio: 1))
        .buildContours(_size, TextDirection.ltr);
    expect(_RecordingBox.calls.last.$4, 9);
    a.buildContours(_size, TextDirection.rtl);
    a.buildContours(const Size(110, 60), TextDirection.ltr);
    expect(_RecordingBox.calls, hasLength(4));
  });

  test('tweens interpolate both offsets, including inserted and removed layers',
      () {
    const a = AnyBoxDecoration(offset: -6, border: AnyBoxBorder(offset: 2));
    const b = AnyBoxDecoration.multi(offset: 10, borders: [
      AnyBoxBorder(offset: -2),
      AnyBoxBorder(offset: 5, sides: AnySide(width: 4, color: _color))
    ]);
    for (final reverse in [false, true]) {
      final tween =
          AnyDecorationTween(begin: reverse ? b : a, end: reverse ? a : b);
      for (final t in [0.001, 0.25, 0.4999, 0.5, 0.5001, 0.75, 0.999]) {
        final u = reverse ? 1 - t : t;
        final d = tween.lerp(t);
        expect(d.offset, closeTo(-6 + 16 * u, 1e-10));
        final points = d.points(Offset.zero & _size, null);
        expect(points.first.point.dx, closeTo(4 - 12 * u, 1e-10));
        expect(
            d.offset + d.border.offset, closeTo(-points.first.point.dx, 1e-10));
        final added = d.points(Offset.zero & _size, null, borderIndex: 1);
        expect(added.first.point.dx, closeTo(1 - 16 * u, 1e-10));
        expect(added.first.side.width, closeTo(4 * u, 1e-10));
        expect(d.buildContours(_size, null),
            isNot(same(d.buildContours(_size, null))));
      }
    }
  });

  test('animated inset collapse stays empty past the threshold', () {
    final tween = AnyDecorationTween(
        begin: const AnyBoxDecoration(
            offset: -15,
            border: AnyBoxBorder(corners: RoundedCorner(radius: 12))),
        end: const AnyBoxDecoration(
            offset: -45,
            border: AnyBoxBorder(corners: RoundedCorner(radius: 12))));
    for (final t in [0.49, 0.4999, 0.5, 0.5001, 0.51, 0.9]) {
      final contour = tween.lerp(t).buildContour(_size, null);
      final area = contour.clipPath;
      expect(area.contains(const Offset(50, 30)), t < 0.5, reason: 't=$t');
      if (t > 0.5) expect(area.computeMetrics(), isEmpty);
    }
  });

  test('shape-only resolution is lazy and ordinary offsets retain direct work',
      () {
    final calls = <(double, double)>[];
    final c = _box(5, corner: _CountCorner(calls));
    expect(calls, isEmpty);
    c.clipPath;
    expect(calls, isEmpty);
    c.outerCorners;
    expect(calls, List.filled(4, (-4.0, -4.0)));
    c.innerCorners;
    expect(calls.skip(4), List.filled(4, (4.0, 4.0)));
    c.clipPath;
    expect(calls, hasLength(8));
    final work = GeometryDiagnostics();
    work.run(() => _box(5, corner: const RoundedCorner(radius: 12))
        .regions(backgroundMerge: false));
    expect(work[GeometryWork.fit], 0);
    expect(work[GeometryWork.flatten], 0);
    expect(work[GeometryWork.boolean], 0);
  });

  test('nonfinite and overflowing offsets fail before caching geometry', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity
    ]) {
      expect(() => AnyBoxDecoration(offset: value).buildContour(_size, null),
          throwsArgumentError);
      expect(
          () => AnyBoxDecoration(border: AnyBoxBorder(offset: value))
              .buildContour(_size, null),
          throwsArgumentError);
    }
    expect(
        () => const AnyBoxDecoration(
                offset: 1e308, border: AnyBoxBorder(offset: 1e308))
            .buildContour(_size, null),
        throwsArgumentError);
  });

  test('native path offset pixels at DPR 1/2/3', () async {
    expect(await checkPathOffsetRegressions(), greaterThan(0));
  });
}
