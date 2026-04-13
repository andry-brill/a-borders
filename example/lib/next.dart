

import 'package:flutter/material.dart';

abstract class IAnyFill {
  Color? get color;
  Gradient? get gradient;
  DecorationImage? get image;
  BlendMode? get blendMode;
  bool get isAntiAlias;
  bool isSameAs(IAnyFill other);
}

mixin MAnyFill implements IAnyFill {
  @override
  bool isSameAs(IAnyFill? other) {
    if (other == null) return false;
    return color == other.color &&
        gradient == other.gradient &&
        image == other.image &&
        blendMode == other.blendMode &&
        isAntiAlias == other.isAntiAlias;
  }
}

extension EAnyFill on IAnyFill {
  bool get hasFill => color != null || gradient != null || image != null;
  bool get hasBaseFill => color != null || gradient != null;
}



/// NB! No negative values support
/// In case of rounded (radius != zero) functions we need to use bezier curves (in case if angle > 90 - split it on several curves)
///   - if radius.x == radius.y then this should looks like a circle (but build on bezier curves)
class AnyCorner {

  final Radius radius;
  const AnyCorner([this.radius = Radius.zero]);

  @override
  bool operator ==(Object other) {
    return other is AnyCorner && other.radius == radius;
  }

  @override
  int get hashCode => radius.hashCode;
}


class AnySide with MAnyFill {

  static const double alignInside = -1;
  static const double alignCenter = 0;
  static const double alignOutside = 1;

  static double alignBase = alignInside;

  final double width;
  final double? _align;

  /// Align means align relative to the corresponding side, not the whole shape.
  double get align => _align ?? alignBase;

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

  const AnySide({
    this.width = 0.0,
    double? align,
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.isAntiAlias = true
  })  : _align = align,
        assert(width >= 0.0),
        assert(align == null || (align >= -1.0 && align <= 1.0));

  AnySide copyWith({
    double? width,
    double? align,
    Color? color,
    Gradient? gradient,
    DecorationImage? image,
    BlendMode? blendMode,
  }) {
    return AnySide(
      width: width ?? this.width,
      align: align ?? this.align,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      image: image ?? this.image,
      blendMode: blendMode ?? this.blendMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AnySide &&
        other.width == width &&
        other.align == align &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode;
  }

  @override
  int get hashCode => Object.hash(
    width,
    align,
    color,
    gradient,
    image,
    blendMode,
  );
}

class AnyPoint {

  final AnyCorner outer;
  final AnyCorner inner;

  final Offset point;
  final AnySide side;

  const AnyPoint({
    required this.outer,
    AnyCorner? inner,
    required this.point,
    required this.side
  }) : inner = inner ?? outer;

  static List<AnyPoint>? lerp(List<AnyPoint>? a, List<AnyPoint>? b, double t) {
    // TODO
    return null;
  }
}

enum AnyShapeBase {
  /// Shape of the element based on border corners but ignoring border side width.
  ///
  /// If a background and an outer border side share the same fill, the region
  /// builder may extend the background path to include that outside
  /// contribution.
  zeroBorder,

  /// Combining all outer paths of border sides into one contour.
  outerBorder,

  /// Combining all inner paths of border sides into one contour.
  innerBorder
}

class AnyContour {

  final AnyShapeBase clipBase;

  final AnyShapeBase backgroundBase;
  final IAnyFill? background;
  /// Could background be merged with sides for drawing
  final bool backgroundMerge;

  AnyContour({
    this.background,
    this.backgroundMerge = true,
    this.backgroundBase = AnyShapeBase.zeroBorder,
    this.clipBase = AnyShapeBase.zeroBorder
  });

  // TODO add here all pre-cached helpful calculations as arrays
  void prepare(List<AnyPoint> points) {
  }

  AnyRegions build(List<AnyPoint> points) {

  }
}

class AnyRegions {

  final (IAnyFill, Path)? background;
  final Path clip;
  final List<(IAnyFill, Path)> regions;

  const AnyRegions({
    this.background,
    required this.clip,
    this.regions = const []
  });

}