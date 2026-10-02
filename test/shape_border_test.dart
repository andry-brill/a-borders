import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(200, 120);

AnyContour _contour(AnyBoxBorder border,
        {AnyShapeBase base = AnyShapeBase.shapeBorder, Size size = _size}) =>
    AnyBoxDecoration(border: border, clipBase: base, enableCache: false)
        .buildContour(size, TextDirection.ltr);

void _samePath(Path a, Path b) {
  expect(Path.combine(PathOperation.xor, a, b).computeMetrics(), isEmpty);
}

AnyBoxBorder _rounded(double width, double align,
        {AnyCorner? outer, AnyCorner? inner}) =>
    AnyBoxBorder(
      corners: const RoundedCorner(radius: 20),
      outerCorners: outer,
      innerCorners: inner,
      sides: AnySide(width: width, align: align),
    );

void main() {
  test('shape is required on points; inner and outer are optional', () {
    const point = AnyPoint(
        shape: RoundedCorner(radius: 20),
        point: Offset.zero,
        side: AnySide(width: 4));
    expect(point.outer, isNull);
    expect(point.inner, isNull);
    expect(const AnyBackground().shapeBase, AnyShapeBase.shapeBorder);
    expect(const AnyBoxDecoration().clipBase, AnyShapeBase.shapeBorder);
    expect(const AnyBoxDecoration().shadowBase, AnyShapeBase.shapeBorder);
  });

  for (final align in [-1.0, -0.5, 0.0, 0.5, 1.0]) {
    test('rounded bands derive independently at alignment $align', () {
      final contour = _contour(_rounded(8, align));
      expect(contour.shapeCorners.first.parameters!.p, 20);
      expect(
          contour.outerCorners.first.parameters!.p, 20 + 8 * (1 + align) / 2);
      expect(
          contour.innerCorners.first.parameters!.p, 20 - 8 * (1 - align) / 2);
      _samePath(contour.clipPath, _contour(_rounded(0, 0)).clipPath);
    });
  }

  test('each explicit override affects only its own band', () {
    for (final outer in [null, const BevelCorner(radius: 35)]) {
      for (final inner in [null, const RoundedCorner(radius: 3)]) {
        final contour = _contour(_rounded(8, 0, outer: outer, inner: inner));
        expect(contour.outerCorners.first.parameters!,
            outer ?? const RoundedCorner(radius: 24));
        expect(contour.innerCorners.first.parameters!,
            inner ?? const RoundedCorner(radius: 16));
        expect(contour.shapeCorners.first.parameters!,
            const RoundedCorner(radius: 20));
        _samePath(contour.clipPath, _contour(_rounded(0, 0)).clipPath);
      }
    }
  });

  test('shape path does not inherit explicit outer corners; legacy zero does',
      () {
    final border = _rounded(8, 1, outer: const BevelCorner(radius: 40));
    final shape = _contour(border);
    final zero = _contour(border, base: AnyShapeBase.zeroBorder);
    expect(shape.shapeCorners.first.parameters!, isA<RoundedCorner>());
    expect(zero.zeroCorners.first.parameters!, isA<BevelCorner>());
    expect(
        Path.combine(PathOperation.xor, shape.clipPath, zero.clipPath)
            .computeMetrics(),
        isNotEmpty);
    expect(
        shape.innerCorners.first.parameters!, const RoundedCorner(radius: 20));
  });

  test('point, per-corner, and global defaults resolve independently', () {
    const decoration = AnyBoxDecoration(
        border: AnyBoxBorder(
      corners: RoundedCorner(radius: 20),
      topLeft: BevelCorner(radius: 12),
      outerCorners: RoundedCorner(radius: 28),
      outerTopLeft: BevelCorner(radius: 18),
      innerCorners: RoundedCorner(radius: 8),
      innerTopRight: BevelCorner(radius: 5),
      sides: AnySide(width: 4),
      top: AnySide(width: 6),
    ));
    final points = decoration.points(Offset.zero & _size, TextDirection.ltr);
    expect(points[0].shape, const BevelCorner(radius: 12));
    expect(points[0].outer, const BevelCorner(radius: 18));
    expect(points[0].inner, const RoundedCorner(radius: 8));
    expect(points[0].side.width, 6);
    expect(points[1].shape, const RoundedCorner(radius: 20));
    expect(points[1].outer, const RoundedCorner(radius: 28));
    expect(points[1].inner, const BevelCorner(radius: 5));
    final explicit = decoration.point(Offset.zero,
        border: decoration.border,
        shape: const RoundedCorner(radius: 7),
        outer: const RoundedCorner(radius: 9),
        inner: const RoundedCorner(radius: 1),
        side: const AnySide(width: 2));
    expect(explicit.shape.p, 7);
    expect(explicit.outer!.p, 9);
    expect(explicit.inner!.p, 1);
    expect(explicit.side.width, 2);
  });

  test('outside layered widths have radii (20,24) and (20,22)', () {
    for (final width in [4.0, 2.0]) {
      final contour = _contour(_rounded(width, 1));
      expect(contour.innerCorners.first.parameters!.p, 20);
      expect(contour.outerCorners.first.parameters!.p, 20 + width);
    }
  });

  test('asymmetric bevel inner is derived from shape without round-trip drift',
      () {
    const shape = BevelCorner.elliptical(p: 30, n: 10);
    final contour = _contour(const AnyBoxBorder(
      corners: shape,
      left: AnySide(width: 4, align: AnySide.alignOutside),
      top: AnySide(width: 8, align: AnySide.alignOutside),
    ));
    expect(
        contour.outerCorners.first.parameters!.p, closeTo(37.3508893593, 1e-8));
    expect(
        contour.outerCorners.first.parameters!.n, closeTo(8.2339262396, 1e-8));
    expect(contour.innerCorners.first.parameters!, shape);
  });

  test('infinite and oversized corners normalize on shape before offsets', () {
    for (final corner in [
      const RoundedCorner.infinity(),
      const RoundedCorner(radius: 1000)
    ]) {
      final contour = _contour(
          AnyBoxBorder(
              corners: corner,
              sides: const AnySide(width: 4, align: AnySide.alignOutside)),
          size: const Size(200, 100));
      expect(
          contour.shapeCorners.map((c) => c.parameters!.p), everyElement(50));
      expect(
          contour.outerCorners.map((c) => c.parameters!.p), everyElement(54));
      expect(
          contour.innerCorners.map((c) => c.parameters!.p), everyElement(50));
    }
  });

  test('circle and pill fit source corners, and zero sides remain valid', () {
    final circle = _contour(const AnyBoxBorder(shape: AnyBoxShape.circle),
        size: const Size(200, 100));
    expect(circle.clipPath.getBounds(), const Rect.fromLTWH(50, 0, 100, 100));
    final pill = _contour(const AnyBoxBorder(shape: AnyBoxShape.pill),
        size: const Size(200, 100));
    expect(pill.shapeCorners.first.parameters!.p, 50);
    expect(pill.regions(backgroundMerge: false).regions, isEmpty);
    expect(pill.clipPath.getBounds(), Offset.zero & const Size(200, 100));
  });

  test('converter policies remain available', () {
    final equal = _contour(const AnyBoxBorder(
        corners: RoundedCorner(radius: 20, converter: CornerConverter.equal),
        sides: AnySide(width: 4, align: AnySide.alignOutside)));
    expect(equal.outerCorners.first.parameters!.p, 20);
    final ratio = _contour(const AnyBoxBorder(
        corners: RoundedCorner.elliptical(
            p: 30, n: 10, converter: CornerConverter.preserveRatio),
        sides: AnySide(width: 4, align: AnySide.alignOutside)));
    expect(
        ratio.outerCorners.first.parameters!.p /
            ratio.outerCorners.first.parameters!.n,
        closeTo(3, 1e-9));
  });

  test('full arcs and arbitrary subdivisions use identical geometry', () {
    for (final corner in <AnyCorner>[
      const RoundedCorner.elliptical(p: 20, n: 35),
      const InverseRoundedCorner(radius: 20),
      const BevelCorner.elliptical(p: 30, n: 12),
    ]) {
      final contour = _contour(AnyBoxBorder(
          corners: corner,
          sides: const AnySide(width: 4, align: AnySide.alignOutside)));
      for (final resolved in [
        contour.shapeCorners.first,
        contour.outerCorners.first
      ]) {
        for (final reverse in [false, true]) {
          final from = reverse ? 1.0 : 0.0, to = reverse ? 0.0 : 1.0;
          final a = Path();
          resolved.appendTo(a, from: from, to: to, moveTo: true);
          a.close();
          final b = Path();
          resolved.appendTo(b, from: from, to: 0.371, moveTo: true);
          resolved.appendTo(b, from: 0.371, to: to);
          b.close();
          for (var x = -5.25; x < 40; x += 0.5) {
            for (var y = -5.25; y < 40; y += 0.5) {
              expect(a.contains(Offset(x, y)), b.contains(Offset(x, y)));
            }
          }
        }
      }
    }
  });
}
