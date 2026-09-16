import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../../any_fill.dart';
import '../../any_utils.dart';
import '../geometry_diagnostics.dart' as diagnostics;
import 'math.dart';

part 'corner_contract.dart';
part 'corner_curves.dart';
part 'contour_engine.dart';

enum AnyShapeBase {
  /// Legacy zero-offset boundary derived from the outer border corners.
  zeroBorder,

  /// Contour built on the outer edge of side widths.
  outerBorder,

  /// Contour built on the inner edge of side widths.
  innerBorder,

  /// Source boundary defined directly by shape corners, before borders.
  shapeBorder,
}

/// Fill and geometry for one contour side.
///
/// Sides are assigned to [AnyPoint] entries and are painted between that point
/// and the next point in the contour.
class AnySide with MAnyFill {
  /// Places the full side width inside the source contour.
  static const double alignInside = -1;

  /// Centers the side width on the source contour.
  static const double alignCenter = 0;

  /// Places the full side width outside the source contour.
  static const double alignOutside = 1;

  /// Stroke width for this side.
  final double width;

  /// Align means align relative to the corresponding side, not the whole shape.
  final double align;

  /// Solid color used as the side base fill.
  @override
  final Color? color;

  /// Gradient used as the side base fill.
  @override
  final Gradient? gradient;

  /// Image painted into the side path.
  @override
  final DecorationImage? image;

  /// Blend mode applied to the side base fill.
  @override
  final BlendMode? blendMode;

  /// Whether side paths should be anti-aliased.
  @override
  final bool isAntiAlias;

  const AnySide({
    this.width = 0.0,
    this.align = alignInside,
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.isAntiAlias = true,
  })  : assert(width >= 0.0),
        assert(align >= alignInside && align <= alignOutside);

  AnySide copyWith({
    double? width,
    double? align,
    Color? color,
    Gradient? gradient,
    DecorationImage? image,
    BlendMode? blendMode,
    bool? isAntiAlias,
  }) {
    return AnySide(
      width: width ?? this.width,
      align: align ?? this.align,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      image: image ?? this.image,
      blendMode: blendMode ?? this.blendMode,
      isAntiAlias: isAntiAlias ?? this.isAntiAlias,
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
        other.blendMode == blendMode &&
        other.isAntiAlias == isAntiAlias;
  }

  @override
  int get hashCode => Object.hash(
        width,
        align,
        color,
        gradient,
        image,
        blendMode,
        isAntiAlias,
      );

  static AnySide lerp(AnySide a, AnySide b, double t) {
    return AnySide(
      width: lerpDouble(a.width, b.width, t)!,
      align: lerpDouble(a.align, b.align, t)!,
      color: Color.lerp(a.color, b.color, t),
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
      image: AnyUtils.pickLerpNullable(a.image, b.image, t),
      blendMode: AnyUtils.pickLerpNullable(a.blendMode, b.blendMode, t),
      isAntiAlias: AnyUtils.pickLerp(a.isAntiAlias, b.isAntiAlias, t),
    );
  }
}

/// One source point in an `AnyDecoration` contour.
///
/// The point defines a vertex of the contour. Its required [shape] and optional
/// [outer] and [inner]
/// corners describe how the contour bends at this point, while [side] describes
/// the border segment painted from this point to the next point.
class AnyPoint {
  /// Corner of the source shape, independent of side widths and alignment.
  final AnyCorner shape;

  /// Corner used for the outer contour band at this point.
  /// When omitted, it is derived from [shape].
  final AnyCorner? outer;

  /// Optional corner used for the inner contour band at this point.
  ///
  /// When null, the contour derives an inner corner directly from [shape]
  /// and the adjacent inside offsets.
  final AnyCorner? inner;

  /// Vertex position in local decoration coordinates.
  final Offset point;

  /// Side painted from this point to the next contour point.
  final AnySide side;

  /// Whether this point should be ignored when building the contour geometry.
  ///
  /// This lets decorations keep a stable point list for interpolation while
  /// avoiding zero-length sides when a point collapses onto a neighbor.
  final bool skip;

  /// Creates a contour point with explicit geometry and side data.
  const AnyPoint({
    required this.shape,
    this.outer,
    this.inner,
    required this.point,
    required this.side,
    this.skip = false,
  });

