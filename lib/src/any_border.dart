import 'package:any_borders/src/any_corner.dart';
import 'any_side.dart';


abstract class IAnyBorder {

}

class AnyBorder2 implements IAnyBorder {

  static IAnyCorner cornersBase = const AnySquareCorner();

  final IAnySide? _left;
  IAnySide? get left => _left ?? sides;

  final IAnySide? _top;
  IAnySide? get top => _top ?? sides;

  final IAnySide? _right;
  IAnySide? get right => _right ?? sides;

  final IAnySide? _bottom;
  IAnySide? get bottom => _bottom ?? sides;

  final IAnySide? sides;

  final IAnyCorner? _topLeft;
  IAnyCorner get topLeft => _topLeft ?? corners;

  final IAnyCorner? _topRight;
  IAnyCorner get topRight => _topRight ?? corners;

  final IAnyCorner? _bottomRight;
  IAnyCorner get bottomRight => _bottomRight ?? corners;

  final IAnyCorner? _bottomLeft;
  IAnyCorner get bottomLeft => _bottomLeft ?? corners;

  final IAnyCorner? _corners;

  IAnyCorner get corners => _corners ?? cornersBase;

  const AnyBorder2({
    IAnySide? left,
    IAnySide? top,
    IAnySide? right,
    IAnySide? bottom,
    this.sides,
    IAnyCorner? topLeft,
    IAnyCorner? topRight,
    IAnyCorner? bottomRight,
    IAnyCorner? bottomLeft,
    IAnyCorner? corners
  }) :
    _corners = corners,
    _left = left,
    _top = top,
    _right = right,
    _bottom = bottom,
    _topLeft = topLeft,
    _topRight = topRight,
    _bottomRight = bottomRight,
    _bottomLeft = bottomLeft
    ;

}