import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('AnyDecoration stores border defaults in AnyBorder', () {

    const border = AnyBorder(
      sides: AnySide(width: 4),
      corners: RoundedCorner(radius: 12),
      ratio: 2,
    );

    const decoration = _TestDecoration(border: border);

    expect(decoration.border, border);
    expect(
      decoration
          .getClipPath(Offset.zero & const Size(200, 200), TextDirection.ltr)
          .getBounds()
          .size,
      const Size(200, 100),
    );

  });

  test('AnyBoxDecoration equality is based on AnyBoxBorder and runtimeType', () {

    const a = AnyBoxDecoration(
      border: AnyBoxBorder(
        sides: AnySide(width: 4),
        corners: RoundedCorner(radius: 12),
      ),
    );
    const b = AnyBoxDecoration(
      border: AnyBoxBorder(
        sides: AnySide(width: 4),
        corners: RoundedCorner(radius: 12),
      ),
    );
    const c = AnyBoxDecoration(
      border: AnyBoxBorder(
        sides: AnySide(width: 8),
        corners: RoundedCorner(radius: 12),
      ),
    );

    expect(a, b);
    expect(a, isNot(c));
    expect(a, isNot(_TestDecoration(border: a.border)));

  });

  test('AnyBorder equality does not mix base and box border types', () {

    const base = AnyBorder(
      sides: AnySide(width: 4),
      corners: RoundedCorner(radius: 12),
    );

    const box = AnyBoxBorder(
      sides: AnySide(width: 4),
      corners: RoundedCorner(radius: 12),
    );

    expect(base == box, isFalse);
    expect(box == base, isFalse);

  });
}

class _TestDecoration extends AnyDecoration {
  const _TestDecoration({super.border});

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection) => [
        point(bounds.topLeft),
        point(bounds.topRight),
        point(bounds.bottomRight),
        point(bounds.bottomLeft),
      ];
}
