import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';


abstract class IAnyFill {
  Color? get color;
  Gradient? get gradient;
  DecorationImage? get image;
  BlendMode? get blendMode;
  bool isSameAs(IAnyFill other);
}

mixin MAnyFill implements IAnyFill {
  @override
  bool isSameAs(IAnyFill? other) {
    if (other == null) return false;
    return color == other.color &&
        gradient == other.gradient &&
        image == other.image &&
        blendMode == other.blendMode;
  }
}

extension EAnyFill on IAnyFill {
  bool get hasFill => color != null || gradient != null || image != null;
  bool get hasBaseFill => color != null || gradient != null;
}



const double _epsilon = 1.0e-6;

bool _nearZero(double value, [double epsilon = _epsilon]) =>
    value.abs() <= epsilon;

bool _samePoint(Offset a, Offset b, [double epsilon = _epsilon]) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return (dx * dx) + (dy * dy) <= epsilon * epsilon;
}

extension _OffsetMath on Offset {

  Offset scaled(double value) => Offset(dx * value, dy * value);

  double cross(Offset other) => (dx * other.dy) - (dy * other.dx);

  Offset get normalized {
    final length = distance;
    if (_nearZero(length)) {
      throw StateError('Can\'t normalize a zero-length vector.');
    }
    return Offset(dx / length, dy / length);
  }

  /// 90° clockwise normal in Flutter coordinates.
  ///
  /// For a polygon traced clockwise, this points to the inside.
  Offset get clockwiseNormal => Offset(-dy, dx);
}

class _Line2D {
  final Offset point;
  final Offset direction;

  const _Line2D(this.point, this.direction);

  Offset intersection(_Line2D other) {
    final denominator = direction.cross(other.direction);
    if (_nearZero(denominator)) {
      throw StateError('Parallel offset lines can\'t be intersected.');
    }

    final delta = other.point - point;
    final t = delta.cross(other.direction) / denominator;
    return point + direction.scaled(t);
  }
}

enum AnyShapeBase {

  /// Shape of the element based on border corners but ignoring border side width.
  ///
  /// If a background and an outer border side share the same fill, the region
  /// builder may extend the background path to include that outside
  /// contribution.
  zeroBorder,

  /// Combining all outer paths of border sides into one contour.
  outerBorder,

  /// Combining all inner paths of border sides into one contour.
  innerBorder
}

enum CommandType {

  line(false),
  rotateLeft(true),
  rotateRight(true);

  final bool isCorner;
  const CommandType(this.isCorner);
}

class Command {
  final CommandType type;
  final double value;
  const Command(this.type, this.value);
}

/// Simple closed polygon (straight lines, no self-intersections) in L-system.
///
/// The implementation assumes the first command is a line, then commands
/// alternate line/corner/line/corner and the traced polygon winds clockwise.
class Polygon {

  final Map<Enum, Command> commands;
  const Polygon(this.commands);

  Command commandOf(Enum value) => commands[value]!;

  bool validate() {

    if (commands.isEmpty || commands.length.isOdd) {
      return false;
    }

    final entries = commands.entries.toList(growable: false);
    if (entries.first.value.type != CommandType.line) {
      return false;
    }

    double total = 0.0;
    bool expectCorner = false;

    for (final entry in entries) {
      final command = entry.value;
      if (expectCorner != command.type.isCorner) {
        return false;
      }

      if (command.type == CommandType.rotateRight) {
        total += command.value;
      } else if (command.type == CommandType.rotateLeft) {
        total -= command.value;
      }

      expectCorner = !expectCorner;
    }

    return (total - (2 * pi)).abs() <= 0.00001;
  }

  List<StrokeRegion> buildMergedStrokeRegions(
      PolygonSetup setup, {
        /// Build only background region.
        /// Useful for clip path building.
        bool backgroundOnly = false,

        /// Override background shape base while building.
        AnyShapeBase? backgroundBase,
      }) {
    final geometry = _PolygonGeometry.fromCommands(commands);
    return _StrokeRegionBuilder(
      geometry,
      setup,
      backgroundOnly: backgroundOnly,
      backgroundBase: backgroundBase,
    ).build();
  }
}

class PolygonSetup {
  final Map<Enum, AnySide> sides;
  final Map<Enum, AnyCorner> corners;
  final Map<Enum, AnyBackground> background;

  PolygonSetup({
    required this.sides,
    required this.corners,
    required this.background,
  }) : assert(background.length <= 1);
}

class StrokeRegion {
  final List<Enum> included;
  final IAnyFill fill;
  final Path path;
  const StrokeRegion(this.included, this.fill, this.path);
}


class AnySide with MAnyFill {

  static const double alignInside = -1;
  static const double alignCenter = 0;
  static const double alignOutside = 1;
  
  static double alignBase = alignInside;
  
  final double width;
  
  final double? _align;

  /// Align means align relative to the corresponding side, not the whole shape.
  double get align => _align ?? alignBase;

  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;

  const AnySide({
    this.width = 0.0,
    double? align,
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
  })  : _align = align,
        assert(width >= 0.0),
        assert(align == null || (align >= -1.0 && align <= 1.0));

  AnySide copyWith({
    double? width,
    double? align,
    Color? color,
    Gradient? gradient,
    DecorationImage? image,
    BlendMode? blendMode,
  }) {
    return AnySide(
      width: width ?? this.width,
      align: align ?? this.align,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      image: image ?? this.image,
      blendMode: blendMode ?? this.blendMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AnySide &&
        other.width == width &&
        other.align == align &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode;
  }

  @override
  int get hashCode => Object.hash(
    width,
    align,
    color,
    gradient,
    image,
    blendMode,
  );
}


class AnyBackground extends AnySide {

