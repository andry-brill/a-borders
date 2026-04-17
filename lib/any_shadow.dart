
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart';

import 'any_fill.dart';
import 'any_utils.dart';

class AnyShadow with MAnyFill {
  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;
  @override
  final bool isAntiAlias;

  final double blurRadius;
  final Offset spreadRadius;
  final Offset offset;
  final BlurStyle style;

  const AnyShadow({
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.blurRadius = 0.0,
    this.offset = Offset.zero,
    this.spreadRadius = Offset.zero,
    this.style = BlurStyle.normal,
    this.isAntiAlias = true,
  });

  double get blurSigma => Shadow.convertRadiusToSigma(blurRadius);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyShadow &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.blurRadius == blurRadius &&
        other.offset == offset &&
        other.spreadRadius == spreadRadius &&
        other.style == style &&
        other.isAntiAlias == isAntiAlias;
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
    isAntiAlias,
  );


  void paint(
      Canvas canvas,
      Path path,
      ImageConfiguration configuration,
      DecorationImagePainter? Function(AnyFill) painterOf
      ) {

    var targetPath = path;

    if (spreadRadius != Offset.zero) {

      final bounds = targetPath.getBounds();
      final width = bounds.width;
      final height = bounds.height;
      if (width > AnyUtils.epsilon && height > AnyUtils.epsilon) {
        final scaleX = (width + spreadRadius.dx) / width;
        final scaleY = (height + spreadRadius.dy) / height;
        final cx = bounds.center.dx;
        final cy = bounds.center.dy;

        final matrix = Matrix4.identity()
          ..translateByDouble(cx, cy, 0, 1.0)
          ..scaleByDouble(scaleX, scaleY, 1.0, 1.0)
          ..translateByDouble(-cx, -cy, 0, 1.0);

        targetPath = targetPath.transform(matrix.storage);
      }

    }

    if (offset != Offset.zero) {
      targetPath = targetPath.shift(offset);
    }

    final imagePainter = painterOf(this);
    if (imagePainter != null) {

      void paintImageSource() {
        imagePainter.paint(
          canvas,
          targetPath.getBounds(),
          targetPath,
          configuration,
        );
      }

      final layerBounds = targetPath.getBounds().inflate(
        blurRadius > 0 ? blurRadius * 2.0 + 1.0 : 1.0,
      );

      final compositePaint = Paint()..isAntiAlias = isAntiAlias;
      if (blendMode != null) {
        compositePaint.blendMode = blendMode!;
      }

      final blurPaint = Paint();
      if (blurSigma > 0.0) {
        blurPaint.imageFilter = ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.decal,
        );
      }

      canvas.saveLayer(layerBounds, compositePaint);

      switch (style) {
        case BlurStyle.normal:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();
          break;
        case BlurStyle.inner:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();

          canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstIn);
          paintImageSource();
          canvas.restore();
          break;
        case BlurStyle.outer:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();

          canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstOut);
          paintImageSource();
          canvas.restore();
          break;
        case BlurStyle.solid:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();

          canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstOut);
          paintImageSource();
          canvas.restore();

          paintImageSource();
          break;
      }

      canvas.restore();
    }

    final paint = createBasePaint(targetPath, configuration);
    if (paint != null) {
      paint.maskFilter = MaskFilter.blur(style, blurSigma);
      canvas.drawPath(targetPath, paint);
    }
  }


  static AnyShadow lerp(AnyShadow a, AnyShadow b, double t) {
    return AnyShadow(
      color: Color.lerp(a.color, b.color, t),
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
      image: AnyUtils.pickLerpNullable(a.image, b.image, t),
      blendMode: AnyUtils.pickLerpNullable(a.blendMode, b.blendMode, t),
      blurRadius: lerpDouble(a.blurRadius, b.blurRadius, t)!,
      offset: Offset.lerp(a.offset, b.offset, t)!,
      spreadRadius: Offset.lerp(a.spreadRadius, b.spreadRadius, t)!,
      style: AnyUtils.pickLerp(a.style, b.style, t),
      isAntiAlias: AnyUtils.pickLerp(a.isAntiAlias, b.isAntiAlias, t),
    );
  }

  static List<AnyShadow> lerpList(
      List<AnyShadow> a,
      List<AnyShadow> b,
      double t,
      ) {
    final count = math.max(a.length, b.length);
    return List<AnyShadow>.generate(count, (index) {
      if (index >= a.length) return b[index];
      if (index >= b.length) return a[index];
      return lerp(a[index], b[index], t);
    }, growable: false);
  }
}