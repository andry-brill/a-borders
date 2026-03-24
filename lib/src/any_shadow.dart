import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'any_align.dart';

abstract class IAnyShadow {

}

@immutable
class AnyShadow implements IAnyShadow {

  const AnyShadow({
    required this.color,
    this.blurRadius = 0.0,
    this.offset = Offset.zero,
    this.spreadRadius = 0.0,
    this.align = AnyAlign.outside,
  });

  final Color color;
  final double blurRadius;
  final Offset offset;
  final double spreadRadius;
  final AnyAlign align;

  @override
  bool operator ==(Object other) {
    return other is AnyShadow &&
        other.color == color &&
        other.blurRadius == blurRadius &&
        other.offset == offset &&
        other.spreadRadius == spreadRadius &&
        other.align == align;
  }

  @override
  int get hashCode => Object.hash(color, blurRadius, offset, spreadRadius, align);
}