  final AnyShapeBase shapeBase;

  const AnyBackground({ super.color, super.gradient, super.image, super.blendMode, this.shapeBase = AnyShapeBase.zeroBorder})
      : super(width: double.infinity, align: AnySide.alignCenter);

}

/// Describes how this corner is rendered.
///
/// Rendering modes:
/// - `radius == Radius.zero`: a sharp corner.
/// - `radius.x > 0 && radius.y > 0`: an inner rounded corner,
///   using the smaller effective radius from the two sides.
/// - `radius.x < 0 && radius.y < 0`: an outer rounded corner,
///   using the larger effective radius from the two sides.
/// - If the adjacent sides are parallel, the corner is rendered
///   as an extended outer arc.
///
/// Note:
/// `radius.x` and `radius.y` do not match Flutter's default
/// `Radius` semantics.
///
/// In this class:
/// - `radius.x` is the perpendicular distance to the side before
///   the corner, measured along that side's inward normal.
/// - `radius.y` is the perpendicular distance to the side after
///   the corner, measured along that side's inward normal.
///
/// Corner construction:
/// - Compute the unit direction vectors of the two adjacent sides.
/// - Compute their inward normals.
/// - Represent points using signed perpendicular distances to both sides.
/// - Define the corner curve by `(d1 / x)^2 + (d2 / y)^2 = 1`.
/// - Build the rendered arc from that curve.
///
/// Side constraint:
/// For a side `S` between corners `L` and `R`, the two corner arcs must not
/// overlap on that side.
///
/// The consumed length on `S` is:
/// - from `L`: `abs(L.radius.x) / sin(angleL)`
/// - from `R`: `abs(R.radius.y) / sin(angleR)`
///
/// Therefore:
/// `abs(L.radius.x) / sin(angleL) + abs(R.radius.y) / sin(angleR) <= length(S)`
///
/// Automatic normalization:
/// If the consumed length is greater than `length(S)`, both values should be
/// scaled proportionally so they exactly fit the side while preserving their
/// relative weights.
///
/// Let:
/// - `a = abs(L.radius.x) / sin(angleL)`
/// - `b = abs(R.radius.y) / sin(angleR)`
///
/// If `a + b > length(S)`, compute:
/// `k = length(S) / (a + b)`
///
/// Then apply:
/// - `L.radius.x *= k`
/// - `R.radius.y *= k`
///
/// This preserves the sign of each radius component and guarantees that the
/// two corners exactly fit on the side without overlap.
///
/// Join handling for adjacent sides with different widths or fills:
/// - If the two adjacent sides share the same fill, they can be merged into a
///   single solid [Path]. In this case, the corner is rendered as one joined
///   shape, and both the outer and inner corner boundaries are rounded by
///   their corresponding arcs.
/// - If the two adjacent sides have different fills, they must remain separate.
///   In this case, the corner transition cannot be rendered as a single merged
///   shape. Instead, the corner arc must be split at the boundary between the
///   two side regions, producing two arc segments: one belonging to the
///   previous side and one belonging to the next side.
///
/// This is especially relevant when adjacent sides have different stroke
/// widths. For example, if one side has width `10` and the next has width `20`,
/// the inner and outer corner offsets differ for each side, so the split point
/// must be chosen consistently to keep both side regions continuous and
/// visually aligned through the corner.
class AnyCorner {
  final Radius radius;
  const AnyCorner([this.radius = Radius.zero]);

  @override
  bool operator ==(Object other) {
    return other is AnyCorner && other.radius == radius;
  }

  @override
  int get hashCode => radius.hashCode;
}



class _PolygonGeometry {
  final List<_SideFrame> sides;
  final List<_CornerFrame> corners;
  final Map<Enum, _SideFrame> sideByKey;
  final Map<Enum, _CornerFrame> cornerByKey;

  const _PolygonGeometry({
    required this.sides,
    required this.corners,
    required this.sideByKey,
    required this.cornerByKey,
  });

  factory _PolygonGeometry.fromCommands(Map<Enum, Command> commands) {
    if (commands.isEmpty || commands.length.isOdd) {
      throw ArgumentError(
        'Polygon commands must contain alternating side/corner entries.',
      );
    }

    final entries = commands.entries.toList(growable: false);
    final sideEntries = <MapEntry<Enum, Command>>[];
    final cornerEntries = <MapEntry<Enum, Command>>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isSidePosition = i.isEven;
      if (isSidePosition != (entry.value.type == CommandType.line)) {
        throw ArgumentError('Commands must alternate side/corner/side/corner.');
      }

      if (isSidePosition) {
        sideEntries.add(entry);
      } else {
        cornerEntries.add(entry);
      }
    }

    if (sideEntries.length != cornerEntries.length) {
      throw ArgumentError(
        'Closed polygon requires the same number of sides and corners.',
      );
    }

    final builtSides = <_SideFrame>[];
    final sideByKey = <Enum, _SideFrame>{};
    final builtCorners = <_CornerFrame>[];
    final cornerByKey = <Enum, _CornerFrame>{};

    var point = Offset.zero;
    var heading = 0.0;

