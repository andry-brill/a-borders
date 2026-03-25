import 'dart:math' as math;
import 'dart:ui';


import '../../decoration/any_align.dart';
import '../../decoration/any_border.dart';
import '../../decoration/any_decoration.dart';
import '../../decoration/any_fill.dart';
import '../../decoration/any_side.dart';
import 'border_contour.dart';
import 'path_region.dart';


class _ResolvedSide {

  const _ResolvedSide({
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

class BorderGeometry {

  BorderGeometry._({
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
  final _ResolvedSide left;
  final _ResolvedSide top;
  final _ResolvedSide right;
  final _ResolvedSide bottom;

  final BorderContour baseContour;
  final BorderContour outerContour;
  final BorderContour innerContour;

  static BorderGeometry resolve(Rect rect, IAnyBorder border) {
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

    return BorderGeometry._(
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

  static _ResolvedSide _resolveSide(IAnySide? side) {
    if (side == null) {
      return const _ResolvedSide(
        side: null,
        outside: 0.0,
        inside: 0.0,
      );
    }

    switch (side.align) {
      case AnyAlign.inside:
        return _ResolvedSide(side: side, outside: 0.0, inside: side.width);
      case AnyAlign.center:
        return _ResolvedSide(
          side: side,
          outside: side.width / 2.0,
          inside: side.width / 2.0,
        );
      case AnyAlign.outside:
        return _ResolvedSide(side: side, outside: side.width, inside: 0.0);
    }
  }

  static BorderContour _makeContour(Rect rect, IAnyBorder border) {
    final size = rect.size;
    return BorderContour(
      rect: rect,
      topLeft: CornerProfile.fromCorner(
        border.topLeft,
        CornerPosition.topLeft,
        size,
      ),
      topRight: CornerProfile.fromCorner(
        border.topRight,
        CornerPosition.topRight,
        size,
      ),
      bottomRight: CornerProfile.fromCorner(
        border.bottomRight,
        CornerPosition.bottomRight,
        size,
      ),
      bottomLeft: CornerProfile.fromCorner(
        border.bottomLeft,
        CornerPosition.bottomLeft,
        size,
      ),
    );
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


  List<PathRegion> buildVisibleRegions(AnyDecoration decoration) {
    final regions = <PathRegion>[];
    final components = _buildFillComponents(decoration);

    for (final component in components) {
      final path = _buildComponentPath(component, decoration);
      if (path == null) continue;
      path.fillType = PathFillType.evenOdd;
      regions.add(
        PathRegion(
          path: path,
          fill: component.fill,
          debugLabel: component.debugLabel,
        ),
      );
    }

    return regions;
  }

  Path buildMergedBackgroundPath(AnyDecoration decoration) {
    final components = _buildFillComponents(decoration);
    final background = components.where((c) => c.includesBackground).toList();
    if (background.isEmpty) {
      return pathForShapeBase(decoration.background);
    }

    Path? merged;
    for (final component in background) {
      final path = _buildComponentPath(component, decoration);
      if (path == null) continue;
      merged = merged == null ? path : Path.combine(PathOperation.union, merged, path);
    }
    return merged ?? pathForShapeBase(decoration.background);
  }

  List<_FillComponent> _buildFillComponents(AnyDecoration decoration) {
    final nodes = <_RegionNode>[];
    if (!decoration.isEmpty) {
      nodes.add(_RegionNode.background(decoration));
    }

    for (final entry in <_SideEntry>[
      _SideEntry(_SideId.top, border.top),
      _SideEntry(_SideId.right, border.right),
      _SideEntry(_SideId.bottom, border.bottom),
      _SideEntry(_SideId.left, border.left),
    ]) {
      if (_isVisibleSide(entry.side)) {
        nodes.add(_RegionNode.side(entry.id, entry.side!));
      }
    }

    final components = <_FillComponent>[];
    final visited = <int>{};

    for (var i = 0; i < nodes.length; i++) {
      if (!visited.add(i)) continue;
      final seed = nodes[i];
      final queue = <int>[i];
      final sideIds = <_SideId>[];
      var includesBackground = false;

      while (queue.isNotEmpty) {
        final currentIndex = queue.removeLast();
        final current = nodes[currentIndex];

        if (current.kind == _RegionNodeKind.background) {
          includesBackground = true;
        } else if (current.sideId != null) {
          sideIds.add(current.sideId!);
        }

        for (var j = 0; j < nodes.length; j++) {
          if (visited.contains(j)) continue;
          final other = nodes[j];
          if (!current.fill.isSameAs(other.fill)) continue;
          if (!_nodesAreConnected(current, other)) continue;
          visited.add(j);
          queue.add(j);
        }
      }

      components.add(
        _FillComponent(
          fill: seed.fill,
          includesBackground: includesBackground,
          sideIds: sideIds,
        ),
      );
    }

    return components;
  }

  bool _nodesAreConnected(_RegionNode a, _RegionNode b) {
    if (a.kind == _RegionNodeKind.background || b.kind == _RegionNodeKind.background) {
      final sideNode = a.kind == _RegionNodeKind.side ? a : b.kind == _RegionNodeKind.side ? b : null;
      return sideNode != null;
    }

    return _areAdjacent(a.sideId!, b.sideId!);
  }

  bool _isVisibleSide(IAnySide? side) {
    return side != null && side.width > 0.0 && !side.isEmpty;
  }

  Path? _buildComponentPath(_FillComponent component, AnyDecoration decoration) {
    Path? result;

    if (component.includesBackground) {
      result = pathForShapeBase(decoration.background);
    }

    final segments = <int>{};
    for (final sideId in component.sideIds) {
      segments.addAll(_segmentIndicesForSide(sideId));
    }

    if (!component.includesBackground && segments.length == 8 && _allVisibleSidesPresent()) {
      final ring = Path.combine(
        PathOperation.difference,
        outerContour.toPath(),
        innerContour.toPath(),
      );
      return result == null ? ring : Path.combine(PathOperation.union, result, ring);
    }

    for (final segment in segments) {
      final piece = _buildHalfBorderSegmentPath(segment);
      if (piece == null) continue;
      result = result == null ? piece : Path.combine(PathOperation.union, result, piece);
    }

    return result;
  }

  bool _allVisibleSidesPresent() {
    return _isVisibleSide(border.top) &&
        _isVisibleSide(border.right) &&
        _isVisibleSide(border.bottom) &&
        _isVisibleSide(border.left);
  }

  List<int> _segmentIndicesForSide(_SideId sideId) {
    switch (sideId) {
      case _SideId.top:
        return const [7, 0];
      case _SideId.right:
        return const [1, 2];
      case _SideId.bottom:
        return const [3, 4];
      case _SideId.left:
        return const [5, 6];
    }
  }

  Path? _buildHalfBorderSegmentPath(int segmentIndex) {
    final outer = _ContourWalker.clockwise(outerContour);
    final inner = _ContourWalker.counterClockwise(innerContour);

    if (!outer.isUsable || !inner.isUsable) return null;

    final path = Path();
    final startOuter = outer.splitPoint(segmentIndex);
    path.moveTo(startOuter.dx, startOuter.dy);
    outer.appendSegment(path, segmentIndex);

    final endInner = inner.splitPoint(segmentIndex + 1);
    path.lineTo(endInner.dx, endInner.dy);
    inner.appendSegmentReverse(path, segmentIndex);

    final startInner = inner.splitPoint(segmentIndex);
    path.lineTo(startInner.dx, startInner.dy);
    path.close();
    return path;
  }

  bool _areAdjacent(_SideId a, _SideId b) {
    return (a == _SideId.top && b == _SideId.right) ||
        (a == _SideId.right && b == _SideId.bottom) ||
        (a == _SideId.bottom && b == _SideId.left) ||
        (a == _SideId.left && b == _SideId.top) ||
        (b == _SideId.top && a == _SideId.right) ||
        (b == _SideId.right && a == _SideId.bottom) ||
        (b == _SideId.bottom && a == _SideId.left) ||
        (b == _SideId.left && a == _SideId.top);
  }
}

class _ContourWalker {
  _ContourWalker._({
    required this.path,
    required this.metric,
    required this.splitOffsets,
    required this.reverseMap,
  });

  final Path path;
  final PathMetric? metric;
  final List<double> splitOffsets;
  final List<int> reverseMap;

  bool get isUsable => metric != null;

  factory _ContourWalker.clockwise(BorderContour contour) {
    final path = contour.toPath();
    final metric = _firstMetric(path);

    final topRightSide = (contour.topMiddle - contour.topEnd()).distance;
    final rightTopSide = (contour.rightMiddle - contour.rightStart()).distance;
    final rightBottomSide = (contour.rightEnd() - contour.rightMiddle).distance;
    final bottomRightSide = (contour.bottomStart() - contour.bottomMiddle).distance;
    final bottomLeftSide = (contour.bottomMiddle - contour.bottomEnd()).distance;
    final leftBottomSide = (contour.leftStart() - contour.leftMiddle).distance;
    final leftTopSide = (contour.leftMiddle - contour.leftEnd()).distance;
    final topLeftSide = (contour.topStart() - contour.topMiddle).distance;

    final topRightHalf = _halfCornerLength(contour, CornerPosition.topRight);
    final bottomRightHalf = _halfCornerLength(contour, CornerPosition.bottomRight);
    final bottomLeftHalf = _halfCornerLength(contour, CornerPosition.bottomLeft);
    final topLeftHalf = _halfCornerLength(contour, CornerPosition.topLeft);

    final splitOffsets = <double>[0.0];
    splitOffsets.add(splitOffsets.last + topRightSide + topRightHalf);
    splitOffsets.add(splitOffsets.last + topRightHalf + rightTopSide);
    splitOffsets.add(splitOffsets.last + rightBottomSide + bottomRightHalf);
    splitOffsets.add(splitOffsets.last + bottomRightHalf + bottomRightSide);
    splitOffsets.add(splitOffsets.last + bottomLeftSide + bottomLeftHalf);
    splitOffsets.add(splitOffsets.last + bottomLeftHalf + leftBottomSide);
    splitOffsets.add(splitOffsets.last + leftTopSide + topLeftHalf);
    // Keep the split table shape stable even for degenerate paths.
    splitOffsets.add(metric?.length ?? splitOffsets.last);

    return _ContourWalker._(
      path: path,
      metric: metric,
      splitOffsets: splitOffsets,
      reverseMap: const [7, 6, 5, 4, 3, 2, 1, 0],
    );
  }

  factory _ContourWalker.counterClockwise(BorderContour contour) {
    final path = contour.toPath(clockwise: false);
    final metric = _firstMetric(path);

    final topLeftSide = (contour.topMiddle - contour.topStart()).distance;
    final leftTopSide = (contour.leftEnd() - contour.leftMiddle).distance;
    final leftBottomSide = (contour.leftMiddle - contour.leftStart()).distance;
    final bottomLeftSide = (contour.bottomEnd() - contour.bottomMiddle).distance;
    final bottomRightSide = (contour.bottomMiddle - contour.bottomStart()).distance;
    final rightBottomSide = (contour.rightMiddle - contour.rightEnd()).distance;
    final rightTopSide = (contour.rightStart() - contour.rightMiddle).distance;
    final topRightSide = (contour.topEnd() - contour.topMiddle).distance;

    final topLeftHalf = _halfCornerLength(contour, CornerPosition.topLeft);
    final bottomLeftHalf = _halfCornerLength(contour, CornerPosition.bottomLeft);
    final bottomRightHalf = _halfCornerLength(contour, CornerPosition.bottomRight);
    final topRightHalf = _halfCornerLength(contour, CornerPosition.topRight);

    final splitOffsets = <double>[0.0];
    splitOffsets.add(splitOffsets.last + topLeftSide + topLeftHalf);
    splitOffsets.add(splitOffsets.last + topLeftHalf + leftTopSide);
    splitOffsets.add(splitOffsets.last + leftBottomSide + bottomLeftHalf);
    splitOffsets.add(splitOffsets.last + bottomLeftHalf + bottomLeftSide);
    splitOffsets.add(splitOffsets.last + bottomRightSide + bottomRightHalf);
    splitOffsets.add(splitOffsets.last + bottomRightHalf + rightBottomSide);
    splitOffsets.add(splitOffsets.last + rightTopSide + topRightHalf);
    // Keep the split table shape stable even for degenerate paths.
    splitOffsets.add(metric?.length ?? splitOffsets.last);

    return _ContourWalker._(
      path: path,
      metric: metric,
      splitOffsets: splitOffsets,
      reverseMap: const [7, 6, 5, 4, 3, 2, 1, 0],
    );
  }

  static double _halfCornerLength(BorderContour contour, CornerPosition position) {
    final p = Path();
    final start = switch (position) {
      CornerPosition.topLeft => contour.topStart(),
      CornerPosition.topRight => contour.topEnd(),
      CornerPosition.bottomRight => contour.rightEnd(),
      CornerPosition.bottomLeft => contour.bottomEnd(),
    };
    p.moveTo(start.dx, start.dy);
    switch (position) {
      case CornerPosition.topLeft:
        contour.appendCornerCW(p, contour.topLeft);
        break;
      case CornerPosition.topRight:
        contour.appendCornerCW(p, contour.topRight);
        break;
      case CornerPosition.bottomRight:
        contour.appendCornerCW(p, contour.bottomRight);
        break;
      case CornerPosition.bottomLeft:
        contour.appendCornerCW(p, contour.bottomLeft);
        break;
    }
    final metric = p.computeMetrics();
    if (metric.isEmpty) return 0.0;
    return metric.first.length / 2.0;
  }

  static PathMetric? _firstMetric(Path path) {
    // `Path.computeMetrics()` returns an iterable that may be one-shot.
    // Materialize it once to safely inspect.
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return null;
    return metrics.first;
  }

  Offset splitPoint(int index) {
    final m = metric;
    if (m == null) return Offset.zero;
    final clamped = index < 0 ? 0 : (index > 8 ? 8 : index);
    final tangent = m.getTangentForOffset(splitOffsets[clamped]);
    return tangent?.position ?? Offset.zero;
  }

  void appendSegment(Path out, int segmentIndex) {
    final m = metric;
    if (m == null) return;
    final subPath = m.extractPath(
      splitOffsets[segmentIndex],
      splitOffsets[segmentIndex + 1],
      startWithMoveTo: false,
    );
    out.addPath(subPath, Offset.zero);
  }

  void appendSegmentReverse(Path out, int segmentIndex) {
    final m = metric;
    if (m == null) return;
    final reverseIndex = reverseMap[segmentIndex];
    final subPath = m.extractPath(
      splitOffsets[reverseIndex],
      splitOffsets[reverseIndex + 1],
      startWithMoveTo: false,
    );
    out.addPath(subPath, Offset.zero);
  }
}

class _FillComponent {
  const _FillComponent({
    required this.fill,
    required this.includesBackground,
    required this.sideIds,
  });

  final IAnyFill fill;
  final bool includesBackground;
  final List<_SideId> sideIds;

  String get debugLabel {
    final parts = <String>[];
    if (includesBackground) parts.add('background');
    parts.addAll(sideIds.map((s) => s.name));
    return parts.join('+');
  }
}

enum _RegionNodeKind { background, side }

class _RegionNode {
  const _RegionNode._({
    required this.kind,
    required this.fill,
    this.sideId,
  });

  factory _RegionNode.background(IAnyFill fill) {
    return _RegionNode._(kind: _RegionNodeKind.background, fill: fill);
  }

  factory _RegionNode.side(_SideId sideId, IAnyFill fill) {
    return _RegionNode._(
      kind: _RegionNodeKind.side,
      fill: fill,
      sideId: sideId,
    );
  }

  final _RegionNodeKind kind;
  final IAnyFill fill;
  final _SideId? sideId;
}

class _SideEntry {
  const _SideEntry(this.id, this.side);

  final _SideId id;
  final IAnySide? side;
}

enum _SideId { top, right, bottom, left }
