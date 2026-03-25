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


enum ContourTarget {
  background,
  top,
  right,
  bottom,
  left;

  static const Set<ContourTarget> sides = { top, right, bottom, left };
}


/// if corner is AnyRoundedCorner
/// side + corner == line
/// corner + split == partial arc (depends on sides widths)
/// corner + corner == full arc
/// split + split == line
enum ContourVariant {

  /// Point on the middle of the some side
  side,
  /// Start or end point of corner
  corner,
  /// Point that splits corner
  split,

}

/// We have three positions for each ContourPoint
///   Example, side = top, and width = 10 and align = center
///     sideMiddle & inner => y position will be offset on 5 from bounds (5 - inside to center of bounds)
///     sideMiddle & middle => y position will be on bounds
///     sideMiddle & outer => y position will be offset on -5 from bounds (-5 - outside from center of bounds)
enum ContourPosition {
  inner,
  middle,
  outer
}

enum ContourPoint {

  // top side

  topLeft,
  topCenter,
  topRight,

  // right side
  rightTop,
  rightCenter,
  rightBottom,

  // bottom side
  bottomRight,
  bottomCenter,
  bottomLeft,

  // left side
  leftBottom,
  leftCenter,
  leftTop
}

class ContourCheckpoint {

  final ContourPosition position;
  final ContourPoint point;
  final ContourVariant variant;

  const ContourCheckpoint({required this.variant, required this.position, required this.point});

  @override
  bool operator ==(Object other) {
    if (other is! ContourCheckpoint) return false;
    return other.position == position && other.variant == variant && other.point == point;
  }

  @override
  int get hashCode => Object.hash(position, point, variant);

  @override
  String toString() {
    return 'cp:${position.name}:${point.name}:${variant.name}';
  }
}


/// TODO Class that collects border checkpoints in the right order based on parts and sides widths
/// TODO Contours must be build on the fly in code, not hardcoded
/// TODO Create some helpful functions to reduce duplications
/// TODO Fill all cases
class CheckpointsBuilder2 {

  late final bool hasTop;
  late final bool hasRight;
  late final bool hasBottom;
  late final bool hasLeft;
  late final int hasBorders;

  IAnyBorder _border;
  CheckpointsBuilder2(this._border) :
    hasTop = _border.top?.hasWidth == true,
    hasRight = _border.right?.hasWidth == true,
    hasBottom = _border.bottom?.hasWidth == true,
    hasLeft = _border.left?.hasWidth == true
  {
    int b = 0;
    if (hasTop) b++;
    if (hasRight) b++;
    if (hasBottom) b++;
    if (hasLeft) b++;
    hasBorders = b;
  }

  static const noBorders = 0;
  static const allBorders = 0;