    for (var i = 0; i < sideEntries.length; i++) {
      final sideEntry = sideEntries[i];
      final sideLength = sideEntry.value.value;
      if (sideLength < 0.0) {
        throw ArgumentError(
          'Side length must be non-negative for ${sideEntry.key}.',
        );
      }

      final direction = Offset(cos(heading), sin(heading));
      final endPoint = point + direction.scaled(sideLength);

      final sideFrame = _SideFrame(
        index: i,
        key: sideEntry.key,
        start: point,
        end: endPoint,
      );
      builtSides.add(sideFrame);
      sideByKey[sideEntry.key] = sideFrame;

      final cornerEntry = cornerEntries[i];
      final cornerFrame = _CornerFrame(
        index: i,
        key: cornerEntry.key,
        vertex: endPoint,
        command: cornerEntry.value,
      );
      builtCorners.add(cornerFrame);
      cornerByKey[cornerEntry.key] = cornerFrame;

      point = endPoint;
      if (cornerEntry.value.type == CommandType.rotateRight) {
        heading += cornerEntry.value.value;
      } else {
        heading -= cornerEntry.value.value;
      }
    }

    if ((point - Offset.zero).distance > 1.0e-4) {
      throw StateError(
        'Polygon walk does not close. End point: $point. '
        'Use side lengths, not Rect edge coordinates.',
      );
    }

    return _PolygonGeometry(
      sides: builtSides,
      corners: builtCorners,
      sideByKey: sideByKey,
      cornerByKey: cornerByKey,
    );
  }

  int get length => sides.length;

  List<Enum> get sideKeys =>
      sides.map((side) => side.key).toList(growable: false);

  _SideFrame sideAt(int index) => sides[index % sides.length];

  _CornerFrame cornerAfterSide(int sideIndex) => corners[sideIndex % corners.length];

  _CornerFrame cornerBeforeSide(int sideIndex) =>
      corners[(sideIndex - 1 + corners.length) % corners.length];

  Offset intersectOffsetLines(
    _SideFrame first,
    double firstSignedOffset,
    _SideFrame second,
    double secondSignedOffset,
  ) {
    final firstLine = first.offsetLine(firstSignedOffset);
    final secondLine = second.offsetLine(secondSignedOffset);
    return firstLine.intersection(secondLine);
  }

  /// Returns one vertex per corner, indexed by "corner after side i".
  List<Offset> buildContourVertices(Map<Enum, double> signedOffsets) {
    if (sides.isEmpty) {
      return const <Offset>[];
    }

    final result = <Offset>[];
    for (var i = 0; i < sides.length; i++) {
      final current = sideAt(i);
      final next = sideAt(i + 1);
      final currentOffset = signedOffsets[current.key] ?? 0.0;
      final nextOffset = signedOffsets[next.key] ?? 0.0;
      result.add(
        intersectOffsetLines(current, currentOffset, next, nextOffset),
      );
    }
    return result;
  }

  Path buildContourPath(Map<Enum, double> signedOffsets) {
    final vertices = buildContourVertices(signedOffsets);
    if (vertices.isEmpty) {
      return Path();
    }
    return Path()..addPolygon(vertices, true);
  }
}

class _SideFrame {

  final int index;
  final Enum key;
  final Offset start;
  final Offset end;

  const _SideFrame({
    required this.index,
    required this.key,
    required this.start,
    required this.end,
  });

  Offset get direction => (end - start).normalized;

  /// Polygon is traced clockwise, so the inside is the clockwise normal.
  Offset get insideNormal => direction.clockwiseNormal;

  _Line2D offsetLine(double signedOffset) {
    final origin = start + insideNormal.scaled(signedOffset);
    return _Line2D(origin, direction);
  }
}

class _CornerFrame {
  final int index;
  final Enum key;
  final Offset vertex;
  final Command command;

  const _CornerFrame({
    required this.index,
    required this.key,
    required this.vertex,
    required this.command,
  });
}

class _ResolvedSide {
  final Enum key;
  final AnySide side;
  final _SideFrame frame;

  const _ResolvedSide({
    required this.key,
    required this.side,
    required this.frame,
  });

  bool get isPainted => side.hasFill && side.width > _epsilon;
  IAnyFill get fill => side;

  double get inside => side.width * (1.0 - side.align) / 2.0;
  double get outside => side.width * (1.0 + side.align) / 2.0;
}

class _BackgroundEntry {

  final Enum key;
  final AnyBackground background;

  const _BackgroundEntry(this.key, this.background);

  IAnyFill get fill => background;
}

class _FillGroup {

  final IAnyFill fill;
  final List<Enum> orderedMembers;
  final Set<Enum> sideKeys;
  final Enum? backgroundKey;

  const _FillGroup({
    required this.fill,
    required this.orderedMembers,
    required this.sideKeys,
    required this.backgroundKey,
  });

  bool get includesBackground => backgroundKey != null;
}

class _SideRun {
  final int startIndex;
  final int length;
  final int sideCount;

  const _SideRun({
    required this.startIndex,
    required this.length,
    required this.sideCount,
  });

  int get endIndex => (startIndex + length - 1) % sideCount;

  bool get isFullCycle => length == sideCount;

  int sideIndexAt(int offset) => (startIndex + offset) % sideCount;
}

class _StrokeRegionBuilder {
  final _PolygonGeometry geometry;
  final PolygonSetup setup;
  final bool backgroundOnly;
  final AnyShapeBase? backgroundBase;

  late final Map<Enum, _ResolvedSide> _resolvedSides = _resolveSides();
  late final Map<Enum, _ResolvedSide> _activeSides = _resolveActiveSides();
  late final _BackgroundEntry? _background = _resolveBackground();

  _StrokeRegionBuilder(this.geometry, this.setup, {
    this.backgroundOnly = false,
    this.backgroundBase,
  }) {
    _validateSetup();
  }

  AnyShapeBase get _effectiveBackgroundBase =>
      backgroundBase ?? _background!.background.shapeBase;

  List<StrokeRegion> build() {

    if (backgroundOnly) {
      final background = _background;
      if (background == null) {
        return const <StrokeRegion>[];
      }

      return <StrokeRegion>[
        StrokeRegion(
          [background.key],
          background.fill,
          _buildBackgroundOnlyPath(),
        ),
      ];
    }

    final groups = _buildPaintGroups();
    return groups.map(_buildRegion).toList(growable: false);
  }

