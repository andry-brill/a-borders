import '../decoration/any_align.dart';
import '../decoration/any_border.dart';
import '../decoration/any_decoration.dart';
import '../decoration/any_side.dart';


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
    return '(position:ContourPosition.${position.name},point:ContourPoint.${point.name},variant:ContourVariant.${variant.name})';
  }
}


class CheckpointsBuilder {

  late final bool hasTop;
  late final bool hasRight;
  late final bool hasBottom;
  late final bool hasLeft;
  late final int hasBorders;

  final IAnyBorder _border;

  CheckpointsBuilder(this._border)
      : hasTop = _border.top?.hasWidth == true,
        hasRight = _border.right?.hasWidth == true,
        hasBottom = _border.bottom?.hasWidth == true,
        hasLeft = _border.left?.hasWidth == true {
    var count = 0;
    if (hasTop) count++;
    if (hasRight) count++;
    if (hasBottom) count++;
    if (hasLeft) count++;
    hasBorders = count;
  }

  static const noBorders = 0;
  static const allBorders = 4;

  static const List<_SideSpec> _order = <_SideSpec>[
    _SideSpec.top,
    _SideSpec.right,
    _SideSpec.bottom,
    _SideSpec.left,
  ];

  List<ContourCheckpoint> build(Set<ContourTarget> targets, {AnyShapeBase? base}) {
    if (targets.isEmpty) return const [];

    final normalized = {...targets};

    if (normalized.contains(ContourTarget.background)) {
      return _buildBackgroundMergedContour(
        normalized,
        base: base ?? AnyShapeBase.zeroBorder,
      );
    }

    final requestedRuns = _requestedRuns(normalized);
    if (requestedRuns.isEmpty) return const [];

    if (requestedRuns.length == 1 &&
        requestedRuns.first.length == 4 &&
        requestedRuns.first.every((side) => _hasSide(side.target))) {
      final resolvedBase = base ?? AnyShapeBase.outerBorder;
      return _buildFullContour(_positionForShapeBase(resolvedBase));
    }

    final result = <ContourCheckpoint>[];
    for (final run in requestedRuns) {
      result.addAll(_buildRequestedRun(run));
    }
    return result;
  }

  List<ContourCheckpoint> _buildBackgroundMergedContour(
      Set<ContourTarget> targets, {
        required AnyShapeBase base,
      }) {
    final basePosition = _positionForShapeBase(base);
    final result = <ContourCheckpoint>[];

    for (var i = 0; i < _order.length; i++) {
      final current = _order[i];
      final next = _order[(i + 1) % _order.length];

      final currentPosition = _effectivePositionForMergedSide(
        current.target,
        targets,
        basePosition,
      );
      final nextPosition = _effectivePositionForMergedSide(
        next.target,
        targets,
        basePosition,
      );

      result.add(_side(current.middle, currentPosition));

      if (currentPosition == nextPosition) {
        result.add(_corner(current.endCorner, currentPosition));
        result.add(_corner(next.startCorner, nextPosition));
      } else {
        result.add(_corner(current.endCorner, currentPosition));
        result.add(_split(current.endSplit, currentPosition));
        result.add(_split(next.startSplit, nextPosition));
        result.add(_corner(next.startCorner, nextPosition));
      }
    }

    return result;
  }

  List<ContourCheckpoint> _buildRequestedRun(List<_SideSpec> requestedRun) {
    final result = <ContourCheckpoint>[];

    var index = 0;
    while (index < requestedRun.length) {
      while (index < requestedRun.length && !_hasSide(requestedRun[index].target)) {
        index++;
      }
      if (index >= requestedRun.length) break;

      final start = index;
      while (index < requestedRun.length && _hasSide(requestedRun[index].target)) {
        index++;
      }
      final end = index - 1;

      final visibleSequence = requestedRun.sublist(start, end + 1);

      final startCap = start == 0
          ? const _BoundaryCap.split()
          : _BoundaryCap.bridgeMissing(requestedRun[start - 1]);

      final endCap = end == requestedRun.length - 1
          ? const _BoundaryCap.split()
          : _BoundaryCap.bridgeMissing(requestedRun[end + 1]);

      result.addAll(
        _buildVisibleSequence(
          visibleSequence,
          startCap: startCap,
          endCap: endCap,
        ),
      );
    }

    return result;
  }

