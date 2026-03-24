import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart';

import '../any_align.dart';
import '../any_border.dart';
import '../any_decoration.dart';
import '../any_fill.dart';
import '../any_side.dart';
import 'any_contour.dart';
import 'any_region.dart';

enum AnyContourLevel {
  base,
  outer,
  inner,
}

class AnyResolvedSide {
  const AnyResolvedSide({
    required this.side,
    required this.outside,
    required this.inside,
  });

  final IAnySide? side;
  final double outside;
  final double inside;

  double get width => side?.width ?? 0.0;

  bool get isVisible => side != null && width > 0.0 && !(side?.isEmpty ?? true);
}

class AnyBorderGeometry {
  AnyBorderGeometry._({
    required this.rect,
    required this.border,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.baseContour,
    required this.outerContour,
    required this.innerContour,
  });

  final Rect rect;
  final IAnyBorder border;
  final AnyResolvedSide left;
  final AnyResolvedSide top;
  final AnyResolvedSide right;
  final AnyResolvedSide bottom;

  final AnyContour baseContour;
  final AnyContour outerContour;
  final AnyContour innerContour;

  static AnyBorderGeometry resolve(Rect rect, IAnyBorder border) {
    final left = _resolveSide(border.left);
    final top = _resolveSide(border.top);
    final right = _resolveSide(border.right);
    final bottom = _resolveSide(border.bottom);

    final outerRect = Rect.fromLTRB(
      rect.left - left.outside,
      rect.top - top.outside,
      rect.right + right.outside,
      rect.bottom + bottom.outside,
    );

    final innerRect = Rect.fromLTRB(
      math.min(rect.right, rect.left + left.inside),
      math.min(rect.bottom, rect.top + top.inside),
      math.max(rect.left, rect.right - right.inside),
      math.max(rect.top, rect.bottom - bottom.inside),
    );

    return AnyBorderGeometry._(
      rect: rect,
      border: border,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      baseContour: _makeContour(rect, border),
      outerContour: _makeContour(outerRect, border),
      innerContour: _makeContour(innerRect, border),
    );
  }

  static AnyResolvedSide _resolveSide(IAnySide? side) {
    if (side == null) {
      return const AnyResolvedSide(
        side: null,
        outside: 0.0,
        inside: 0.0,
      );
    }

    switch (side.align) {
      case AnyAlign.inside:
        return AnyResolvedSide(side: side, outside: 0.0, inside: side.width);
      case AnyAlign.center:
        return AnyResolvedSide(
          side: side,
          outside: side.width / 2.0,
          inside: side.width / 2.0,
        );
      case AnyAlign.outside:
        return AnyResolvedSide(side: side, outside: side.width, inside: 0.0);
    }
  }

  static AnyContour _makeContour(Rect rect, IAnyBorder border) {
    final size = rect.size;
    return AnyContour(
      rect: rect,
      topLeft: AnyCornerProfile.fromCorner(
        border.topLeft,
        AnyCornerPosition.topLeft,
        size,
      ),
      topRight: AnyCornerProfile.fromCorner(
        border.topRight,
        AnyCornerPosition.topRight,
        size,
      ),
      bottomRight: AnyCornerProfile.fromCorner(
        border.bottomRight,
        AnyCornerPosition.bottomRight,
        size,
      ),
      bottomLeft: AnyCornerProfile.fromCorner(
        border.bottomLeft,
        AnyCornerPosition.bottomLeft,
        size,
      ),
    );
  }

  Path contourPath(AnyContourLevel level) {
    switch (level) {
      case AnyContourLevel.base:
        return baseContour.toPath();
      case AnyContourLevel.outer:
        return outerContour.toPath();
      case AnyContourLevel.inner:
        return innerContour.toPath();
    }
  }

  Path pathForShapeBase(AnyShapeBase base) {
    switch (base) {
      case AnyShapeBase.zeroBorder:
        return baseContour.toPath();
      case AnyShapeBase.outerBorder:
        return outerContour.toPath();
      case AnyShapeBase.innerBorder:
        return innerContour.toPath();
    }
  }

