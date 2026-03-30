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
const double _arcSampleStep = 6.0;
const int _minArcSamples = 4;
const int _maxArcSamples = 48;

bool _nearZero(double value, [double epsilon = _epsilon]) =>
    value.abs() <= epsilon;

double _clampDouble(double value, double minValue, double maxValue) {
  if (value < minValue) return minValue;
  if (value > maxValue) return maxValue;
  return value;
}

double _lerpDouble(double a, double b, double t) => a + ((b - a) * t);

bool _samePoint(Offset a, Offset b, [double epsilon = _epsilon]) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return (dx * dx) + (dy * dy) <= epsilon * epsilon;
}

extension _OffsetMath on Offset {
  Offset scaled(double value) => Offset(dx * value, dy * value);

  double cross(Offset other) => (dx * other.dy) - (dy * other.dx);

  double dot(Offset other) => (dx * other.dx) + (dy * other.dy);

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

  const AnyBackground({
    super.color,
    super.gradient,
    super.image,
    super.blendMode,
    this.shapeBase = AnyShapeBase.zeroBorder,
  }) : super(width: double.infinity, align: AnySide.alignCenter);
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

  _CornerFrame cornerAfterSide(int sideIndex) =>
      corners[sideIndex % corners.length];

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

  double get length => (end - start).distance;

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

class _ResolvedCornerRadii {
  final Map<Enum, double> beforeByKey;
  final Map<Enum, double> afterByKey;

  const _ResolvedCornerRadii({
    required this.beforeByKey,
    required this.afterByKey,
  });

  factory _ResolvedCornerRadii.resolve(
      _PolygonGeometry geometry,
      PolygonSetup setup,
      ) {
    final rawBefore = <Enum, double>{};
    final rawAfter = <Enum, double>{};

    for (final cornerFrame in geometry.corners) {
      final corner = setup.corners[cornerFrame.key]!;
      rawBefore[cornerFrame.key] = corner.radius.x;
      rawAfter[cornerFrame.key] = corner.radius.y;
    }

    final normalizedBefore = <Enum, double>{...rawBefore};
    final normalizedAfter = <Enum, double>{...rawAfter};

    for (final side in geometry.sides) {
      final startCorner = geometry.cornerBeforeSide(side.index);
      final endCorner = geometry.cornerAfterSide(side.index);

      final startTurn = startCorner.command.value.abs();
      final endTurn = endCorner.command.value.abs();
      final startSin = sin(startTurn).abs();
      final endSin = sin(endTurn).abs();

      if (_nearZero(startSin) || _nearZero(endSin)) {
        continue;
      }

      // The corner radius semantics are:
      // - radius.x -> distance to the side before the corner.
      // - radius.y -> distance to the side after the corner.
      //
      // So on a side segment S:
      // - the corner before S consumes its `radius.y`,
      // - the corner after S consumes its `radius.x`.
      final startConsumption = normalizedAfter[startCorner.key]!.abs() / startSin;
      final endConsumption = normalizedBefore[endCorner.key]!.abs() / endSin;
      final totalConsumption = startConsumption + endConsumption;

      if (totalConsumption <= side.length + _epsilon || _nearZero(totalConsumption)) {
        continue;
      }

      final scale = side.length / totalConsumption;
      normalizedAfter[startCorner.key] = normalizedAfter[startCorner.key]! * scale;
      normalizedBefore[endCorner.key] = normalizedBefore[endCorner.key]! * scale;
    }

    return _ResolvedCornerRadii(
      beforeByKey: normalizedBefore,
      afterByKey: normalizedAfter,
    );
  }

  double beforeOf(Enum key) => beforeByKey[key] ?? 0.0;

  double afterOf(Enum key) => afterByKey[key] ?? 0.0;
}

class _ConicArcSegment {
  final Offset start;
  final Offset control;
  final Offset end;
  final double weight;

  const _ConicArcSegment({
    required this.start,
    required this.control,
    required this.end,
    required this.weight,
  });

  void appendTo(Path path) {
    path.conicTo(control.dx, control.dy, end.dx, end.dy, weight);
  }
}

class _ResolvedCorner {
  final Enum key;
  final AnyCorner corner;
  final _CornerFrame frame;
  final _SideFrame previousSide;
  final _SideFrame nextSide;
  final double beforeRadius;
  final double afterRadius;

  const _ResolvedCorner({
    required this.key,
    required this.corner,
    required this.frame,
    required this.previousSide,
    required this.nextSide,
    required this.beforeRadius,
    required this.afterRadius,
  });

  bool get isSharp =>
      _nearZero(beforeRadius) || _nearZero(afterRadius) || curvatureSign == 0;

  bool get isInnerRounded => beforeRadius > _epsilon && afterRadius > _epsilon;

  bool get isOuterRounded => beforeRadius < -_epsilon && afterRadius < -_epsilon;

  int get curvatureSign => isInnerRounded
      ? 1
      : isOuterRounded
      ? -1
      : 0;

  int get mode => curvatureSign;

  double get beforeAbs => beforeRadius.abs();

  double get afterAbs => afterRadius.abs();

  double get turnAngle => frame.command.value.abs();

  double get sinTurn => sin(turnAngle).abs();

  bool get isParallel => sinTurn <= _epsilon;

  bool get hasExactQuarterConic => !isSharp && !isParallel;

  Offset get vertex => frame.vertex;

  Offset get previousNormal => previousSide.insideNormal;

  Offset get nextNormal => nextSide.insideNormal;

