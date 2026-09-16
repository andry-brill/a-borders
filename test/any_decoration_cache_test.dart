import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(AnyDecorationCache.clear);

  tearDown(() {
    AnyDecorationCache.limit = 1000;
    AnyDecorationCache.clear();
  });

  test('returns null for missing keys', () {
    final key = (_TestDecoration(1), const Size(10, 10), TextDirection.ltr);

    expect(AnyDecorationCache.get(key), isNull);
  });

  test('stores and returns contours by key', () {
    final key = (_TestDecoration(1), const Size(10, 10), TextDirection.ltr);
    final contour = _contour();

    AnyDecorationCache.put(key, [contour]);

    expect(AnyDecorationCache.get(key)!.single, same(contour));
  });

  test('evicts least recently used contours when limit is exceeded', () {
    AnyDecorationCache.limit = 2;
    final firstKey =
        (_TestDecoration(1), const Size(10, 10), TextDirection.ltr);
    final secondKey =
        (_TestDecoration(2), const Size(10, 10), TextDirection.ltr);
    final thirdKey =
        (_TestDecoration(3), const Size(10, 10), TextDirection.ltr);
    final firstContour = _contour();
    final secondContour = _contour();
    final thirdContour = _contour();

    AnyDecorationCache.put(firstKey, [firstContour]);
    AnyDecorationCache.put(secondKey, [secondContour]);
    AnyDecorationCache.put(thirdKey, [thirdContour]);

    expect(AnyDecorationCache.get(firstKey), isNull);
    expect(AnyDecorationCache.get(secondKey)!.single, same(secondContour));
    expect(AnyDecorationCache.get(thirdKey)!.single, same(thirdContour));
  });

  test('refreshes key recency on get', () {
    AnyDecorationCache.limit = 2;
    final firstKey =
        (_TestDecoration(1), const Size(10, 10), TextDirection.ltr);
    final secondKey =
        (_TestDecoration(2), const Size(10, 10), TextDirection.ltr);
    final thirdKey =
        (_TestDecoration(3), const Size(10, 10), TextDirection.ltr);
    final firstContour = _contour();
    final secondContour = _contour();
    final thirdContour = _contour();

    AnyDecorationCache.put(firstKey, [firstContour]);
    AnyDecorationCache.put(secondKey, [secondContour]);

    expect(AnyDecorationCache.get(firstKey)!.single, same(firstContour));

    AnyDecorationCache.put(thirdKey, [thirdContour]);

    expect(AnyDecorationCache.get(secondKey), isNull);
    expect(AnyDecorationCache.get(firstKey)!.single, same(firstContour));
    expect(AnyDecorationCache.get(thirdKey)!.single, same(thirdContour));
  });

  test('clear removes stored contours', () {
    final key = (_TestDecoration(1), const Size(10, 10), TextDirection.ltr);

    AnyDecorationCache.put(key, [_contour()]);
    AnyDecorationCache.clear();

    expect(AnyDecorationCache.get(key), isNull);
  });
}

AnyContour _contour() {
  return AnyContour(
    points: [
      AnyPoint(
        shape: const RoundedCorner(),
        point: Offset.zero,
        side: const AnySide(),
      ),
      AnyPoint(
        shape: const RoundedCorner(),
        point: const Offset(10, 0),
        side: const AnySide(),
      ),
      AnyPoint(
        shape: const RoundedCorner(),
        point: const Offset(10, 10),
        side: const AnySide(),
      ),
      AnyPoint(
        shape: const RoundedCorner(),
        point: const Offset(0, 10),
        side: const AnySide(),
      ),
    ],
    background: null,
    backgroundBase: AnyShapeBase.zeroBorder,
    clipBase: AnyShapeBase.zeroBorder,
    shadowBase: AnyShapeBase.zeroBorder,
  );
}

class _TestDecoration extends AnyDecoration {
  final int value;

  const _TestDecoration(this.value);

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is _TestDecoration && other.value == value && super == other;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, value);
}
