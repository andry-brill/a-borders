import 'dart:math' as math;
import 'dart:ui';

import '../any_corner.dart';

enum AnyCornerVariant {
  square,
  rounded,
  innerRounded,
  sideRoundedHorizontal,
  sideRoundedVertical,
}

enum AnyCornerPosition {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
}

class AnyCornerProfile {
  const AnyCornerProfile({
    required this.variant,
    required this.radius,
    required this.position,
  });

  final AnyCornerVariant variant;
  final Radius radius;
  final AnyCornerPosition position;

  bool get isSquare =>
      variant == AnyCornerVariant.square ||
          (radius.x == 0.0 && radius.y == 0.0);

  static AnyCornerProfile fromCorner(
      IAnyCorner corner,
      AnyCornerPosition position,
      Size contourSize,
      ) {
    if (corner is AnySquareCorner) {
      return AnyCornerProfile(
        variant: AnyCornerVariant.square,
        radius: Radius.zero,
        position: position,
      );
    }

    if (corner is AnyRoundedCorner) {
      return AnyCornerProfile(
        variant: AnyCornerVariant.rounded,
        radius: corner.resolveForSize(contourSize),
        position: position,
      );
    }

    if (corner is AnyInnerRoundedCorner) {
      return AnyCornerProfile(
        variant: AnyCornerVariant.innerRounded,
        radius: corner.resolveForSize(contourSize),
        position: position,
      );
    }

    if (corner is AnySideRoundedCorner) {
      return AnyCornerProfile(
        variant: corner.horizontal
            ? AnyCornerVariant.sideRoundedHorizontal
            : AnyCornerVariant.sideRoundedVertical,
        radius: corner.resolveForSize(contourSize),
        position: position,
      );
    }

    return AnyCornerProfile(
      variant: AnyCornerVariant.square,
      radius: Radius.zero,
      position: position,
    );
  }
}

class AnyContour {
  AnyContour({
    required Rect rect,
    required AnyCornerProfile topLeft,
    required AnyCornerProfile topRight,
    required AnyCornerProfile bottomRight,
    required AnyCornerProfile bottomLeft,
  })  : rect = rect,
        topLeft = topLeft,
        topRight = topRight,
        bottomRight = bottomRight,
        bottomLeft = bottomLeft {
    _normalizeRadii();
  }

  final Rect rect;
  AnyCornerProfile topLeft;
  AnyCornerProfile topRight;
  AnyCornerProfile bottomRight;
  AnyCornerProfile bottomLeft;

  Size get size => rect.size;
  Offset get topMiddle => Offset(rect.center.dx, rect.top);
  Offset get rightMiddle => Offset(rect.right, rect.center.dy);
  Offset get bottomMiddle => Offset(rect.center.dx, rect.bottom);
  Offset get leftMiddle => Offset(rect.left, rect.center.dy);

  Radius get tlRadius => topLeft.radius;
  Radius get trRadius => topRight.radius;
  Radius get brRadius => bottomRight.radius;
  Radius get blRadius => bottomLeft.radius;

  void _normalizeRadii() {
    double tlx = math.max(0.0, topLeft.radius.x);
    double trx = math.max(0.0, topRight.radius.x);
    double brx = math.max(0.0, bottomRight.radius.x);
    double blx = math.max(0.0, bottomLeft.radius.x);

    double tly = math.max(0.0, topLeft.radius.y);
    double tryy = math.max(0.0, topRight.radius.y);
    double bry = math.max(0.0, bottomRight.radius.y);
    double bly = math.max(0.0, bottomLeft.radius.y);

    final width = rect.width.abs();
    final height = rect.height.abs();
    if (width == 0.0 || height == 0.0) {
      topLeft = AnyCornerProfile(
        variant: topLeft.variant,
        radius: Radius.zero,
        position: topLeft.position,
      );
      topRight = AnyCornerProfile(
        variant: topRight.variant,
        radius: Radius.zero,
        position: topRight.position,
      );
      bottomRight = AnyCornerProfile(
        variant: bottomRight.variant,
        radius: Radius.zero,
        position: bottomRight.position,
      );
      bottomLeft = AnyCornerProfile(
        variant: bottomLeft.variant,
        radius: Radius.zero,
        position: bottomLeft.position,
      );
      return;
    }

    final sx1 = (tlx + trx) > width ? width / (tlx + trx) : 1.0;
    final sx2 = (blx + brx) > width ? width / (blx + brx) : 1.0;
    final sy1 = (tly + bly) > height ? height / (tly + bly) : 1.0;
    final sy2 = (tryy + bry) > height ? height / (tryy + bry) : 1.0;
    final s = math.min(math.min(sx1, sx2), math.min(sy1, sy2));

    topLeft = AnyCornerProfile(
      variant: topLeft.variant,
      radius: Radius.elliptical(tlx * s, tly * s),
      position: topLeft.position,
    );
    topRight = AnyCornerProfile(
      variant: topRight.variant,
      radius: Radius.elliptical(trx * s, tryy * s),
      position: topRight.position,
    );
    bottomRight = AnyCornerProfile(
      variant: bottomRight.variant,
      radius: Radius.elliptical(brx * s, bry * s),
      position: bottomRight.position,
    );
    bottomLeft = AnyCornerProfile(
      variant: bottomLeft.variant,
      radius: Radius.elliptical(blx * s, bly * s),
      position: bottomLeft.position,
    );
  }