  Path _buildBackgroundOnlyPath() {
    final offsets = <Enum, double>{};

    for (final frame in geometry.sides) {
      final side = _resolvedSides[frame.key]!;

      offsets[frame.key] = switch (_effectiveBackgroundBase) {
        AnyShapeBase.zeroBorder => 0.0,
        AnyShapeBase.outerBorder => -side.outside,
        AnyShapeBase.innerBorder => side.inside,
      };
    }

    return geometry.buildContourPath(offsets);
  }

  void _validateSetup() {
    for (final key in setup.sides.keys) {
      if (!geometry.sideByKey.containsKey(key)) {
        throw ArgumentError('Unknown side key in setup.sides: $key');
      }
    }

    for (final corner in geometry.corners) {
      final resolved = setup.corners[corner.key];
      if (resolved == null) {
        throw ArgumentError('Missing corner setup for ${corner.key}.');
      }
    }
  }

  Map<Enum, _ResolvedSide> _resolveSides() {
    final result = <Enum, _ResolvedSide>{};

    for (final frame in geometry.sides) {
      final side = setup.sides[frame.key] ?? const AnySide();
      result[frame.key] = _ResolvedSide(
        key: frame.key,
        side: side,
        frame: frame,
      );
    }

    return result;
  }

  Map<Enum, _ResolvedSide> _resolveActiveSides() {
    return {
      for (final entry in _resolvedSides.entries)
        if (entry.value.isPainted) entry.key: entry.value,
    };
  }

  _BackgroundEntry? _resolveBackground() {
    if (setup.background.isEmpty) {
      return null;
    }

    final entry = setup.background.entries.single;
    return _BackgroundEntry(entry.key, entry.value);
  }

  _ResolvedSide _sideAt(int sideIndex) {
    final key = geometry.sideAt(sideIndex).key;
    return _resolvedSides[key]!;
  }

  bool _isMergedSide(Set<Enum> mergedSideKeys, int sideIndex) {
    return mergedSideKeys.contains(geometry.sideAt(sideIndex).key);
  }

  _SideRun _collectMergedRunFrom(int startIndex, Set<Enum> mergedSideKeys) {
    var length = 1;
    while (
    length < geometry.length &&
        _isMergedSide(mergedSideKeys, startIndex + length)
    ) {
      length++;
    }

    return _SideRun(
      startIndex: startIndex,
      length: length,
      sideCount: geometry.length,
    );
  }

  _SideRun _collectBackgroundSpanFrom(int startIndex, Set<Enum> mergedSideKeys) {
    var length = 1;
    while (
    length < geometry.length &&
        !_isMergedSide(mergedSideKeys, startIndex + length)
    ) {
      length++;
    }

    return _SideRun(
      startIndex: startIndex,
      length: length,
      sideCount: geometry.length,
    );
  }

  double _backgroundOffsetForSide(_ResolvedSide side) {
    if (side.isPainted) {
      // Background must share exact edge with a differently painted side.
      return side.inside;
    }

    return switch (_background!.background.shapeBase) {
      AnyShapeBase.zeroBorder => 0.0,
      AnyShapeBase.outerBorder => -side.outside,
      AnyShapeBase.innerBorder => side.inside,
    };
  }

  Offset _buildBackgroundSpanStart(
      _SideRun span,
      Set<Enum> mergedSideKeys,
      ) {
    final current = _sideAt(span.startIndex);
    final previous = _sideAt(span.startIndex - 1);
    final currentOffset = _backgroundOffsetForSide(current);

    if (!_isMergedSide(mergedSideKeys, span.startIndex - 1)) {
      return geometry.intersectOffsetLines(
        previous.frame,
        _backgroundOffsetForSide(previous),
        current.frame,
        currentOffset,
      );
    }

    return geometry.intersectOffsetLines(
      previous.frame,
      current.isPainted ? previous.inside : -previous.outside,
      current.frame,
      currentOffset,
    );
  }

  Offset _buildBackgroundSpanEnd(
      _SideRun span,
      Set<Enum> mergedSideKeys,
      ) {
    final current = _sideAt(span.endIndex);
    final next = _sideAt(span.endIndex + 1);
    final currentOffset = _backgroundOffsetForSide(current);

    if (!_isMergedSide(mergedSideKeys, span.endIndex + 1)) {
      return geometry.intersectOffsetLines(
        current.frame,
        currentOffset,
        next.frame,
        _backgroundOffsetForSide(next),
      );
    }

    return geometry.intersectOffsetLines(
      current.frame,
      currentOffset,
      next.frame,
      current.isPainted ? next.inside : -next.outside,
    );
  }

  List<Offset> _buildBackgroundSpanChain(
      _SideRun span,
      Set<Enum> mergedSideKeys,
      ) {
    final points = <Offset>[];

    _appendPoint(points, _buildBackgroundSpanStart(span, mergedSideKeys));

    for (var step = 0; step < span.length - 1; step++) {
      final current = _sideAt(span.sideIndexAt(step));
      final next = _sideAt(span.sideIndexAt(step + 1));

      _appendPoint(
        points,
        geometry.intersectOffsetLines(
          current.frame,
          _backgroundOffsetForSide(current),
          next.frame,
          _backgroundOffsetForSide(next),
        ),
      );
    }

    _appendPoint(points, _buildBackgroundSpanEnd(span, mergedSideKeys));
    return points;
  }

