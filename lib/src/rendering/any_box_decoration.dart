import 'package:flutter/painting.dart';

import '../any_align.dart';
import '../any_decoration.dart';
import '../any_fill.dart';
import '../any_shadow.dart';
import '../geometry/any_border_geometry.dart';
import '../geometry/any_region.dart';

class AnyBoxDecoration extends AnyDecoration {
  const AnyBoxDecoration({
    required super.border,
    super.shadows,
    super.color,
    super.gradient,
    super.image,
    super.blendMode,
    super.clip,
    super.background,
  });

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
    return other is AnyBoxDecoration &&
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

  final AnyBoxDecoration decoration;
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
      canvas.drawShadow(path.shift(rawShadow.offset), rawShadow.color, rawShadow.blurRadius + rawShadow.spreadRadius, true);
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
      final imagePainter = _imagePainters.putIfAbsent(
        fill.image!,
        () => fill.image!.createPainter(onChanged!),
      );
      imagePainter.paint(canvas, rect, Path()..addRect(rect), configuration);
      canvas.restore();
    }
  }
}
