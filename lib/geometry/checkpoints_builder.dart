import '../decoration/any_align.dart';
import '../decoration/any_border.dart';
import '../decoration/any_decoration.dart';
import '../decoration/any_side.dart';
import 'border_geometry.dart';

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

    final selectedSides = _selectedSides(normalized);

    if (selectedSides.isEmpty) return const [];

    if (selectedSides.length == 4) {
      final resolvedBase = base ?? AnyShapeBase.outerBorder;
      return _buildFullContour(_positionForShapeBase(resolvedBase));
    }

    final runs = _contiguousRuns(selectedSides);

    if (runs.isEmpty) return const [];

    if (runs.length == 1) {
      return _buildBorderRun(runs.first);
    }

    final result = <ContourCheckpoint>[];
    for (final run in runs) {
      if (result.isNotEmpty) {
        result.addAll(_buildBorderRun(run));
      } else {
        result.addAll(_buildBorderRun(run));
      }
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

  List<ContourCheckpoint> _buildBorderRun(List<_SideSpec> run) {
    final result = <ContourCheckpoint>[];
    final first = run.first;

    result.add(_side(first.middle, ContourPosition.outer));

    for (var i = 0; i < run.length; i++) {
      final current = run[i];
      final hasNextInRun = i < run.length - 1;

      if (hasNextInRun) {
        final next = run[i + 1];
        result.add(_corner(current.endCorner, ContourPosition.outer));
        result.add(_corner(next.startCorner, ContourPosition.outer));
        result.add(_side(next.middle, ContourPosition.outer));
      } else {
        result.add(_corner(current.endCorner, ContourPosition.outer));
        result.add(_split(current.endSplit, ContourPosition.outer));
        result.add(_split(current.endSplit, ContourPosition.inner));
        result.add(_corner(current.endCorner, ContourPosition.inner));
      }
    }

    for (var i = run.length - 1; i >= 0; i--) {
      final current = run[i];
      result.add(_side(current.middle, ContourPosition.inner));

      final hasPrevInRun = i > 0;
      if (hasPrevInRun) {
        final previous = run[i - 1];
        result.add(_corner(current.startCorner, ContourPosition.inner));
        result.add(_corner(previous.endCorner, ContourPosition.inner));
      } else {
        result.add(_corner(current.startCorner, ContourPosition.inner));
        result.add(_split(current.startSplit, ContourPosition.inner));
        result.add(_split(current.startSplit, ContourPosition.outer));
        result.add(_corner(current.startCorner, ContourPosition.outer));
      }
    }

    return result;
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

  List<_SideSpec> _selectedSides(Set<ContourTarget> targets) {
    final result = <_SideSpec>[];

    for (final side in _order) {
      if (!targets.contains(side.target)) continue;
      if (!_hasSide(side.target)) continue;
      result.add(side);
    }

    return result;
  }

  List<List<_SideSpec>> _contiguousRuns(List<_SideSpec> selected) {
    if (selected.isEmpty) return const [];

    final selectedSet = selected.map((e) => e.target).toSet();
    final starts = <_SideSpec>[];

    for (final side in selected) {
      if (!selectedSet.contains(side.previous.target)) {
        starts.add(side);
      }
    }

    if (starts.isEmpty) {
      return <List<_SideSpec>>[
        List<_SideSpec>.from(_order.where((s) => selectedSet.contains(s.target))),
      ];
    }

    final runs = <List<_SideSpec>>[];
    for (final start in starts) {
      final run = <_SideSpec>[start];
      var current = start;
      while (selectedSet.contains(current.next.target)) {
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