  List<AnyRegion> buildVisibleRegions(AnyDecoration decoration) {
    final regions = <AnyRegion>[];

    if (!decoration.isEmpty) {
      regions.add(
        AnyRegion(
          path: buildMergedBackgroundPath(decoration),
          fill: decoration,
          debugLabel: 'background',
        ),
      );
    }

    final visible = <_SideEntry>[
      _SideEntry(_SideId.top, border.top),
      _SideEntry(_SideId.right, border.right),
      _SideEntry(_SideId.bottom, border.bottom),
      _SideEntry(_SideId.left, border.left),
    ];

    final sideGroups = _groupConnectedSameFillSides(visible, decoration);
    for (final group in sideGroups) {
      final fill = group.first.side!;
      final path = _buildGroupedSideStripPath(group);
      regions.add(
        AnyRegion(
          path: path,
          fill: fill,
          debugLabel: 'sides:${group.map((e) => e.id.name).join("+")}',
        ),
      );
    }

    return regions;
  }

  Path buildMergedBackgroundPath(AnyDecoration decoration) {
    final useTopOuter = _sideMatchesDecoration(border.top, decoration);
    final useRightOuter = _sideMatchesDecoration(border.right, decoration);
    final useBottomOuter = _sideMatchesDecoration(border.bottom, decoration);
    final useLeftOuter = _sideMatchesDecoration(border.left, decoration);

    switch (decoration.background) {
      case AnyShapeBase.outerBorder:
        return outerContour.toPath();
      case AnyShapeBase.innerBorder:
        return innerContour.toPath();
      case AnyShapeBase.zeroBorder:
        break;
    }

    if (!useTopOuter && !useRightOuter && !useBottomOuter && !useLeftOuter) {
      return baseContour.toPath();
    }

    final path = Path();
    final topStart = useTopOuter ? outerContour.topMiddle : baseContour.topMiddle;
    path.moveTo(topStart.dx, topStart.dy);

    _appendSide(
      path,
      _SideId.top,
      useTopOuter ? outerContour : baseContour,
      fromMiddle: true,
    );
    _appendJoin(
      path,
      AnyCornerPosition.topRight,
      decoration,
      useTopOuter,
      useRightOuter,
    );
    _appendSide(
      path,
      _SideId.right,
      useRightOuter ? outerContour : baseContour,
    );
    _appendJoin(
      path,
      AnyCornerPosition.bottomRight,
      decoration,
      useRightOuter,
      useBottomOuter,
    );
    _appendSide(
      path,
      _SideId.bottom,
      useBottomOuter ? outerContour : baseContour,
    );
    _appendJoin(
      path,
      AnyCornerPosition.bottomLeft,
      decoration,
      useBottomOuter,
      useLeftOuter,
    );
    _appendSide(
      path,
      _SideId.left,
      useLeftOuter ? outerContour : baseContour,
    );
    _appendJoin(
      path,
      AnyCornerPosition.topLeft,
      decoration,
      useLeftOuter,
      useTopOuter,
    );

    path.close();
    return path;
  }

  bool _sideMatchesDecoration(IAnySide? side, AnyDecoration decoration) {
    if (side == null) return false;
    if (side.width <= 0.0) return false;
    if (side.isEmpty) return false;
    return side.isSameAs(decoration);
  }

  List<List<_SideEntry>> _groupConnectedSameFillSides(
      List<_SideEntry> orderedSides,
      AnyDecoration decoration,
      ) {
    final filtered = orderedSides
        .where((entry) => _isIndependentVisibleSide(entry.side, decoration))
        .toList();

    if (filtered.isEmpty) return const [];

    final groups = <List<_SideEntry>>[];
    var current = <_SideEntry>[filtered.first];

    for (var i = 1; i < filtered.length; i++) {
      final prev = filtered[i - 1];
      final next = filtered[i];
      if (_areAdjacent(prev.id, next.id) && prev.side!.isSameAs(next.side)) {
        current.add(next);
      } else {
        groups.add(current);
        current = <_SideEntry>[next];
      }
    }
    groups.add(current);

    if (groups.length > 1) {
      final first = groups.first;
      final last = groups.last;
      final firstHead = first.first;
      final lastTail = last.last;
      if (_areAdjacent(lastTail.id, firstHead.id) &&
          lastTail.side!.isSameAs(firstHead.side)) {
        final merged = <_SideEntry>[...last, ...first];
        groups
          ..removeLast()
          ..removeAt(0)
          ..insert(0, merged);
      }
    }

    return groups;
  }

  bool _isIndependentVisibleSide(IAnySide? side, AnyDecoration decoration) {
    if (side == null || side.width <= 0.0 || side.isEmpty) return false;
    if (side.isSameAs(decoration) && !decoration.isEmpty) return false;
    return true;
  }

  bool _areAdjacent(_SideId a, _SideId b) {
    return (a == _SideId.top && b == _SideId.right) ||
        (a == _SideId.right && b == _SideId.bottom) ||
        (a == _SideId.bottom && b == _SideId.left) ||
        (a == _SideId.left && b == _SideId.top);
  }