  List<Offset> _buildBackgroundRunTrace(
      _SideRun run,
      Set<Enum> mergedSideKeys,
      ) {
    final points = <Offset>[];
    final innerChain = _buildRunChain(run, isInner: true);
    final outerChain = _buildRunChain(run, isInner: false);

    final previousIsMerged = _isMergedSide(mergedSideKeys, run.startIndex - 1);
    final nextIsMerged = _isMergedSide(mergedSideKeys, run.endIndex + 1);

    if (!previousIsMerged) {
      final previous = _sideAt(run.startIndex - 1);
      if (previous.isPainted) {
        // Start on background inner contour, then diagonal to outer contour.
        _appendPoint(points, innerChain.first);
      }
    }

    _appendPoints(points, outerChain);

    if (!nextIsMerged) {
      final next = _sideAt(run.endIndex + 1);
      if (next.isPainted) {
        // Close the merged side against the neighbour's inner contour.
        _appendPoint(points, innerChain.last);
      }
    }

    return points;
  }

  List<_FillGroup> _buildPaintGroups() {
    final nodes = <Enum>[
      ...geometry.sideKeys.where(_activeSides.containsKey),
      if (_background != null) _background!.key,
    ];

    final adjacency = <Enum, Set<Enum>>{
      for (final node in nodes) node: <Enum>{},
    };

    for (var i = 0; i < geometry.length; i++) {
      final firstKey = geometry.sideAt(i).key;
      final secondKey = geometry.sideAt(i + 1).key;
      final firstSide = _activeSides[firstKey];
      final secondSide = _activeSides[secondKey];
      if (firstSide == null || secondSide == null) {
        continue;
      }
      if (firstSide.fill.isSameAs(secondSide.fill)) {
        adjacency[firstKey]!.add(secondKey);
        adjacency[secondKey]!.add(firstKey);
      }
    }

    if (_background != null) {
      for (final side in _activeSides.values) {
        if (side.fill.isSameAs(_background!.fill)) {
          adjacency[side.key]!.add(_background!.key);
          adjacency[_background!.key]!.add(side.key);
        }
      }
    }

    final orderedNodes = <Enum>[
      ...geometry.sideKeys.where(adjacency.containsKey),
      if (_background != null) _background!.key,
    ];

    final visited = <Enum>{};
    final groups = <_FillGroup>[];

    for (final start in orderedNodes) {
      if (!visited.add(start)) {
        continue;
      }

      final stack = <Enum>[start];
      final component = <Enum>{start};

      while (stack.isNotEmpty) {
        final node = stack.removeLast();
        for (final next in adjacency[node]!) {
          if (visited.add(next)) {
            component.add(next);
            stack.add(next);
          }
        }
      }

      final sideKeys = component.where(_activeSides.containsKey).toSet();
      final backgroundKey =
          component.contains(_background?.key) ? _background!.key : null;

      final orderedMembers = <Enum>[
        ...geometry.sideKeys.where(component.contains),
        if (backgroundKey != null) backgroundKey,
      ];

      final paint = backgroundKey != null
          ? _background!.fill
          : _activeSides[orderedMembers.first]!.fill;

      groups.add(
        _FillGroup(
          fill: paint,
          orderedMembers: orderedMembers,
          sideKeys: sideKeys,
          backgroundKey: backgroundKey,
        ),
      );
    }

    return groups;
  }

  StrokeRegion _buildRegion(_FillGroup group) {
    final path = group.includesBackground
        ? _buildBackgroundGroupPath(group)
        : (_canUseRingOptimization(group)
            ? _buildRingPath(group)
            : _buildSideOnlyPath(group.sideKeys));

    return StrokeRegion(group.orderedMembers, group.fill, path);
  }

  bool _canUseRingOptimization(_FillGroup group) {
    if (group.includesBackground) {
      return false;
    }

    if (group.sideKeys.length != geometry.length) {
      return false;
    }

    final firstPaint = _activeSides[geometry.sideAt(0).key]?.fill;
    if (firstPaint == null) {
      return false;
    }

    for (final frame in geometry.sides) {
      final resolved = _activeSides[frame.key];
      if (resolved == null ||
          !resolved.isPainted ||
          !resolved.fill.isSameAs(firstPaint)) {
        return false;
      }
    }

    if (_background == null) {
      return true;
    }

    return !_background!.fill.isSameAs(firstPaint);
  }

  Path _buildRingPath(_FillGroup group) {
    final outerOffsets = <Enum, double>{};
    final innerOffsets = <Enum, double>{};

    for (final frame in geometry.sides) {
      final side = _activeSides[frame.key]!;
      outerOffsets[frame.key] = -side.outside;
      innerOffsets[frame.key] = side.inside;
    }

    final outer = geometry.buildContourPath(outerOffsets);
    final inner = geometry.buildContourPath(innerOffsets);
    return Path.combine(PathOperation.difference, outer, inner);
  }

  Path _buildSideOnlyPath(Set<Enum> sideKeys) {
    final path = Path();

    for (final run in _collectSideRuns(sideKeys)) {
      final innerChain = _buildRunChain(run, isInner: true);
      final outerChain = _buildRunChain(run, isInner: false);

      final polygon = <Offset>[
        ...innerChain,
        ...outerChain.reversed,
      ];

      _addPolygon(path, polygon);
    }

    return path;
  }

