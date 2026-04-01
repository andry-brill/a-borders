import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

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

double _lerpDouble(double a, double b, double t) => a + ((b - a) * t);

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
        bool backgroundOnly = false,
        bool backgroundMerge = true,
        AnyShapeBase? backgroundBase,
      }) {
    final geometry = _PolygonGeometry.fromCommands(commands);
    return _StrokeRegionBuilder(
      geometry,
      setup,
      backgroundOnly: backgroundOnly,
      backgroundMerge: backgroundMerge,
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

  bool get hasFill => fill.hasFill;
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

  @override
  bool operator ==(Object other) {
    return super == other && (other is AnyBackground && shapeBase == other.shapeBase);
  }

  @override
  int get hashCode => Object.hash(super.hashCode, shapeBase);

}

/// Describes how this corner is rendered.
///
/// `radius.x` and `radius.y` do not follow Flutter's built-in [Radius]
/// semantics. Here they are geometric distances interpreted in the local
/// corner coordinate system.
///
/// Base meanings:
/// - `radius.x` is associated with the side **before** the corner.
/// - `radius.y` is associated with the side **after** the corner.
///
/// Rendering modes:
/// - `radius == Radius.zero`: a sharp corner.
/// - `radius.x > 0 && radius.y > 0`: build an ellipse tangent to both sides
///   and use the **smaller** arc between the tangent points. This is the
///   standard rounded outer corner.
/// - `radius.x < 0 && radius.y < 0`: build an ellipse whose center lies on the
///   two side lines and use the **smaller** arc between the tangent points.
///   This produces an inward notch, similar to a postmark cut.
/// - `radius.x < 0 && radius.y > 0`: `|x|` is the circular radius for the
///   **inner** contour, and `y` is the circular radius for the **outer**
///   contour.
/// - `radius.x > 0 && radius.y < 0`: `x` is the circular radius for the
///   **outer** contour, and `|y|` is the circular radius for the **inner**
///   contour.
/// - `radius.x == 0 && radius.y > 0`, or `radius.y == 0 && radius.x > 0`:
///   the non-zero value is the circular radius for the **outer** contour, and
///   the inner contour stays sharp.
/// - `radius.x == 0 && radius.y < 0`, or `radius.y == 0 && radius.x < 0`:
///   the absolute non-zero value is the circular radius for the **inner**
///   contour, and the outer contour stays sharp.
///
/// For all mixed-sign and single-non-zero cases, the corner is treated as a
/// contour-driven circular corner:
/// - the outer contour uses the configured outer circular radius,
/// - the inner contour uses the configured inner circular radius,
/// - intermediate contours interpolate between those two radii.
///
/// If the adjacent sides are parallel, the corner falls back to a sharp
/// connection for now.
///
/// Side constraint:
/// For a side `S` between corners `L` and `R`, the two corner arcs must not
/// overlap on that side.
///
/// The consumed length on `S` is computed from the radii that are active on
/// that side. For same-sign corners this uses the side-associated component.
/// For contour-driven circular corners it uses the larger of the outer/inner
/// circular radii so every contour still fits.
///
/// Automatic normalization scales the affected corner radii proportionally so
/// the total side consumption does not exceed the side length.
///
/// Join handling for adjacent sides with different widths or fills:
/// - If the two adjacent sides share the same fill, they can be merged into a
///   single solid [Path]. In this case, the corner is rendered as one joined
///   shape, and both the outer and inner corner boundaries are rounded by
///   their corresponding arcs.
/// - If the two adjacent sides have different fills, they must remain separate.
///   In this case, the corner transition is split at the boundary between the
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

  _CornerFrame cornerAfterSide(int index) => corners[index % corners.length];

  _CornerFrame cornerBeforeSide(int index) =>
      corners[(index - 1 + corners.length) % corners.length];

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

  bool get hasWidth => side.width > _epsilon;
  bool get isPainted => side.hasFill && hasWidth;
  IAnyFill get fill => side;

  double get inside => side.width * (1.0 - side.align) / 2.0;
  double get outside => side.width * (1.0 + side.align) / 2.0;

  /// Center line of the painted strip relative to the base polygon side.
  ///
  /// Corner construction should be based on the strip width, not on align.
  /// So most corner math is performed in coordinates centered on this line.
  double get stripCenterOffset => (inside - outside) / 2.0;

  double get halfWidth => side.width / 2.0;

  double centeredOffsetForActual(double actualOffset) =>
      actualOffset - stripCenterOffset;

  double actualOffsetForCentered(double centeredOffset) =>
      stripCenterOffset + centeredOffset;
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

    bool isInset(Enum key) {
      final before = normalizedBefore[key] ?? 0.0;
      final after = normalizedAfter[key] ?? 0.0;
      return before > _epsilon && after > _epsilon;
    }

    bool isNotch(Enum key) {
      final before = normalizedBefore[key] ?? 0.0;
      final after = normalizedAfter[key] ?? 0.0;
      return before < -_epsilon && after < -_epsilon;
    }

    bool isContourDrivenCircular(Enum key) {
      if (isInset(key) || isNotch(key)) {
        return false;
      }
      final before = normalizedBefore[key] ?? 0.0;
      final after = normalizedAfter[key] ?? 0.0;
      return !_nearZero(before) || !_nearZero(after);
    }

    double circularConsumption(Enum key) {
      final before = normalizedBefore[key] ?? 0.0;
      final after = normalizedAfter[key] ?? 0.0;
      final outer = max(0.0, max(before, after));
      final inner = max(0.0, max(-before, -after));
      return max(outer, inner);
    }

    double sideConsumptionFromStart(_CornerFrame cornerFrame, double sinTurn) {
      final key = cornerFrame.key;
      if (isContourDrivenCircular(key)) {
        return circularConsumption(key) / sinTurn;
      }
      return (normalizedAfter[key] ?? 0.0).abs() / sinTurn;
    }

    double sideConsumptionFromEnd(_CornerFrame cornerFrame, double sinTurn) {
      final key = cornerFrame.key;
      if (isContourDrivenCircular(key)) {
        return circularConsumption(key) / sinTurn;
      }
      return (normalizedBefore[key] ?? 0.0).abs() / sinTurn;
    }

    void scaleCorner(Enum key, double scale, {required bool affectsAfterSide}) {
      if (isContourDrivenCircular(key)) {
        normalizedBefore[key] = (normalizedBefore[key] ?? 0.0) * scale;
        normalizedAfter[key] = (normalizedAfter[key] ?? 0.0) * scale;
        return;
      }

      if (affectsAfterSide) {
        normalizedAfter[key] = (normalizedAfter[key] ?? 0.0) * scale;
      } else {
        normalizedBefore[key] = (normalizedBefore[key] ?? 0.0) * scale;
      }
    }

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

      final startConsumption = sideConsumptionFromStart(startCorner, startSin);
      final endConsumption = sideConsumptionFromEnd(endCorner, endSin);
      final totalConsumption = startConsumption + endConsumption;

      if (totalConsumption <= side.length + _epsilon ||
          _nearZero(totalConsumption)) {
        continue;
      }

      final scale = side.length / totalConsumption;
      scaleCorner(startCorner.key, scale, affectsAfterSide: true);
      scaleCorner(endCorner.key, scale, affectsAfterSide: false);
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

}

