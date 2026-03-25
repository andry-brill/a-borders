import 'package:flutter/painting.dart';

import '../decoration/any_decoration.dart';
import '../decoration/any_fill.dart';
import 'checkpoints_builder.dart';

class PathRegion {
  final Path path;
  final IAnyFill fill;
  final String debugLabel;
  final Set<ContourTarget> targets;
  final List<AnyShapeBase> bases;
  final List<List<ContourCheckpoint>> checkpointSets;

  const PathRegion({
    required this.path,
    required this.fill,
    required this.debugLabel,
    this.targets = const <ContourTarget>{},
    this.bases = const <AnyShapeBase>[],
    this.checkpointSets = const <List<ContourCheckpoint>>[],
  });
}
