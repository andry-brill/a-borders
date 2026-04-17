
import 'package:flutter/painting.dart';

abstract class AnyFill {
  Color? get color;
  Gradient? get gradient;
  DecorationImage? get image;
  BlendMode? get blendMode;
  bool get isAntiAlias;
  bool isSameAs(AnyFill other);
  bool get hasFill;
  bool get hasBaseFill;
  Paint? createBasePaint(Path path, ImageConfiguration configuration);
}

mixin MAnyFill implements AnyFill {

  @override
  bool isSameAs(AnyFill? other) {
    if (other == null) return false;
    return color == other.color &&
        gradient == other.gradient &&
        image == other.image &&
        blendMode == other.blendMode &&
        isAntiAlias == other.isAntiAlias;
  }

  @override
  bool get hasBaseFill => color != null || gradient != null;

  @override
  bool get hasFill => hasBaseFill || image != null;

  @override
  Paint? createBasePaint(Path path, ImageConfiguration configuration) {

    if (!hasBaseFill) return null;

    final paint = Paint()..isAntiAlias = isAntiAlias;

    if (blendMode != null) {
      paint.blendMode = blendMode!;
    }

    if (gradient != null) {
      paint.shader = gradient!.createShader(
        path.getBounds(),
        textDirection: configuration.textDirection,
      );
    } else if (color != null) {
      paint.color = color!;
    }

    return paint;
  }
}