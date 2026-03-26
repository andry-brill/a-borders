import 'package:flutter/painting.dart';

import 'any_align.dart';
import 'any_fill.dart';

abstract class IAnySide implements IAnyFill {
  double get width;
  AnyAlign get align;
}

extension EAnySide on IAnySide {

  bool get hasWidth => width > 0.0;
  bool get isVisible => hasWidth && !isEmpty;

}

extension ESideFill on IAnyFill {
  bool get isSide => this is IAnySide;
}

class AnySide with MAnyFill implements IAnySide {
  static AnyAlign alignBase = AnyAlign.inside;

  @override
  final double width;
  final AnyAlign? _align;
  @override
  AnyAlign get align => _align ?? alignBase;

  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;

  const AnySide({
    required this.width,
    AnyAlign? align,
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
  })  : _align = align,
        assert(width >= 0.0), assert(color != null || gradient != null || image != null);

  AnySide copyWith({
    double? width,
    AnyAlign? align,
    Color? color,
    Gradient? gradient,
    DecorationImage? image,
    BlendMode? blendMode,
  }) {
    return AnySide(
      width: width ?? this.width,
      align: align ?? _align,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      image: image ?? this.image,
      blendMode: blendMode ?? this.blendMode,
    );
  }
}
