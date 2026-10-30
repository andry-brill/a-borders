import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'any_decoration_cache.dart';
import 'any_fill.dart';
import 'any_shadow.dart';
import 'src/utils.dart';
import 'src/geometry_diagnostics.dart' as diagnostics;

import 'src/geometry/core.dart';
import 'src/corners/rounded_corner.dart';

export 'src/geometry/core.dart' hide AnyContourTransition, AnyContourSample;
export 'src/corners/corner_converter.dart';
export 'src/corners/rounded_corner.dart';
export 'src/corners/bevel_corner.dart';
export 'src/corners/inverse_rounded_corner.dart';

part 'src/decoration_tween.dart';
part 'src/decoration_construction.dart';

/// Fill painted behind the side regions of an [AnyDecoration].
class AnyBackground with MAnyFill {
  /// Contour band used to build the background path.
  final AnyShapeBase shapeBase;

  /// Solid color used as the background base fill.
  @override
  final Color? color;

  /// Gradient used as the background base fill.
  @override
  final Gradient? gradient;

  /// Image painted into the background path.
  @override
  final DecorationImage? image;

  /// Blend mode applied to the background base fill.
  @override
  final BlendMode? blendMode;

  /// Whether the background path should be anti-aliased.
  @override
  final bool isAntiAlias;

  const AnyBackground({
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.isAntiAlias = true,
    this.shapeBase = AnyShapeBase.shapeBorder,
  });

  AnyBackground copyWith({
    AnyShapeBase? shapeBase,
    Color? color,
    Gradient? gradient,
    DecorationImage? image,
    BlendMode? blendMode,
    bool? isAntiAlias,
  }) {
    return AnyBackground(
      shapeBase: shapeBase ?? this.shapeBase,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      image: image ?? this.image,
      blendMode: blendMode ?? this.blendMode,
      isAntiAlias: isAntiAlias ?? this.isAntiAlias,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AnyBackground &&
        other.shapeBase == shapeBase &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.isAntiAlias == isAntiAlias;
  }

  @override
  int get hashCode => Object.hash(
        shapeBase,
        color,
        gradient,
        image,
        blendMode,
        isAntiAlias,
      );

  static AnyBackground? lerp(
    AnyBackground? a,
    AnyBackground? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    if (a == null || b == null) return AnyUtils.pickLerpNullable(a, b, t);

    return AnyBackground(
      color: Color.lerp(a.color, b.color, t),
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
      image: AnyUtils.pickLerpNullable(a.image, b.image, t),
      blendMode: AnyUtils.pickLerpNullable(a.blendMode, b.blendMode, t),
      isAntiAlias: AnyUtils.pickLerp(a.isAntiAlias, b.isAntiAlias, t),
      shapeBase: AnyUtils.pickLerp(a.shapeBase, b.shapeBase, t),
    );
  }
}

/// Base class for borders built for [AnyDecoration].
class AnyBorder {
  /// Default side used by [AnyDecoration.point].
  final AnySide sides;

  /// Default source-shape corner used by [AnyDecoration.point].
  final AnyCorner corners;

  /// Default explicit outer corner; null derives it from the shape.
  final AnyCorner? outerCorners;

  /// Default explicit inner corner; null derives it from the shape.
  final AnyCorner? innerCorners;

  /// Optional width / height ratio fitted inside offset-adjusted bounds.
  /// Null/nonpositive values use all available bounds.
  final double? ratio;

  /// Construction-bounds adjustment before ratio fitting, added to
  /// [AnyDecoration.offset], in logical units.
  /// Negative values inset; positive values outset. Must be finite.
  final double offset;

  const AnyBorder({
    AnySide? sides,
    AnyCorner? corners,
    this.outerCorners,
    this.innerCorners,
    this.ratio,
    this.offset = 0.0,
  })  : sides = sides ?? const AnySide(),
        corners = corners ?? const RoundedCorner();

