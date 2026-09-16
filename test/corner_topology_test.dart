import 'dart:ui';
import 'dart:math' as math;
import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';

AnyContour outlined(List<Offset> points, AnyCorner corner, double width) =>
    AnyContour(
        points: [
          for (var i = 0; i < points.length; i++)
            AnyPoint(
                point: points[i],
                shape: corner,
                side: AnySide(
                    width: width,
                    align: -1,
                    color: Color(0xff000000 + i * 123456)))
        ],
        background: null,
        backgroundBase: AnyShapeBase.shapeBorder,
        clipBase: AnyShapeBase.innerBorder,
        shadowBase: AnyShapeBase.shapeBorder);

void main() {
  test('inside widths consume an entire box without reopening reversed edges',
      () {
    for (final corner in [
      const RoundedCorner(),
      const RoundedCorner(radius: 20),
      const BevelCorner(radius: 20),
      const InverseRoundedCorner(radius: 20)
    ]) {
      for (final width in [50.0, 60.0, 100.0]) {
        final c = outlined([
          Offset.zero,
          const Offset(100, 0),
          const Offset(100, 100),
          const Offset(0, 100)
        ], corner, width);
        expect(c.pathFor(AnyShapeBase.innerBorder).computeMetrics(), isEmpty,
            reason: '$corner width=$width');
      }
    }
  });
  test('closing a narrow neck preserves both surviving interior components',
      () {
    final c = outlined(const [
      Offset(0, 0),
      Offset(60, 0),
      Offset(60, 20),
      Offset(100, 20),
      Offset(100, 0),
      Offset(160, 0),
      Offset(160, 60),
      Offset(100, 60),
      Offset(100, 40),
      Offset(60, 40),
      Offset(60, 60),
      Offset(0, 60)
    ], const RoundedCorner(), 12);
    final inner = c.pathFor(AnyShapeBase.innerBorder);
    expect(inner.computeMetrics().length, 2);
    expect(inner.contains(const Offset(30, 30)), isTrue);
    expect(inner.contains(const Offset(130, 30)), isTrue);
    expect(inner.contains(const Offset(80, 30)), isFalse);
  });
  test('painted side areas partition the final ring without holes or overlap',
      () {
    for (final corner in [
      const RoundedCorner(radius: 20),
      const BevelCorner.elliptical(p: 25, n: 15),
      const InverseRoundedCorner(radius: 20)
    ]) {
      for (final width in [8.0, 35.0, 60.0]) {
        final c = outlined(const [
          Offset(0, 0),
          Offset(100, 0),
          Offset(100, 100),
          Offset(0, 100)
        ], corner, width);
        final outer = c.pathFor(AnyShapeBase.outerBorder),
            inner = c.pathFor(AnyShapeBase.innerBorder);
        final regions =
            c.regions(backgroundMerge: false).regions.map((r) => r.$2).toList();
        for (var x = 0.713; x < 100; x += 3) {
          for (var y = 0.317; y < 100; y += 3) {
            final p = Offset(x, y),
                expected = outer.contains(p) && !inner.contains(p);
            expect(regions.where((r) => r.contains(p)).length, expected ? 1 : 0,
                reason: '${corner.runtimeType} width=$width point=$p');
          }
        }
      }
    }
  });
  test('concentric scoop filled area matches circle and sharp-join equations',
      () {
    for (final width in [4.0, 20.0, 25.0]) {
      for (final align in [-1.0, 1.0]) {
        final d = -align * width;
        final c = AnyBoxDecoration(
                enableCache: false,
                border: AnyBoxBorder(
                    topLeft: const InverseRoundedCorner(radius: 20),
                    sides: AnySide(width: width, align: align)))
            .buildContour(const Size(200, 160), TextDirection.ltr);
        final path = c.pathFor(
            align < 0 ? AnyShapeBase.innerBorder : AnyShapeBase.outerBorder);
        for (var x = -26.317; x < 210; x += 2.5) {
          for (var y = -26.713; y < 170; y += 2.5) {
            final point = Offset(x, y),
                radius = 20 + d,
                outsideCut = d >= 0
                    ? point.distance >= radius
                    : radius > 0
                        ? Offset(math.max(0, x), math.max(0, y)).distance >=
                            radius
                        : x >= radius || y >= radius,
                inside = x >= d &&
                    y >= d &&
                    x <= 200 - d &&
                    y <= 160 - d &&
                    outsideCut;
            expect(path.contains(point), inside,
                reason: 'width=$width align=$align point=$point');
          }
        }
      }
    }
  });
}