  List<ContourCheckpoint> _buildVisibleSequence(
      List<_SideSpec> run, {
        required _BoundaryCap startCap,
        required _BoundaryCap endCap,
      }) {
    final result = <ContourCheckpoint>[];
    final first = run.first;
    final last = run.last;

    result.add(_side(first.middle, ContourPosition.outer));

    for (var i = 0; i < run.length - 1; i++) {
      final current = run[i];
      final next = run[i + 1];
      result.add(_corner(current.endCorner, ContourPosition.outer));
      result.add(_corner(next.startCorner, ContourPosition.outer));
      result.add(_side(next.middle, ContourPosition.outer));
    }

    _appendEndCap(
      result,
      side: last,
      cap: endCap,
    );

    for (var i = run.length - 1; i >= 0; i--) {
      final current = run[i];
      result.add(_side(current.middle, ContourPosition.inner));

      if (i > 0) {
        final previous = run[i - 1];
        result.add(_corner(current.startCorner, ContourPosition.inner));
        result.add(_corner(previous.endCorner, ContourPosition.inner));
      } else {
        _appendStartCap(
          result,
          side: current,
          cap: startCap,
        );
      }
    }

    return result;
  }

  void _appendEndCap(
      List<ContourCheckpoint> out, {
        required _SideSpec side,
        required _BoundaryCap cap,
      }) {
    out.add(_corner(side.endCorner, ContourPosition.outer));

    if (cap.missingNeighbor == null) {
      out.add(_split(side.endSplit, ContourPosition.outer));
      out.add(_split(side.endSplit, ContourPosition.inner));
      out.add(_corner(side.endCorner, ContourPosition.inner));
      return;
    }

    final next = cap.missingNeighbor!;
    out.add(_corner(next.startCorner, ContourPosition.outer));
    out.add(_corner(side.endCorner, ContourPosition.inner));
  }

  void _appendStartCap(
      List<ContourCheckpoint> out, {
        required _SideSpec side,
        required _BoundaryCap cap,
      }) {
    out.add(_corner(side.startCorner, ContourPosition.inner));

    if (cap.missingNeighbor == null) {
      out.add(_split(side.startSplit, ContourPosition.inner));
      out.add(_split(side.startSplit, ContourPosition.outer));
      out.add(_corner(side.startCorner, ContourPosition.outer));
      return;
    }

    final previous = cap.missingNeighbor!;
    out.add(_corner(previous.endCorner, ContourPosition.outer));
    out.add(_corner(side.startCorner, ContourPosition.outer));
  }

  List<ContourCheckpoint> _buildFullContour(ContourPosition position) {
    final result = <ContourCheckpoint>[];
    for (var i = 0; i < _order.length; i++) {
      final current = _order[i];
      final next = _order[(i + 1) % _order.length];
      result.add(_side(current.middle, position));
      result.add(_corner(current.endCorner, position));
      result.add(_corner(next.startCorner, position));
    }
    return result;
  }

  List<List<_SideSpec>> _requestedRuns(Set<ContourTarget> targets) {
    final requested = _order.where((side) => targets.contains(side.target)).toList();
    if (requested.isEmpty) return const [];

    final requestedSet = requested.map((e) => e.target).toSet();
    final starts = <_SideSpec>[];

    for (final side in requested) {
      if (!requestedSet.contains(side.previous.target)) {
        starts.add(side);
      }
    }

    if (starts.isEmpty) {
      return <List<_SideSpec>>[
        List<_SideSpec>.from(_order.where((s) => requestedSet.contains(s.target))),
      ];
    }

    final runs = <List<_SideSpec>>[];
    for (final start in starts) {
      final run = <_SideSpec>[start];
      var current = start;
      while (requestedSet.contains(current.next.target)) {
        current = current.next;
        if (current.target == start.target) break;
        run.add(current);
      }
      runs.add(run);
    }

    return runs;
  }

