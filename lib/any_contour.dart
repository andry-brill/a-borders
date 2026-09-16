import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'any_decoration_cache.dart';
import 'any_fill.dart';
import 'any_shadow.dart';
import 'any_utils.dart';
import 'src/geometry_diagnostics.dart' as diagnostics;
import 'src/point_offset.dart';

import 'src/geometry/core.dart';
import 'src/corners/rounded_corner.dart';
export 'src/geometry/core.dart' hide AnyContourTransition;
export 'src/corners/corner_converter.dart';
export 'src/corners/rounded_corner.dart';
export 'src/corners/bevel_corner.dart';
export 'src/corners/inverse_rounded_corner.dart';

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

  /// Optional width / height ratio used to fit the contour inside the paint size.
  final double? ratio;

  /// Path displacement in logical units, added to [AnyDecoration.offset].
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
  /// Build contour points for [borderIndex] from the fitted [bounds].
  /// [offset] is the combined decoration and border displacement: positive
  /// outward, negative inward. Apply it to the outline before assigning corners.
  /// Forward [borderIndex] to [point] for layer defaults. Return an empty list
  /// when the inset exhausts the outline.
  @protected
  List<AnyPoint> buildPoints(
    Rect bounds,
    TextDirection? textDirection,
    int borderIndex,
    double offset,
  );

  @nonVirtual
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection,
      {int? borderIndex}) {
    final index = borderIndex ?? primaryBorderIndex;
    _validateBorders();
    RangeError.checkValidIndex(index, borders, 'borderIndex');
    return buildPoints(
        bounds, textDirection, index, offset + borders[index].offset);
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

  /// Path displacement added to each border's offset, in logical units.
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

  /// Builds an [AnyPoint] using decoration defaults for missing values.
  AnyPoint point(
    Offset point, {
    required int borderIndex,
    AnyCorner? shape,
    AnyCorner? outer,
    AnyCorner? inner,
    AnySide? side,
    bool skip = false,
  }) {
    final selectedBorder = borders[borderIndex];
    return AnyPoint(
      point: point,
      shape: shape ?? selectedBorder.corners,
      outer: outer ?? selectedBorder.outerCorners,
      inner: inner ?? selectedBorder.innerCorners,
      side: side ?? selectedBorder.sides,
      skip: skip,
    );
  }

  /// Move a polygon's straight edges by [offset] and intersect adjacent lines.
  /// Corner and side settings are retained; resolution happens afterwards.
  /// Supports either winding and straight helper vertices. The offset must
  /// preserve the polygon's edges, or completely exhaust a convex polygon.
  /// For disappearing edges, split outlines or reversing helpers, implement
  /// the shape's construction rules directly in [buildPoints].
  @protected
  List<AnyPoint> offsetPoints(List<AnyPoint> points, double offset) =>
      offsetContourPoints(points, offset);

  Rect fitRatio(Size size, double? ratio) {
    if (ratio == null || ratio <= 0.0) {
      return Offset.zero & size;
    }

    var width = size.width;
    var height = width / ratio;

    if (height > size.height) {
      height = size.height;
      width = height * ratio;
    }

    return Rect.fromLTWH(
      (size.width - width) / 2.0,
      (size.height - height) / 2.0,
      width,
      height,
    );
  }

  /// Bounds for a layer, fitted independently using that border's ratio.
  @protected
  Rect boundsForBorder(Size size, int borderIndex) =>
      fitRatio(size, borders[borderIndex].ratio);

  /// Construct one fitted layer. Tweens specialize this to evaluate prepared
  /// boundary transitions; ordinary decorations only need [buildPoints].
  @protected
  AnyContour buildContourForBorder(
          Rect bounds, TextDirection? textDirection, int index) =>
      AnyContour(
        points: points(bounds, textDirection, borderIndex: index),
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
          (index) => buildContourForBorder(
              boundsForBorder(size, index), textDirection, index)),
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
