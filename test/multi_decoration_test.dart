import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/any_extras.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(200, 100);
const _blue = Color(0xFF0000FF);
const _a = AnyBoxBorder(
    corners: RoundedCorner(radius: 20), sides: AnySide(width: 4, color: _blue));
const _b = AnyBoxBorder(
    corners: BevelCorner(radius: 10),
    ratio: 1,
    sides: AnySide(width: 8, color: _blue));

void main() {
  setUp(AnyDecorationCache.clear);

  test('const multi layers have independent ratios and a primary contour', () {
    const decoration = AnyBoxDecoration.multi(
        borders: [_a, _b],
        primaryBorderIndex: 1,
        background: AnyBackground(color: _blue));
    expect(decoration.border, _b);
    final contours = decoration.buildContours(_size, TextDirection.ltr);
    expect(contours, hasLength(2));
    expect(contours[0].clipPath.getBounds(), Offset.zero & _size);
    expect(
        contours[1].clipPath.getBounds(), const Rect.fromLTWH(50, 0, 100, 100));
    expect(contours[0].backgroundPath, isNull);
    expect(contours[1].backgroundPath, isNotNull);
    expect(
        decoration.buildContour(_size, TextDirection.ltr), same(contours[1]));
    expect(decoration.buildContours(_size, TextDirection.ltr), same(contours));
    expect(() => contours.clear(), throwsUnsupportedError);
    expect(() => decoration.borders.add(_a), throwsUnsupportedError);
  });

  test('all selectors use primary and clipping honors the paint origin', () {
    for (final base in AnyShapeBase.values) {
      final multi = AnyBoxDecoration.multi(
          borders: const [_a, _b],
          primaryBorderIndex: 1,
          clipBase: base,
          shadowBase: base,
          background: AnyBackground(color: _blue, shapeBase: base));
      final single = AnyBoxDecoration(
          border: _b,
          clipBase: base,
          shadowBase: base,
          background: AnyBackground(color: _blue, shapeBase: base));
      final actual = multi.buildContour(_size, TextDirection.ltr);
      final expected = single.buildContour(_size, TextDirection.ltr);
      for (final pair in [
        (actual.clipPath, expected.clipPath),
        (actual.shadowPath, expected.shadowPath),
        (actual.backgroundPath!, expected.backgroundPath!)
      ]) {
        expect(
            Path.combine(PathOperation.xor, pair.$1, pair.$2).computeMetrics(),
            isEmpty);
      }
      const origin = Offset(17, 31);
      expect(multi.getClipPath(origin & _size, TextDirection.ltr).getBounds(),
          expected.clipPath.getBounds().shift(origin));
    }
  });

  test('single and one-layer multi compare and hash equally', () {
    const single = AnyBoxDecoration(border: _a);
    const multi = AnyBoxDecoration.multi(borders: [_a]);
    expect(single, multi);
    expect(single.hashCode, multi.hashCode);
    expect(single.buildContour(_size, TextDirection.ltr),
        same(multi.buildContour(_size, TextDirection.ltr)));
  });

  test('equality and cache include order, primary, and new corner fields', () {
    const a = AnyBoxDecoration.multi(borders: [_a, _b]);
    const reversed = AnyBoxDecoration.multi(borders: [_b, _a]);
    const primary =
        AnyBoxDecoration.multi(borders: [_a, _b], primaryBorderIndex: 1);
    expect(a, isNot(reversed));
    expect(a, isNot(primary));
    expect(a.buildContours(_size, TextDirection.ltr),
        isNot(same(primary.buildContours(_size, TextDirection.ltr))));
    const shape = AnyBoxBorder(topLeft: RoundedCorner(radius: 7));
    const outer = AnyBoxBorder(outerTopLeft: RoundedCorner(radius: 7));
    const inner = AnyBoxBorder(innerTopLeft: RoundedCorner(radius: 7));
    expect(shape, isNot(outer));
    expect(outer, isNot(inner));
    expect(const AnyBorder(outerCorners: BevelCorner(radius: 2)),
        isNot(const AnyBorder()));
  });

  test('disabled cache builds fresh complete collections', () {
    const decoration =
        AnyBoxDecoration.multi(borders: [_a, _b], enableCache: false);
    final a = decoration.buildContours(_size, TextDirection.ltr);
    final b = decoration.buildContours(_size, TextDirection.ltr);
    expect(a, isNot(same(b)));
    expect(a.first, isNot(same(b.first)));
  });

  test('rejects empty layers and invalid primary or point indices', () {
    expect(
        () => const AnyBoxDecoration.multi(borders: [])
            .buildContours(_size, TextDirection.ltr),
        throwsArgumentError);
    expect(
        () =>
            AnyBoxDecoration.multi(borders: const [_a], primaryBorderIndex: -1),
        throwsAssertionError);
    expect(
        () => const AnyBoxDecoration.multi(borders: [_a], primaryBorderIndex: 1)
            .buildContours(_size, TextDirection.ltr),
        throwsRangeError);
    const decoration = AnyBoxDecoration.multi(borders: [_a, _b]);
    expect(
        () => decoration.points(Offset.zero & _size, TextDirection.ltr,
            borderIndex: 2),
        throwsRangeError);
    // Even when a caller violates the immutable-input contract, construction
    // must fail before trying to index or calculate geometry in release mode.
    final input = <AnyBoxBorder>[_a];
    final invalid = AnyBoxDecoration.multi(borders: input);
    input.clear();
    expect(() => invalid.buildContours(_size, TextDirection.ltr),
        throwsArgumentError);
  });

  test('point retrieval and default resolution use the selected index', () {
    const decoration =
        AnyBoxDecoration.multi(borders: [_a, _b], primaryBorderIndex: 1);
    final primary = decoration.points(Offset.zero & _size, TextDirection.ltr);
    final first = decoration.points(Offset.zero & _size, TextDirection.ltr,
        borderIndex: 0);
    expect(primary.first.shape, _b.corners);
    expect(primary.first.side.width, 8);
    expect(first.first.shape, _a.corners);
    expect(first.first.side.width, 4);
  });

  test('tab multi derives each tab outline from its own shape corners', () {
    const decoration = AnyTabDecoration.multi(borders: [
      AnyBoxBorder(bottomLeft: RoundedCorner(radius: 10)),
      AnyBoxBorder(
          bottomLeft: RoundedCorner(radius: 25),
          outerBottomLeft: BevelCorner(radius: 40)),
    ], primaryBorderIndex: 1);
    final first = decoration.points(Offset.zero & _size, TextDirection.ltr,
        borderIndex: 0);
    final second = decoration.points(Offset.zero & _size, TextDirection.ltr);
    expect(first.first.point.dx, -10);
    expect(second.first.point.dx, -25);
    expect(second[1].shape, const RoundedCorner(radius: 25));
    expect(second[1].outer, const BevelCorner(radius: 40));
    expect(decoration.buildContours(_size, TextDirection.ltr), hasLength(2));
  });

  test('custom decorations can invoke the abstract multi constructor', () {
    const decoration = _Polygon.multi(borders: [
      AnyBorder(),
      AnyBorder(corners: BevelCorner(radius: 4), sides: AnySide(width: 2))
    ]);
    expect(
        decoration
            .buildContours(_size, TextDirection.ltr)[1]
            .shapeCorners
            .first
            .parameters!,
        const BevelCorner(radius: 4));
  });

  test('layer tween animates insertion and removal without changing fills', () {
    const one = AnyBoxDecoration(border: _a);
    const two =
        AnyBoxDecoration.multi(borders: [_a, _b], primaryBorderIndex: 1);
    for (final pair in [(one, two), (two, one)]) {
      final tween = AnyDecorationTween(begin: pair.$1, end: pair.$2);
      expect(tween.lerp(0), same(pair.$1));
      expect(tween.lerp(1), same(pair.$2));
      final mid = tween.lerp(0.25);
      final contours = mid.buildContours(_size, TextDirection.ltr);
      expect(contours, hasLength(2));
      expect(contours[1].sides.first.width, pair.$1 == one ? 2 : 6);
      expect(contours[1].sides.first.color, _blue);
      expect(contours[1].shapeCorners.first.parameters!, _b.corners);
      expect(contours[1].clipPath.getBounds(),
          const Rect.fromLTWH(50, 0, 100, 100));
      expect(mid.primaryBorderIndex, pair.$1.primaryBorderIndex);
      expect(tween.lerp(0.75).primaryBorderIndex, pair.$2.primaryBorderIndex);
      expect(mid.enableCache, isFalse);
    }
  });

  test('matched layer ratios and shape corners interpolate independently', () {
    const begin = AnyBoxDecoration.multi(borders: [
      AnyBoxBorder(ratio: 1, corners: RoundedCorner(radius: 10)),
      AnyBoxBorder(ratio: 2, corners: RoundedCorner(radius: 20)),
    ]);
    const end = AnyBoxDecoration.multi(borders: [
      AnyBoxBorder(ratio: 2, corners: RoundedCorner(radius: 30)),
      AnyBoxBorder(ratio: 4, corners: RoundedCorner(radius: 40)),
    ]);
    final contours = AnyDecorationTween(begin: begin, end: end)
        .lerp(0.5)
        .buildContours(_size, TextDirection.ltr);
    expect(contours[0].clipPath.getBounds().width, closeTo(150, 1e-8));
    expect(contours[0].shapeCorners.first.parameters!.p, closeTo(20, 1e-8));
    expect(contours[1].clipPath.getBounds().height, closeTo(200 / 3, 1e-5));
    expect(contours[1].shapeCorners.first.parameters!.p, closeTo(80 / 3, 1e-8));
  });

  test(
      'nullable override and mismatched point-count interpolation stays defined',
      () {
    const a = AnyPoint(
        shape: RoundedCorner(radius: 10), point: Offset.zero, side: AnySide());
    const b = AnyPoint(
        shape: BevelCorner(radius: 20),
        outer: RoundedCorner(radius: 30),
        inner: BevelCorner(radius: 5),
        point: Offset.zero,
        side: AnySide());
    final before = AnyPoint.lerp([a], [b], 0.25)!.single;
    final after = AnyPoint.lerp([a], [b], 0.75)!.single;
    expect(before.outer, isNull);
    expect(before.inner, isNull);
    expect(after.outer, b.outer);
    expect(after.inner, b.inner);
    expect(AnyPoint.lerp([a], [b, b], 0.25), [a]);
    expect(AnyPoint.lerp([a], [b, b], 0.75), [b, b]);
    final tween = AnyDecorationTween(
        begin: const AnyBoxDecoration(
            border: AnyBoxBorder(corners: RoundedCorner.infinity())),
        end: const AnyBoxDecoration(
            border: AnyBoxBorder(corners: BevelCorner(radius: 20))));
    for (final t in [0.25, 0.5, 0.75]) {
      expect(
          tween
              .lerp(t)
              .buildContour(_size, TextDirection.ltr)
              .clipPath
              .getBounds()
              .isFinite,
          isTrue);
    }
  });
}

class _Polygon extends AnyDecoration {
  const _Polygon.multi({required super.borders}) : super.multi();

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection,
      int borderIndex, double offset) {
    bounds = bounds.inflate(offset);
    if (bounds.isEmpty) return const [];
    return [
      point(bounds.topLeft, borderIndex: borderIndex),
      point(bounds.topRight, borderIndex: borderIndex),
      point(bounds.bottomRight, borderIndex: borderIndex),
      point(bounds.bottomLeft, borderIndex: borderIndex),
    ];
  }
}
