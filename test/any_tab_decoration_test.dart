import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/any_extras.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives outward tab offsets from bottom corner extents by default', () {
    const decoration = AnyTabDecoration(
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 12, n: 4),
        bottomRight: RoundedCorner.elliptical(p: 8, n: 24),
      ),
    );

    final points = decoration.points(
      Offset.zero & const Size(100, 40),
      TextDirection.ltr,
    );

    expect(points[0].point, const Offset(-12, 40));
    expect(points[1].point, const Offset(0, 40));
    expect(points[2].point, const Offset(0, 0));
    expect(points[3].point, const Offset(100, 0));
    expect(points[4].point, const Offset(100, 40));
    expect(points[5].point, const Offset(124, 40));
  });

  test('can inset tab offsets inside the bounds', () {
    const decoration = AnyTabDecoration(
      offsetOutward: false,
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 12, n: 4),
        bottomRight: RoundedCorner.elliptical(p: 8, n: 24),
      ),
    );

    final points = decoration.points(
      Offset.zero & const Size(100, 40),
      TextDirection.ltr,
    );

    expect(points[0].point, const Offset(0, 40));
    expect(points[1].point, const Offset(12, 40));
    expect(points[2].point, const Offset(12, 0));
    expect(points[3].point, const Offset(76, 0));
    expect(points[4].point, const Offset(76, 40));
    expect(points[5].point, const Offset(100, 40));
  });

  test('normalizes oversized bottom corner extents to fit width', () {
    const decoration = AnyTabDecoration(
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 80, n: 0),
        bottomRight: RoundedCorner.elliptical(p: 0, n: 40),
      ),
    );

    final points = decoration.points(
      Offset.zero & const Size(90, 40),
      TextDirection.ltr,
    );

    expect(points[0].point.dx, -60);
    expect(points[1].point.dx, 0);
    expect(points[4].point.dx, 90);
    expect(points[5].point.dx, 120);
  });

  test('skips collapsed bottom tab points while keeping point count stable',
      () {
    const decoration = AnyTabDecoration(
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 0, n: 0),
        bottomRight: RoundedCorner.elliptical(p: 0, n: 0),
      ),
    );

    final points = decoration.points(
      Offset.zero & const Size(100, 40),
      TextDirection.ltr,
    );

    final contour = decoration.buildContour(
      const Size(100, 40),
      TextDirection.ltr,
    );

    expect(points, hasLength(6));
    expect(points.first.skip, isTrue);
    expect(points.last.skip, isTrue);
    expect(contour.count, 4);
  });

  test('lerp keeps collapsed outward tab point when only one side skips it',
      () {
    const collapsed = AnyTabDecoration(
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 0, n: 0),
      ),
    );
    const expanded = AnyTabDecoration(
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 20, n: 0),
      ),
    );

    final points = AnyPoint.lerp(
      collapsed.points(Offset.zero & const Size(100, 40), TextDirection.ltr),
      expanded.points(Offset.zero & const Size(100, 40), TextDirection.ltr),
      0.75,
    )!;

    expect(points, hasLength(6));
    expect(points[0].skip, isFalse);
    expect(points[0].point, const Offset(-15, 40));
  });

  test('AnyTabDecoration equality is based on AnyBoxBorder and runtimeType',
      () {
    const a = AnyTabDecoration(
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 12, n: 4),
        bottomRight: RoundedCorner.elliptical(p: 8, n: 24),
      ),
    );
    const b = AnyTabDecoration(
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 12, n: 4),
        bottomRight: RoundedCorner.elliptical(p: 8, n: 24),
      ),
    );
    const c = AnyTabDecoration(
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 16, n: 4),
        bottomRight: RoundedCorner.elliptical(p: 8, n: 24),
      ),
    );
    const d = AnyTabDecoration(
      offsetOutward: false,
      border: AnyBoxBorder(
        bottomLeft: RoundedCorner.elliptical(p: 12, n: 4),
        bottomRight: RoundedCorner.elliptical(p: 8, n: 24),
      ),
    );

    expect(a, b);
    expect(a, isNot(c));
    expect(a, isNot(d));
    expect(a, isNot(AnyBoxDecoration(border: a.border)));
  });
}