  Offset topStart() => Offset(rect.left + tlRadius.x, rect.top);
  Offset topEnd() => Offset(rect.right - trRadius.x, rect.top);
  Offset rightStart() => Offset(rect.right, rect.top + trRadius.y);
  Offset rightEnd() => Offset(rect.right, rect.bottom - brRadius.y);
  Offset bottomStart() => Offset(rect.right - brRadius.x, rect.bottom);
  Offset bottomEnd() => Offset(rect.left + blRadius.x, rect.bottom);
  Offset leftStart() => Offset(rect.left, rect.bottom - blRadius.y);
  Offset leftEnd() => Offset(rect.left, rect.top + tlRadius.y);

  Path toPath({bool clockwise = true}) {
    if (!clockwise) {
      final p = Path();
      _appendAntiClockwise(p);
      p.close();
      return p;
    }
    final p = Path();
    _appendClockwise(p);
    p.close();
    return p;
  }

  void _appendClockwise(Path path) {
    final tm = topMiddle;
    path.moveTo(tm.dx, tm.dy);
    path.lineTo(topEnd().dx, topEnd().dy);
    appendCornerCW(path, topRight);
    path.lineTo(rightEnd().dx, rightEnd().dy);
    appendCornerCW(path, bottomRight);
    path.lineTo(bottomEnd().dx, bottomEnd().dy);
    appendCornerCW(path, bottomLeft);
    path.lineTo(leftEnd().dx, leftEnd().dy);
    appendCornerCW(path, topLeft);
    path.lineTo(tm.dx, tm.dy);
  }

  void _appendAntiClockwise(Path path) {
    final tm = topMiddle;
    path.moveTo(tm.dx, tm.dy);
    path.lineTo(topStart().dx, topStart().dy);
    appendCornerCCW(path, topLeft);
    path.lineTo(leftStart().dx, leftStart().dy);
    appendCornerCCW(path, bottomLeft);
    path.lineTo(bottomStart().dx, bottomStart().dy);
    appendCornerCCW(path, bottomRight);
    path.lineTo(rightStart().dx, rightStart().dy);
    appendCornerCCW(path, topRight);
    path.lineTo(tm.dx, tm.dy);
  }

  void appendCornerCW(Path path, AnyCornerProfile c) {
    final rx = c.radius.x;
    final ry = c.radius.y;
    switch (c.position) {
      case AnyCornerPosition.topLeft:
        _appendCornerPathCW(
          path,
          c,
          from: topStart(),
          to: leftEnd(),
          vertex: rect.topLeft,
          inward: Offset(rect.left + rx, rect.top + ry),
        );
        break;
      case AnyCornerPosition.topRight:
        _appendCornerPathCW(
          path,
          c,
          from: topEnd(),
          to: rightStart(),
          vertex: rect.topRight,
          inward: Offset(rect.right - rx, rect.top + ry),
        );
        break;
      case AnyCornerPosition.bottomRight:
        _appendCornerPathCW(
          path,
          c,
          from: rightEnd(),
          to: bottomStart(),
          vertex: rect.bottomRight,
          inward: Offset(rect.right - rx, rect.bottom - ry),
        );
        break;
      case AnyCornerPosition.bottomLeft:
        _appendCornerPathCW(
          path,
          c,
          from: bottomEnd(),
          to: leftStart(),
          vertex: rect.bottomLeft,
          inward: Offset(rect.left + rx, rect.bottom - ry),
        );
        break;
    }
  }