  /// Selected sides in a stable logical construction order.
  ///
  /// The base border has one shared side. Shape-specific borders override this
  /// to resolve their side defaults; box borders use top, right, bottom, left.
  /// These slots need not correspond one-to-one with contour points.
  List<AnySide> get resolvedSides => List<AnySide>.unmodifiable([sides]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyBorder &&
        other.runtimeType == runtimeType &&
        other.ratio == ratio &&
        other.offset == offset &&
        other.sides == sides &&
        other.corners == corners &&
        other.outerCorners == outerCorners &&
        other.innerCorners == innerCorners;
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        ratio,
        offset,
        sides,
        corners,
        outerCorners,
        innerCorners,
      );
}

/// Base class for decorations built from arbitrary contour points.
///
/// Subclasses define their geometry by overriding [buildPoints]. They must also
/// override [operator ==] and [hashCode] when they add fields, because contour
/// caching is keyed by decoration equality.
abstract class AnyDecoration extends Decoration {
  /// Adjust raw construction bounds before ratio fitting.
  /// Positive offsets expand; negative offsets inset. The scalar [offset]
  /// already combines decoration and border values. Use the supplied current
  /// [sideOffsets], including during animation, rather than authored values.
  /// The default supports zero slots or one shared slot. Other layouts must
  /// override this hook. Return crossed/empty bounds when an inset exhausts
  /// the available area; do not normalize them or fit corners here.
  @protected
  Rect adjustBounds(Rect layoutBounds, TextDirection? textDirection,
      AnyBorder border, double offset, List<double> sideOffsets) {
    if (sideOffsets.length > 1) {
      throw UnsupportedError(
          'Multiple side slots require an adjustBounds override.');
    }
    final side = sideOffsets.isEmpty ? 0.0 : sideOffsets.single;
    return AnyUtils.displaceBox(layoutBounds, offset,
        top: side, right: side, bottom: side, left: side);
  }

  /// Build points from already adjusted, ratio-fitted [bounds].
  /// Never displace these bounds again. Carry current [sideOffsets] in the
  /// corresponding AnySide metadata, and forward [border] to [point].
  @protected
  List<AnyPoint> buildPoints(
    Rect bounds,
    TextDirection? textDirection,
    AnyBorder border,
    List<double> sideOffsets,
  );

  /// Authored side-offset slots for construction-time tween interpolation.
  ///
  /// Defaults to offsets from the selected border's [AnyBorder.resolvedSides].
  /// Box and tab builders therefore share top, right, bottom, left slots.
  /// Override this when the decoration uses different construction sides or
  /// ordering. Slots must have a stable logical order and are supplied to
  /// [buildPoints] for both ordinary construction and animation. An empty list
  /// describes a shape with no side-offset slots. Discovery receives raw layout
  /// bounds, before adjustment and fitting. Slot count/order must remain stable
  /// for a shape configuration across layouts.
  @protected
  List<double> sideOffsetsForBorder(
    Rect bounds,
    TextDirection? textDirection,
    AnyBorder border,
  ) =>
      border.resolvedSides.map((side) => side.offset).toList(growable: false);

  /// Build a layer's points from raw layout [bounds], applying offsets and
  /// ratio fitting exactly once. Nonzero rectangle origins are preserved.
  @nonVirtual
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection,
      {int? borderIndex}) {
    final index = borderIndex ?? primaryBorderIndex;
    _validateBorders();
    RangeError.checkValidIndex(index, borders, 'borderIndex');
    return _construct(bounds, textDirection, index).points;
  }

  _LayerRecipe _recipe(_ConstructionContext context) {
    final selected = borders[context.index];
    final layoutBounds = context.bounds, direction = context.direction;
    return _LayerRecipe(
      sideOffsetsForBorder(layoutBounds, direction, selected),
      (offset, slots) =>
          adjustBounds(layoutBounds, direction, selected, offset, slots),
      (_) => selected.ratio,
      (bounds, slots) =>
          AnyContourSample(buildPoints(bounds, direction, selected, slots)),
    );
  }

  AnyContourSample _construct(
      Rect layoutBounds, TextDirection? direction, int index) {
    AnyUtils.validateBounds(layoutBounds);
    final recipe =
        _ConstructionContext(layoutBounds, direction, index).recipe(this);
    final available =
        recipe.adjust(offset + borders[index].offset, recipe.slots);
    if (available.isEmpty) return AnyContourSample(const []);
    final fitted = AnyUtils.fitRatio(available, recipe.ratio(available));
    if (fitted.isEmpty) return AnyContourSample(const []);
    return recipe.build(fitted, recipe.slots);
  }

  /// Fill painted behind side regions.
  final AnyBackground? background;

  final AnyBorder? _singleBorder;
  final List<AnyBorder>? _multipleBorders;

  /// Borders in paint order. Later borders paint over earlier borders.
  /// Lists passed to the const constructor must not be mutated afterwards.
  List<AnyBorder> get borders =>
      UnmodifiableListView(_multipleBorders ?? [_singleBorder!]);

  /// Border supplying background, clipping, and shadow boundaries.
  final int primaryBorderIndex;

  /// Convenience access to the primary border.
  AnyBorder get border {
    _validateBorders();
    return borders[primaryBorderIndex];
  }

  /// Shadows painted from [shadowBase].
  final List<AnyShadow> shadows;