  Path _buildBackgroundGroupPath(_FillGroup group) {
    final mergedSideKeys = group.sideKeys;

    if (mergedSideKeys.length == geometry.length) {
      final outerOffsets = <Enum, double>{};
      for (final frame in geometry.sides) {
        final side = _resolvedSides[frame.key]!;
        outerOffsets[frame.key] = -side.outside;
      }
      return geometry.buildContourPath(outerOffsets);
    }

    final startSide = List<int>.generate(geometry.length, (i) => i).firstWhere(
          (i) => !_isMergedSide(mergedSideKeys, i),
      orElse: () => 0,
    );

    final points = <Offset>[];
    var processed = 0;
    var sideIndex = startSide;

    while (processed < geometry.length) {
      if (_isMergedSide(mergedSideKeys, sideIndex)) {
        final run = _collectMergedRunFrom(sideIndex, mergedSideKeys);
        _appendPoints(points, _buildBackgroundRunTrace(run, mergedSideKeys));
        processed += run.length;
        sideIndex = (run.endIndex + 1) % geometry.length;
      } else {
        final span = _collectBackgroundSpanFrom(sideIndex, mergedSideKeys);
        _appendPoints(points, _buildBackgroundSpanChain(span, mergedSideKeys));
        processed += span.length;
        sideIndex = (span.endIndex + 1) % geometry.length;
      }
    }

    final path = Path();
    _addPolygon(path, points);
    return path;
  }

  List<_SideRun> _collectSideRuns(Set<Enum> sideKeys) {
    if (sideKeys.isEmpty) {
      return const <_SideRun>[];
    }

    final count = geometry.length;
    final included = <bool>[
      for (final frame in geometry.sides) sideKeys.contains(frame.key),
    ];

    final selectedCount = included.where((value) => value).length;
    if (selectedCount == count) {
      return <_SideRun>[
        _SideRun(startIndex: 0, length: count, sideCount: count),
      ];
    }

    final runs = <_SideRun>[];

    for (var i = 0; i < count; i++) {
      if (!included[i] || included[(i - 1 + count) % count]) {
        continue;
      }

      var length = 1;
      while (included[(i + length) % count]) {
        length++;
      }

      runs.add(
        _SideRun(
          startIndex: i,
          length: length,
          sideCount: count,
        ),
      );
    }

    return runs;
  }

  List<Offset> _buildRunChain(_SideRun run, {required bool isInner}) {
    final points = <Offset>[];

    _appendPoint(points, _buildRunStartPoint(run, isInner: isInner));

    for (var step = 0; step < run.length - 1; step++) {
      final current = _resolvedSideAt(run.sideIndexAt(step));
      final next = _resolvedSideAt(run.sideIndexAt(step + 1));

      _appendPoint(
        points,
        geometry.intersectOffsetLines(
          current.frame,
          isInner ? current.inside : -current.outside,
          next.frame,
          isInner ? next.inside : -next.outside,
        ),
      );
    }

    _appendPoint(points, _buildRunEndPoint(run, isInner: isInner));
    return points;
  }

  Offset _buildRunStartPoint(_SideRun run, {required bool isInner}) {
    final current = _resolvedSideAt(run.startIndex);
    final previous = _activeSideAt(run.startIndex - 1);

    if (previous == null) {
      return isInner
          ? current.frame.start +
              current.frame.insideNormal.scaled(current.inside)
          : current.frame.start -
              current.frame.insideNormal.scaled(current.outside);
    }

    return geometry.intersectOffsetLines(
      previous.frame,
      isInner ? previous.inside : -previous.outside,
      current.frame,
      isInner ? current.inside : -current.outside,
    );
  }

  Offset _buildRunEndPoint(_SideRun run, {required bool isInner}) {
    final current = _resolvedSideAt(run.endIndex);
    final next = _activeSideAt(run.endIndex + 1);

    if (next == null) {
      return isInner
          ? current.frame.end + current.frame.insideNormal.scaled(current.inside)
          : current.frame.end -
              current.frame.insideNormal.scaled(current.outside);
    }

    return geometry.intersectOffsetLines(
      current.frame,
      isInner ? current.inside : -current.outside,
      next.frame,
      isInner ? next.inside : -next.outside,
    );
  }

  _ResolvedSide _resolvedSideAt(int sideIndex) {
    final key = geometry.sideAt(sideIndex).key;
    return _activeSides[key]!;
  }

  _ResolvedSide? _activeSideAt(int sideIndex) {
    final key = geometry.sideAt(sideIndex).key;
    return _activeSides[key];
  }

  void _appendPoint(List<Offset> points, Offset point) {
    if (points.isEmpty || !_samePoint(points.last, point)) {
      points.add(point);
    }
  }

  void _appendPoints(List<Offset> target, Iterable<Offset> points) {
    for (final point in points) {
      _appendPoint(target, point);
    }
  }

  void _addPolygon(Path path, List<Offset> rawPoints) {
    final points = <Offset>[];
    _appendPoints(points, rawPoints);

    if (points.length >= 2 && _samePoint(points.first, points.last)) {
      points.removeLast();
    }

    if (points.length >= 3) {
      path.addPolygon(points, true);
    }
  }
}

enum ShadowAlign {
  inside,
  outside
}

class AnyShadow with MAnyFill {

  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;

  const AnyShadow({
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.blurRadius = 0.0,
    this.offset = Offset.zero,
    this.spreadRadius = 0.0,
    this.align = ShadowAlign.outside,
  });

  final double blurRadius;
  final double spreadRadius;
  final Offset offset;
  final ShadowAlign align;

  @override
  bool operator ==(Object other) {
    return other is AnyShadow &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.blurRadius == blurRadius &&
        other.offset == offset &&
        other.spreadRadius == spreadRadius &&
        other.align == align;
  }

  @override
  int get hashCode => Object.hash(color, gradient, image, blendMode, blurRadius, offset, spreadRadius, align);

}




abstract class AnyDecoration extends Decoration with MAnyFill {

  /// Polygon defines shape
  (Polygon, PolygonSetup) polygon(Rect rect, TextDirection? textDirection);

