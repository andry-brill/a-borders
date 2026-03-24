import 'package:flutter/painting.dart';

import '../../decoration/any_fill.dart';

class PathRegion {

  final Path path;
  final IAnyFill fill;
  final String debugLabel;

  const PathRegion({
    required this.path,
    required this.fill,
    required this.debugLabel,
  });

}