  /// Contour band returned by [getClipPath].
  final AnyShapeBase clipBase;

  /// Contour band used as the source path for shadows.
  final AnyShapeBase shadowBase;

  /// Whether built contours should be cached by decoration, size, and text direction.
  final bool enableCache;

  /// Construction-bounds adjustment added to each border's offset before
  /// ratio fitting, in logical units. This does not change widget layout.
  /// Negative values inset; positive values outset. Must be finite.
  final double offset;

  const AnyDecoration({
    this.shadows = const [],
    this.background,
    this.clipBase = AnyShapeBase.shapeBorder,
    this.shadowBase = AnyShapeBase.shapeBorder,
    this.enableCache = true,
    this.offset = 0.0,
    AnyBorder border = const AnyBorder(),
  })  : _singleBorder = border,
        _multipleBorders = null,
        primaryBorderIndex = 0;

  /// Paints independent border layers, using [primaryBorderIndex] for paths.
  /// [borders] must be nonempty and must not be mutated after construction.
  /// List-dependent validation occurs before point or contour construction,
  /// because Dart const assertions cannot evaluate a list's length.
  const AnyDecoration.multi({
    required List<AnyBorder> borders,
    this.primaryBorderIndex = 0,
    this.shadows = const [],
    this.background,
    this.clipBase = AnyShapeBase.shapeBorder,
    this.shadowBase = AnyShapeBase.shapeBorder,
    this.enableCache = true,
    this.offset = 0.0,
  })  : assert(primaryBorderIndex >= 0),
        _singleBorder = null,
        _multipleBorders = borders;

  void _validateBorders() {
    if (!offset.isFinite) {
      throw ArgumentError.value(offset, 'offset', 'Must be finite');
    }
    final count = _multipleBorders?.length ?? 1;
    if (count == 0) {
      throw ArgumentError.value(
          _multipleBorders, 'borders', 'Must not be empty');
    }
    RangeError.checkValidIndex(primaryBorderIndex,
        _multipleBorders ?? [_singleBorder!], 'primaryBorderIndex');
    for (final border in _multipleBorders ?? [_singleBorder!]) {
      if (!border.offset.isFinite || !(offset + border.offset).isFinite) {
        throw ArgumentError(
            'Border offsets and combined offsets must be finite.');
      }
    }
  }

  /// Builds an [AnyPoint] using the supplied [border] for missing values.
  AnyPoint point(
    Offset point, {
    required AnyBorder border,
    AnyCorner? shape,
    AnyCorner? outer,
    AnyCorner? inner,
    AnySide? side,
    bool skip = false,
  }) {
    return AnyPoint(
      point: point,
      shape: shape ?? border.corners,
      outer: outer ?? border.outerCorners,
      inner: inner ?? border.innerCorners,
      side: side ?? border.sides,
      skip: skip,
    );
  }

  // Every entry point constructs from raw layout bounds. Recipes preserve
  // the original raw context through nested tween samples.
  AnyContour _buildContourForBorder(
          Rect bounds, TextDirection? textDirection, int index) =>
      _construct(bounds, textDirection, index).contour(
        background: index == primaryBorderIndex ? background : null,
        backgroundBase: background?.shapeBase ?? AnyShapeBase.shapeBorder,
        clipBase: clipBase,
        shadowBase: shadowBase,
      );

  /// Builds all contours in paint order, sharing one cache entry.
  List<AnyContour> buildContours(Size size, TextDirection? textDirection) {
    _validateBorders();
    late final AnyDecorationCacheKey key;
    if (enableCache) {
      key = (this, size, textDirection);
      final cached = AnyDecorationCache.get(key);
      if (cached != null) {
        return cached;
      }
    }

    final contours = List<AnyContour>.unmodifiable(
      List<AnyContour>.generate(
          borders.length,
          (index) =>
              _buildContourForBorder(Offset.zero & size, textDirection, index)),
    );

    if (enableCache) {
      AnyDecorationCache.put(key, contours);
      return AnyDecorationCache.get(key) ?? contours;
    }
    return contours;
  }

  /// Builds the primary contour. Use [buildContours] to inspect every layer.
  AnyContour buildContour(Size size, TextDirection? textDirection) =>
      buildContours(size, textDirection)[primaryBorderIndex];

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _AnyDecorationPainter(this, onChanged);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    final contour = buildContour(rect.size, textDirection);
    return contour.shiftedClipPath(rect.topLeft);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyDecoration &&
        other.runtimeType == runtimeType &&
        other.shadowBase == shadowBase &&
        other.clipBase == clipBase &&
        other.enableCache == enableCache &&
        other.offset == offset &&
        other.background == background &&
        other.primaryBorderIndex == primaryBorderIndex &&
        listEquals(other.borders, borders) &&
        listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        clipBase,
        shadowBase,
        enableCache,
        offset,
        background,
        primaryBorderIndex,
        Object.hashAll(borders),
        Object.hashAll(shadows),
      );
}

