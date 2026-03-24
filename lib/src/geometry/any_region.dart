import 'package:flutter/painting.dart';

import '../any_fill.dart';

class AnyRegion {
  const AnyRegion({
    required this.path,
    required this.fill,
    required this.debugLabel,
  });

  final Path path;
  final IAnyFill fill;
  final String debugLabel;
}
