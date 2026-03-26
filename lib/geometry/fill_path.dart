import 'package:flutter/painting.dart';

import '../decoration/any_fill.dart';
import 'checkpoints_builder.dart';

class FillPath {

  final Path path;
  final IAnyFill fill;
  final String debugLabel;
  final Set<ContourTarget> targets;

  const FillPath({
    required this.path,
    required this.fill,
    required this.debugLabel,
    required this.targets,
  });
}
