import 'package:flutter/painting.dart';

abstract class IAnyFill {
  Color? get color;
  Gradient? get gradient;
  DecorationImage? get image;
  BlendMode? get blendMode;
  bool isSameAs(IAnyFill? other);
}

mixin MAnyFill implements IAnyFill {

  @override
  bool isSameAs(IAnyFill? other) {
    if (other == null) return false;
    return color == other.color &&
        gradient == other.gradient &&
        image == other.image &&
        blendMode == other.blendMode;
  }
}

extension EAnyFill on IAnyFill {
  bool get isEmpty => color == null && gradient == null && image == null;
  bool get hasBaseFill => color != null || gradient != null;
}