  ContourPosition _effectivePositionForMergedSide(
      ContourTarget side,
      Set<ContourTarget> targets,
      ContourPosition basePosition,
      ) {
    if (!targets.contains(side)) {
      return basePosition;
    }

    final align = _alignForTarget(side);
    final sidePosition = _outerExtentPositionForAlign(align);
    return _maxPosition(basePosition, sidePosition);
  }

  ContourPosition _positionForShapeBase(AnyShapeBase base) {
    switch (base) {
      case AnyShapeBase.zeroBorder:
        return ContourPosition.middle;
      case AnyShapeBase.outerBorder:
        return ContourPosition.outer;
      case AnyShapeBase.innerBorder:
        return ContourPosition.inner;
    }
  }

  ContourPosition _outerExtentPositionForAlign(AnyAlign? align) {
    switch (align) {
      case AnyAlign.inside:
        return ContourPosition.inner;
      case AnyAlign.center:
        return ContourPosition.middle;
      case AnyAlign.outside:
        return ContourPosition.outer;
      case null:
        return ContourPosition.middle;
    }
  }

  ContourPosition _maxPosition(ContourPosition a, ContourPosition b) {
    if (_positionRank(a) >= _positionRank(b)) return a;
    return b;
  }

  int _positionRank(ContourPosition position) {
    switch (position) {
      case ContourPosition.inner:
        return 0;
      case ContourPosition.middle:
        return 1;
      case ContourPosition.outer:
        return 2;
    }
  }

  bool _hasSide(ContourTarget side) {
    switch (side) {
      case ContourTarget.top:
        return hasTop;
      case ContourTarget.right:
        return hasRight;
      case ContourTarget.bottom:
        return hasBottom;
      case ContourTarget.left:
        return hasLeft;
      case ContourTarget.background:
        return true;
    }
  }

  AnyAlign? _alignForTarget(ContourTarget side) {
    switch (side) {
      case ContourTarget.top:
        return _border.top?.align;
      case ContourTarget.right:
        return _border.right?.align;
      case ContourTarget.bottom:
        return _border.bottom?.align;
      case ContourTarget.left:
        return _border.left?.align;
      case ContourTarget.background:
        return null;
    }
  }

  static ContourCheckpoint _side(
      ContourPoint point,
      ContourPosition position,
      ) {
    return ContourCheckpoint(
      variant: ContourVariant.side,
      position: position,
      point: point,
    );
  }

  static ContourCheckpoint _corner(
      ContourPoint point,
      ContourPosition position,
      ) {
    return ContourCheckpoint(
      variant: ContourVariant.corner,
      position: position,
      point: point,
    );
  }

  static ContourCheckpoint _split(
      ContourPoint point,
      ContourPosition position,
      ) {
    return ContourCheckpoint(
      variant: ContourVariant.split,
      position: position,
      point: point,
    );
  }
}

class _SideSpec {
  final ContourTarget target;
  final ContourPoint middle;
  final ContourPoint startCorner;
  final ContourPoint endCorner;
  final ContourPoint startSplit;
  final ContourPoint endSplit;
  final int index;

  const _SideSpec._({
    required this.target,
    required this.middle,
    required this.startCorner,
    required this.endCorner,
    required this.startSplit,
    required this.endSplit,
    required this.index,
  });

  static const top = _SideSpec._(
    target: ContourTarget.top,
    middle: ContourPoint.topCenter,
    startCorner: ContourPoint.topLeft,
    endCorner: ContourPoint.topRight,
    startSplit: ContourPoint.topLeft,
    endSplit: ContourPoint.topRight,
    index: 0,
  );

  static const right = _SideSpec._(
    target: ContourTarget.right,
    middle: ContourPoint.rightCenter,
    startCorner: ContourPoint.rightTop,
    endCorner: ContourPoint.rightBottom,
    startSplit: ContourPoint.rightTop,
    endSplit: ContourPoint.rightBottom,
    index: 1,
  );