class _ResolvedCorner {
  final Enum key;
  final AnyCorner corner;
  final _CornerFrame frame;
  final _SideFrame previousSide;
  final _SideFrame nextSide;
  final double beforeRadius;
  final double afterRadius;
  final double previousStripCenterOffset;
  final double nextStripCenterOffset;
  final double previousHalfWidth;
  final double nextHalfWidth;

  const _ResolvedCorner({
    required this.key,
    required this.corner,
    required this.frame,
    required this.previousSide,
    required this.nextSide,
    required this.beforeRadius,
    required this.afterRadius,
    required this.previousStripCenterOffset,
    required this.nextStripCenterOffset,
    required this.previousHalfWidth,
    required this.nextHalfWidth,
  });

  bool get isInsetRounded => beforeRadius > _epsilon && afterRadius > _epsilon;

  bool get isNotchRounded => beforeRadius < -_epsilon && afterRadius < -_epsilon;

  double get beforeAbs => beforeRadius.abs();

  double get afterAbs => afterRadius.abs();

  double get outerContourRadius => max(0.0, max(beforeRadius, afterRadius));

  double get innerContourRadius => max(0.0, max(-beforeRadius, -afterRadius));

  bool get isContourDrivenCircular =>
      !isInsetRounded &&
          !isNotchRounded &&
          (outerContourRadius > _epsilon || innerContourRadius > _epsilon);

  bool get isDualContourRounded =>
      isContourDrivenCircular &&
          outerContourRadius > _epsilon &&
          innerContourRadius > _epsilon;

  bool get isOuterOnlyCircular =>
      isContourDrivenCircular &&
          outerContourRadius > _epsilon &&
          innerContourRadius <= _epsilon;

  bool get isInnerOnlyCircular =>
      isContourDrivenCircular &&
          innerContourRadius > _epsilon &&
          outerContourRadius <= _epsilon;

  bool get isSharp =>
      !isInsetRounded && !isNotchRounded && !isContourDrivenCircular;

  double get turnAngle => frame.command.value.abs();

  double get sinTurn => sin(turnAngle).abs();

  bool get isParallel => sinTurn <= _epsilon;

  bool get hasExactConic => !isSharp && !isParallel;

  Offset get vertex => frame.vertex;

  Offset get previousNormal => previousSide.insideNormal;

  Offset get nextNormal => nextSide.insideNormal;

  double get consumedOnPreviousSide =>
      isParallel
          ? double.infinity
          : (isContourDrivenCircular ? max(outerContourRadius, innerContourRadius) : afterAbs) / sinTurn;

  double get consumedOnNextSide =>
      isParallel
          ? double.infinity
          : (isContourDrivenCircular ? max(outerContourRadius, innerContourRadius) : beforeAbs) / sinTurn;

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

/// Exact conic representation of one resolved corner for a specific pair of
/// adjacent side offsets.
///
/// Local coordinates are signed perpendicular distances to the previous and
/// next side. Depending on the radius semantics, the primitive uses either
/// the tangent ellipse/notch geometry or the contour-driven circular radius
/// for the currently traced contour.
class _CornerPrimitive {
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

  bool get isInsetRounded => corner.isInsetRounded;

  bool get isNotchRounded => corner.isNotchRounded;

  bool get isContourDrivenCircular => corner.isContourDrivenCircular;

  bool get isDualContourRounded => corner.isDualContourRounded;

  bool get isOuterOnlyCircular => corner.isOuterOnlyCircular;

  bool get isInnerOnlyCircular => corner.isInnerOnlyCircular;

  double _blendForSide(double actualOffset, double centerOffset, double halfWidth) {
    if (halfWidth <= _epsilon) {
      return double.nan;
    }

    final centered = actualOffset - centerOffset;
    final blend = (centered / halfWidth + 1.0) / 2.0;
    return max(0.0, min(1.0, blend));
  }

  double get contourBlend {
    final blends = <double>[];

    final previousBlend = _blendForSide(
      previousOffset,
      corner.previousStripCenterOffset,
      corner.previousHalfWidth,
    );
    if (!previousBlend.isNaN) {
      blends.add(previousBlend);
    }

    final nextBlend = _blendForSide(
      nextOffset,
      corner.nextStripCenterOffset,
      corner.nextHalfWidth,
    );
    if (!nextBlend.isNaN) {
      blends.add(nextBlend);
    }

    if (blends.isEmpty) {
      final averageOffset = (previousOffset + nextOffset) / 2.0;
      return averageOffset > _epsilon ? 1.0 : 0.0;
    }

    return blends.reduce((a, b) => a + b) / blends.length;
  }

  double get circularRadiusForContour => _lerpDouble(
    corner.outerContourRadius,
    corner.innerContourRadius,
    contourBlend,
  );

  double get beforeRadius =>
      isContourDrivenCircular ? circularRadiusForContour : corner.beforeAbs;

  double get afterRadius =>
      isContourDrivenCircular ? circularRadiusForContour : corner.afterAbs;

  bool get canBuildExactConic =>
      corner.hasExactConic &&
          beforeRadius > _epsilon &&
          afterRadius > _epsilon;