  final List<AnyShadow> shadows;

  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;

  final AnyShapeBase clip;
  final AnyShapeBase background;

  const AnyDecoration({
    this.shadows = const [],
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.clip = AnyShapeBase.zeroBorder,
    this.background = AnyShapeBase.zeroBorder,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _AnyDecorationPainter(this, onChanged);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    final (shape, setup) = polygon(rect, textDirection);
    final background = shape.buildMergedStrokeRegions(setup, backgroundOnly: true, backgroundBase: clip);
    return background.first.path.shift(rect.topLeft);
  }

}

class _AnyDecorationPainter extends BoxPainter {

  _AnyDecorationPainter(this.decoration, super.onChanged);

  final AnyDecoration decoration;
  final Map<DecorationImage, DecorationImagePainter> _imagePainters = <DecorationImage, DecorationImagePainter>{};

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    final rect = offset & size;
    final (shape, setup) = decoration.polygon(rect, configuration.textDirection);

    // _paintShadows(canvas, geometry);

    final regions = shape.buildMergedStrokeRegions(setup);
    final backgroundKey = setup.background.keys.firstOrNull;

    StrokeRegion? backgroundRegion;
    if (backgroundKey != null) {
      backgroundRegion = regions.firstWhereOrNull((r) => r.included.contains(backgroundKey));
      if (backgroundRegion != null) {
        _paintRegion(canvas, backgroundRegion, rect, configuration);
      }
    }

    for (final region in regions) {
      if (backgroundRegion == region) continue;
      _paintRegion(canvas, region, rect, configuration);
    }

  }

  // void _paintShadows(Canvas canvas, BorderGeometry geometry) {
  //   final shadows = decoration.shadows;
  //   if (shadows == null || shadows.isEmpty) return;
  //
  //   for (final rawShadow in shadows) {
  //     if (rawShadow is! AnyShadow) continue;
  //     final path = switch (rawShadow.align) {
  //       AnyAlign.inside => geometry.innerContour.toPath(),
  //       AnyAlign.center => geometry.baseContour.toPath(),
  //       AnyAlign.outside => geometry.outerContour.toPath(),
  //     };
  //     canvas.drawShadow(
  //       path.shift(rawShadow.offset),
  //       rawShadow.color,
  //       rawShadow.blurRadius + rawShadow.spreadRadius,
  //       true,
  //     );
  //   }
  // }

  void _paintRegion(
      Canvas canvas,
      StrokeRegion region,
      Rect rect,
      ImageConfiguration configuration,
      ) {
    final fill = region.fill;
    if (fill.color != null || fill.gradient != null) {
      final paint = Paint()..isAntiAlias = true;
      if (fill.blendMode != null) {
        paint.blendMode = fill.blendMode!;
      }
      if (fill.gradient != null) {
        paint.shader = fill.gradient!.createShader(rect, textDirection: configuration.textDirection);
      } else if (fill.color != null) {
        paint.color = fill.color!;
      }
      canvas.drawPath(region.path.shift(rect.topLeft), paint);
    }

    if (fill.image != null) {
      canvas.save();
      canvas.clipPath(region.path.shift(rect.topLeft));
      final painterCallback = onChanged;
      final imagePainter = _imagePainters.putIfAbsent(
        fill.image!,
            () => fill.image!.createPainter(painterCallback!),
      );
      imagePainter.paint(canvas, rect, Path()..addRect(rect), configuration);
      canvas.restore();
    }
  }
}


enum BoxSide {
  top,
  right,
  bottom,
  left,
  background,
}

enum BoxCorner {
  topRight,
  bottomRight,
  bottomLeft,
  topLeft,
}

class AnyBoxDecoration extends AnyDecoration {


  static AnySide zeroSide = const AnySide(width: 0);
  static AnyCorner cornersBase = const AnyCorner();

  final AnySide? _left;
  AnySide get left => _left ?? sides;

  final AnySide? _top;
  AnySide get top => _top ?? sides;

  final AnySide? _right;
  AnySide get right => _right ?? sides;

  final AnySide? _bottom;
  AnySide get bottom => _bottom ?? sides;

  final AnySide? _sides;
  AnySide get sides => _sides ?? zeroSide;

  final AnyCorner? _topLeft;
  AnyCorner get topLeft => _topLeft ?? corners;

  final AnyCorner? _topRight;
  AnyCorner get topRight => _topRight ?? corners;

  final AnyCorner? _bottomRight;
  AnyCorner get bottomRight => _bottomRight ?? corners;

  final AnyCorner? _bottomLeft;
  AnyCorner get bottomLeft => _bottomLeft ?? corners;

  final AnyCorner? _corners;
  AnyCorner get corners => _corners ?? cornersBase;

  const AnyBoxDecoration({
    super.shadows,
    super.color,
    super.gradient,
    super.image,
    super.blendMode,
    super.clip,
    super.background,
    AnySide? left,
    AnySide? top,
    AnySide? right,
    AnySide? bottom,
    AnySide? sides,
    AnyCorner? topLeft,
    AnyCorner? topRight,
    AnyCorner? bottomRight,
    AnyCorner? bottomLeft,
    AnyCorner? corners,
  }) :
        _corners = corners,
        _sides = sides,
        _left = left,
        _top = top,
        _right = right,
        _bottom = bottom,
        _topLeft = topLeft,
        _topRight = topRight,
        _bottomRight = bottomRight,
        _bottomLeft = bottomLeft;

