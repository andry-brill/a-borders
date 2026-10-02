import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(100, 60);

class _ShapeBorder extends AnyBorder {
  final double shift;
  const _ShapeBorder(
      {this.shift = 0, super.offset, super.sides, super.corners});

  @override
  bool operator ==(Object other) =>
      other is _ShapeBorder && other.shift == shift && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, shift);
}

class _ShapeDecoration extends AnyDecoration {
  static final discovered = <AnyBorder>[];
  static final built = <(AnyBorder, double, List<double>)>[];

  const _ShapeDecoration.multi({
    required List<_ShapeBorder> borders,
    super.primaryBorderIndex,
  }) : super.multi(borders: borders);

  @override
  List<double> sideOffsetsForBorder(
      Rect bounds, TextDirection? direction, AnyBorder border) {
    discovered.add(border);
    return super.sideOffsetsForBorder(bounds, direction, border);
  }

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
      covariant _ShapeBorder border, double offset, List<double> sideOffsets) {
    built.add((border, offset, List.unmodifiable(sideOffsets)));
    bounds = bounds.inflate(offset + sideOffsets.single);
    if (bounds.isEmpty) return const [];
    bounds = bounds.shift(Offset(border.shift, 0));
    final side = border.sides.copyWith(offset: sideOffsets.single);
    return [
      for (final vertex in [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomRight,
        bounds.bottomLeft
      ])
        point(vertex, border: border, side: side),
    ];
  }
}

void main() {
  setUp(() {
    AnyDecorationCache.clear();
    _ShapeDecoration.discovered.clear();
    _ShapeDecoration.built.clear();
  });

  test('builders and discovery receive the selected custom border instance',
      () {
    const a = _ShapeBorder(shift: 7, sides: AnySide(offset: 2));
    const b = _ShapeBorder(
        shift: 11, sides: AnySide(offset: -3), corners: BevelCorner(radius: 4));
    const decoration =
        _ShapeDecoration.multi(borders: [a, b], primaryBorderIndex: 1);
    final primary = decoration.points(Offset.zero & _size, null);
    final first = decoration.points(Offset.zero & _size, null, borderIndex: 0);
    expect(_ShapeDecoration.discovered[0], same(b));
    expect(_ShapeDecoration.discovered[1], same(a));
    expect(_ShapeDecoration.built[0].$1, same(b));
    expect(_ShapeDecoration.built[1].$1, same(a));
    expect(primary.first.point, const Offset(14, 3));
    expect(primary.first.shape, same(b.corners));
    expect(primary.first.side.offset, -3);
    expect(first.first.point, const Offset(5, -2));
  });

  test('point defaults come from the supplied border without list lookup', () {
    const decoration = AnyBoxDecoration();
    const selected = AnyBorder(
        offset: 12,
        corners: BevelCorner(radius: 8),
        outerCorners: RoundedCorner(radius: 10),
        innerCorners: RoundedCorner(radius: 3),
        sides: AnySide(offset: 9, width: 5));
    final p = decoration.point(const Offset(7, 8), border: selected);
    expect(p.point, const Offset(7, 8));
    expect(p.shape, same(selected.corners));
    expect(p.outer, same(selected.outerCorners));
    expect(p.inner, same(selected.innerCorners));
    expect(p.side, same(selected.sides));
  });

  test('animation passes original custom borders alongside current offsets',
      () {
    const a = _ShapeBorder(offset: 1, sides: AnySide(offset: 2, width: 4));
    const b =
        _ShapeBorder(shift: 10, offset: 3, sides: AnySide(offset: 6, width: 8));
    final tween = AnyDecorationTween(
        begin: const _ShapeDecoration.multi(borders: [a]),
        end: const _ShapeDecoration.multi(borders: [b]));
    final middle = tween.lerp(.5);
    final contour = middle.buildContour(_size, null);
    expect(contour.clipPath.getBounds(), const Rect.fromLTRB(-1, -6, 111, 66));
    expect(_ShapeDecoration.built, hasLength(2));
    expect(_ShapeDecoration.built[0].$1, same(a));
    expect(_ShapeDecoration.built[1].$1, same(b));
    for (final call in _ShapeDecoration.built) {
      expect(call.$2, 2);
      expect(call.$3, [4]);
    }
    expect(
        _ShapeDecoration.discovered
            .every((border) => identical(border, a) || identical(border, b)),
        isTrue);
    final points = middle.points(Offset.zero & _size, null);
    expect(points.first.side.offset, 4);
    expect(points.first.side.width, 6);
    expect(_ShapeDecoration.built, hasLength(2));
  });

  test('equal and shared borders keep separate tween layers and saved samples',
      () {
    for (final sharedInstance in [false, true]) {
      final first = AnyBoxBorder(sides: const AnySide(offset: 2, width: 4));
      final second = sharedInstance
          ? first
          : AnyBoxBorder(sides: const AnySide(offset: 2, width: 4));
      expect(first, second);
      expect(identical(first, second), sharedInstance);
      final begin = AnyBoxDecoration.multi(
          borders: [first, second], primaryBorderIndex: 1);
      const end = AnyBoxDecoration.multi(borders: [
        AnyBoxBorder(sides: AnySide(offset: 6, width: 8)),
        AnyBoxBorder(sides: AnySide(offset: -8, width: 12)),
      ], primaryBorderIndex: 1);
      final tween = AnyDecorationTween(begin: begin, end: end);
      final saved = tween.lerp(.5);
      const expected = [
        Rect.fromLTRB(-4, -4, 104, 64),
        Rect.fromLTRB(3, 3, 97, 57)
      ];
      final contours = saved.buildContours(_size, null);
      expect(contours.map((c) => c.clipPath.getBounds()), expected);
      expect(saved.buildContour(_size, null).clipPath.getBounds(), expected[1]);
      expect(saved.points(Offset.zero & _size, null).first.side.width, 8);
      expect(
          saved
              .points(Offset.zero & _size, null, borderIndex: 0)
              .first
              .side
              .width,
          6);

      tween.begin = saved;
      tween.end = begin;
      final retargeted = tween.lerp(.5).buildContours(_size, null);
      expect(retargeted.map((c) => c.clipPath.getBounds()), const [
        Rect.fromLTRB(-3, -3, 103, 63),
        Rect.fromLTRB(.5, .5, 99.5, 59.5)
      ]);
      expect(
          saved.buildContours(_size, null).map((c) => c.clipPath.getBounds()),
          expected);
    }
  });
}