  List<ContourCheckpoint> build(Set<ContourTarget> targets, {AnyShapeBase? base}) {

    if (targets.isEmpty) return [];

    if (targets.contains(ContourTarget.background)) {

      final backBase = base ?? AnyShapeBase.zeroBorder;
      if (backBase == AnyShapeBase.innerBorder || backBase == AnyShapeBase.outerBorder) {
        targets = ContourTarget.sides;
      } else {

        AnyShapeBase? simplifiedBase;

        /// When no borders outline of zero borders will be used
        if (hasBorders == noBorders) {
          simplifiedBase = AnyShapeBase.outerBorder;
        }

        /// Checking that all borders align inside or empty, then we can just build background as sides outlines
        if (simplifiedBase == null && (
            (!hasTop || _border.top!.align == AnyAlign.inside) &&
            (!hasRight || _border.right!.align == AnyAlign.inside) &&
            (!hasBottom || _border.bottom!.align == AnyAlign.inside) &&
            (!hasLeft || _border.left!.align == AnyAlign.inside))
        ) {
          simplifiedBase = AnyShapeBase.outerBorder;
        }

        if (hasBorders == allBorders) {
          /// If all borders aligned in the same way
          final align = _border.top!.align;
          if (align == _border.right!.align && align == _border.bottom!.align && align == _border.left!.align) {
            simplifiedBase = AnyShapeBase.outerBorder;
          }
        }

        if (simplifiedBase != null) {
          targets = ContourTarget.sides;
          base = AnyShapeBase.outerBorder;
        }

      }

    }


    if (targets.length == 1) {

      if (targets.contains(ContourTarget.top)) {
        assert(hasTop);
        return const [
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.split),
          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.split),
          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),

          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),

          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner), // will be connected to first checkpoint
        ];
      }
    }

    if (targets.length == 2) {

      // This means that background has the same fill as top side and paths could be merged
      if (targets.contains(ContourTarget.background) && targets.contains(ContourTarget.top)) {

        List<ContourCheckpoint> result = [
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
        ];

        switch (_border.top!.align) {

          case AnyAlign.inside:
            throw 'Should not be called, as it will be handled in other way';
          case AnyAlign.center:
            result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.split));
            result.add(ContourCheckpoint(position: ContourPosition.middle, point: ContourPoint.topRight, variant: ContourVariant.split));
          case AnyAlign.outside:
            result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.split));
            result.add(ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.split));
        }

        // NB! We can you outer or inner here as all other borders will be treated as they has 0 width
        result.addAll([

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.split),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomRight, variant: ContourVariant.corner),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomCenter, variant: ContourVariant.side),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomLeft, variant: ContourVariant.corner),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftBottom, variant: ContourVariant.corner),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftCenter, variant: ContourVariant.side),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftTop, variant: ContourVariant.corner),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftTop, variant: ContourVariant.split),

        ]);

        switch (_border.top!.align) {

          case AnyAlign.inside:
            throw 'Should not be called, as it will be handled in other way';
          case AnyAlign.center:
            result.add(ContourCheckpoint(position: ContourPosition.middle, point: ContourPoint.topLeft, variant: ContourVariant.split));
            result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split));
          case AnyAlign.outside:
            result.add(ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split));
            result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split));
        }

        result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner));

        return result;
      }


      if (targets.contains(ContourTarget.top) && targets.contains(ContourTarget.right)) {

        assert(hasTop || hasRight);

        // If no border in top in that case we only drawing corner from top side (to visualize change), not full top side
        if (!hasTop) {
          return const [

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.split),
            ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.split),
            ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.corner),

            ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightCenter, variant: ContourVariant.side),

            ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightTop, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner), // will be connected to first checkpoint

          ];
        }

        // If no border in right in that case we only drawing corner from right side (to visualize change), not full right side
        if (!hasRight) {
          return const [

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),

            ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),

            ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner), // will be connected to first checkpoint
          ];
        }

        return const [

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),

          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.split),
          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.split),
          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.corner),

          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightCenter, variant: ContourVariant.side),

          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightTop, variant: ContourVariant.corner),
          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),

          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),

          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
          ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split),
          ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner), // will be connected to first checkpoint

        ];
      }
    }


    if (targets.length == 4) {
      if (targets.contains(ContourTarget.top) && targets.contains(ContourTarget.right) && targets.contains(ContourTarget.bottom) && targets.contains(ContourTarget.left)) {

        if (hasBottom && hasLeft && hasRight && hasTop) {

          assert(base != null);

          if (base == AnyShapeBase.innerBorder) {
            return const [

              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),

              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.leftTop, variant: ContourVariant.corner),

              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.leftCenter, variant: ContourVariant.side),

              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.leftBottom, variant: ContourVariant.corner),
              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.bottomLeft, variant: ContourVariant.corner),

              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.bottomCenter, variant: ContourVariant.side),

              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.bottomRight, variant: ContourVariant.corner),
              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.corner),

              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightCenter, variant: ContourVariant.side),

              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightTop, variant: ContourVariant.corner),
              ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),

            ];
          }

          assert(base == AnyShapeBase.outerBorder);

          return const [

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomRight, variant: ContourVariant.corner),

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomCenter, variant: ContourVariant.side),

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomLeft, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftBottom, variant: ContourVariant.corner),

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftCenter, variant: ContourVariant.side),

            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftTop, variant: ContourVariant.corner),
            ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner),


          ];

        }

        throw 'TODO';
      }
    }
    
    throw 'Missing case for $targets';
  }


}

class BorderCheckpointsGeometry {

  Rect _bounds;
  Path _path;
  IAnyBorder _border;

  BorderCheckpointsGeometry(this._bounds, this._border) : _path = Path()
    ..fillType = PathFillType.evenOdd;

  void alignBounds() {
    // TODO base on _border.topLeft, ... corners detect do we need to reduce bounds
    // TODO we need to reduce bounds in case CornerVariant.rounded (AnyRoundedCorner) and radius is infinity - it means that this corder is circle, and next side is starts in the edge of this circle
    // TODO Example of AnyRoundedCorner(infinity) in top right corner for Rect.fromLTRB(0, 0, 200, 100), bounds mut be reduces to Rect.fromLTRB(0, 0, 150, 100)
  }

  Path build(List<ContourCheckpoint> checkpoints, {bool isClosed = true}) {
    assert(checkpoints.length > 1);
    assert(checkpoints.first.variant == ContourVariant.side); // contour always must starts from side

    Offset lastPoint = _bounds.topCenter; // TODO resolve based on first checkpoint
    _path.moveTo(lastPoint.dx, lastPoint.dy);

    for (int i = 0; i < checkpoints.length; i++) {
      if (i != checkpoints.length - 1) {
        lastPoint = connect(lastPoint, checkpoints[i], checkpoints[i + 1]);
      } else {
        lastPoint = connect(lastPoint, checkpoints[i], checkpoints[0]);
      }
    }

    _path.close();
    return _path;
  }

  /// Probably we can connect always clockwise?
  Offset connect(Offset previousPoint, ContourCheckpoint start, ContourCheckpoint end) {
    // TODO logic that will connect two checkpoints
    Offset lastPoint = previousPoint; // TODO return really last point
    return lastPoint; // TODO return really last point
  }

}