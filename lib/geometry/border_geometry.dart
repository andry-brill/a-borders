import 'dart:math' as math;
import 'dart:ui';


import '../decoration/any_align.dart';
import '../decoration/any_border.dart';
import '../decoration/any_decoration.dart';
import '../decoration/any_fill.dart';
import '../decoration/any_side.dart';
import 'border_contour.dart';
import 'checkpoints_builder.dart';
import 'fill_path.dart';


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

  List<FillPath> build(AnyDecoration decoration) {

    final paths = <FillPath>[];
    final contours = _buildContours(decoration);

    if (contours.isNotEmpty) {

      final builder = CheckpointsBuilder(border);
      final geometry = BorderCheckpointsGeometry(rect, border);

      for (final contour in contours) {
        final descriptor = buildFillPath(builder, geometry, contour, decoration);
        if (descriptor == null) continue;
        paths.add(descriptor);
      }

    }


    return paths;
  }

  List<_FillContour> _buildContours(AnyDecoration decoration) {

    final contours = <_FillContour>[];

    if (!decoration.isEmpty) {
      contours.add(
        _FillContour(
          fill: decoration,
          targets: const {ContourTarget.background},
        ),
      );
    }

    for (var side in ContourTarget.sides) {
      final borderSide = side.sideOf(border);
      if (borderSide != null && borderSide.isVisible) {
        contours.add(
          _FillContour(
            fill: borderSide,
            targets: {side},
          ),
        );
      }
    }

    var changed = true;
    while (changed) {

      changed = false;

      for (var i = 0; i < contours.length; i++) {
        for (var j = i + 1; j < contours.length; j++) {
          final a = contours[i];
          final b = contours[j];

          if (!_canMergeContours(a, b)) continue;

          contours[i] = _mergeContours(a, b);
          contours.removeAt(j);
          changed = true;
          break;
        }

        if (changed) break;
      }
    }

    return contours;
  }

  bool _canMergeContours(_FillContour a, _FillContour b) {

    if (!a.fill.isSameAs(b.fill)) return false;

    for (final ta in a.targets) {
      for (final tb in b.targets) {
        if (ContourTarget.areAdjacent(ta, tb)) {
          return true;
        }
      }
    }

    return false;
  }

  _FillContour _mergeContours(_FillContour a, _FillContour b) {
    return _FillContour(
      fill: a.fill,
      targets: <ContourTarget>{
        ...a.targets,
        ...b.targets,
      },
    );
  }

  FillPath? buildFillPath(
      CheckpointsBuilder builder,
      BorderCheckpointsGeometry geometry,
      _FillContour contour,
      AnyDecoration decoration,
      ) {

    final targets = _targetsForContour(contour);
    if (targets.isEmpty) return null;

    late final Path path;

    if (!contour.hasBackground && _isFullVisibleBorderComponent(contour)) {

      final outerCheckpoints = builder.build(ContourTarget.sides, base: AnyShapeBase.outerBorder);
      final innerCheckpoints = builder.build(ContourTarget.sides, base: AnyShapeBase.innerBorder);

      path = Path.combine(
        PathOperation.difference,
        geometry.build(outerCheckpoints),
        geometry.build(innerCheckpoints),
      );
    } else {

      final base = contour.hasBackground ? decoration.background : null;

      final checkpoints = builder.build(targets, base: base);
      path = geometry.build(checkpoints);
    }

    return FillPath(
      path: path,
      fill: contour.fill,
      debugLabel: contour.debugLabel,
      targets: targets,
    );
  }

  Path clipPath(AnyShapeBase clip) {
    IAnyBorder border = clip == AnyShapeBase.zeroBorder ? this.border.copyWithout() : this.border;
    final builder = CheckpointsBuilder(border);
    final geometry = BorderCheckpointsGeometry(rect, border);
    final checkpoints = builder.build(const { ContourTarget.background }, base: clip);
    return geometry.build(checkpoints);
  }

  Set<ContourTarget> _targetsForContour(_FillContour contour) {

    final targets = <ContourTarget>{...contour.targets};

    final sideTargets = contour.targets.where((t) => t.isSide).toSet();

    final ordered = <ContourTarget>[
      ContourTarget.top,
      ContourTarget.right,
      ContourTarget.bottom,
      ContourTarget.left,
    ].where(sideTargets.contains).toList();

    if (ordered.isEmpty) return targets;

    final targetSet = ordered.toSet();

    for (final side in ordered) {
      final previous = side.previousSide;
      final next = side.nextSide;

      final hasPreviousInComponent = targetSet.contains(previous);
      final hasNextInComponent = targetSet.contains(next);

      if (!hasPreviousInComponent && previous.sideOf(border)?.isVisible != true) {
        targets.add(previous);
      }
      if (!hasNextInComponent && next.sideOf(border)?.isVisible != true) {
        targets.add(next);
      }
    }

    return targets;
  }

  bool _isFullVisibleBorderComponent(_FillContour contour) {
    return !contour.hasBackground &&
        contour.targets.length == 4 &&
        _allVisibleSidesPresent();
  }


  bool _allVisibleSidesPresent() {
    return border.top?.isVisible == true &&
        border.right?.isVisible == true &&
        border.bottom?.isVisible == true &&
        border.left?.isVisible == true;
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

class _FillContour {

  final IAnyFill fill;
  final Set<ContourTarget> targets;
  bool get hasBackground => targets.contains(ContourTarget.background);

  const _FillContour({
    required this.fill,
    required this.targets,
  });

  String get debugLabel {
    final parts = <String>[];
    parts.addAll(targets.map((s) => s.name));
    return parts.join('+');
  }

}



class BorderCheckpointsGeometry {
  final Rect _bounds;
  final IAnyBorder _border;
  late final BorderGeometry _geometry;
  late final Map<ContourPosition, _ContourNavigator> _cw;
  late final Map<ContourPosition, _ContourNavigator> _ccw;

  BorderCheckpointsGeometry(this._bounds, this._border) {
    _geometry = BorderGeometry.resolve(_bounds, _border);
    _cw = {
      ContourPosition.outer: _ContourNavigator.clockwise(_geometry.outerContour),
      ContourPosition.middle: _ContourNavigator.clockwise(_geometry.baseContour),
      ContourPosition.inner: _ContourNavigator.clockwise(_geometry.innerContour),
    };
    _ccw = {
      ContourPosition.outer: _ContourNavigator.counterClockwise(_geometry.outerContour),
      ContourPosition.middle: _ContourNavigator.counterClockwise(_geometry.baseContour),
      ContourPosition.inner: _ContourNavigator.counterClockwise(_geometry.innerContour),
    };
  }

  void alignBounds() {
    // TODO base on _border.topLeft, ... corners detect do we need to reduce bounds
    // TODO we need to reduce bounds in case CornerVariant.rounded (AnyRoundedCorner) and radius is infinity - it means that this corder is circle, and next side is starts in the edge of this circle
    // TODO Example of AnyRoundedCorner(infinity) in top right corner for Rect.fromLTRB(0, 0, 200, 100), bounds mut be reduces to Rect.fromLTRB(0, 0, 150, 100)
  }

  Path build(List<ContourCheckpoint> checkpoints) {
    final path = Path()..fillType = PathFillType.evenOdd;
    if (checkpoints.isEmpty) return path;

    final firstPoint = _pointFor(checkpoints.first);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    for (var i = 0; i < checkpoints.length; i++) {
      final current = checkpoints[i];
      final next = checkpoints[(i + 1) % checkpoints.length];
      _connect(path, current, next);
    }

    path.close();
    return path;
  }

  void _connect(Path path, ContourCheckpoint start, ContourCheckpoint end) {
    if (start.position == end.position) {
      final startPoint = _pointFor(start);
      final endPoint = _pointFor(end);
      if ((startPoint - endPoint).distance <= 0.0001) {
        return;
      }

      final cw = _cw[start.position]!;
      final ccw = _ccw[start.position]!;
      final cwLength = cw.segmentLength(start, end);
      final ccwLength = ccw.segmentLength(start, end);
      if (cwLength <= ccwLength) {
        cw.appendSegment(path, start, end);
      } else {
        ccw.appendSegment(path, start, end);
      }
      return;
    }

    final endPoint = _pointFor(end);
    path.lineTo(endPoint.dx, endPoint.dy);
  }

  Offset _pointFor(ContourCheckpoint checkpoint) {
    final position = checkpoint.position;
    switch (checkpoint.variant) {
      case ContourVariant.side:
        return _sidePoint(position, checkpoint.point);
      case ContourVariant.corner:
        return _cornerPoint(position, checkpoint.point);
      case ContourVariant.split:
        return _cw[position]!.pointFor(checkpoint);
    }
  }

  Offset _sidePoint(ContourPosition position, ContourPoint point) {
    final contour = _contourFor(position);
    switch (point) {
      case ContourPoint.topCenter:
        return contour.topMiddle;
      case ContourPoint.rightCenter:
        return contour.rightMiddle;
      case ContourPoint.bottomCenter:
        return contour.bottomMiddle;
      case ContourPoint.leftCenter:
        return contour.leftMiddle;
      default:
        throw ArgumentError('Invalid side checkpoint point: $point');
    }
  }

  Offset _cornerPoint(ContourPosition position, ContourPoint point) {
    final contour = _contourFor(position);
    switch (point) {
      case ContourPoint.topLeft:
        return contour.topStart();
      case ContourPoint.topRight:
        return contour.topEnd();
      case ContourPoint.rightTop:
        return contour.rightStart();
      case ContourPoint.rightBottom:
        return contour.rightEnd();
      case ContourPoint.bottomRight:
        return contour.bottomStart();
      case ContourPoint.bottomLeft:
        return contour.bottomEnd();
      case ContourPoint.leftBottom:
        return contour.leftStart();
      case ContourPoint.leftTop:
        return contour.leftEnd();
      default:
        throw ArgumentError('Invalid corner checkpoint point: $point');
    }
  }

  BorderContour _contourFor(ContourPosition position) {
    switch (position) {
      case ContourPosition.outer:
        return _geometry.outerContour;
      case ContourPosition.middle:
        return _geometry.baseContour;
      case ContourPosition.inner:
        return _geometry.innerContour;
    }
  }
}

class _ContourNavigator {
  _ContourNavigator._({
    required this.path,
    required this.metric,
    required this.offsets,
  });

  final Path path;
  final PathMetric? metric;
  final Map<_CheckpointKey, double> offsets;

  factory _ContourNavigator.clockwise(BorderContour contour) {
    final path = contour.toPath();
    final metric = _ContourWalker._firstMetric(path);
    return _ContourNavigator._(
      path: path,
      metric: metric,
      offsets: _buildOffsets(contour, clockwise: true, totalLength: metric?.length ?? 0.0),
    );
  }

  factory _ContourNavigator.counterClockwise(BorderContour contour) {
    final path = contour.toPath(clockwise: false);
    final metric = _ContourWalker._firstMetric(path);
    return _ContourNavigator._(
      path: path,
      metric: metric,
      offsets: _buildOffsets(contour, clockwise: false, totalLength: metric?.length ?? 0.0),
    );
  }

  static Map<_CheckpointKey, double> _buildOffsets(
    BorderContour contour, {
    required bool clockwise,
    required double totalLength,
  }) {
    final topRightHalf = _ContourWalker._halfCornerLength(contour, CornerPosition.topRight);
    final bottomRightHalf = _ContourWalker._halfCornerLength(contour, CornerPosition.bottomRight);
    final bottomLeftHalf = _ContourWalker._halfCornerLength(contour, CornerPosition.bottomLeft);
    final topLeftHalf = _ContourWalker._halfCornerLength(contour, CornerPosition.topLeft);

    final topRightCornerLength = topRightHalf * 2.0;
    final bottomRightCornerLength = bottomRightHalf * 2.0;
    final bottomLeftCornerLength = bottomLeftHalf * 2.0;
    final topLeftCornerLength = topLeftHalf * 2.0;

    final topRightSide = (contour.topMiddle - contour.topEnd()).distance;
    final rightTopSide = (contour.rightMiddle - contour.rightStart()).distance;
    final rightBottomSide = (contour.rightEnd() - contour.rightMiddle).distance;
    final bottomRightSide = (contour.bottomStart() - contour.bottomMiddle).distance;
    final bottomLeftSide = (contour.bottomMiddle - contour.bottomEnd()).distance;
    final leftBottomSide = (contour.leftStart() - contour.leftMiddle).distance;
    final leftTopSide = (contour.leftMiddle - contour.leftEnd()).distance;
    final topLeftSide = (contour.topStart() - contour.topMiddle).distance;

    if (clockwise) {
      final split1 = topRightSide + topRightHalf;
      final sideRight = split1 + topRightHalf + rightTopSide;
      final split3 = sideRight + rightBottomSide + bottomRightHalf;
      final sideBottom = split3 + bottomRightHalf + bottomRightSide;
      final split5 = sideBottom + bottomLeftSide + bottomLeftHalf;
      final sideLeft = split5 + bottomLeftHalf + leftBottomSide;
      final split7 = sideLeft + leftTopSide + topLeftHalf;

      return {
        _CheckpointKey(ContourVariant.side, ContourPoint.topCenter): 0.0,
        _CheckpointKey(ContourVariant.corner, ContourPoint.topRight): topRightSide,
        _CheckpointKey(ContourVariant.split, ContourPoint.topRight): split1,
        _CheckpointKey(ContourVariant.corner, ContourPoint.rightTop): topRightSide + topRightCornerLength,
        _CheckpointKey(ContourVariant.side, ContourPoint.rightCenter): sideRight,
        _CheckpointKey(ContourVariant.corner, ContourPoint.rightBottom): sideRight + rightBottomSide,
        _CheckpointKey(ContourVariant.split, ContourPoint.rightBottom): split3,
        _CheckpointKey(ContourVariant.corner, ContourPoint.bottomRight): sideRight + rightBottomSide + bottomRightCornerLength,
        _CheckpointKey(ContourVariant.side, ContourPoint.bottomCenter): sideBottom,
        _CheckpointKey(ContourVariant.corner, ContourPoint.bottomLeft): sideBottom + bottomLeftSide,
        _CheckpointKey(ContourVariant.split, ContourPoint.bottomLeft): split5,
        _CheckpointKey(ContourVariant.corner, ContourPoint.leftBottom): sideBottom + bottomLeftSide + bottomLeftCornerLength,
        _CheckpointKey(ContourVariant.side, ContourPoint.leftCenter): sideLeft,
        _CheckpointKey(ContourVariant.corner, ContourPoint.leftTop): sideLeft + leftTopSide,
        _CheckpointKey(ContourVariant.split, ContourPoint.topLeft): split7,
        _CheckpointKey(ContourVariant.corner, ContourPoint.topLeft): totalLength - topLeftSide,
      };
    }

    final split1 = topLeftSide + topLeftHalf;
    final sideLeft = split1 + topLeftHalf + leftTopSide;
    final split3 = sideLeft + leftBottomSide + bottomLeftHalf;
    final sideBottom = split3 + bottomLeftHalf + bottomLeftSide;
    final split5 = sideBottom + bottomRightSide + bottomRightHalf;
    final sideRight = split5 + bottomRightHalf + rightBottomSide;
    final split7 = sideRight + rightTopSide + topRightHalf;

    return {
      _CheckpointKey(ContourVariant.side, ContourPoint.topCenter): 0.0,
      _CheckpointKey(ContourVariant.corner, ContourPoint.topLeft): topLeftSide,
      _CheckpointKey(ContourVariant.split, ContourPoint.topLeft): split1,
      _CheckpointKey(ContourVariant.corner, ContourPoint.leftTop): topLeftSide + topLeftCornerLength,
      _CheckpointKey(ContourVariant.side, ContourPoint.leftCenter): sideLeft,
      _CheckpointKey(ContourVariant.corner, ContourPoint.leftBottom): sideLeft + leftBottomSide,
      _CheckpointKey(ContourVariant.split, ContourPoint.bottomLeft): split3,
      _CheckpointKey(ContourVariant.corner, ContourPoint.bottomLeft): sideLeft + leftBottomSide + bottomLeftCornerLength,
      _CheckpointKey(ContourVariant.side, ContourPoint.bottomCenter): sideBottom,
      _CheckpointKey(ContourVariant.corner, ContourPoint.bottomRight): sideBottom + bottomRightSide,
      _CheckpointKey(ContourVariant.split, ContourPoint.bottomRight): split5,
      _CheckpointKey(ContourVariant.corner, ContourPoint.rightBottom): sideBottom + bottomRightSide + bottomRightCornerLength,
      _CheckpointKey(ContourVariant.side, ContourPoint.rightCenter): sideRight,
      _CheckpointKey(ContourVariant.corner, ContourPoint.rightTop): sideRight + rightTopSide,
      _CheckpointKey(ContourVariant.split, ContourPoint.topRight): split7,
      _CheckpointKey(ContourVariant.corner, ContourPoint.topRight): sideRight + rightTopSide + topRightCornerLength,
    };
  }

  double segmentLength(ContourCheckpoint start, ContourCheckpoint end) {
    final m = metric;
    if (m == null) return double.infinity;
    final startOffset = offsets[_CheckpointKey(start.variant, start.point)]!;
    final endOffset = offsets[_CheckpointKey(end.variant, end.point)]!;
    if (endOffset >= startOffset) {
      return endOffset - startOffset;
    }
    return (m.length - startOffset) + endOffset;
  }

  Offset pointFor(ContourCheckpoint checkpoint) {
    final m = metric;
    if (m == null) return Offset.zero;
    final offset = offsets[_CheckpointKey(checkpoint.variant, checkpoint.point)]!;
    return m.getTangentForOffset(offset)?.position ?? Offset.zero;
  }

  void appendSegment(Path out, ContourCheckpoint start, ContourCheckpoint end) {
    final m = metric;
    if (m == null) return;
    final startOffset = offsets[_CheckpointKey(start.variant, start.point)]!;
    final endOffset = offsets[_CheckpointKey(end.variant, end.point)]!;
    if (endOffset >= startOffset) {
      out.addPath(
        m.extractPath(startOffset, endOffset, startWithMoveTo: false),
        Offset.zero,
      );
      return;
    }
    out.addPath(
      m.extractPath(startOffset, m.length, startWithMoveTo: false),
      Offset.zero,
    );
    out.addPath(
      m.extractPath(0.0, endOffset, startWithMoveTo: false),
      Offset.zero,
    );
  }
}

class _CheckpointKey {
  final ContourVariant variant;
  final ContourPoint point;

  const _CheckpointKey(this.variant, this.point);

  @override
  bool operator ==(Object other) =>
      other is _CheckpointKey && other.variant == variant && other.point == point;

  @override
  int get hashCode => Object.hash(variant, point);
}