  @override
  (Polygon, PolygonSetup) polygon(Rect rect, TextDirection? textDirection) {

    const d90 = pi / 2.0;
    final polygon = Polygon({
      BoxSide.top: Command(CommandType.line, rect.width),
      BoxCorner.topRight: const Command(CommandType.rotateRight, d90),
      BoxSide.right: Command(CommandType.line, rect.height),
      BoxCorner.bottomRight: const Command(CommandType.rotateRight, d90),
      BoxSide.bottom: Command(CommandType.line, rect.width),
      BoxCorner.bottomLeft: const Command(CommandType.rotateRight, d90),
      BoxSide.left: Command(CommandType.line, rect.height),
      BoxCorner.topLeft: const Command(CommandType.rotateRight, d90),
    });

    return (polygon, PolygonSetup(
      corners: {
        BoxCorner.topLeft: topLeft,
        BoxCorner.topRight: topRight,
        BoxCorner.bottomRight: bottomRight,
        BoxCorner.bottomLeft: bottomLeft,
      },
      sides: {
        BoxSide.left : left,
        BoxSide.top : top,
        BoxSide.right : right,
        BoxSide.bottom : bottom,
      },
      background: {
        BoxSide.background : AnyBackground(color: color, gradient: gradient, image: image, blendMode: blendMode, shapeBase: background)
      }
    ));
  }

}



class AnySideBuilder {

  double width = 0.0;
  double align = AnySide.alignCenter;

  Color? color;
  Gradient? gradient;
  DecorationImage? image;
  BlendMode? blendMode;

  AnySideBuilder();

  bool get isEmpty =>
      width.abs() <= 0.00001 &&
          color == null &&
          gradient == null &&
          image == null;

  AnySide? buildOrNull() {
    if (isEmpty) return null;

    return AnySide(
      width: width,
      align: align,
      color: color,
      gradient: gradient,
      image: image,
      blendMode: blendMode,
    );
  }
}


class AnyDecorationBuilder {

  final AnySideBuilder left = AnySideBuilder();
  final AnySideBuilder top = AnySideBuilder();
  final AnySideBuilder right = AnySideBuilder();
  final AnySideBuilder bottom = AnySideBuilder();
  final AnySideBuilder sides = AnySideBuilder();

  List<AnyShadow> shadows = [];

  Color? color;
  Gradient? gradient;
  DecorationImage? image;
  BlendMode? blendMode;

  AnyShapeBase? clip;
  AnyShapeBase? background;

  AnyDecorationBuilder();

  AnyDecoration build() {
    return AnyBoxDecoration(
      left: left.buildOrNull(),
      top: top.buildOrNull(),
      right: right.buildOrNull(),
      bottom: bottom.buildOrNull(),
      sides: sides.buildOrNull(),
      shadows: shadows,
      color: color,
      gradient: gradient,
      image: image,
      blendMode: blendMode,
      clip: clip ?? AnyShapeBase.zeroBorder,
      background: background ?? AnyShapeBase.zeroBorder,
    );
  }
}


class Change {
  final String name;
  final void Function(AnyDecorationBuilder) change;
  const Change(this.name, this.change);
}

class ChangeGroup {
  final String name;
  final List<Change> changes;
  const ChangeGroup(this.name, this.changes);
}

class ExampleGenerator  {

  static const groupSeparator = ' ';
  static const changeSeparator = '-';

  final List<ChangeGroup> groups;
  const ExampleGenerator(this.groups);

  Iterable<(String, List<Change>)> changes() sync* {
    if (groups.isEmpty) return;

    // Group ChangeGroups by their name, preserving first appearance order.
    final orderedNames = <String>[];
    final grouped = <String, List<ChangeGroup>>{};

    for (final group in groups) {
      final bucket = grouped[group.name];
      if (bucket == null) {
        orderedNames.add(group.name);
        grouped[group.name] = [group];
      } else {
        bucket.add(group);
      }
    }

    // For each unique group name, build all combinations across all groups
    // sharing that name.
    final perNamedGroup = <List<(String, List<Change>)>>[];

    for (final groupName in orderedNames) {
      final sameNameGroups = grouped[groupName]!;

      List<(String, List<Change>)> combinations = [('', <Change>[])];

      for (final group in sameNameGroups) {
        final next = <(String, List<Change>)>[];

        for (final current in combinations) {
          for (final change in group.changes) {
            final currentName = current.$1;
            final nextName = currentName.isEmpty
                ? change.name
                : '$currentName$changeSeparator${change.name}';

            next.add((
            nextName,
            [...current.$2, change],
            ));
          }
        }

        combinations = next;
      }

      perNamedGroup.add([
        for (final combo in combinations)
          (
          combo.$1.isEmpty
              ? groupName
              : groupName.isEmpty
              ? combo.$1
              : '$groupName$changeSeparator${combo.$1}',
          combo.$2,
          ),
      ]);
    }

    // Cross join across unique named groups.
    List<(String, List<Change>)> result = [('', <Change>[])];

    for (final namedGroupVariants in perNamedGroup) {
      final next = <(String, List<Change>)>[];

      for (final current in result) {
        for (final variant in namedGroupVariants) {
          final currentName = current.$1;
          final variantName = variant.$1;

          final nextName = currentName.isEmpty
              ? variantName
              : variantName.isEmpty
              ? currentName
              : '$currentName$groupSeparator$variantName';

          next.add((
          nextName,
          [...current.$2, ...variant.$2],
          ));
        }
      }

      result = next;
    }

    yield* result;
  }

  List<(String,AnyDecoration)> build() {

    List<(String,AnyDecoration)> result = [];

    for (var (name, changes) in changes()) {
      AnyDecorationBuilder builder = AnyDecorationBuilder();
      for (var change in changes) {
        change.change(builder);
      }

      final decoration = builder.build();
      result.add((name, decoration));
    }

    debugPrint('Built ${result.length} examples');

    return result;
  }
}