  Path _buildGroupedSideStripPath(List<_SideEntry> group) {
    assert(group.isNotEmpty);

    if (group.length == 1) {
      return _buildSideStripPath(group.first.id);
    }

    final firstId = group.first.id;
    final lastId = group.last.id;

    final path = Path();

    final outerStart = _sideMiddle(firstId, outerContour);
    path.moveTo(outerStart.dx, outerStart.dy);

    for (var i = 0; i < group.length; i++) {
      final current = group[i];
      _appendOuterSide(path, current.id, fromMiddle: i == 0);

      if (i < group.length - 1) {
        final corner = _clockwiseCornerBetween(current.id, group[i + 1].id);
        _appendCornerContour(path, corner, outerContour, clockwise: true);
      }
    }

    final bridgeCorner = _clockwiseCornerAfter(lastId);
    _appendCornerBridge(path, bridgeCorner, outerContour, innerContour);

    _appendInnerSideReverse(path, lastId, toMiddle: false);

    for (var i = group.length - 2; i >= 0; i--) {
      final corner = _clockwiseCornerBetween(group[i].id, group[i + 1].id);
      _appendCornerContour(path, corner, innerContour, clockwise: false);
      _appendInnerSideReverse(
        path,
        group[i].id,
        toMiddle: i == 0,
      );
    }

    final closingCorner = _clockwiseCornerBefore(firstId);
    _appendCornerBridge(
      path,
      closingCorner,
      innerContour,
      outerContour,
      reverse: true,
    );

    path.close();
    return path;
  }

  Path _buildSideStripPath(_SideId id) {
    final path = Path();
    switch (id) {
      case _SideId.top:
        path.moveTo(outerContour.topMiddle.dx, outerContour.topMiddle.dy);
        path.lineTo(outerContour.topEnd().dx, outerContour.topEnd().dy);
        _appendCornerBridge(
          path,
          AnyCornerPosition.topRight,
          outerContour,
          innerContour,
        );
        path.lineTo(innerContour.topStart().dx, innerContour.topStart().dy);
        _appendCornerBridge(
          path,
          AnyCornerPosition.topLeft,
          innerContour,
          outerContour,
          reverse: true,
        );
        path.close();
        break;
      case _SideId.right:
        path.moveTo(outerContour.rightMiddle.dx, outerContour.rightMiddle.dy);
        path.lineTo(outerContour.rightEnd().dx, outerContour.rightEnd().dy);
        _appendCornerBridge(
          path,
          AnyCornerPosition.bottomRight,
          outerContour,
          innerContour,
        );
        path.lineTo(innerContour.rightStart().dx, innerContour.rightStart().dy);
        _appendCornerBridge(
          path,
          AnyCornerPosition.topRight,
          innerContour,
          outerContour,
          reverse: true,
        );
        path.close();
        break;
      case _SideId.bottom:
        path.moveTo(outerContour.bottomMiddle.dx, outerContour.bottomMiddle.dy);
        path.lineTo(outerContour.bottomEnd().dx, outerContour.bottomEnd().dy);
        _appendCornerBridge(
          path,
          AnyCornerPosition.bottomLeft,
          outerContour,
          innerContour,
        );
        path.lineTo(
          innerContour.bottomStart().dx,
          innerContour.bottomStart().dy,
        );
        _appendCornerBridge(
          path,
          AnyCornerPosition.bottomRight,
          innerContour,
          outerContour,
          reverse: true,
        );
        path.close();
        break;
      case _SideId.left:
        path.moveTo(outerContour.leftMiddle.dx, outerContour.leftMiddle.dy);
        path.lineTo(outerContour.leftEnd().dx, outerContour.leftEnd().dy);
        _appendCornerBridge(
          path,
          AnyCornerPosition.topLeft,
          outerContour,
          innerContour,
        );
        path.lineTo(innerContour.leftStart().dx, innerContour.leftStart().dy);
        _appendCornerBridge(
          path,
          AnyCornerPosition.bottomLeft,
          innerContour,
          outerContour,
          reverse: true,
        );
        path.close();
        break;
    }
    return path;
  }

  Offset _sideMiddle(_SideId id, AnyContour contour) {
    switch (id) {
      case _SideId.top:
        return contour.topMiddle;
      case _SideId.right:
        return contour.rightMiddle;
      case _SideId.bottom:
        return contour.bottomMiddle;
      case _SideId.left:
        return contour.leftMiddle;
    }
  }