  double get consumedOnPreviousSide => isParallel ? double.infinity : afterAbs / sinTurn;

  double get consumedOnNextSide => isParallel ? double.infinity : beforeAbs / sinTurn;

  _CornerPrimitive primitive({
    required double previousOffset,
    required double nextOffset,
  }) {
    return _CornerPrimitive(
      corner: this,
      previousOffset: previousOffset,
      nextOffset: nextOffset,
    );
  }
}

/// Exact quarter-conic representation of one resolved corner for a specific
/// pair of adjacent side offsets.
///
/// Local coordinates are signed perpendicular distances to the previous and
/// next side. The corner curve is represented exactly as a rational quadratic,
/// so later tracing code can use [Path.conicTo] without sampling.
class _CornerPrimitive {
  static const double startAngle = pi;
  static const double endAngle = 1.5 * pi;

  final _ResolvedCorner corner;
  final double previousOffset;
  final double nextOffset;

  const _CornerPrimitive({
    required this.corner,
    required this.previousOffset,
    required this.nextOffset,
  });

  bool get isSharp => corner.isSharp;

  bool get isParallel => corner.isParallel;

  bool get canBuildExactConic => corner.hasExactQuarterConic;

  int get curvatureSign => corner.curvatureSign;

  double get beforeRadius => corner.beforeAbs;

  double get afterRadius => corner.afterAbs;

  Offset get localCenter => Offset(
    previousOffset + (curvatureSign * beforeRadius),
    nextOffset + (curvatureSign * afterRadius),
  );

  double angleAt(double t) => _lerpDouble(startAngle, endAngle, t);

  Offset localPointAtAngle(double angle) {
    if (!canBuildExactConic) {
      throw StateError(
        'Corner ${corner.key} does not support exact conic construction.',
      );
    }

    final center = localCenter;
    return Offset(
      center.dx + (curvatureSign * beforeRadius * cos(angle)),
      center.dy + (curvatureSign * afterRadius * sin(angle)),
    );
  }

  Offset worldPointAtAngle(double angle) {
    final local = localPointAtAngle(angle);
    return mapDistancesToWorld(local.dx, local.dy);
  }

  Offset tangentOnPreviousSide() => worldPointAtAngle(startAngle);

  Offset tangentOnNextSide() => worldPointAtAngle(endAngle);

  Offset mapDistancesToWorld(double previousDistance, double nextDistance) {
    final a = corner.previousNormal.dx;
    final b = corner.previousNormal.dy;
    final c = corner.nextNormal.dx;
    final d = corner.nextNormal.dy;

    final determinant = (a * d) - (b * c);
    if (_nearZero(determinant)) {
      throw StateError(
        'Corner ${corner.key} uses parallel adjacent sides and has no unique local-to-world mapping.',
      );
    }

    final x = ((d * previousDistance) - (b * nextDistance)) / determinant;
    final y = ((-c * previousDistance) + (a * nextDistance)) / determinant;
    return corner.vertex + Offset(x, y);
  }

  _ConicArcSegment conicSegment({
    required double fromAngle,
    required double toAngle,
  }) {
    if (!canBuildExactConic) {
      throw StateError(
        'Corner ${corner.key} does not support exact conic construction.',
      );
    }

    final delta = toAngle - fromAngle;
    if (_nearZero(delta)) {
      final point = worldPointAtAngle(fromAngle);
      return _ConicArcSegment(
        start: point,
        control: point,
        end: point,
        weight: 1.0,
      );
    }

    if (delta.abs() >= pi - _epsilon) {
      throw ArgumentError(
        'Exact rational quadratic segments must span less than π radians. '
            'Split larger corner spans before emitting conics.',
      );
    }

    final middleAngle = (fromAngle + toAngle) / 2.0;
    final weight = cos(delta / 2.0);
    if (weight <= _epsilon) {
      throw StateError(
        'Corner ${corner.key} produced a non-positive conic weight.',
      );
    }

    final startLocal = localPointAtAngle(fromAngle);
    final endLocal = localPointAtAngle(toAngle);
    final center = localCenter;
    final controlLocal = Offset(
      center.dx + (curvatureSign * beforeRadius * cos(middleAngle) / weight),
      center.dy + (curvatureSign * afterRadius * sin(middleAngle) / weight),
    );

    return _ConicArcSegment(
      start: mapDistancesToWorld(startLocal.dx, startLocal.dy),
      control: mapDistancesToWorld(controlLocal.dx, controlLocal.dy),
      end: mapDistancesToWorld(endLocal.dx, endLocal.dy),
      weight: weight,
    );
  }

  _ConicArcSegment fullQuarterSegment() =>
      conicSegment(fromAngle: startAngle, toAngle: endAngle);

  void appendConic(
      Path path, {
        required double fromAngle,
        required double toAngle,
      }) {
    final segment = conicSegment(fromAngle: fromAngle, toAngle: toAngle);
    segment.appendTo(path);
  }
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

enum _CornerSlice {
  full,
  prevToSplit,
  splitToNext,
}

class _StrokeRegionBuilder {
  final _PolygonGeometry geometry;
  final PolygonSetup setup;
  final bool backgroundOnly;
  final AnyShapeBase? backgroundBase;

  late final Map<Enum, _ResolvedSide> _resolvedSides = _resolveSides();
  late final Map<Enum, _ResolvedSide> _activeSides = _resolveActiveSides();
  late final Map<Enum, _ResolvedCorner> _resolvedCorners = _resolveCorners();
  late final _BackgroundEntry? _background = _resolveBackground();