  Offset get localCenter {
    if (isInsetRounded || isContourDrivenCircular) {
      return Offset(
        previousOffset + beforeRadius,
        nextOffset + afterRadius,
      );
    }

    return Offset(previousOffset, nextOffset);
  }

  double get startAngle {
    if (isInsetRounded || isContourDrivenCircular) {
      return pi;
    }
    return pi / 2.0;
  }

  double get endAngle {
    if (isInsetRounded || isContourDrivenCircular) {
      return 1.5 * pi;
    }
    return 0.0;
  }

  Offset localPointAtAngle(double angle) {
    if (!canBuildExactConic) {
      throw StateError(
        'Corner ${corner.key} does not support exact conic construction.',
      );
    }

    final center = localCenter;
    return Offset(
      center.dx + (beforeRadius * cos(angle)),
      center.dy + (afterRadius * sin(angle)),
    );
  }

  double angleForDistancePoint(Offset distancePoint) {
    if (!canBuildExactConic) {
      throw StateError(
        'Corner ${corner.key} does not support exact conic construction.',
      );
    }

    final center = localCenter;
    final x = (distancePoint.dx - center.dx) / beforeRadius;
    final y = (distancePoint.dy - center.dy) / afterRadius;
    var angle = atan2(y, x);
    if (angle < 0.0) {
      angle += 2.0 * pi;
    }
    return canonicalizeAngleToSweep(angle);
  }

  double canonicalizeAngleToSweep(double angle) {
    if (endAngle >= startAngle) {
      var normalized = angle;
      while (normalized < startAngle - _epsilon) {
        normalized += 2.0 * pi;
      }
      while (normalized > endAngle + _epsilon &&
          normalized - 2.0 * pi >= startAngle - _epsilon) {
        normalized -= 2.0 * pi;
      }
      if (normalized < startAngle) {
        return startAngle;
      }
      if (normalized > endAngle) {
        return endAngle;
      }
      return normalized;
    }

    if (angle < endAngle) {
      return endAngle;
    }
    if (angle > startAngle) {
      return startAngle;
    }
    return angle;
  }

  Offset worldPointAtAngle(double angle) {
    final local = localPointAtAngle(angle);
    return mapDistancesToWorld(local.dx, local.dy);
  }

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

  Iterable<_ConicArcSegment> conicSegments({
    required double fromAngle,
    required double toAngle,
  }) sync* {
    if (!canBuildExactConic) {
      throw StateError(
        'Corner ${corner.key} does not support exact conic construction.',
      );
    }

    final delta = toAngle - fromAngle;
    if (_nearZero(delta)) {
      final point = worldPointAtAngle(fromAngle);
      yield _ConicArcSegment(
        start: point,
        control: point,
        end: point,
        weight: 1.0,
      );
      return;
    }

    final segmentCount = max(1, (delta.abs() / (pi / 2.0 - 1.0e-5)).ceil());
    for (var index = 0; index < segmentCount; index++) {
      final t0 = index / segmentCount;
      final t1 = (index + 1) / segmentCount;
      final segmentFrom = fromAngle + (delta * t0);
      final segmentTo = fromAngle + (delta * t1);
      yield conicSegment(
        fromAngle: segmentFrom,
        toAngle: segmentTo,
      );
    }
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
      center.dx + (beforeRadius * cos(middleAngle) / weight),
      center.dy + (afterRadius * sin(middleAngle) / weight),
    );