  AnyCornerPosition _clockwiseCornerAfter(_SideId id) {
    switch (id) {
      case _SideId.top:
        return AnyCornerPosition.topRight;
      case _SideId.right:
        return AnyCornerPosition.bottomRight;
      case _SideId.bottom:
        return AnyCornerPosition.bottomLeft;
      case _SideId.left:
        return AnyCornerPosition.topLeft;
    }
  }

  AnyCornerPosition _clockwiseCornerBefore(_SideId id) {
    switch (id) {
      case _SideId.top:
        return AnyCornerPosition.topLeft;
      case _SideId.right:
        return AnyCornerPosition.topRight;
      case _SideId.bottom:
        return AnyCornerPosition.bottomRight;
      case _SideId.left:
        return AnyCornerPosition.bottomLeft;
    }
  }

  AnyCornerPosition _clockwiseCornerBetween(_SideId from, _SideId to) {
    if (from == _SideId.top && to == _SideId.right) {
      return AnyCornerPosition.topRight;
    }
    if (from == _SideId.right && to == _SideId.bottom) {
      return AnyCornerPosition.bottomRight;
    }
    if (from == _SideId.bottom && to == _SideId.left) {
      return AnyCornerPosition.bottomLeft;
    }
    return AnyCornerPosition.topLeft;
  }

  void _appendOuterSide(
      Path path,
      _SideId id, {
        required bool fromMiddle,
      }) {
    _appendSide(path, id, outerContour, fromMiddle: fromMiddle);
  }

  void _appendInnerSideReverse(
      Path path,
      _SideId id, {
        required bool toMiddle,
      }) {
    switch (id) {
      case _SideId.top:
        path.lineTo(innerContour.topStart().dx, innerContour.topStart().dy);
        if (toMiddle) {
          path.lineTo(innerContour.topMiddle.dx, innerContour.topMiddle.dy);
        }
        break;
      case _SideId.right:
        path.lineTo(innerContour.rightStart().dx, innerContour.rightStart().dy);
        if (toMiddle) {
          path.lineTo(
            innerContour.rightMiddle.dx,
            innerContour.rightMiddle.dy,
          );
        }
        break;
      case _SideId.bottom:
        path.lineTo(
          innerContour.bottomStart().dx,
          innerContour.bottomStart().dy,
        );
        if (toMiddle) {
          path.lineTo(
            innerContour.bottomMiddle.dx,
            innerContour.bottomMiddle.dy,
          );
        }
        break;
      case _SideId.left:
        path.lineTo(innerContour.leftStart().dx, innerContour.leftStart().dy);
        if (toMiddle) {
          path.lineTo(innerContour.leftMiddle.dx, innerContour.leftMiddle.dy);
        }
        break;
    }
  }

  void _appendSide(
      Path path,
      _SideId id,
      AnyContour contour, {
        bool fromMiddle = false,
      }) {
    switch (id) {
      case _SideId.top:
        if (!fromMiddle) path.lineTo(contour.topStart().dx, contour.topStart().dy);
        path.lineTo(contour.topEnd().dx, contour.topEnd().dy);
        break;
      case _SideId.right:
        path.lineTo(contour.rightEnd().dx, contour.rightEnd().dy);
        break;
      case _SideId.bottom:
        path.lineTo(contour.bottomEnd().dx, contour.bottomEnd().dy);
        break;
      case _SideId.left:
        path.lineTo(contour.leftEnd().dx, contour.leftEnd().dy);
        break;
    }
  }

  void _appendJoin(
      Path path,
      AnyCornerPosition position,
      AnyDecoration decoration,
      bool currentUsesOuter,
      bool nextUsesOuter,
      ) {
    if (currentUsesOuter == nextUsesOuter) {
      _appendCornerContour(
        path,
        position,
        currentUsesOuter ? outerContour : baseContour,
        clockwise: true,
      );
      return;
    }

    final fromContour = currentUsesOuter ? outerContour : baseContour;
    final toContour = nextUsesOuter ? outerContour : baseContour;
    _appendSplitter(path, position, fromContour, toContour, clockwise: true);
  }

  void _appendCornerBridge(
      Path path,
      AnyCornerPosition position,
      AnyContour from,
      AnyContour to, {
        bool reverse = false,
      }) {
    _appendSplitter(path, position, from, to, clockwise: !reverse);
  }