  _StrokeRegionBuilder(
      this.geometry,
      this.setup, {
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
          _pathFromClosedPoints(_buildBackgroundOnlyPoints()),
        ),
      ];
    }

    final groups = _buildPaintGroups();
    return groups.map(_buildRegion).toList(growable: false);
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
      final rx = resolved.radius.x;
      final ry = resolved.radius.y;
      final sameSign =
          (_nearZero(rx) && _nearZero(ry)) || (rx.sign == ry.sign && !_nearZero(rx) && !_nearZero(ry));
      if (!sameSign) {
        throw ArgumentError(
          'Corner ${corner.key} must use Radius.zero, both positive values, or both negative values.',
        );
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

  Map<Enum, _ResolvedCorner> _resolveCorners() {
    final normalizedRadii = _ResolvedCornerRadii.resolve(geometry, setup);
    final result = <Enum, _ResolvedCorner>{};

    for (final cornerFrame in geometry.corners) {
      final previousSide = geometry.sideAt(cornerFrame.index);
      final nextSide = geometry.sideAt(cornerFrame.index + 1);
      result[cornerFrame.key] = _ResolvedCorner(
        key: cornerFrame.key,
        corner: setup.corners[cornerFrame.key]!,
        frame: cornerFrame,
        previousSide: previousSide,
        nextSide: nextSide,
        beforeRadius: normalizedRadii.beforeOf(cornerFrame.key),
        afterRadius: normalizedRadii.afterOf(cornerFrame.key),
      );
    }

    return result;
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

  _ResolvedCorner _cornerAfter(int prevSideIndex) {
    final key = geometry.cornerAfterSide(prevSideIndex).key;
    return _resolvedCorners[key]!;
  }

  bool _isMergedSide(Set<Enum> mergedSideKeys, int sideIndex) {
    return mergedSideKeys.contains(geometry.sideAt(sideIndex).key);
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

    final outerPoints = _buildClosedContourPoints(outerOffsets);
    final innerPoints = _buildClosedContourPoints(innerOffsets);

    final path = Path()..fillType = PathFillType.evenOdd;
    _addClosedPolyline(path, outerPoints);
    _addClosedPolyline(path, innerPoints.reversed.toList(growable: false));
    return path;
  }

  Path _buildSideOnlyPath(Set<Enum> sideKeys) {
    final path = Path();

    for (final run in _collectSideRuns(sideKeys)) {
      final polygon = _buildSideRunPolygon(run);
      _addClosedPolyline(path, polygon);
    }

    return path;
  }

  Path _buildBackgroundGroupPath(_FillGroup group) {
    final mergedSideKeys = group.sideKeys;

    if (mergedSideKeys.length == geometry.length) {
      final offsets = <Enum, double>{};
      for (final frame in geometry.sides) {
        offsets[frame.key] = -_resolvedSides[frame.key]!.outside;
      }
      return _pathFromClosedPoints(_buildClosedContourPoints(offsets));
    }

    final points = _buildBackgroundGroupPoints(mergedSideKeys);
    return _pathFromClosedPoints(points);
  }

  List<Offset> _buildBackgroundOnlyPoints() {
    final offsets = <Enum, double>{};

    for (final frame in geometry.sides) {
      final side = _resolvedSides[frame.key]!;
      offsets[frame.key] = switch (_effectiveBackgroundBase) {
        AnyShapeBase.zeroBorder => 0.0,
        AnyShapeBase.outerBorder => -side.outside,
        AnyShapeBase.innerBorder => side.inside,
      };
    }

    return _buildClosedContourPoints(offsets);
  }

  double _backgroundOffsetForSide(_ResolvedSide side) {
    if (side.isPainted) {
      // Background must share exact edge with a differently painted side.
      return side.inside;
    }

    return switch (_effectiveBackgroundBase) {
      AnyShapeBase.zeroBorder => 0.0,
      AnyShapeBase.outerBorder => -side.outside,
      AnyShapeBase.innerBorder => side.inside,
    };
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

  List<Offset> _buildSideRunPolygon(_SideRun run) {
    final startCap = _buildRunStartCap(run);
    final endCap = _buildRunEndCap(run);

    final points = <Offset>[];
    _appendPoints(points, startCap);

    // Outer boundary.
    for (var step = 0; step < run.length; step++) {
      final sideIndex = run.sideIndexAt(step);
      if (step == run.length - 1) {
        _appendPoint(points, endCap.first);
        continue;
      }

      final current = _resolvedSideAt(sideIndex);
      final next = _resolvedSideAt(sideIndex + 1);
      final fragment = _buildCornerContourSlice(
        sideIndex,
        oPrev: -current.outside,
        oNext: -next.outside,
        slice: _CornerSlice.full,
      );
      _appendPoints(points, fragment);
    }

    _appendPoints(points, endCap.skip(1));

    // Inner boundary in reverse.
    for (var step = run.length - 1; step >= 0; step--) {
      final sideIndex = run.sideIndexAt(step);
      if (step == 0) {
        _appendPoint(points, startCap.first);
        continue;
      }

      final previous = _resolvedSideAt(sideIndex - 1);
      final current = _resolvedSideAt(sideIndex);
      final fragment = _buildCornerContourSlice(
        sideIndex - 1,
        oPrev: previous.inside,
        oNext: current.inside,
        slice: _CornerSlice.full,
      ).reversed;
      _appendPoints(points, fragment);
    }

    return points;
  }

  List<Offset> _buildRunStartCap(_SideRun run) {
    final previous = _sideAt(run.startIndex - 1);
    final current = _resolvedSideAt(run.startIndex);
    final cornerIndex = run.startIndex - 1;

    final inner = _buildCornerContourSlice(
      cornerIndex,
      oPrev: previous.inside,
      oNext: current.inside,
      slice: _CornerSlice.splitToNext,
    ).reversed.toList(growable: false);

    final connector =
    _buildCornerSplitConnector(cornerIndex, outerToInner: false);

    final outer = _buildCornerContourSlice(
      cornerIndex,
      oPrev: -previous.outside,
      oNext: -current.outside,
      slice: _CornerSlice.splitToNext,
    );

    final points = <Offset>[];
    _appendPoints(points, inner);
    _appendPoints(points, connector.skip(1));
    _appendPoints(points, outer.skip(1));
    return points;
  }

  List<Offset> _buildRunEndCap(_SideRun run) {
    final current = _resolvedSideAt(run.endIndex);
    final next = _sideAt(run.endIndex + 1);
    final cornerIndex = run.endIndex;

    final outer = _buildCornerContourSlice(
      cornerIndex,
      oPrev: -current.outside,
      oNext: -next.outside,
      slice: _CornerSlice.prevToSplit,
    );

    final connector =
    _buildCornerSplitConnector(cornerIndex, outerToInner: true);

    final inner = _buildCornerContourSlice(
      cornerIndex,
      oPrev: current.inside,
      oNext: next.inside,
      slice: _CornerSlice.prevToSplit,
    ).reversed.toList(growable: false);

    final points = <Offset>[];
    _appendPoints(points, outer);
    _appendPoints(points, connector.skip(1));
    _appendPoints(points, inner.skip(1));
    return points;
  }

  List<Offset> _buildBackgroundGroupPoints(Set<Enum> mergedSideKeys) {
    final fragments = <List<Offset>>[];

    for (var i = 0; i < geometry.length; i++) {
      fragments.add(_buildBackgroundCornerFragment(i, mergedSideKeys));
    }

    final points = <Offset>[];
    _appendPoint(points, fragments.last.last);
    for (final fragment in fragments) {
      _appendPoints(points, fragment);
    }
    return points;
  }

  List<Offset> _buildBackgroundCornerFragment(
      int prevSideIndex,
      Set<Enum> mergedSideKeys,
      ) {
    final current = _sideAt(prevSideIndex);
    final next = _sideAt(prevSideIndex + 1);
    final currentMerged = _isMergedSide(mergedSideKeys, prevSideIndex);
    final nextMerged = _isMergedSide(mergedSideKeys, prevSideIndex + 1);

    if (currentMerged && !nextMerged && next.isPainted) {
      final outerPart = _buildCornerContourSlice(
        prevSideIndex,
        oPrev: -current.outside,
        oNext: -next.outside,
        slice: _CornerSlice.prevToSplit,
      );
      final connector =
      _buildCornerSplitConnector(prevSideIndex, outerToInner: true);
      final innerPart = _buildCornerContourSlice(
        prevSideIndex,
        oPrev: current.inside,
        oNext: next.inside,
        slice: _CornerSlice.splitToNext,
      );

      final points = <Offset>[];
      _appendPoints(points, outerPart);
      _appendPoints(points, connector.skip(1));
      _appendPoints(points, innerPart.skip(1));
      return points;
    }

    if (!currentMerged && current.isPainted && nextMerged) {
      final innerPart = _buildCornerContourSlice(
        prevSideIndex,
        oPrev: current.inside,
        oNext: next.inside,
        slice: _CornerSlice.prevToSplit,
      );
      final connector =
      _buildCornerSplitConnector(prevSideIndex, outerToInner: false);
      final outerPart = _buildCornerContourSlice(
        prevSideIndex,
        oPrev: -current.outside,
        oNext: -next.outside,
        slice: _CornerSlice.splitToNext,
      );

      final points = <Offset>[];
      _appendPoints(points, innerPart);
      _appendPoints(points, connector.skip(1));
      _appendPoints(points, outerPart.skip(1));
      return points;
    }

    final currentOffset = currentMerged ? -current.outside : _backgroundOffsetForSide(current);
    final nextOffset = nextMerged ? -next.outside : _backgroundOffsetForSide(next);

    return _buildCornerContourSlice(
      prevSideIndex,
      oPrev: currentOffset,
      oNext: nextOffset,
      slice: _CornerSlice.full,
    );
  }

  List<Offset> _buildClosedContourPoints(Map<Enum, double> offsets) {
    if (geometry.length == 0) {
      return const <Offset>[];
    }

    final fragments = <List<Offset>>[];
    for (var i = 0; i < geometry.length; i++) {
      final current = _sideAt(i);
      final next = _sideAt(i + 1);
      fragments.add(
        _buildCornerContourSlice(
          i,
          oPrev: offsets[current.key] ?? 0.0,
          oNext: offsets[next.key] ?? 0.0,
          slice: _CornerSlice.full,
        ),
      );
    }

    final points = <Offset>[];
    _appendPoint(points, fragments.last.last);
    for (final fragment in fragments) {
      _appendPoints(points, fragment);
    }
    return points;
  }

  List<Offset> _buildCornerSplitConnector(
      int prevSideIndex, {
        required bool outerToInner,
      }) {
    final previous = _sideAt(prevSideIndex);
    final next = _sideAt(prevSideIndex + 1);
    final corner = _cornerAfter(prevSideIndex);

    final samples = _connectorSampleCount(previous, next, corner);
    final points = <Offset>[];

    for (var i = 0; i <= samples; i++) {
      final rawT = i / samples;
      final t = outerToInner ? rawT : (1.0 - rawT);

      final oPrev = _lerpDouble(-previous.outside, previous.inside, t);
      final oNext = _lerpDouble(-next.outside, next.inside, t);
      final point = _buildCornerSplitPoint(prevSideIndex, oPrev, oNext);
      _appendPoint(points, point);
    }

    return points;
  }

  Offset _buildCornerSplitPoint(int prevSideIndex, double oPrev, double oNext) {
    final dPoint = _buildCornerSplitPointInDistanceSpace(prevSideIndex, oPrev, oNext);
    final corner = _cornerAfter(prevSideIndex);
    return _pointFromDistanceCoordinates(corner, dPoint.dx, dPoint.dy);
  }

  Offset _buildCornerSplitPointInDistanceSpace(
      int prevSideIndex,
      double oPrev,
      double oNext,
      ) {
    final corner = _cornerAfter(prevSideIndex);
    if (!_cornerCanRound(corner, oPrev, oNext)) {
      return Offset(oPrev, oNext);
    }

    final previous = _sideAt(prevSideIndex);
    final next = _sideAt(prevSideIndex + 1);

    final lineStart = Offset(-previous.outside, -next.outside);
    final lineEnd = Offset(previous.inside, next.inside);
    final direction = lineEnd - lineStart;
    if (_nearZero(direction.distance)) {
      return Offset(oPrev, oNext);
    }

    final s = corner.mode.toDouble();
    final a = corner.beforeAbs;
    final b = corner.afterAbs;
    final rx = a - (s * oPrev);
    final ry = b - (s * oNext);

    if (rx <= _epsilon || ry <= _epsilon) {
      return Offset(oPrev, oNext);
    }

    final x0 = lineStart.dx - (s * a);
    final y0 = lineStart.dy - (s * b);
    final ux = direction.dx;
    final uy = direction.dy;

    final qa = ((ux * ux) / (rx * rx)) + ((uy * uy) / (ry * ry));
    final qb = 2.0 * (((x0 * ux) / (rx * rx)) + ((y0 * uy) / (ry * ry)));
    final qc = ((x0 * x0) / (rx * rx)) + ((y0 * y0) / (ry * ry)) - 1.0;

    final discriminant = max(0.0, (qb * qb) - (4.0 * qa * qc));
    if (_nearZero(qa)) {
      return Offset(oPrev, oNext);
    }

    final sqrtDisc = sqrt(discriminant);
    final roots = <double>[
      (-qb - sqrtDisc) / (2.0 * qa),
      (-qb + sqrtDisc) / (2.0 * qa),
    ];

    final expectedT = _expectedInterpolationT(previous, next, oPrev, oNext);
    double? chosenRoot;
    double chosenScore = double.infinity;

    for (final root in roots) {
      if (root < -0.0001 || root > 1.0001) {
        continue;
      }

      final candidate = lineStart + direction.scaled(root);
      final phi = _contourPhiForDistancePoint(corner, oPrev, oNext, candidate);
      if (phi == null) {
        continue;
      }

      final range = _fullCornerPhiRange(corner);
      if (phi < range.$1 - 0.0001 || phi > range.$2 + 0.0001) {
        continue;
      }

      final score = (root - expectedT).abs();
      if (score < chosenScore) {
        chosenScore = score;
        chosenRoot = root;
      }
    }

    if (chosenRoot == null) {
      return Offset(oPrev, oNext);
    }

    return lineStart + direction.scaled(chosenRoot);
  }

  double _expectedInterpolationT(
      _ResolvedSide previous,
      _ResolvedSide next,
      double oPrev,
      double oNext,
      ) {
    final prevDenominator = previous.inside + previous.outside;
    if (!_nearZero(prevDenominator)) {
      return _clampDouble((oPrev + previous.outside) / prevDenominator, 0.0, 1.0);
    }

    final nextDenominator = next.inside + next.outside;
    if (!_nearZero(nextDenominator)) {
      return _clampDouble((oNext + next.outside) / nextDenominator, 0.0, 1.0);
    }

    return 0.5;
  }

  List<Offset> _buildCornerContourSlice(
      int prevSideIndex, {
        required double oPrev,
        required double oNext,
        required _CornerSlice slice,
      }) {
    final corner = _cornerAfter(prevSideIndex);

    if (!_cornerCanRound(corner, oPrev, oNext)) {
      return <Offset>[
        _pointFromDistanceCoordinates(corner, oPrev, oNext),
      ];
    }

    final startEnd = switch (slice) {
      _CornerSlice.full => _fullCornerPhiRange(corner),
      _CornerSlice.prevToSplit => (
      _fullCornerPhiRange(corner).$1,
      _splitPhi(prevSideIndex, oPrev, oNext),
      ),
      _CornerSlice.splitToNext => (
      _splitPhi(prevSideIndex, oPrev, oNext),
      _fullCornerPhiRange(corner).$2,
      ),
    };

    return _sampleCornerArc(
      prevSideIndex,
      oPrev: oPrev,
      oNext: oNext,
      phiStart: startEnd.$1,
      phiEnd: startEnd.$2,
    );
  }

  double _splitPhi(int prevSideIndex, double oPrev, double oNext) {
    final corner = _cornerAfter(prevSideIndex);
    final dPoint = _buildCornerSplitPointInDistanceSpace(prevSideIndex, oPrev, oNext);
    final phi = _contourPhiForDistancePoint(corner, oPrev, oNext, dPoint);
    if (phi == null) {
      return _fullCornerPhiRange(corner).$1;
    }
    return phi;
  }

  (double, double) _fullCornerPhiRange(_ResolvedCorner corner) {
    return corner.mode == 1 ? (pi, 1.5 * pi) : (0.0, 0.5 * pi);
  }

  bool _cornerCanRound(_ResolvedCorner corner, double oPrev, double oNext) {
    if (corner.mode == 0 || corner.isParallel) {
      return false;
    }

    final s = corner.mode.toDouble();
    final rx = corner.beforeAbs - (s * oPrev);
    final ry = corner.afterAbs - (s * oNext);
    return rx > _epsilon && ry > _epsilon;
  }

  double? _contourPhiForDistancePoint(
      _ResolvedCorner corner,
      double oPrev,
      double oNext,
      Offset dPoint,
      ) {
    if (!_cornerCanRound(corner, oPrev, oNext)) {
      return null;
    }

    final s = corner.mode.toDouble();
    final rx = corner.beforeAbs - (s * oPrev);
    final ry = corner.afterAbs - (s * oNext);
    if (rx <= _epsilon || ry <= _epsilon) {
      return null;
    }

    final cosValue = _clampDouble((dPoint.dx - (s * corner.beforeAbs)) / rx, -1.0, 1.0);
    final sinValue = _clampDouble((dPoint.dy - (s * corner.afterAbs)) / ry, -1.0, 1.0);

    var phi = atan2(sinValue, cosValue);
    if (phi < 0.0) {
      phi += 2 * pi;
    }
    if (corner.mode == 1 && phi < pi) {
      phi += 2 * pi;
    }
    return phi;
  }

  List<Offset> _sampleCornerArc(
      int prevSideIndex, {
        required double oPrev,
        required double oNext,
        required double phiStart,
        required double phiEnd,
      }) {
    final corner = _cornerAfter(prevSideIndex);
    if (!_cornerCanRound(corner, oPrev, oNext)) {
      return <Offset>[
        _pointFromDistanceCoordinates(corner, oPrev, oNext),
      ];
    }

    if ((phiEnd - phiStart).abs() <= _epsilon) {
      return <Offset>[
        _pointFromDistanceCoordinates(
          corner,
          _distancePointOnCornerArc(corner, oPrev, oNext, phiEnd).dx,
          _distancePointOnCornerArc(corner, oPrev, oNext, phiEnd).dy,
        ),
      ];
    }

    final samples = _arcSampleCount(corner, oPrev, oNext, (phiEnd - phiStart).abs());
    final points = <Offset>[];

    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final phi = _lerpDouble(phiStart, phiEnd, t);
      final dPoint = _distancePointOnCornerArc(corner, oPrev, oNext, phi);
      final point = _pointFromDistanceCoordinates(corner, dPoint.dx, dPoint.dy);
      _appendPoint(points, point);
    }

    return points;
  }

  Offset _distancePointOnCornerArc(
      _ResolvedCorner corner,
      double oPrev,
      double oNext,
      double phi,
      ) {
    final s = corner.mode.toDouble();
    final rx = corner.beforeAbs - (s * oPrev);
    final ry = corner.afterAbs - (s * oNext);
    return Offset(
      (s * corner.beforeAbs) + (rx * cos(phi)),
      (s * corner.afterAbs) + (ry * sin(phi)),
    );
  }

  int _arcSampleCount(
      _ResolvedCorner corner,
      double oPrev,
      double oNext,
      double phiSpan,
      ) {
    final s = corner.mode.toDouble();
    final rx = corner.beforeAbs - (s * oPrev);
    final ry = corner.afterAbs - (s * oNext);
    final worldScale = 1.0 / max(corner.sinTurn, 0.15);
    final estimatedLength = max(rx, ry) * worldScale * phiSpan;
    final samples = max(
      _minArcSamples,
      min(_maxArcSamples, (estimatedLength / _arcSampleStep).ceil()),
    );
    return samples;
  }

  int _connectorSampleCount(
      _ResolvedSide previous,
      _ResolvedSide next,
      _ResolvedCorner corner,
      ) {
    final estimate = max(
      previous.inside + previous.outside,
      next.inside + next.outside,
    );
    final samples = max(
      3,
      min(_maxArcSamples, (estimate / _arcSampleStep).ceil()),
    );
    return max(samples, corner.isSharp ? 1 : 3);
  }

  Offset _pointFromDistanceCoordinates(
      _ResolvedCorner corner,
      double dPrev,
      double dNext,
      ) {
    // Conservative fallback for parallel adjacent sides.
    // The main rounded-corner implementation is based on intersecting the two
    // offset side lines. When the lines are parallel, that coordinate system no
    // longer gives a unique point. In that case we keep a sharp connection.
    if (corner.isParallel) {
      final previousPoint = corner.previousSide.end +
          corner.previousSide.insideNormal.scaled(dPrev);
      final nextPoint = corner.nextSide.start +
          corner.nextSide.insideNormal.scaled(dNext);
      return Offset(
        (previousPoint.dx + nextPoint.dx) / 2.0,
        (previousPoint.dy + nextPoint.dy) / 2.0,
      );
    }

    return geometry.intersectOffsetLines(
      corner.previousSide,
      dPrev,
      corner.nextSide,
      dNext,
    );
  }

  _ResolvedSide _resolvedSideAt(int sideIndex) {
    final key = geometry.sideAt(sideIndex).key;
    return _activeSides[key]!;
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

  void _addClosedPolyline(Path path, List<Offset> rawPoints) {
    final points = <Offset>[];
    _appendPoints(points, rawPoints);

    if (points.length >= 2 && _samePoint(points.first, points.last)) {
      points.removeLast();
    }

    if (points.length >= 3) {
      path.addPolygon(points, true);
    }
  }

  Path _pathFromClosedPoints(List<Offset> points) {
    final path = Path();
    _addClosedPolyline(path, points);
    return path;
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
  int get hashCode => Object.hash(
    color,
    gradient,
    image,
    blendMode,
    blurRadius,
    offset,
    spreadRadius,
    align,
  );
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
    final background = shape.buildMergedStrokeRegions(
      setup,
      backgroundOnly: true,
      backgroundBase: clip,
    );
    return background.first.path.shift(rect.topLeft);
  }
}

class _AnyDecorationPainter extends BoxPainter {
  _AnyDecorationPainter(this.decoration, super.onChanged);

  final AnyDecoration decoration;
  final Map<DecorationImage, DecorationImagePainter> _imagePainters =
  <DecorationImage, DecorationImagePainter>{};

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    final rect = offset & size;
    final (shape, setup) = decoration.polygon(rect, configuration.textDirection);

    final regions = shape.buildMergedStrokeRegions(setup);
    final backgroundKey = setup.background.keys.firstOrNull;

    StrokeRegion? backgroundRegion;
    if (backgroundKey != null) {
      backgroundRegion =
          regions.firstWhereOrNull((r) => r.included.contains(backgroundKey));
      if (backgroundRegion != null) {
        _paintRegion(canvas, backgroundRegion, rect, configuration);
      }
    }

    for (final region in regions) {
      if (backgroundRegion == region) continue;
      _paintRegion(canvas, region, rect, configuration);
    }
  }

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
        paint.shader = fill.gradient!
            .createShader(rect, textDirection: configuration.textDirection);
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
  })  : _corners = corners,
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

