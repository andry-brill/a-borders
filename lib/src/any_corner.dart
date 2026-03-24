

import 'package:flutter/painting.dart';

abstract class IAnyCorner {
}

abstract class AAnyCorner implements IAnyCorner {
  const AAnyCorner();
}

/// Standard 90 degree corner
class AnySquareCorner extends AAnyCorner {
  const AnySquareCorner();
}

class AAnyRoundedCorner extends AAnyCorner {
  final Radius radius;
  const AAnyRoundedCorner(this.radius);
}

/// Standard rounded corner
class AnyRoundedCorner extends AAnyRoundedCorner {
  const AnyRoundedCorner(super.radius);
}

/// Rounded corner that looks inside (like post mark)
class AnyInnerRoundedCorner extends AAnyRoundedCorner {
  const AnyInnerRoundedCorner(super.radius);
}

/// Rounded corner that goes outside. Example: _| TAB |_ with horizontal bottom side corners.
class AnySideRoundedCorner extends AAnyRoundedCorner {
  final bool horizontal;
  const AnySideRoundedCorner.horizontal(super.radius) : horizontal = true;
  const AnySideRoundedCorner.vertical(super.radius) : horizontal = false;
}