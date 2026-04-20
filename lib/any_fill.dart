import 'package:flutter/painting.dart';

/// Shared fill contract for decorations, sides, backgrounds, and shadows.
///
/// An [AnyFill] can paint a solid [color], a [gradient], an [image], or a
/// combination of a base fill and an image. Implementers usually mix in
/// [MAnyFill] to get consistent fill comparison and paint creation behavior.
abstract class AnyFill {
  /// Solid color used as the base fill.
  Color? get color;

  /// Gradient used as the base fill.
  ///
  /// When both [color] and [gradient] are set, [gradient] takes precedence.
  Gradient? get gradient;

  /// Image painted into the target path before the base fill.
  DecorationImage? get image;

  /// Blend mode applied to the paint created for [color] or [gradient].
  BlendMode? get blendMode;

  /// Whether path painting should use anti-aliasing.
  bool get isAntiAlias;

  /// Returns true when this fill has the same visual fill options as [other].
  bool isSameAs(AnyFill other);

  /// Whether this fill has any paintable content.
  bool get hasFill;

  /// Whether this fill has a [color] or [gradient] base fill.
  bool get hasBaseFill;

  /// Creates a configured paint for the base fill, or null if there is none.
  Paint? createBasePaint(Path path, ImageConfiguration configuration);
}

/// Default implementation for [AnyFill].
///
/// Use this mixin on classes that expose [AnyFill] fields directly. It keeps
/// equality-style fill comparison and base paint creation consistent across
/// [AnySide], [AnyBackground], and [AnyShadow].
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