    return (
    polygon,
    PolygonSetup(
      corners: {
        BoxCorner.topLeft: topLeft,
        BoxCorner.topRight: topRight,
        BoxCorner.bottomRight: bottomRight,
        BoxCorner.bottomLeft: bottomLeft,
      },
      sides: {
        BoxSide.left: left,
        BoxSide.top: top,
        BoxSide.right: right,
        BoxSide.bottom: bottom,
      },
      background: {
        BoxSide.background: AnyBackground(
          color: color,
          gradient: gradient,
          image: image,
          blendMode: blendMode,
          shapeBase: background,
        )
      },
    )
    );
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

class ExampleGenerator {
  static const groupSeparator = ' ';
  static const changeSeparator = '-';

  final List<ChangeGroup> groups;
  const ExampleGenerator(this.groups);

  Iterable<(String, List<Change>)> changes() sync* {
    if (groups.isEmpty) return;

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

  List<(String, AnyDecoration)> build() {
    final result = <(String, AnyDecoration)>[];

    for (final (name, changes) in changes()) {
      final builder = AnyDecorationBuilder();
      for (final change in changes) {
        change.change(builder);
      }

      final decoration = builder.build();
      result.add((name, decoration));
    }

    debugPrint('Built ${result.length} examples');

    return result;
  }
}


enum ContourBand {
  /// Contour traced along the outer extent of painted sides.
  outer,