  void _appendCornerContour(
      Path path,
      AnyCornerPosition pos,
      AnyContour contour, {
        required bool clockwise,
      }) {
    switch (pos) {
      case AnyCornerPosition.topLeft:
        if (clockwise) {
          contour.appendCornerCW(path, contour.topLeft);
        } else {
          contour.appendCornerCCW(path, contour.topLeft);
        }
        break;
      case AnyCornerPosition.topRight:
        if (clockwise) {
          contour.appendCornerCW(path, contour.topRight);
        } else {
          contour.appendCornerCCW(path, contour.topRight);
        }
        break;
      case AnyCornerPosition.bottomRight:
        if (clockwise) {
          contour.appendCornerCW(path, contour.bottomRight);
        } else {
          contour.appendCornerCCW(path, contour.bottomRight);
        }
        break;
      case AnyCornerPosition.bottomLeft:
        if (clockwise) {
          contour.appendCornerCW(path, contour.bottomLeft);
        } else {
          contour.appendCornerCCW(path, contour.bottomLeft);
        }
        break;
    }
  }

  void _appendSplitter(
      Path path,
      AnyCornerPosition position,
      AnyContour from,
      AnyContour to, {
        required bool clockwise,
      }) {
    final end = _cornerStartPoint(position, to, clockwise: clockwise);
    final vertex = _cornerVertex(position, rect);
    final fromProfile = _cornerProfile(position, from);
    final toProfile = _cornerProfile(position, to);

    final avgRadius = Radius.elliptical(
      (fromProfile.radius.x + toProfile.radius.x) / 2.0,
      (fromProfile.radius.y + toProfile.radius.y) / 2.0,
    );

    if (fromProfile.isSquare || toProfile.isSquare) {
      path.lineTo(vertex.dx, vertex.dy);
      path.lineTo(end.dx, end.dy);
      return;
    }

    final start = _cornerEndPoint(position, from, clockwise: clockwise);
    final inward = Offset(
      (start.dx + end.dx + vertex.dx) / 3.0,
      (start.dy + end.dy + vertex.dy) / 3.0,
    );

    switch (fromProfile.variant) {
      case AnyCornerVariant.rounded:
        path.arcToPoint(end, radius: avgRadius, clockwise: clockwise);
        return;
      case AnyCornerVariant.innerRounded:
      case AnyCornerVariant.sideRoundedHorizontal:
      case AnyCornerVariant.sideRoundedVertical:
      case AnyCornerVariant.square:
        path.quadraticBezierTo(inward.dx, inward.dy, end.dx, end.dy);
        return;
    }
  }

  Offset _cornerVertex(AnyCornerPosition pos, Rect rect) {
    switch (pos) {
      case AnyCornerPosition.topLeft:
        return rect.topLeft;
      case AnyCornerPosition.topRight:
        return rect.topRight;
      case AnyCornerPosition.bottomRight:
        return rect.bottomRight;
      case AnyCornerPosition.bottomLeft:
        return rect.bottomLeft;
    }
  }

  AnyCornerProfile _cornerProfile(AnyCornerPosition pos, AnyContour contour) {
    switch (pos) {
      case AnyCornerPosition.topLeft:
        return contour.topLeft;
      case AnyCornerPosition.topRight:
        return contour.topRight;
      case AnyCornerPosition.bottomRight:
        return contour.bottomRight;
      case AnyCornerPosition.bottomLeft:
        return contour.bottomLeft;
    }
  }

  Offset _cornerEndPoint(
      AnyCornerPosition pos,
      AnyContour contour, {
        required bool clockwise,
      }) {
    switch (pos) {
      case AnyCornerPosition.topLeft:
        return clockwise ? contour.topStart() : contour.leftEnd();
      case AnyCornerPosition.topRight:
        return clockwise ? contour.topEnd() : contour.rightStart();
      case AnyCornerPosition.bottomRight:
        return clockwise ? contour.rightEnd() : contour.bottomStart();
      case AnyCornerPosition.bottomLeft:
        return clockwise ? contour.bottomEnd() : contour.leftStart();
    }
  }

  Offset _cornerStartPoint(
      AnyCornerPosition pos,
      AnyContour contour, {
        required bool clockwise,
      }) {
    switch (pos) {
      case AnyCornerPosition.topLeft:
        return clockwise ? contour.leftEnd() : contour.topStart();
      case AnyCornerPosition.topRight:
        return clockwise ? contour.rightStart() : contour.topEnd();
      case AnyCornerPosition.bottomRight:
        return clockwise ? contour.bottomStart() : contour.rightEnd();
      case AnyCornerPosition.bottomLeft:
        return clockwise ? contour.leftStart() : contour.bottomEnd();
    }
  }
}

class _SideEntry {
  const _SideEntry(this.id, this.side);

  final _SideId id;
  final IAnySide? side;
}

enum _SideId { top, right, bottom, left }