  /// Linearly interpolates two point lists for `AnyDecorationTween`.
  ///
  /// If the lists have different lengths, one list is picked based on [t]
  /// because point-by-point interpolation is not possible.
  static List<AnyPoint>? lerp(List<AnyPoint>? a, List<AnyPoint>? b, double t) {
    if (a == null || b == null) return null;
    if (identical(a, b)) return a;
    if (a.length != b.length) return AnyUtils.pickLerp(a, b, t);

    AnyCorner? lerpOptional(AnyCorner? a, AnyCorner? b) {
      if (a == null && b == null) return null;
      if (a == null || b == null) return AnyUtils.pickLerpNullable(a, b, t);
      return AnyCorner.lerp(a, b, t);
    }

    return List<AnyPoint>.generate(a.length, (index) {
      final pa = a[index];
      final pb = b[index];

      return AnyPoint(
        point: Offset.lerp(pa.point, pb.point, t)!,
        shape: AnyCorner.lerp(pa.shape, pb.shape, t),
        outer: lerpOptional(pa.outer, pb.outer),
        inner: lerpOptional(pa.inner, pb.inner),
        side: AnySide.lerp(pa.side, pb.side, t),
        skip: AnyUtils.pickLerp(pa.skip, pb.skip, t),
      );
    }, growable: false);
  }
}

class AnyRegions {
  final (AnyFill, Path)? background;
  final List<(AnyFill, Path)> regions;

  const AnyRegions({
    this.background,
    this.regions = const [],
  });

  AnyRegions withOffset(Offset offset) {
    return AnyRegions(
      background: background == null
          ? null
          : (background!.$1, background!.$2.shift(offset)),
      regions: regions
          .map((el) => (el.$1, el.$2.shift(offset)))
          .toList(growable: false),
    );
  }
}

/// Resolved geometry for one border layer. Local corner segments are retained
/// for inspection; [pathFor] returns the final, topology-correct filled area.
/// An empty point list represents an exhausted outline and produces empty paths.
class AnyContour {
  final AnyShapeBase shadowBase;
  final AnyShapeBase clipBase;
  final AnyShapeBase backgroundBase;
  final AnyFill? background;
  AnyContour(
      {required this.background,
      required this.backgroundBase,
      required this.clipBase,
      required this.shadowBase,
      required List<AnyPoint> points}) {
    _prepareGeometry(points.where((p) => !p.skip).toList());
  }

  late final int count;
  late final List<AnySide> sides;
  late final List<AnyCornerFrame> frames;
  late final List<AnyResolvedCorner> shapeCorners;
  late final List<AnyCorner?> _outerSettings;
  late final List<AnyCorner?> _innerSettings;
  late final List<AnyResolvedCorner> outerCorners =
      _resolveBand(_outerSettings, AnyShapeBase.outerBorder);
  late final List<AnyResolvedCorner> innerCorners =
      _resolveBand(_innerSettings, AnyShapeBase.innerBorder);
  late final List<AnyResolvedCorner> zeroCorners = _resolveZeroBand();
  late final List<double> sideInsideOffset;
  late final List<double> sideOutsideOffset;
  late final List<double> sideLength;
  late final List<bool> _explicitOuter;
  late final List<bool> _explicitInner;
  final Map<AnyShapeBase, Path> _paths = {};
  final Map<AnyShapeBase, bool> _directBands = {};
  final Map<List<AnyResolvedCorner>, bool> _simpleBands = Map.identity();
  final Map<(List<AnyResolvedCorner>, List<AnyResolvedCorner>), bool>
      _partitions = {};
  bool? _directPartition;
  List<Path>? _paintRegions;
  AnyRegions? _regionsMerged;
  AnyRegions? _regionsSeparate;

  int wrap(int index) => index % count;
  double offsetForBase(int side, AnyShapeBase base) => switch (base) {
        AnyShapeBase.innerBorder => sideInsideOffset[side],
        AnyShapeBase.outerBorder => -sideOutsideOffset[side],
        _ => 0,
      };

  /// A defensive copy of the final area, including empty or multiple contours.
  Path pathFor(AnyShapeBase base) => Path.from(_areaFor(base));
  Path get clipPath => pathFor(clipBase);
  Path get shadowPath => pathFor(shadowBase);
  Path? get backgroundPath => background == null || !background!.hasFill
      ? null
      : pathFor(backgroundBase);
  Path shiftedClipPath(Offset offset) => clipPath.shift(offset);
  Path shiftedShadowPath(Offset offset) => shadowPath.shift(offset);

  AnyRegions regions({required bool backgroundMerge}) => backgroundMerge
      ? _regionsMerged ??= _buildRegions(true)
      : _regionsSeparate ??= _buildRegions(false);
  AnyRegions shiftedRegions(
          {required Offset offset, required bool backgroundMerge}) =>
      regions(backgroundMerge: backgroundMerge).withOffset(offset);
}