  /// Contour traced along the inner extent of painted sides.
  inner,

  /// Contour traced along the base/background shape.
  base,
}

enum ContourNodeKind {
  /// A point that lies on a side span (typically some anchor/middle/tangent point).
  sideAnchor,

  /// A tangent point where a contour enters or leaves a rounded corner.
  cornerTangent,

  /// A split point on a rounded corner, used when the corner ownership
  /// changes between two differently painted adjacent regions.
  cornerSplit,
}

/// One resolved geometric checkpoint in a contour itinerary.
///
/// This is intentionally more semantic than a raw [Offset]:
/// - side anchors identify which side they belong to
/// - corner points identify which corner primitive and which local parameter `t`
///   they correspond to
///
/// Later, the tracer can connect two nodes either by a straight segment or by an
/// exact conic segment, depending on the edge type between them.
class ContourNode {
  final ContourNodeKind kind;
  final ContourBand band;
  final Offset point;

  /// Present for nodes that lie on a side-driven span.
  final int? sideIndex;

  /// Present for nodes that lie on a corner-driven span.
  final int? cornerIndex;

  /// Present for corner nodes only.
  final _CornerPrimitive? corner;

  /// Local corner parameter for corner nodes only.
  ///
  /// The exact meaning of `t` is defined by [_CornerPrimitive]. The intended
  /// convention is the quarter-conic parameter used to build exact `conicTo`
  /// segments.
  final double? t;

