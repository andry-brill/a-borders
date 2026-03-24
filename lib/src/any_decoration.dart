
import 'package:flutter/painting.dart';

import 'any_border.dart';
import 'any_fill.dart';
import 'any_shadow.dart';


enum AnyShapeBase {
  /// Shape of the element based on border corners but ignoring border side width
  /// In case of background - outer paths of border with SAME paint will be joined to result Path to draw
  zeroBorder,
  /// Combining all outer paths of border sides into one path
  outerBorder,
  /// Combining all inner paths of border sides into one path
  innerBorder
}

abstract class AnyDecoration extends Decoration with MAnyFill {

  static AnyShapeBase clipBase = AnyShapeBase.zeroBorder;
  static AnyShapeBase backgroundBase = AnyShapeBase.zeroBorder;

  /// Border defines shape of the decoration
  final IAnyBorder border;

  final List<IAnyShadow>? shadows;

  // background
  @override final Color? color;
  @override final Gradient? gradient;
  @override final DecorationImage? image;
  @override final BlendMode? blendMode;

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
    AnyShapeBase? background
  }) :
        _clip = clip,
        _background = background;

}