  static const bottom = _SideSpec._(
    target: ContourTarget.bottom,
    middle: ContourPoint.bottomCenter,
    startCorner: ContourPoint.bottomRight,
    endCorner: ContourPoint.bottomLeft,
    startSplit: ContourPoint.bottomRight,
    endSplit: ContourPoint.bottomLeft,
    index: 2,
  );

  static const left = _SideSpec._(
    target: ContourTarget.left,
    middle: ContourPoint.leftCenter,
    startCorner: ContourPoint.leftBottom,
    endCorner: ContourPoint.leftTop,
    startSplit: ContourPoint.leftBottom,
    endSplit: ContourPoint.leftTop,
    index: 3,
  );

  static const List<_SideSpec> values = <_SideSpec>[top, right, bottom, left];

  _SideSpec get next => values[(index + 1) % values.length];
  _SideSpec get previous => values[(index + values.length - 1) % values.length];
}

class _BoundaryCap {
  final _SideSpec? missingNeighbor;

  const _BoundaryCap._(this.missingNeighbor);

  const _BoundaryCap.split() : this._(null);

  const _BoundaryCap.bridgeMissing(_SideSpec neighbor) : this._(neighbor);
}



// class CheckpointsBuilder2 {
//
//   late final bool hasTop;
//   late final bool hasRight;
//   late final bool hasBottom;
//   late final bool hasLeft;
//   late final int hasBorders;
//
//   IAnyBorder _border;
//   CheckpointsBuilder2(this._border) :
//     hasTop = _border.top?.hasWidth == true,
//     hasRight = _border.right?.hasWidth == true,
//     hasBottom = _border.bottom?.hasWidth == true,
//     hasLeft = _border.left?.hasWidth == true
//   {
//     int b = 0;
//     if (hasTop) b++;
//     if (hasRight) b++;
//     if (hasBottom) b++;
//     if (hasLeft) b++;
//     hasBorders = b;
//   }
//
//   static const noBorders = 0;
//   static const allBorders = 0;
//
//   List<ContourCheckpoint> build(Set<ContourTarget> targets, {AnyShapeBase? base}) {
//
//     if (targets.isEmpty) return [];
//
//     if (targets.contains(ContourTarget.background)) {
//
//       final backBase = base ?? AnyShapeBase.zeroBorder;
//       if (backBase == AnyShapeBase.innerBorder || backBase == AnyShapeBase.outerBorder) {
//         targets = ContourTarget.sides;
//       } else {
//
//         AnyShapeBase? simplifiedBase;
//
//         /// When no borders outline of zero borders will be used
//         if (hasBorders == noBorders) {
//           simplifiedBase = AnyShapeBase.outerBorder;
//         }
//
//         /// Checking that all borders align inside or empty, then we can just build background as sides outlines
//         if (simplifiedBase == null && (
//             (!hasTop || _border.top!.align == AnyAlign.inside) &&
//             (!hasRight || _border.right!.align == AnyAlign.inside) &&
//             (!hasBottom || _border.bottom!.align == AnyAlign.inside) &&
//             (!hasLeft || _border.left!.align == AnyAlign.inside))
//         ) {
//           simplifiedBase = AnyShapeBase.outerBorder;
//         }
//
//         if (hasBorders == allBorders) {
//           /// If all borders aligned in the same way
//           final align = _border.top!.align;
//           if (align == _border.right!.align && align == _border.bottom!.align && align == _border.left!.align) {
//             simplifiedBase = AnyShapeBase.outerBorder;
//           }
//         }
//
//         if (simplifiedBase != null) {
//           targets = ContourTarget.sides;
//           base = AnyShapeBase.outerBorder;
//         }
//
//       }
//
//     }
//
//     if (targets.length == 2) {
//
//       // This means that background has the same fill as top side and paths could be merged
//       if (targets.contains(ContourTarget.background) && targets.contains(ContourTarget.top)) {
//
//         List<ContourCheckpoint> result = [
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
//         ];
//
//         switch (_border.top!.align) {
//
//           case AnyAlign.inside:
//             throw 'Should not be called, as it will be handled in other way';
//           case AnyAlign.center:
//             result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.split));
//             result.add(ContourCheckpoint(position: ContourPosition.middle, point: ContourPoint.topRight, variant: ContourVariant.split));
//           case AnyAlign.outside:
//             result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.split));
//             result.add(ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.split));
//         }
//
//         // NB! We can you outer or inner here as all other borders will be treated as they has 0 width
//         result.addAll([
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.split),
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomRight, variant: ContourVariant.corner),
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomCenter, variant: ContourVariant.side),
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomLeft, variant: ContourVariant.corner),
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftBottom, variant: ContourVariant.corner),
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftCenter, variant: ContourVariant.side),
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftTop, variant: ContourVariant.corner),
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftTop, variant: ContourVariant.split),
//
//         ]);
//
//         switch (_border.top!.align) {
//
//           case AnyAlign.inside:
//             throw 'Should not be called, as it will be handled in other way';
//           case AnyAlign.center:
//             result.add(ContourCheckpoint(position: ContourPosition.middle, point: ContourPoint.topLeft, variant: ContourVariant.split));
//             result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split));
//           case AnyAlign.outside:
//             result.add(ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split));
//             result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split));
//         }
//
//         result.add(ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner));
//
//         return result;
//       }
//
//
//       if (targets.contains(ContourTarget.top) && targets.contains(ContourTarget.right)) {
//
//         assert(hasTop || hasRight);
//
//         // If no border in top in that case we only drawing corner from top side (to visualize change), not full top side
//         if (!hasTop) {
//           return const [
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.split),
//             ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.split),
//             ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
//
//             ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightCenter, variant: ContourVariant.side),
//
//             ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightTop, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner), // will be connected to first checkpoint
//
//           ];
//         }
//
//         // If no border in right in that case we only drawing corner from right side (to visualize change), not full right side
//         if (!hasRight) {
//           return const [
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),
//
//             ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),
//
//             ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner), // will be connected to first checkpoint
//           ];
//         }
//
//         return const [
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),
//
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.split),
//           ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.split),
//           ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
//
//           ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightCenter, variant: ContourVariant.side),
//
//           ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightTop, variant: ContourVariant.corner),
//           ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),
//
//           ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),
//
//           ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
//           ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split),
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split),
//           ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner), // will be connected to first checkpoint
//
//         ];
//       }
//     }
//
//
//     if (targets.length == 4) {
//       if (targets.contains(ContourTarget.top) && targets.contains(ContourTarget.right) && targets.contains(ContourTarget.bottom) && targets.contains(ContourTarget.left)) {
//
//         if (hasBottom && hasLeft && hasRight && hasTop) {
//
//           assert(base != null);
//
//           if (base == AnyShapeBase.innerBorder) {
//             return const [
//
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),
//
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.leftTop, variant: ContourVariant.corner),
//
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.leftCenter, variant: ContourVariant.side),
//
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.leftBottom, variant: ContourVariant.corner),
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.bottomLeft, variant: ContourVariant.corner),
//
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.bottomCenter, variant: ContourVariant.side),
//
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.bottomRight, variant: ContourVariant.corner),
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
//
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightCenter, variant: ContourVariant.side),
//
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightTop, variant: ContourVariant.corner),
//               ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),
//
//             ];
//           }
//
//           assert(base == AnyShapeBase.outerBorder);
//
//           return const [
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomRight, variant: ContourVariant.corner),
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomCenter, variant: ContourVariant.side),
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomLeft, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftBottom, variant: ContourVariant.corner),
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftCenter, variant: ContourVariant.side),
//
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftTop, variant: ContourVariant.corner),
//             ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner),
//
//
//           ];
//
//         }
//
//         throw 'TODO';
//       }
//     }
//
//     throw 'Missing case for $targets';
//   }
//
//
// }