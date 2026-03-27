import 'dart:math' as math;

import 'package:flutter/painting.dart';

abstract class IAnyCorner {}

abstract class AAnyCorner implements IAnyCorner {
  const AAnyCorner();

}

/// Standard 90 degree corner.
class AnySquareCorner extends AAnyCorner {

  const AnySquareCorner();

  @override
  bool operator ==(Object other) => other is AnySquareCorner;

  @override
  int get hashCode => 31;

}

abstract class AAnyRoundedCorner extends AAnyCorner {
  final Radius radius;
  const AAnyRoundedCorner(this.radius);

  bool get isInfinite => radius.x.isInfinite || radius.y.isInfinite;

  Radius resolveForSize(Size size) {
    if (!isInfinite) return radius;
    final m = math.min(size.width, size.height) / 2.0;
    return Radius.elliptical(m, m);
  }
}

/// Standard rounded corner.
class AnyRoundedCorner extends AAnyRoundedCorner {
  const AnyRoundedCorner(super.radius);

  @override
  bool operator ==(Object other) {
    return other is AnyRoundedCorner && other.radius == radius;
  }

  @override
  int get hashCode => Object.hash(AnyRoundedCorner, radius);
}

/// Rounded corner that looks inside (like a post mark notch).
class AnyInnerRoundedCorner extends AAnyRoundedCorner {
  const AnyInnerRoundedCorner(super.radius);

  @override
  bool operator ==(Object other) {
    return other is AnyInnerRoundedCorner && other.radius == radius;
  }

  @override
  int get hashCode => Object.hash(AnyInnerRoundedCorner, radius);
}

/// Rounded corner that goes outside.
///
/// Example: a tab-like edge where only one axis bulges.
class AnySideRoundedCorner extends AAnyRoundedCorner {

  final bool horizontal;
  const AnySideRoundedCorner.horizontal(super.radius) : horizontal = true;
  const AnySideRoundedCorner.vertical(super.radius) : horizontal = false;


  @override
  bool operator ==(Object other) {
    return other is AnySideRoundedCorner &&
        other.radius == radius &&
        other.horizontal == horizontal;
  }

  @override
  int get hashCode => Object.hash(AnySideRoundedCorner, radius, horizontal);
}