    return _ConicArcSegment(
      start: mapDistancesToWorld(startLocal.dx, startLocal.dy),
      control: mapDistancesToWorld(controlLocal.dx, controlLocal.dy),
      end: mapDistancesToWorld(endLocal.dx, endLocal.dy),
      weight: weight,
    );
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

enum _CornerSlice { full, prevToSplit, splitToNext }

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
  })  : assert(
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

class _StrokeRegionBuilder {
  final _PolygonGeometry geometry;
  final PolygonSetup setup;
  final bool backgroundOnly;
  final bool backgroundMerge;
  final AnyShapeBase? backgroundBase;

  late final Map<Enum, _ResolvedSide> _resolvedSides = _resolveSides();
  late final Map<Enum, _ResolvedSide> _activeSides = _resolveActiveSides();
  late final Map<Enum, _ResolvedCorner> _resolvedCorners = _resolveCorners();
  late final _BackgroundEntry? _background = _resolveBackground();

  _StrokeRegionBuilder(
      this.geometry,
      this.setup, {
        this.backgroundOnly = false,
        this.backgroundMerge = true,
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
      if (rx.isNaN || ry.isNaN) {
        throw ArgumentError('Corner ${corner.key} contains NaN radius values.');
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
      final previousSideFrame = geometry.sideAt(cornerFrame.index);
      final nextSideFrame = geometry.sideAt(cornerFrame.index + 1);
      final previousResolvedSide = _resolvedSides[previousSideFrame.key]!;
      final nextResolvedSide = _resolvedSides[nextSideFrame.key]!;

      result[cornerFrame.key] = _ResolvedCorner(
        key: cornerFrame.key,
        corner: setup.corners[cornerFrame.key]!,
        frame: cornerFrame,
        previousSide: previousSideFrame,
        nextSide: nextSideFrame,
        beforeRadius: normalizedRadii.beforeOf(cornerFrame.key),
        afterRadius: normalizedRadii.afterOf(cornerFrame.key),
        previousStripCenterOffset: previousResolvedSide.stripCenterOffset,
        nextStripCenterOffset: nextResolvedSide.stripCenterOffset,
        previousHalfWidth: previousResolvedSide.halfWidth,
        nextHalfWidth: nextResolvedSide.halfWidth,
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

  _ResolvedSide _activeSideAt(int sideIndex) {
    final key = geometry.sideAt(sideIndex).key;
    return _activeSides[key]!;
  }

  _ResolvedCorner _cornerAfter(int previousSideIndex) {
    final key = geometry.cornerAfterSide(previousSideIndex).key;
    return _resolvedCorners[key]!;
  }

  _CornerPrimitive _primitiveForCornerOffsets(
      int previousSideIndex, {
        required double oPrev,
        required double oNext,
      }) {
    final corner = _cornerAfter(previousSideIndex);
    return corner.primitive(
      previousOffset: oPrev,
      nextOffset: oNext,
    );
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

    if (_background != null && backgroundMerge) {
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
      final backgroundKey = component.contains(_background?.key) ? _background!.key : null;

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

  Path _buildBackgroundOnlyPath() => _pathFromPlan(_buildBackgroundOnlyPlan());

  Path _buildBackgroundGroupPath(_FillGroup group) =>
      _pathFromPlan(_buildBackgroundGroupPlan(group));

  Path _buildSideOnlyPath(Set<Enum> sideKeys) {
    final path = Path();
    for (final run in _collectSideRuns(sideKeys)) {
      _appendPlanToPath(path, _buildSideRunPlan(run));
    }
    return path;
  }

  Path _buildRingPath(_FillGroup group) {
    final outerOffsets = <Enum, double>{};
    final innerOffsets = <Enum, double>{};

    for (final frame in geometry.sides) {
      final side = _activeSides[frame.key]!;
      outerOffsets[frame.key] = -side.outside;
      innerOffsets[frame.key] = side.inside;
    }

    final path = Path()..fillType = PathFillType.evenOdd;
    _appendPlanToPath(
      path,
      _buildClosedContourPlan(outerOffsets, band: ContourBand.outer),
    );
    _appendPlanToPath(
      path,
      _buildClosedContourPlan(innerOffsets, band: ContourBand.inner),
    );
    return path;
  }

  ContourPathPlan _buildBackgroundOnlyPlan() {
    final offsets = <Enum, double>{};

    for (final frame in geometry.sides) {
      final side = _resolvedSides[frame.key]!;
      offsets[frame.key] = switch (_effectiveBackgroundBase) {
        AnyShapeBase.zeroBorder => 0.0,
        AnyShapeBase.outerBorder => -side.outside,
        AnyShapeBase.innerBorder => side.inside,
      };
    }

    return _buildClosedContourPlan(offsets, band: ContourBand.base);
  }

  ContourPathPlan _buildBackgroundGroupPlan(_FillGroup group) {
    final fragments = <ContourPathPlan>[];
    for (var i = 0; i < geometry.length; i++) {
      fragments.add(_buildBackgroundCornerFragmentPlan(i, group.sideKeys));
    }
    return _buildClosedContourPlanFromFragments(fragments);
  }

  ContourPathPlan _buildSideRunPlan(_SideRun run) {
    final fragments = <ContourPathPlan>[];
    fragments.add(_buildRunStartCapPlan(run));

    for (var step = 0; step < run.length - 1; step++) {
      final sideIndex = run.sideIndexAt(step);
      final current = _activeSideAt(sideIndex);
      final next = _activeSideAt(sideIndex + 1);
      fragments.add(
        _buildCornerSlicePlan(
          sideIndex,
          oPrev: -current.outside,
          oNext: -next.outside,
          slice: _CornerSlice.full,
          band: ContourBand.outer,
        ),
      );
    }

    fragments.add(_buildRunEndCapPlan(run));

    for (var step = run.length - 2; step >= 0; step--) {
      final sideIndex = run.sideIndexAt(step);
      final current = _activeSideAt(sideIndex);
      final next = _activeSideAt(sideIndex + 1);
      final inner = _buildCornerSlicePlan(
        sideIndex,
        oPrev: current.inside,
        oNext: next.inside,
        slice: _CornerSlice.full,
        band: ContourBand.inner,
      );
      fragments.add(_reverseOpenPlan(inner));
    }

    return _buildClosedContourPlanFromFragments(fragments);
  }

  ContourPathPlan _buildRunStartCapPlan(_SideRun run) {
    final previous = _sideAt(run.startIndex - 1);
    final current = _activeSideAt(run.startIndex);
    final cornerIndex = run.startIndex - 1;

    if (!previous.hasWidth && current.hasWidth) {
      final inner = _reverseOpenPlan(
        _buildCornerSlicePlan(
          cornerIndex,
          oPrev: previous.inside,
          oNext: current.inside,
          slice: _CornerSlice.full,
          band: ContourBand.inner,
        ),
      );

      final connector = _buildZeroWidthNeighborConnectorPlan(
        cornerIndex,
        zeroOnPreviousSide: true,
        outerToInner: false,
        outerPrevOffset: -previous.outside,
        outerNextOffset: -current.outside,
        innerPrevOffset: previous.inside,
        innerNextOffset: current.inside,
      );

      final outer = _buildCornerSlicePlan(
        cornerIndex,
        oPrev: -previous.outside,
        oNext: -current.outside,
        slice: _CornerSlice.full,
        band: ContourBand.outer,
      );

      return _concatenateOpenPlans([inner, connector, outer]);
    }

    final inner = _reverseOpenPlan(
      _buildCornerSlicePlan(
        cornerIndex,
        oPrev: previous.inside,
        oNext: current.inside,
        slice: _CornerSlice.splitToNext,
        band: ContourBand.inner,
      ),
    );

    final connector = _buildCornerSplitConnectorPlan(
      cornerIndex,
      outerToInner: false,
      previousSide: previous,
      nextSide: current,
    );

    final outer = _buildCornerSlicePlan(
      cornerIndex,
      oPrev: -previous.outside,
      oNext: -current.outside,
      slice: _CornerSlice.splitToNext,
      band: ContourBand.outer,
    );

    return _concatenateOpenPlans([inner, connector, outer]);
  }

  ContourPathPlan _buildRunEndCapPlan(_SideRun run) {
    final current = _activeSideAt(run.endIndex);
    final next = _sideAt(run.endIndex + 1);
    final cornerIndex = run.endIndex;

    if (current.hasWidth && !next.hasWidth) {
      final outer = _buildCornerSlicePlan(
        cornerIndex,
        oPrev: -current.outside,
        oNext: -next.outside,
        slice: _CornerSlice.full,
        band: ContourBand.outer,
      );

      final connector = _buildZeroWidthNeighborConnectorPlan(
        cornerIndex,
        zeroOnPreviousSide: false,
        outerToInner: true,
        outerPrevOffset: -current.outside,
        outerNextOffset: -next.outside,
        innerPrevOffset: current.inside,
        innerNextOffset: next.inside,
      );

      final inner = _reverseOpenPlan(
        _buildCornerSlicePlan(
          cornerIndex,
          oPrev: current.inside,
          oNext: next.inside,
          slice: _CornerSlice.full,
          band: ContourBand.inner,
        ),
      );

      return _concatenateOpenPlans([outer, connector, inner]);
    }

    final outer = _buildCornerSlicePlan(
      cornerIndex,
      oPrev: -current.outside,
      oNext: -next.outside,
      slice: _CornerSlice.prevToSplit,
      band: ContourBand.outer,
    );

    final connector = _buildCornerSplitConnectorPlan(
      cornerIndex,
      outerToInner: true,
      previousSide: current,
      nextSide: next,
    );

    final inner = _reverseOpenPlan(
      _buildCornerSlicePlan(
        cornerIndex,
        oPrev: current.inside,
        oNext: next.inside,
        slice: _CornerSlice.prevToSplit,
        band: ContourBand.inner,
      ),
    );

    return _concatenateOpenPlans([outer, connector, inner]);
  }

  ContourPathPlan _buildBackgroundCornerFragmentPlan(
      int previousSideIndex,
      Set<Enum> mergedSideKeys,
      ) {
    final current = _sideAt(previousSideIndex);
    final next = _sideAt(previousSideIndex + 1);
    final currentMerged = _isMergedSide(mergedSideKeys, previousSideIndex);
    final nextMerged = _isMergedSide(mergedSideKeys, previousSideIndex + 1);

    if (currentMerged && !nextMerged && next.isPainted) {
      final outer = _buildCornerSlicePlan(
        previousSideIndex,
        oPrev: -current.outside,
        oNext: -next.outside,
        slice: _CornerSlice.prevToSplit,
        band: ContourBand.outer,
      );
      final connector = _buildCornerSplitConnectorPlan(
        previousSideIndex,
        outerToInner: true,
        previousSide: current,
        nextSide: next,
      );
      final inner = _buildCornerSlicePlan(
        previousSideIndex,
        oPrev: current.inside,
        oNext: next.inside,
        slice: _CornerSlice.splitToNext,
        band: ContourBand.base,
      );
      return _concatenateOpenPlans([outer, connector, inner]);
    }

    if (!currentMerged && current.isPainted && nextMerged) {
      final inner = _buildCornerSlicePlan(
        previousSideIndex,
        oPrev: current.inside,
        oNext: next.inside,
        slice: _CornerSlice.prevToSplit,
        band: ContourBand.base,
      );
      final connector = _buildCornerSplitConnectorPlan(
        previousSideIndex,
        outerToInner: false,
        previousSide: current,
        nextSide: next,
      );
      final outer = _buildCornerSlicePlan(
        previousSideIndex,
        oPrev: -current.outside,
        oNext: -next.outside,
        slice: _CornerSlice.splitToNext,
        band: ContourBand.outer,
      );
      return _concatenateOpenPlans([inner, connector, outer]);
    }

    final currentOffset =
    currentMerged ? -current.outside : _backgroundOffsetForSide(current);
    final nextOffset = nextMerged ? -next.outside : _backgroundOffsetForSide(next);

    return _buildCornerSlicePlan(
      previousSideIndex,
      oPrev: currentOffset,
      oNext: nextOffset,
      slice: _CornerSlice.full,
      band: currentMerged || nextMerged ? ContourBand.outer : ContourBand.base,
    );
  }

  double _backgroundOffsetForSide(_ResolvedSide side) {
    if (side.isPainted) {
      return side.inside;
    }

    return switch (_effectiveBackgroundBase) {
      AnyShapeBase.zeroBorder => 0.0,
      AnyShapeBase.outerBorder => -side.outside,
      AnyShapeBase.innerBorder => side.inside,
    };
  }

  ContourPathPlan _buildClosedContourPlan(
      Map<Enum, double> offsets, {
        required ContourBand band,
      }) {
    final fragments = <ContourPathPlan>[];
    for (var i = 0; i < geometry.length; i++) {
      final current = _sideAt(i);
      final next = _sideAt(i + 1);
      fragments.add(
        _buildCornerSlicePlan(
          i,
          oPrev: offsets[current.key] ?? 0.0,
          oNext: offsets[next.key] ?? 0.0,
          slice: _CornerSlice.full,
          band: band,
        ),
      );
    }
    return _buildClosedContourPlanFromFragments(fragments);
  }

  ContourPathPlan _buildClosedContourPlanFromFragments(List<ContourPathPlan> fragments) {
    if (fragments.isEmpty) {
      return ContourPathPlan(
        nodes: const <ContourNode>[],
        edges: const <ContourEdge>[],
        isClosed: true,
      );
    }

    final builder = ContourPathPlanBuilder();
    builder.addNode(fragments.last.lastNode);
    for (final fragment in fragments) {
      _appendOpenPlan(builder, fragment);
    }
    return builder.build(close: true);
  }

  ContourPathPlan _buildCornerSlicePlan(
      int previousSideIndex, {
        required double oPrev,
        required double oNext,
        required _CornerSlice slice,
        required ContourBand band,
      }) {
    final corner = _cornerAfter(previousSideIndex);
    if (!_cornerCanRound(previousSideIndex, corner, oPrev, oNext)) {
      final point = _pointFromDistanceCoordinates(corner, oPrev, oNext);
      final node = _cornerNode(
        corner: corner,
        angle: corner.primitive(previousOffset: oPrev, nextOffset: oNext).startAngle,
        band: band,
        point: point,
        kind: slice == _CornerSlice.full
            ? ContourNodeKind.cornerTangent
            : ContourNodeKind.cornerSplit,
      );
      return ContourPathPlan(
        nodes: <ContourNode>[node],
        edges: const <ContourEdge>[],
        isClosed: false,
      );
    }

    final primitive = _primitiveForCornerOffsets(
      previousSideIndex,
      oPrev: oPrev,
      oNext: oNext,
    );

    final splitAngle = switch (slice) {
      _CornerSlice.full => null,
      _CornerSlice.prevToSplit || _CornerSlice.splitToNext =>
          _splitAngle(previousSideIndex, oPrev, oNext, primitive),
    };

    final (startAngle, endAngle, startKind, endKind) = switch (slice) {
      _CornerSlice.full => (
        primitive.startAngle,
        primitive.endAngle,
        ContourNodeKind.cornerTangent,
        ContourNodeKind.cornerTangent,
      ),
      _CornerSlice.prevToSplit => (
        primitive.startAngle,
        splitAngle!,
        ContourNodeKind.cornerTangent,
        ContourNodeKind.cornerSplit,
      ),
      _CornerSlice.splitToNext => (
        splitAngle!,
        primitive.endAngle,
        ContourNodeKind.cornerSplit,
        ContourNodeKind.cornerTangent,
      ),
    };

    final startNode = _cornerNode(
      corner: corner,
      angle: startAngle,
      band: band,
      point: primitive.worldPointAtAngle(startAngle),
      kind: startKind,
      primitive: primitive,
    );

    if (_nearZero(endAngle - startAngle)) {
      return ContourPathPlan(
        nodes: <ContourNode>[startNode],
        edges: const <ContourEdge>[],
        isClosed: false,
      );
    }

    final endNode = _cornerNode(
      corner: corner,
      angle: endAngle,
      band: band,
      point: primitive.worldPointAtAngle(endAngle),
      kind: endKind,
      primitive: primitive,
    );

    final builder = ContourPathPlanBuilder();
    builder.addNode(startNode);
    builder.addCornerTo(
      endNode,
      corner: primitive,
      t0: startAngle,
      t1: endAngle,
    );
    return builder.build(close: false);
  }


  ContourPathPlan _buildZeroWidthNeighborConnectorPlan(
      int previousSideIndex, {
        required bool zeroOnPreviousSide,
        required bool outerToInner,
        required double outerPrevOffset,
        required double outerNextOffset,
        required double innerPrevOffset,
        required double innerNextOffset,
      }) {
    final corner = _cornerAfter(previousSideIndex);

    final outerPoint = _pointFromDistanceCoordinates(
      corner,
      outerPrevOffset,
      outerNextOffset,
    );
    final innerPoint = _pointFromDistanceCoordinates(
      corner,
      innerPrevOffset,
      innerNextOffset,
    );

    final anglePrimitive = corner.primitive(
      previousOffset: outerPrevOffset,
      nextOffset: outerNextOffset,
    );
    final angle = zeroOnPreviousSide
        ? anglePrimitive.startAngle
        : anglePrimitive.endAngle;

    final outerNode = _cornerNode(
      corner: corner,
      angle: angle,
      band: ContourBand.outer,
      point: outerPoint,
      kind: ContourNodeKind.cornerSplit,
    );

    final innerNode = _cornerNode(
      corner: corner,
      angle: angle,
      band: ContourBand.inner,
      point: innerPoint,
      kind: ContourNodeKind.cornerSplit,
    );

    final builder = ContourPathPlanBuilder();
    builder.addNode(outerToInner ? outerNode : innerNode);
    builder.addLineTo(outerToInner ? innerNode : outerNode);
    return builder.build(close: false);
  }

  ContourPathPlan _buildCornerSplitConnectorPlan(
      int previousSideIndex, {
        required bool outerToInner,
        required _ResolvedSide previousSide,
        required _ResolvedSide nextSide,
      }) {
    final corner = _cornerAfter(previousSideIndex);

    final outerNode = () {
      if (_usesMidArcSplit(previousSide, nextSide) &&
          _cornerCanRound(
            previousSideIndex,
            corner,
            -previousSide.outside,
            -nextSide.outside,
          )) {
        final primitive = _primitiveForCornerOffsets(
          previousSideIndex,
          oPrev: -previousSide.outside,
          oNext: -nextSide.outside,
        );
        final angle = _midArcSplitAngle(primitive);
        return _cornerNode(
          corner: corner,
          angle: angle,
          band: ContourBand.outer,
          point: primitive.worldPointAtAngle(angle),
          kind: ContourNodeKind.cornerSplit,
          primitive: primitive,
        );
      }

      final outerDistancePoint = _buildCornerSplitPointInDistanceSpace(
        previousSideIndex,
        -previousSide.outside,
        -nextSide.outside,
      );
      return _cornerNode(
        corner: corner,
        angle: _primitiveForCornerOffsets(
          previousSideIndex,
          oPrev: -previousSide.outside,
          oNext: -nextSide.outside,
        ).startAngle,
        band: ContourBand.outer,
        point: _pointFromDistanceCoordinates(
          corner,
          outerDistancePoint.dx,
          outerDistancePoint.dy,
        ),
        kind: ContourNodeKind.cornerSplit,
      );
    }();

    final innerNode = () {
      if (_usesMidArcSplit(previousSide, nextSide) &&
          _cornerCanRound(
            previousSideIndex,
            corner,
            previousSide.inside,
            nextSide.inside,
          )) {
        final primitive = _primitiveForCornerOffsets(
          previousSideIndex,
          oPrev: previousSide.inside,
          oNext: nextSide.inside,
        );
        final angle = _midArcSplitAngle(primitive);
        return _cornerNode(
          corner: corner,
          angle: angle,
          band: ContourBand.inner,
          point: primitive.worldPointAtAngle(angle),
          kind: ContourNodeKind.cornerSplit,
          primitive: primitive,
        );
      }

      final innerDistancePoint = _buildCornerSplitPointInDistanceSpace(
        previousSideIndex,
        previousSide.inside,
        nextSide.inside,
      );
      return _cornerNode(
        corner: corner,
        angle: _primitiveForCornerOffsets(
          previousSideIndex,
          oPrev: previousSide.inside,
          oNext: nextSide.inside,
        ).startAngle,
        band: ContourBand.inner,
        point: _pointFromDistanceCoordinates(
          corner,
          innerDistancePoint.dx,
          innerDistancePoint.dy,
        ),
        kind: ContourNodeKind.cornerSplit,
      );
    }();

    final builder = ContourPathPlanBuilder();
    builder.addNode(outerToInner ? outerNode : innerNode);
    builder.addLineTo(outerToInner ? innerNode : outerNode);
    return builder.build(close: false);
  }

  ContourNode _cornerNode({
    required _ResolvedCorner corner,
    required double angle,
    required ContourBand band,
    required Offset point,
    required ContourNodeKind kind,
    _CornerPrimitive? primitive,
  }) {
    final resolvedPrimitive = primitive ??
        corner.primitive(previousOffset: 0.0, nextOffset: 0.0);
    return switch (kind) {
      ContourNodeKind.sideAnchor => throw ArgumentError('Use sideAnchor constructor for side nodes.'),
      ContourNodeKind.cornerTangent => ContourNode.cornerTangent(
        cornerIndex: corner.frame.index,
        corner: resolvedPrimitive,
        t: angle,
        band: band,
        point: point,
      ),
      ContourNodeKind.cornerSplit => ContourNode.cornerSplit(
        cornerIndex: corner.frame.index,
        corner: resolvedPrimitive,
        t: angle,
        band: band,
        point: point,
      ),
    };
  }

  bool _cornerCanRound(int previousSideIndex, _ResolvedCorner corner, double oPrev, double oNext) {
    if (corner.isSharp || corner.isParallel) {
      return false;
    }

    final primitive = _primitiveForCornerOffsets(
      previousSideIndex,
      oPrev: oPrev,
      oNext: oNext,
    );
    return primitive.canBuildExactConic;
  }

  bool _usesMidArcSplit(_ResolvedSide previousSide, _ResolvedSide nextSide) {
    return previousSide.hasWidth && nextSide.hasWidth;
  }

  double _midArcSplitAngle(_CornerPrimitive primitive) {
    return (primitive.startAngle + primitive.endAngle) / 2.0;
  }

  double _splitAngle(
      int previousSideIndex,
      double oPrev,
      double oNext,
      _CornerPrimitive primitive,
      ) {
    final previousSide = _sideAt(previousSideIndex);
    final nextSide = _sideAt(previousSideIndex + 1);

    if (_usesMidArcSplit(previousSide, nextSide)) {
      return _midArcSplitAngle(primitive);
    }

    final distancePoint = _buildCornerSplitPointInDistanceSpace(
      previousSideIndex,
      oPrev,
      oNext,
    );
    return primitive.angleForDistancePoint(distancePoint);
  }

  Offset _buildCornerSplitPointInDistanceSpace(
      int previousSideIndex,
      double oPrev,
      double oNext,
      ) {
    final corner = _cornerAfter(previousSideIndex);
    if (!_cornerCanRound(previousSideIndex, corner, oPrev, oNext)) {
      return Offset(oPrev, oNext);
    }

    final previous = _sideAt(previousSideIndex);
    final next = _sideAt(previousSideIndex + 1);

    final lineStart = Offset(-previous.outside, -next.outside);
    final lineEnd = Offset(previous.inside, next.inside);
    final direction = lineEnd - lineStart;
    if (_nearZero(direction.distance)) {
      return Offset(oPrev, oNext);
    }

    final primitive = _primitiveForCornerOffsets(
      previousSideIndex,
      oPrev: oPrev,
      oNext: oNext,
    );
    final a = primitive.beforeRadius;
    final b = primitive.afterRadius;
    if (a <= _epsilon || b <= _epsilon) {
      return Offset(oPrev, oNext);
    }

    final center = primitive.localCenter;
    final centerX = center.dx;
    final centerY = center.dy;
    final x0 = lineStart.dx - centerX;
    final y0 = lineStart.dy - centerY;
    final ux = direction.dx;
    final uy = direction.dy;

    final qa = ((ux * ux) / (a * a)) + ((uy * uy) / (b * b));
    final qb = 2.0 * (((x0 * ux) / (a * a)) + ((y0 * uy) / (b * b)));
    final qc = ((x0 * x0) / (a * a)) + ((y0 * y0) / (b * b)) - 1.0;

    if (_nearZero(qa)) {
      return Offset(oPrev, oNext);
    }

    final discriminant = max(0.0, (qb * qb) - (4.0 * qa * qc));
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
      final angle = primitive.angleForDistancePoint(candidate);
      final projected = primitive.localPointAtAngle(angle);
      if ((projected - candidate).distance > 1.0e-4) {
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

    final centeredPoint = lineStart + direction.scaled(chosenRoot);
    return Offset(
      previous.actualOffsetForCentered(centeredPoint.dx),
      next.actualOffsetForCentered(centeredPoint.dy),
    );
  }

  double _expectedInterpolationT(
      _ResolvedSide previous,
      _ResolvedSide next,
      double oPrev,
      double oNext,
      ) {
    if (previous.hasWidth) {
      final t = (oPrev + previous.outside) / previous.side.width;
      if (t < 0.0) return 0.0;
      if (t > 1.0) return 1.0;
      return t;
    }

    if (next.hasWidth) {
      final t = (oNext + next.outside) / next.side.width;
      if (t < 0.0) return 0.0;
      if (t > 1.0) return 1.0;
      return t;
    }

    return 0.5;
  }

  Offset _pointFromDistanceCoordinates(
      _ResolvedCorner corner,
      double dPrev,
      double dNext,
      ) {
    if (corner.isParallel) {
      final previousPoint =
          corner.previousSide.end + corner.previousSide.insideNormal.scaled(dPrev);
      final nextPoint =
          corner.nextSide.start + corner.nextSide.insideNormal.scaled(dNext);
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

  ContourPathPlan _concatenateOpenPlans(List<ContourPathPlan> plans) {
    final builder = ContourPathPlanBuilder();
    for (final plan in plans) {
      _appendOpenPlan(builder, plan);
    }
    return builder.build(close: false);
  }

  void _appendOpenPlan(ContourPathPlanBuilder builder, ContourPathPlan plan) {
    if (plan.isEmpty) {
      return;
    }

    if (builder.isEmpty) {
      builder.addNode(plan.firstNode);
    } else {
      builder.addLineTo(plan.firstNode);
    }

    for (final edge in plan.edges) {
      if (edge is LineContourEdge) {
        builder.addLineTo(edge.to);
      } else if (edge is CornerContourEdge) {
        builder.addCornerTo(
          edge.to,
          corner: edge.corner,
          t0: edge.t0,
          t1: edge.t1,
        );
      } else {
        throw StateError('Unsupported contour edge type: ${edge.runtimeType}.');
      }
    }
  }

  ContourPathPlan _reverseOpenPlan(ContourPathPlan plan) {
    if (plan.isClosed) {
      throw ArgumentError("Closed contour plans can't be reversed as open plans.");
      }

      if (plan.isEmpty) {
        return plan;
      }

      final reversedNodes = plan.nodes.reversed.toList(growable: false);
      final reversedEdges = <ContourEdge>[];

      for (final edge in plan.edges.reversed) {
        if (edge is LineContourEdge) {
          reversedEdges.add(LineContourEdge(edge.to, edge.from));
        } else if (edge is CornerContourEdge) {
          reversedEdges.add(
            CornerContourEdge(
              from: edge.to,
              to: edge.from,
              corner: edge.corner,
              t0: edge.t1,
              t1: edge.t0,
            ),
          );
        } else {
          throw StateError('Unsupported contour edge type: ${edge.runtimeType}.');
        }
      }

      return ContourPathPlan(
        nodes: reversedNodes,
        edges: reversedEdges,
        isClosed: false,
      );
    }

  Path _pathFromPlan(ContourPathPlan plan) {
    final path = Path();
    _appendPlanToPath(path, plan);
    return path;
  }

  void _appendPlanToPath(Path path, ContourPathPlan plan) {
    if (plan.isEmpty) {
      return;
    }

    final first = plan.firstNode.point;
    path.moveTo(first.dx, first.dy);

    for (final edge in plan.edges) {
      if (edge.isDegenerate) {
        continue;
      }

      if (edge is LineContourEdge) {
        path.lineTo(edge.to.point.dx, edge.to.point.dy);
        continue;
      }

      if (edge is CornerContourEdge) {
        for (final segment in edge.corner.conicSegments(
          fromAngle: edge.t0,
          toAngle: edge.t1,
        )) {
          path.conicTo(
            segment.control.dx,
            segment.control.dy,
            segment.end.dx,
            segment.end.dy,
            segment.weight,
          );
        }
        continue;
      }

      throw StateError('Unsupported contour edge type: ${edge.runtimeType}.');
    }

    if (plan.isClosed) {
      path.close();
    }
  }
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

  final double blurRadius;
  final double spreadRadius;
  final Offset offset;
  final BlurStyle style;

  const AnyShadow({
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.blurRadius = 0.0,
    this.offset = Offset.zero,
    this.spreadRadius = 0.0,
    this.style = BlurStyle.normal,
  });


  @override
  bool operator ==(Object other) {

    if (identical(this, other)) {
      return true;
    }

    return other is AnyShadow &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.blurRadius == blurRadius &&
        other.offset == offset &&
        other.spreadRadius == spreadRadius &&
        other.style == style;
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
    style,
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

  final bool isAntiAlias;

  const AnyDecoration({
    this.shadows = const [],
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.clip = AnyShapeBase.zeroBorder,
    this.background = AnyShapeBase.zeroBorder,
    this.isAntiAlias = true,
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


  @override
  bool operator ==(Object other) {
    return other is AnyDecoration &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.clip == clip &&
        other.background == background &&
        listEquals(other.shadows, shadows)
    ;
  }

  @override
  int get hashCode => Object.hash(color, gradient, image, blendMode, clip, background, Object.hashAll(shadows));

}

class _AnyDecorationPainter extends BoxPainter {

  _AnyDecorationPainter(this.decoration, super.onChanged);

  final AnyDecoration decoration;
  final Map<DecorationImage, DecorationImagePainter> _imagePainters = <DecorationImage, DecorationImagePainter>{};

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    final List<AnyShadow> innerShadows = [];
    final List<AnyShadow> otherShadows = [];
    for (var shadow in decoration.shadows) {
      ( shadow.style == BlurStyle.inner ? innerShadows : otherShadows ).add(shadow);
    }

    final rect = offset & size;
    final (shape, setup) = decoration.polygon(rect, configuration.textDirection);
    final regions = shape.buildMergedStrokeRegions(
      setup,
      backgroundMerge: innerShadows.isEmpty
    );

    final backgroundKey = setup.background.keys.firstOrNull;
    StrokeRegion? backgroundRegion;
    Path? shadowPath;

    if (backgroundKey != null) {

      backgroundRegion = regions.firstWhereOrNull((r) => r.included.contains(backgroundKey));

      if (backgroundRegion?.included.length == 1) {
        shadowPath = backgroundRegion!.path;
      }
    }

    if (decoration.shadows.isNotEmpty) {

      if (shadowPath == null) {
        shadowPath = shape.buildMergedStrokeRegions(
            setup,
            backgroundOnly: true,
            backgroundBase: decoration.background
        ).first.path;
      }

      shadowPath = shadowPath.shift(offset);
    }

    for (var shadow in otherShadows) {
      _paintShadow(canvas, shadow, shadowPath!, configuration);
    }

    if (backgroundRegion != null && backgroundRegion.hasFill) {
      final path = backgroundRegion.path.shift(offset);
      _paintRegion(canvas, backgroundRegion.fill, path, configuration);
    }

    for (var shadow in innerShadows) {
      _paintShadow(canvas, shadow, shadowPath!, configuration);
    }

    for (final region in regions) {
      if (backgroundRegion == region || !region.hasFill) continue;
      final path = region.path.shift(offset);
      _paintRegion(canvas, region.fill, path, configuration);
    }
  }

  void _paintRegion(
      Canvas canvas,
      IAnyFill fill,
      Path path,
      ImageConfiguration configuration,
      ) {

    final bounds = path.getBounds();

    if (fill.color != null || fill.gradient != null) {

      final paint = Paint()
        ..isAntiAlias = decoration.isAntiAlias;

      if (fill.blendMode != null) {
        paint.blendMode = fill.blendMode!;
      }

      if (fill.gradient != null) {
        paint.shader = fill.gradient!.createShader(bounds, textDirection: configuration.textDirection);
      } else if (fill.color != null) {
        paint.color = fill.color!;
      }

      canvas.drawPath(path, paint);
    }

    if (fill.image != null) {
      final painterCallback = onChanged;
      final imagePainter = _imagePainters.putIfAbsent(
        fill.image!,
            () => fill.image!.createPainter(painterCallback!),
      );
      imagePainter.paint(canvas, bounds, path, configuration);
    }
  }

  void _paintShadow(Canvas canvas,
      AnyShadow shadow,
      Path path,
      ImageConfiguration configuration,
      ) {

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