  const ContourNode._({
    required this.kind,
    required this.band,
    required this.point,
    this.sideIndex,
    this.cornerIndex,
    this.corner,
    this.t,
  }) : assert(
  (kind == ContourNodeKind.sideAnchor) == (sideIndex != null),
  'sideAnchor nodes must have sideIndex, and only sideAnchor nodes may have it.',
  ),
        assert(
        kind == ContourNodeKind.sideAnchor ||
            (cornerIndex != null && corner != null && t != null),
        'corner nodes must have cornerIndex, corner primitive and t.',
        );

  const ContourNode.sideAnchor({
    required int sideIndex,
    required ContourBand band,
    required Offset point,
  }) : this._(
    kind: ContourNodeKind.sideAnchor,
    band: band,
    point: point,
    sideIndex: sideIndex,
  );

  const ContourNode.cornerTangent({
    required int cornerIndex,
    required _CornerPrimitive corner,
    required double t,
    required ContourBand band,
    required Offset point,
  }) : this._(
    kind: ContourNodeKind.cornerTangent,
    band: band,
    point: point,
    cornerIndex: cornerIndex,
    corner: corner,
    t: t,
  );

  const ContourNode.cornerSplit({
    required int cornerIndex,
    required _CornerPrimitive corner,
    required double t,
    required ContourBand band,
    required Offset point,
  }) : this._(
    kind: ContourNodeKind.cornerSplit,
    band: band,
    point: point,
    cornerIndex: cornerIndex,
    corner: corner,
    t: t,
  );