class _AnyDecorationPainter extends BoxPainter {
  _AnyDecorationPainter(this.decoration, super.onChanged);

  final AnyDecoration decoration;
  final Map<DecorationImage, DecorationImagePainter> _imagePainters =
      <DecorationImage, DecorationImagePainter>{};

  DecorationImagePainter? painterOf(AnyFill fill) {
    if (fill.image == null) return null;
    return _imagePainters.putIfAbsent(
      fill.image!,
      () => fill.image!.createPainter(onChanged ?? () {}),
    );
  }

  @override
  void paint(Canvas canvas, Offset topLeft, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    final innerShadows = <AnyShadow>[];
    final otherShadows = <AnyShadow>[];
    for (final shadow in decoration.shadows) {
      if (!shadow.hasFill) continue;
      if (shadow.style == BlurStyle.inner) {
        innerShadows.add(shadow);
      } else {
        otherShadows.add(shadow);
      }
    }

    final contours =
        decoration.buildContours(size, configuration.textDirection);
    final contour = contours[decoration.primaryBorderIndex];
    final layerRegions = contours
        .map((layer) => layer.shiftedRegions(
              offset: topLeft,
              backgroundMerge: contours.length == 1 && innerShadows.isEmpty,
            ))
        .toList(growable: false);
    final regions = layerRegions[decoration.primaryBorderIndex];

    final backgroundRegion = regions.background;

    Path? shadowPath;
    if (innerShadows.isNotEmpty || otherShadows.isNotEmpty) {
      shadowPath = contour.shiftedShadowPath(topLeft);
    }

    for (final shadow in otherShadows) {
      shadow.paint(canvas, shadowPath!, configuration, painterOf);
    }

    if (backgroundRegion != null && backgroundRegion.$1.hasFill) {
      _paintRegion(
        canvas,
        backgroundRegion.$1,
        backgroundRegion.$2,
        configuration,
      );
    }

    for (final shadow in innerShadows) {
      shadow.paint(canvas, shadowPath!, configuration, painterOf);
    }

    for (final layer in layerRegions) {
      final regions = layer.regions.where((r) => r.$1.hasFill).toList();
      final combineCoverage = regions.length > 1 &&
          regions.every((r) =>
              r.$1.blendMode == null || r.$1.blendMode == BlendMode.srcOver);
      if (combineCoverage) {
        // Adjacent antialiased masks describe disjoint subpixel coverage.
        // Accumulate their premultiplied colors before compositing the layer;
        // source-over on each mask separately creates translucent seams.
        final bounds = regions
            .map((r) => r.$2.getBounds())
            .reduce((a, b) => a.expandToInclude(b));
        canvas.saveLayer(bounds, Paint());
        assert(diagnostics.record(diagnostics.GeometryWork.layer));
        for (final region in regions) {
          final fill = region.$1, path = region.$2, bounds = path.getBounds();
          if (bounds.isEmpty) continue;
          if (!diagnostics.legacyPainter &&
              fill.runtimeType == AnySide &&
              fill.image == null) {
            // A built-in base fill is one draw: accumulate its premultiplied
            // coverage directly. Images/custom fills retain grouped rendering.
            final paint = fill.createBasePaint(path, configuration);
            if (paint != null) {
              canvas.drawPath(path, paint..blendMode = BlendMode.plus);
            }
            continue;
          }
          canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.plus);
          assert(diagnostics.record(diagnostics.GeometryWork.layer));
          _paintRegion(canvas, fill, path, configuration);
          canvas.restore();
        }
        canvas.restore();
      } else {
        for (final region in regions) {
          _paintRegion(canvas, region.$1, region.$2, configuration);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final painter in _imagePainters.values) {
      painter.dispose();
    }
    _imagePainters.clear();
    super.dispose();
  }

  void _paintRegion(
    Canvas canvas,
    AnyFill fill,
    Path path,
    ImageConfiguration configuration,
  ) {
    final imagePainter = painterOf(fill);
    if (imagePainter != null) {
      imagePainter.paint(canvas, path.getBounds(), path, configuration);
    }

    final paint = fill.createBasePaint(path, configuration);
    if (paint != null) {
      canvas.drawPath(path, paint);
    }
  }
}
