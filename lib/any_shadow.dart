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
      DecorationImagePainter? Function(AnyFill) painterOf,
      ) {
    final geometry = _LazyShadowGeometry(
      path: path,
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
      offset: offset,
    );

    final imagePainter = painterOf(this);
    if (imagePainter != null) {
      _paintImageShadow(
        canvas: canvas,
        geometry: geometry,
        configuration: configuration,
        imagePainter: imagePainter,
      );
      return;
    }

    _paintBaseShadow(
      canvas: canvas,
      geometry: geometry,
      configuration: configuration,
    );
  }

  void _paintBaseShadow({
    required Canvas canvas,
    required _LazyShadowGeometry geometry,
    required ImageConfiguration configuration,
  }) {
    switch (style) {
      case BlurStyle.normal:
        final paint = _createConfiguredBasePaint(
          geometry.outerSourcePath,
          configuration,
          blurStyle: BlurStyle.normal,
        );
        if (paint == null) return;

        canvas.drawPath(geometry.outerSourcePath, paint);
        break;

      case BlurStyle.inner:
        final paint = _createConfiguredBasePaint(
          geometry.innerClipPath,
          configuration,
          blurStyle: BlurStyle.normal,
        );
        if (paint == null) return;

        _paintInnerShadow(
          canvas: canvas,
          clipPath: geometry.innerClipPath,
          layerBounds: geometry.innerLayerBounds,
          isAntiAlias: isAntiAlias,
          paintSource: () {
            canvas.drawPath(geometry.innerInversePath, paint);
          },
        );
        break;

      case BlurStyle.outer:
        final paint = _createConfiguredBasePaint(
          geometry.outerSourcePath,
          configuration,
          blurStyle: BlurStyle.normal,
        );
        if (paint == null) return;

        _paintOuterShadow(
          canvas: canvas,
          layerBounds: geometry.outerLayerBounds,
          compositePaint: _createCompositePaint(),
          paintShadowSource: () {
            canvas.drawPath(geometry.outerSourcePath, paint);
          },
          paintCutout: () {
            canvas.drawPath(geometry.outerCutoutPath, _createOpaqueMaskPaint());
          },
        );
        break;

      case BlurStyle.solid:
        final fillPaint = _createConfiguredBasePaint(
          geometry.outerCutoutPath,
          configuration,
        );
        final blurPaint = _createConfiguredBasePaint(
          geometry.outerSourcePath,
          configuration,
          blurStyle: BlurStyle.normal,
        );
        if (fillPaint == null || blurPaint == null) return;

        canvas.saveLayer(geometry.outerLayerBounds, _createCompositePaint());

        _paintOuterShadow(
          canvas: canvas,
          layerBounds: geometry.outerLayerBounds,
          paintShadowSource: () {
            canvas.drawPath(geometry.outerSourcePath, blurPaint);
          },
          paintCutout: () {
            canvas.drawPath(geometry.outerCutoutPath, _createOpaqueMaskPaint());
          },
        );

        // Fill only the hole, not the expanded shadow shape.
        canvas.drawPath(geometry.outerCutoutPath, fillPaint);
        canvas.restore();
        break;
    }
  }

  void _paintImageShadow({
    required Canvas canvas,
    required _LazyShadowGeometry geometry,
    required ImageConfiguration configuration,
    required DecorationImagePainter imagePainter,
  }) {
    final compositePaint = _createCompositePaint();

    final blurPaint = Paint()..isAntiAlias = isAntiAlias;
    if (blurSigma > 0.0) {
      blurPaint.imageFilter = ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
        tileMode: TileMode.decal,
      );
    }

    void paintOuterImage() {
      _paintImagePath(
        canvas: canvas,
        imagePainter: imagePainter,
        bounds: geometry.outerSourceBounds,
        path: geometry.outerSourcePath,
        configuration: configuration,
      );
    }

    void paintInnerImage() {
      _paintImagePath(
        canvas: canvas,
        imagePainter: imagePainter,
        bounds: geometry.innerLayerBounds,
        path: geometry.innerInversePath,
        configuration: configuration,
      );
    }

    switch (style) {
      case BlurStyle.normal:
        canvas.saveLayer(geometry.outerLayerBounds, compositePaint);
        canvas.saveLayer(geometry.outerLayerBounds, blurPaint);
        paintOuterImage();
        canvas.restore();
        canvas.restore();
        break;

      case BlurStyle.inner:
        canvas.saveLayer(geometry.innerLayerBounds, compositePaint);
        _paintInnerShadow(
          canvas: canvas,
          clipPath: geometry.innerClipPath,
          layerBounds: geometry.innerLayerBounds,
          isAntiAlias: isAntiAlias,
          blurLayerPaint: blurPaint,
          paintSource: paintInnerImage,
        );
        canvas.restore();
        break;

      case BlurStyle.outer:
        _paintOuterShadow(
          canvas: canvas,
          layerBounds: geometry.outerLayerBounds,
          compositePaint: compositePaint,
          blurLayerPaint: blurPaint,
          paintShadowSource: paintOuterImage,
          paintCutout: () {
            canvas.drawPath(geometry.outerCutoutPath, _createOpaqueMaskPaint());
          },
        );
        break;

      case BlurStyle.solid:
        void paintCutoutImage() {
          _paintImagePath(
            canvas: canvas,
            imagePainter: imagePainter,
            bounds: geometry.outerCutoutBounds,
            path: geometry.outerCutoutPath,
            configuration: configuration,
          );
        }

        canvas.saveLayer(geometry.outerLayerBounds, compositePaint);

        _paintOuterShadow(
          canvas: canvas,
          layerBounds: geometry.outerLayerBounds,
          blurLayerPaint: blurPaint,
          paintShadowSource: paintOuterImage,
          paintCutout: () {
            canvas.drawPath(geometry.outerCutoutPath, _createOpaqueMaskPaint());
          },
        );

        // Paint only the hole.
        paintCutoutImage();
        canvas.restore();
        break;
    }
  }

  Paint _createCompositePaint() {
    final paint = Paint()..isAntiAlias = isAntiAlias;
    if (blendMode != null) {
      paint.blendMode = blendMode!;
    }
    return paint;
  }

  Paint _createOpaqueMaskPaint() {
    return Paint()
      ..isAntiAlias = isAntiAlias
      ..color = const Color(0xFFFFFFFF);
  }

  Paint? _createConfiguredBasePaint(
      Path referencePath,
      ImageConfiguration configuration, {
        BlurStyle? blurStyle,
      }) {
    final paint = createBasePaint(referencePath, configuration);
    if (paint == null) return null;

    paint.isAntiAlias = isAntiAlias;

    if (blendMode != null) {
      paint.blendMode = blendMode!;
    }

    if (blurStyle != null && blurSigma > 0.0) {
      paint.maskFilter = MaskFilter.blur(blurStyle, blurSigma);
    }

    return paint;
  }

  static void _paintOuterShadow({
    required Canvas canvas,
    required Rect layerBounds,
    required VoidCallback paintShadowSource,
    required VoidCallback paintCutout,
    Paint? compositePaint,
    Paint? blurLayerPaint,
  }) {
    if (compositePaint != null) {
      canvas.saveLayer(layerBounds, compositePaint);
    }

    if (blurLayerPaint != null) {
      canvas.saveLayer(layerBounds, blurLayerPaint);
      paintShadowSource();
      canvas.restore();
    } else {
      paintShadowSource();
    }

    canvas.saveLayer(
      layerBounds,
      Paint()..blendMode = BlendMode.dstOut,
    );
    paintCutout();
    canvas.restore();

    if (compositePaint != null) {
      canvas.restore();
    }
  }

  static void _paintInnerShadow({
    required Canvas canvas,
    required Path clipPath,
    required Rect layerBounds,
    required bool isAntiAlias,
    required VoidCallback paintSource,
    Paint? blurLayerPaint,
  }) {
    canvas.save();
    canvas.clipPath(clipPath, doAntiAlias: isAntiAlias);

    if (blurLayerPaint != null) {
      canvas.saveLayer(layerBounds, blurLayerPaint);
      paintSource();
      canvas.restore();
    } else {
      paintSource();
    }

    canvas.restore();
  }

  static void _paintImagePath({
    required Canvas canvas,
    required DecorationImagePainter imagePainter,
    required Rect bounds,
    required Path path,
    required ImageConfiguration configuration,
  }) {
    imagePainter.paint(
      canvas,
      bounds,
      path,
      configuration,
    );
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

class _LazyShadowGeometry {

  final Path path;
  final double blurRadius;
  final Offset spreadRadius;
  final Offset offset;

  _LazyShadowGeometry({
    required this.path,
    required this.blurRadius,
    required this.spreadRadius,
    required this.offset,
  });

  late final Rect baseBounds = path.getBounds();

  late final Path outerSpreadPath = _buildScaledPath(spreadRadius);

  late final Path outerSourcePath =
  offset == Offset.zero ? outerSpreadPath : outerSpreadPath.shift(offset);

  late final Rect outerSourceBounds = outerSourcePath.getBounds();

  late final Path outerCutoutPath = path;
  late final Rect outerCutoutBounds = path.getBounds();

  late final Rect outerLayerBounds = baseBounds
      .expandToInclude(outerSourceBounds)
      .inflate(blurRadius > 0.0 ? blurRadius * 2.0 + 1.0 : 1.0);

  late final Path innerClipPath = path;

  // Positive spread for inner shadow usually means "more shadow inward",
  // which corresponds to a smaller hole.
  late final Path innerSpreadPath = _buildScaledPath(Offset(
    -spreadRadius.dx,
    -spreadRadius.dy,
  ));

  // Keep this sign so the visible inset shadow moves in the same visual
  // direction as a regular shadow offset.
  late final Path innerHolePath =
  offset == Offset.zero ? innerSpreadPath : innerSpreadPath.shift(-offset);

  late final Rect innerLayerBounds = innerClipPath
      .getBounds()
      .expandToInclude(innerHolePath.getBounds())
      .inflate(
    math.max(
      1.0,
      blurRadius * 3.0 +
          offset.distance +
          math.max(spreadRadius.dx.abs(), spreadRadius.dy.abs()) +
          1.0,
    ),
  );

  late final Path innerInversePath = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(innerLayerBounds)
    ..addPath(innerHolePath, Offset.zero);

  Path _buildScaledPath(Offset delta) {
    if (delta == Offset.zero) {
      return path;
    }

    final bounds = path.getBounds();
    final width = bounds.width;
    final height = bounds.height;

    if (width <= AnyUtils.epsilon || height <= AnyUtils.epsilon) {
      return path;
    }

    final targetWidth = math.max(AnyUtils.epsilon, width + delta.dx);
    final targetHeight = math.max(AnyUtils.epsilon, height + delta.dy);

    final scaleX = targetWidth / width;
    final scaleY = targetHeight / height;
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;

    final matrix = Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1.0)
      ..scaleByDouble(scaleX, scaleY, 1.0, 1.0)
      ..translateByDouble(-cx, -cy, 0, 1.0);

    return path.transform(matrix.storage);
  }
}