  bool get isSideAnchor => kind == ContourNodeKind.sideAnchor;
  bool get isCornerNode => !isSideAnchor;
  bool get isCornerTangent => kind == ContourNodeKind.cornerTangent;
  bool get isCornerSplit => kind == ContourNodeKind.cornerSplit;

  @override
  String toString() {
    final buffer = StringBuffer('ContourNode(')
      ..write('kind:${kind.name}, ')
      ..write('band:${band.name}, ')
      ..write('point:$point');
    if (sideIndex != null) {
      buffer.write(', sideIndex:$sideIndex');
    }
    if (cornerIndex != null) {
      buffer.write(', cornerIndex:$cornerIndex, t:$t');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

/// Topological edge between two contour nodes.
///
/// Geometry is not encoded here beyond the edge subtype. The later path builder
/// decides how to turn each edge into `lineTo` / `conicTo`.
abstract class ContourEdge {
  final ContourNode from;
  final ContourNode to;

  const ContourEdge(this.from, this.to);

  bool get isDegenerate => _samePoint(from.point, to.point);
}

/// Straight segment between two contour nodes.
class LineContourEdge extends ContourEdge {
  const LineContourEdge(super.from, super.to);

  @override
  String toString() => 'LineContourEdge(from:$from, to:$to)';
}

/// Exact conic segment along one resolved rounded corner.
///
/// Both endpoints must belong to the same [_CornerPrimitive], and `t0` / `t1`
/// define the exact partial corner segment to render.
class CornerContourEdge extends ContourEdge {
  final _CornerPrimitive corner;
  final double t0;
  final double t1;

  CornerContourEdge({
    required ContourNode from,
    required ContourNode to,
    required this.corner,
    required this.t0,
    required this.t1,
  })  : assert(
  from.cornerIndex != null &&
      to.cornerIndex != null &&
      from.cornerIndex == to.cornerIndex,
  'CornerContourEdge endpoints must belong to the same corner.',
  ),
        assert(
        from.corner == corner && to.corner == corner,
        'CornerContourEdge endpoints must reference the same corner primitive.',
        ),
        super(from, to);

  bool get isReversed => t1 < t0;

  @override
  String toString() {
    return 'CornerContourEdge('
        'corner:${from.cornerIndex}, '
        't0:$t0, '
        't1:$t1, '
        'from:$from, '
        'to:$to'
        ')';
  }
}

/// Ordered closed/open contour itinerary, independent from [Path].
///
/// The future tracer can build these first, inspect/debug them, and only then
/// convert them into Flutter path commands.
class ContourPathPlan {
  final List<ContourNode> nodes;
  final List<ContourEdge> edges;
  final bool isClosed;

  ContourPathPlan({
    required this.nodes,
    required this.edges,
    required this.isClosed,
  }) : assert(
  nodes.length >= 2 || edges.isEmpty,
  'A non-empty contour plan should contain at least two nodes.',
  );

  bool get isEmpty => nodes.isEmpty;
  ContourNode get firstNode => nodes.first;
  ContourNode get lastNode => nodes.last;

  @override
  String toString() {
    return 'ContourPathPlan('
        'nodes:${nodes.length}, '
        'edges:${edges.length}, '
        'isClosed:$isClosed'
        ')';
  }
}

/// Mutable helper for building a [ContourPathPlan] while keeping edge creation
/// explicit and easy to debug.
class ContourPathPlanBuilder {
  final List<ContourNode> _nodes = <ContourNode>[];
  final List<ContourEdge> _edges = <ContourEdge>[];

  ContourNode? get lastNode => _nodes.isEmpty ? null : _nodes.last;
  bool get isEmpty => _nodes.isEmpty;

  void addNode(ContourNode node) {
    _nodes.add(node);
  }

  void addLineTo(ContourNode node) {
    final previous = lastNode;
    if (previous == null) {
      addNode(node);
      return;
    }

    _edges.add(LineContourEdge(previous, node));
    _nodes.add(node);
  }

  void addCornerTo(
      ContourNode node, {
        required _CornerPrimitive corner,
        required double t0,
        required double t1,
      }) {
    final previous = lastNode;
    if (previous == null) {
      addNode(node);
      return;
    }

    _edges.add(
      CornerContourEdge(
        from: previous,
        to: node,
        corner: corner,
        t0: t0,
        t1: t1,
      ),
    );
    _nodes.add(node);
  }

  ContourPathPlan build({required bool close}) {
    return ContourPathPlan(
      nodes: List<ContourNode>.unmodifiable(_nodes),
      edges: List<ContourEdge>.unmodifiable(_edges),
      isClosed: close,
    );
  }
}