  void appendCornerCCW(Path path, AnyCornerProfile c) {
    final rx = c.radius.x;
    final ry = c.radius.y;
    switch (c.position) {
      case AnyCornerPosition.topLeft:
        _appendCornerPathCCW(
          path,
          c,
          from: leftEnd(),
          to: topStart(),
          vertex: rect.topLeft,
          inward: Offset(rect.left + rx, rect.top + ry),
        );
        break;
      case AnyCornerPosition.topRight:
        _appendCornerPathCCW(
          path,
          c,
          from: rightStart(),
          to: topEnd(),
          vertex: rect.topRight,
          inward: Offset(rect.right - rx, rect.top + ry),
        );
        break;
      case AnyCornerPosition.bottomRight:
        _appendCornerPathCCW(
          path,
          c,
          from: bottomStart(),
          to: rightEnd(),
          vertex: rect.bottomRight,
          inward: Offset(rect.right - rx, rect.bottom - ry),
        );
        break;
      case AnyCornerPosition.bottomLeft:
        _appendCornerPathCCW(
          path,
          c,
          from: leftStart(),
          to: bottomEnd(),
          vertex: rect.bottomLeft,
          inward: Offset(rect.left + rx, rect.bottom - ry),
        );
        break;
    }
  }

  void _appendCornerPathCW(
      Path path,
      AnyCornerProfile c, {
        required Offset from,
        required Offset to,
        required Offset vertex,
        required Offset inward,
      }) {
    final rx = c.radius.x;
    final ry = c.radius.y;
    if (c.isSquare || rx == 0.0 || ry == 0.0) {
      path.lineTo(vertex.dx, vertex.dy);
      path.lineTo(to.dx, to.dy);
      return;
    }

    switch (c.variant) {
      case AnyCornerVariant.square:
        path.lineTo(vertex.dx, vertex.dy);
        path.lineTo(to.dx, to.dy);
        return;
      case AnyCornerVariant.rounded:
        path.arcToPoint(to, radius: c.radius, clockwise: true);
        return;
      case AnyCornerVariant.innerRounded:
        path.quadraticBezierTo(inward.dx, inward.dy, to.dx, to.dy);
        return;
      case AnyCornerVariant.sideRoundedHorizontal:
        final control = Offset(
          positionIsRight(c.position) ? vertex.dx + rx : vertex.dx - rx,
          vertex.dy,
        );
        path.quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
        return;
      case AnyCornerVariant.sideRoundedVertical:
        final control = Offset(
          vertex.dx,
          positionIsBottom(c.position) ? vertex.dy + ry : vertex.dy - ry,
        );
        path.quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
        return;
    }
  }

  void _appendCornerPathCCW(
      Path path,
      AnyCornerProfile c, {
        required Offset from,
        required Offset to,
        required Offset vertex,
        required Offset inward,
      }) {
    final rx = c.radius.x;
    final ry = c.radius.y;
    if (c.isSquare || rx == 0.0 || ry == 0.0) {
      path.lineTo(vertex.dx, vertex.dy);
      path.lineTo(to.dx, to.dy);
      return;
    }

    switch (c.variant) {
      case AnyCornerVariant.square:
        path.lineTo(vertex.dx, vertex.dy);
        path.lineTo(to.dx, to.dy);
        return;
      case AnyCornerVariant.rounded:
        path.arcToPoint(to, radius: c.radius, clockwise: false);
        return;
      case AnyCornerVariant.innerRounded:
        path.quadraticBezierTo(inward.dx, inward.dy, to.dx, to.dy);
        return;
      case AnyCornerVariant.sideRoundedHorizontal:
        final control = Offset(
          positionIsRight(c.position) ? vertex.dx + rx : vertex.dx - rx,
          vertex.dy,
        );
        path.quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
        return;
      case AnyCornerVariant.sideRoundedVertical:
        final control = Offset(
          vertex.dx,
          positionIsBottom(c.position) ? vertex.dy + ry : vertex.dy - ry,
        );
        path.quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
        return;
    }
  }

  static bool positionIsRight(AnyCornerPosition p) =>
      p == AnyCornerPosition.topRight || p == AnyCornerPosition.bottomRight;

  static bool positionIsBottom(AnyCornerPosition p) =>
      p == AnyCornerPosition.bottomRight || p == AnyCornerPosition.bottomLeft;
}
