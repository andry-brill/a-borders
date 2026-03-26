import 'any_corner.dart';
import 'any_side.dart';

abstract class IAnyBorder {
  IAnySide? get left;
  IAnySide? get top;
  IAnySide? get right;
  IAnySide? get bottom;

  IAnyCorner get topLeft;
  IAnyCorner get topRight;
  IAnyCorner get bottomRight;
  IAnyCorner get bottomLeft;

  IAnyBorder copyWithout({bool left = true, bool top = true, bool right = true, bool bottom = true});
}

class AnyBorder implements IAnyBorder {

  static IAnyCorner cornersBase = const AnySquareCorner();

  final IAnySide? _left;
  @override
  IAnySide? get left => _left ?? sides;

  final IAnySide? _top;
  @override
  IAnySide? get top => _top ?? sides;

  final IAnySide? _right;
  @override
  IAnySide? get right => _right ?? sides;

  final IAnySide? _bottom;
  @override
  IAnySide? get bottom => _bottom ?? sides;

  final IAnySide? sides;

  final IAnyCorner? _topLeft;
  @override
  IAnyCorner get topLeft => _topLeft ?? corners;

  final IAnyCorner? _topRight;
  @override
  IAnyCorner get topRight => _topRight ?? corners;

  final IAnyCorner? _bottomRight;
  @override
  IAnyCorner get bottomRight => _bottomRight ?? corners;

  final IAnyCorner? _bottomLeft;
  @override
  IAnyCorner get bottomLeft => _bottomLeft ?? corners;

  final IAnyCorner? _corners;
  IAnyCorner get corners => _corners ?? cornersBase;

  const AnyBorder({
    IAnySide? left,
    IAnySide? top,
    IAnySide? right,
    IAnySide? bottom,
    this.sides,
    IAnyCorner? topLeft,
    IAnyCorner? topRight,
    IAnyCorner? bottomRight,
    IAnyCorner? bottomLeft,
    IAnyCorner? corners,
  })  :
        _corners = corners,
        _left = left,
        _top = top,
        _right = right,
        _bottom = bottom,
        _topLeft = topLeft,
        _topRight = topRight,
        _bottomRight = bottomRight,
        _bottomLeft = bottomLeft;

  @override
  IAnyBorder copyWithout({bool left = true, bool top = true, bool right = true, bool bottom = true}) {

    if (!left && !top && !right && !bottom) return this;

    // NB! Must be used separately (in case sides is set)
    return AnyBorder(
      left: left ? null : this.left,
      top: top ? null : this.top,
      right: right ? null : this.right,
      bottom: bottom ? null : this.bottom,
      topLeft: topLeft,
      topRight: topRight,
      bottomRight: bottomRight,
      bottomLeft: bottomLeft,
    );
  }
}
