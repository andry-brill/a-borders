import 'package:flutter/painting.dart';

import 'any_align.dart';
import 'any_border.dart';
import 'any_fill.dart';
import 'any_shadow.dart';
import 'geometry/any_border_geometry.dart';
import 'geometry/any_region.dart';

enum AnyShapeBase {
  /// Shape of the element based on border corners but ignoring border side width.
  ///
  /// If a background and an outer border side share the same fill, the region
  /// builder may extend the background path to include that outside contribution.
  zeroBorder,

  /// Combining all outer paths of border sides into one contour.
  outerBorder,

  /// Combining all inner paths of border sides into one contour.
  innerBorder
}

class AnyDecoration extends Decoration with MAnyFill {
  static AnyShapeBase clipBase = AnyShapeBase.zeroBorder;
  static AnyShapeBase backgroundBase = AnyShapeBase.zeroBorder;

  /// Border defines shape of the decoration.
  final IAnyBorder border;

  final List<IAnyShadow>? shadows;

  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;

  final AnyShapeBase? _clip;
  AnyShapeBase get clip => _clip ?? clipBase;

  final AnyShapeBase? _background;
  AnyShapeBase get background => _background ?? backgroundBase;

  const AnyDecoration({
    required this.border,
    this.shadows,
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    AnyShapeBase? clip,
    AnyShapeBase? background,
  })  : _clip = clip,
        _background = background;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _AnyBoxPainter(this, onChanged);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    final geometry = AnyBorderGeometry.resolve(rect, border);
    return geometry.pathForShapeBase(clip);
  }

  @override
  bool operator ==(Object other) {
    return other is AnyDecoration &&
        other.border == border &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.clip == clip &&
        other.background == background;
  }

  @override
  int get hashCode => Object.hash(border, color, gradient, image, blendMode, clip, background);
}

class _AnyBoxPainter extends BoxPainter {
  _AnyBoxPainter(this.decoration, super.onChanged);

  final AnyDecoration decoration;
  final Map<DecorationImage, DecorationImagePainter> _imagePainters = <DecorationImage, DecorationImagePainter>{};

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    final rect = offset & size;
    final geometry = AnyBorderGeometry.resolve(rect, decoration.border);

    _paintShadows(canvas, geometry);

    final regions = geometry.buildVisibleRegions(decoration);
    for (final region in regions) {
      _paintRegion(canvas, region, rect, configuration);
    }
  }

  void _paintShadows(Canvas canvas, AnyBorderGeometry geometry) {
    final shadows = decoration.shadows;
    if (shadows == null || shadows.isEmpty) return;

    for (final rawShadow in shadows) {
      if (rawShadow is! AnyShadow) continue;
      final path = switch (rawShadow.align) {
        AnyAlign.inside => geometry.innerContour.toPath(),
        AnyAlign.center => geometry.baseContour.toPath(),
        AnyAlign.outside => geometry.outerContour.toPath(),
      };
      canvas.drawShadow(
        path.shift(rawShadow.offset),
        rawShadow.color,
        rawShadow.blurRadius + rawShadow.spreadRadius,
        true,
      );
    }
  }

  void _paintRegion(
      Canvas canvas,
      AnyRegion region,
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
      canvas.drawPath(region.path, paint);
    }

    if (fill.image != null) {
      canvas.save();
      canvas.clipPath(region.path);
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
