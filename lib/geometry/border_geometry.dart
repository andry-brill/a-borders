import 'dart:ui';

import 'package:any_borders/helpers/path_debugger.dart';

import '../decoration/any_align.dart';
import '../decoration/any_border.dart';
import '../decoration/any_decoration.dart';
import '../decoration/any_fill.dart';
import '../decoration/any_side.dart';
import 'checkpoints_builder.dart';
import 'fill_path.dart';


class BorderGeometry {

  BorderGeometry._({
    required this.rect,
    required this.border,
  });

  final Rect rect;
  final IAnyBorder border;

  static BorderGeometry resolve(Rect rect, IAnyBorder border) {
    return BorderGeometry._(
      rect: rect,
      border: border,
    );
  }

  List<FillPath> build(AnyDecoration decoration) {

    final paths = <FillPath>[];
    final contours = _buildContours(decoration);

    if (contours.isNotEmpty) {

      final builder = CheckpointsBuilder(border);
      final geometry = BorderCheckpointsGeometry(rect, border);

      for (final contour in contours) {
        final descriptor = buildFillPath(builder, geometry, contour, decoration);
        if (descriptor == null) continue;
        paths.add(descriptor);
      }

    }


    return paths;
  }

  List<_FillContour> _buildContours(AnyDecoration decoration) {

    final contours = <_FillContour>[];

    if (!decoration.isEmpty) {
      contours.add(
        _FillContour(
          fill: decoration,
          targets: const {ContourTarget.background},
        ),
      );
    }

    for (var side in ContourTarget.sides) {
      final borderSide = side.sideOf(border);
      if (borderSide != null && borderSide.isVisible) {
        contours.add(
          _FillContour(
            fill: borderSide,
            targets: {side},
          ),
        );
      }
    }

    var changed = true;
    while (changed) {

      changed = false;

      for (var i = 0; i < contours.length; i++) {
        for (var j = i + 1; j < contours.length; j++) {
          final a = contours[i];
          final b = contours[j];

          if (!_canMergeContours(a, b)) continue;

          contours[i] = _mergeContours(a, b);
          contours.removeAt(j);
          changed = true;
          break;
        }

        if (changed) break;
      }
    }

    return contours;
  }

  bool _canMergeContours(_FillContour a, _FillContour b) {

    if (!a.fill.isSameAs(b.fill)) return false;

    for (final ta in a.targets) {
      for (final tb in b.targets) {
        if (ContourTarget.areAdjacent(ta, tb)) {
          return true;
        }
      }
    }

    return false;
  }

  _FillContour _mergeContours(_FillContour a, _FillContour b) {
    return _FillContour(
      fill: a.fill,
      targets: <ContourTarget>{
        ...a.targets,
        ...b.targets,
      },
    );
  }

  FillPath? buildFillPath(
      CheckpointsBuilder builder,
      BorderCheckpointsGeometry geometry,
      _FillContour contour,
      AnyDecoration decoration,
      ) {

    final targets = _targetsForContour(contour);
    if (targets.isEmpty) return null;

    late final Path path;

    if (!contour.hasBackground && _isFullVisibleBorderComponent(contour)) {

      final outerCheckpoints = builder.build(ContourTarget.sides, base: AnyShapeBase.outerBorder);
      final innerCheckpoints = builder.build(ContourTarget.sides, base: AnyShapeBase.innerBorder);

      path = Path.combine(
        PathOperation.difference,
        geometry.build(outerCheckpoints),
        geometry.build(innerCheckpoints),
      );
    } else {

      final base = contour.hasBackground ? decoration.background : null;
      final checkpoints = builder.build(targets, base: base);

      if (base == AnyShapeBase.zeroBorder) {

        // NB! Resetting sides to make sure that background is build purely on shape base if this sides not merged into it
        IAnyBorder zeroBorder = geometry._border.copyWithout(
          left: !contour.targets.contains(ContourTarget.left),
          top: !contour.targets.contains(ContourTarget.top),
          right: !contour.targets.contains(ContourTarget.right),
          bottom: !contour.targets.contains(ContourTarget.bottom),
        );

        BorderCheckpointsGeometry backgroundGeometry = BorderCheckpointsGeometry(geometry._bounds, zeroBorder);
        path = backgroundGeometry.build(checkpoints);
      } else {
        print('>>> $checkpoints');
        path = geometry.build(checkpoints);
      }
    }

    return FillPath(
      path: path,
      fill: contour.fill,
      debugLabel: contour.debugLabel,
      targets: targets,
    );
  }

  Path clipPath(AnyShapeBase clip) {
    IAnyBorder border = clip == AnyShapeBase.zeroBorder ? this.border.copyWithout() : this.border;
    final builder = CheckpointsBuilder(border);
    final geometry = BorderCheckpointsGeometry(rect, border);
    final checkpoints = builder.build(const { ContourTarget.background }, base: clip);
    return geometry.build(checkpoints);
  }

  Set<ContourTarget> _targetsForContour(_FillContour contour) {

    final targets = <ContourTarget>{...contour.targets};

    final sideTargets = contour.targets.where((t) => t.isSide).toSet();

    final ordered = <ContourTarget>[
      ContourTarget.top,
      ContourTarget.right,
      ContourTarget.bottom,
      ContourTarget.left,
    ].where(sideTargets.contains).toList();

    if (ordered.isEmpty) return targets;

    final targetSet = ordered.toSet();

    for (final side in ordered) {
      final previous = side.previousSide;
      final next = side.nextSide;

      final hasPreviousInComponent = targetSet.contains(previous);
      final hasNextInComponent = targetSet.contains(next);

      if (!hasPreviousInComponent && previous.sideOf(border)?.isVisible != true) {
        targets.add(previous);
      }
      if (!hasNextInComponent && next.sideOf(border)?.isVisible != true) {
        targets.add(next);
      }
    }

    return targets;
  }

  bool _isFullVisibleBorderComponent(_FillContour contour) {
    return !contour.hasBackground &&
        contour.targets.length == 4 &&
        _allVisibleSidesPresent();
  }


  bool _allVisibleSidesPresent() {
    return border.top.isVisible &&
        border.right.isVisible &&
        border.bottom.isVisible &&
        border.left.isVisible;
  }


}

class _FillContour {

  final IAnyFill fill;
  final Set<ContourTarget> targets;
  bool get hasBackground => targets.contains(ContourTarget.background);

  const _FillContour({
    required this.fill,
    required this.targets,
  });

  String get debugLabel {
    final parts = <String>[];
    parts.addAll(targets.map((s) => s.name));
    return parts.join('+');
  }

}



class BorderCheckpointsGeometry {

  final Rect _bounds;
  final IAnyBorder _border;

  BorderCheckpointsGeometry(this._bounds, this._border) {
    alignBounds();
  }

  void alignBounds() {

    // print('> ${_bounds} w: ${_bounds.width} h: ${_bounds.height}');

    // TODO base on _border.topLeft, ... corners detect do we need to reduce bounds
    // TODO we need to reduce bounds in case CornerVariant.rounded (AnyRoundedCorner) and radius is infinity - it means that this corder is circle, and next side is starts in the edge of this circle
    // TODO Example of AnyRoundedCorner(infinity) in top right corner for Rect.fromLTRB(0, 0, 200, 100), bounds mut be reduces to Rect.fromLTRB(0, 0, 150, 100)
  }

  Path build(List<ContourCheckpoint> checkpoints) {

    // print('>>> build checkpoints ${checkpoints}');

    Path path = Path()
      ..fillType = PathFillType.evenOdd;

    if (checkpoints.isEmpty) return path;

    path = PathDebugger('>', path);

    Offset startPoint = _pointFor(checkpoints.first);
    path.moveTo(startPoint.dx, startPoint.dy);

    for (var i = 0; i < checkpoints.length; i++) {
      final current = checkpoints[i];
      final next = checkpoints[(i + 1) % checkpoints.length];
      startPoint = _connect(startPoint, path, current, next);
    }

    path.close();

    return PathDebugger.unwrap(path);
  }

  Offset _connect(Offset startPoint, Path path, ContourCheckpoint start, ContourCheckpoint end) {


    final endPoint = _pointFor(end);
    if ((startPoint - endPoint).distance <= 0.0001) {
      return startPoint;
    }

    print('>> $end');

    if (start.variant == ContourVariant.corner && end.variant == ContourVariant.corner) {

      if (start.point == ContourPoint.topRight && end.point == ContourPoint.rightTop) {
        path.lineTo(endPoint.dx, startPoint.dy);
      } else if (start.point == ContourPoint.rightBottom && end.point == ContourPoint.bottomRight) {
        path.lineTo(startPoint.dx, endPoint.dy);
      } else if (start.point == ContourPoint.bottomLeft && end.point == ContourPoint.leftBottom) {
        path.lineTo(endPoint.dx, startPoint.dy);
      } else if (start.point == ContourPoint.leftTop && end.point == ContourPoint.topLeft) {
        path.lineTo(startPoint.dx, endPoint.dy);
      } else if (start.point == ContourPoint.bottomRight && end.point == ContourPoint.rightBottom) {
        path.lineTo(endPoint.dx, startPoint.dy);
      } else if (start.point == ContourPoint.rightTop && end.point == ContourPoint.topRight) {
        path.lineTo(startPoint.dx, endPoint.dy);
      } else if (start.point == ContourPoint.topLeft && end.point == ContourPoint.leftTop) {
        path.lineTo(endPoint.dx, startPoint.dy);
      } else {
        throw UnimplementedError(' from: ${start.point.name} to: ${end.point.name}');
      }

      path.lineTo(endPoint.dx, endPoint.dy);

    } else {
      // NB! Implementing only squared corners for now
      path.lineTo(endPoint.dx, endPoint.dy);
    }
    return endPoint;
  }

  Offset _pointFor(ContourCheckpoint checkpoint) {
    if (checkpoint.variant == ContourVariant.side) {
      return borderPointFor(_bounds, _border, checkpoint);
    } else {
      return cornerPointFor(_bounds, _border, checkpoint);
    }
  }

  Offset cornerPointFor(Rect bounds, IAnyBorder border, ContourCheckpoint checkpoint) {
    assert(checkpoint.variant != ContourVariant.side);

    // NB! Implementing only squared corners for now
    // NB! This will be totally different in case rounded corners

    switch (checkpoint.variant) {
      case ContourVariant.corner:

        if (checkpoint.point == ContourPoint.topRight || checkpoint.point == ContourPoint.topLeft) {

          final origin = checkpoint.point == ContourPoint.topRight ? bounds.topRight : bounds.topLeft;
          var side = border.top;

          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.outer) {
              return Offset(origin.dx, origin.dy - side.width);
          }
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy - side.width / 2);
          }
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy);
          }

          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy - side.width / 2);
          }
          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy);
          }
          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy + side.width / 2);
          }

          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy);
          }
          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy + side.width / 2);
          }
          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy + side.width);
          }
        }

        if (checkpoint.point == ContourPoint.bottomRight || checkpoint.point == ContourPoint.bottomLeft) {

          final origin = checkpoint.point == ContourPoint.bottomRight ? bounds.bottomRight : bounds.bottomLeft;
          var side = border.bottom;

          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy + side.width);
          }
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy + side.width / 2);
          }
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy);
          }

          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy + side.width / 2);
          }
          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy);
          }
          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy - side.width / 2);
          }

          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy);
          }
          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy - side.width / 2);
          }
          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy - side.width);
          }
        }


        if (checkpoint.point == ContourPoint.leftTop || checkpoint.point == ContourPoint.leftBottom) {

          final origin = checkpoint.point == ContourPoint.leftTop ? bounds.topLeft : bounds.bottomLeft;
          final side = border.left;
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx - side.width, origin.dy);
          }
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx - side.width / 2, origin.dy);
          }
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy);
          }

          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx - side.width / 2, origin.dy);
          }
          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy);
          }
          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx + side.width / 2, origin.dy);
          }

          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy);
          }
          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx + side.width / 2, origin.dy);
          }
          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx + side.width, origin.dy);
          }
        }

        if (checkpoint.point == ContourPoint.rightTop) {

          final origin = bounds.topRight;
          final right = border.right;
          final top = border.top;

          double dy = 0;
          if (right.align == AnyAlign.outside || top.align == AnyAlign.outside) {
            dy = 0;
          } else {
            if (top.align == AnyAlign.center) {
              dy = top.width / 2;
            }
            if (top.align == AnyAlign.inside) {
              dy = top.width;
            }
          }


          if (right.align == AnyAlign.outside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx + right.width, origin.dy + dy);
          }
          if (right.align == AnyAlign.outside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx + right.width / 2, origin.dy + dy);
          }
          if (right.align == AnyAlign.outside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy + dy);
          }

          if (right.align == AnyAlign.center && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx + right.width / 2, origin.dy + dy);
          }
          if (right.align == AnyAlign.center && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy + dy);
          }
          if (right.align == AnyAlign.center && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx - right.width / 2, origin.dy + dy);
          }

          if (right.align == AnyAlign.inside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy + dy);
          }
          if (right.align == AnyAlign.inside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx - right.width / 2, origin.dy + dy);
          }
          if (right.align == AnyAlign.inside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx - right.width, origin.dy + dy);
          }
        }

        if (checkpoint.point == ContourPoint.rightBottom) {

          final origin = bounds.bottomRight;
          final side = border.right;
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx + side.width, origin.dy);
          }
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx + side.width / 2, origin.dy);
          }
          if (side.align == AnyAlign.outside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy);
          }

          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx + side.width / 2, origin.dy);
          }
          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy);
          }
          if (side.align == AnyAlign.center && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx - side.width / 2, origin.dy);
          }

          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy);
          }
          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx - side.width / 2, origin.dy);
          }
          if (side.align == AnyAlign.inside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx - side.width, origin.dy);
          }
        }

        throw UnimplementedError();
      case ContourVariant.split:

        if (checkpoint.point == ContourPoint.topRight || checkpoint.point == ContourPoint.rightTop) {

          final origin = bounds.topRight;
          var hSide = border.top;
          var vSide = border.right;

          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx + vSide.width, origin.dy - hSide.width);
          }
          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx + vSide.width / 2, origin.dy - hSide.width / 2);
          }
          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy);
          }

          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx + vSide.width / 2, origin.dy - hSide.width / 2);
          }
          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy);
          }
          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx - vSide.width / 2, origin.dy + hSide.width / 2);
          }

          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy);
          }
          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx - vSide.width / 2, origin.dy + hSide.width / 2);
          }
          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx - vSide.width, origin.dy + hSide.width);
          }
        }

        if (checkpoint.point == ContourPoint.topLeft || checkpoint.point == ContourPoint.leftTop) {

          final origin = bounds.topLeft;
          var hSide = border.top;
          var vSide = border.left;

          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx - vSide.width, origin.dy - hSide.width);
          }
          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx - vSide.width / 2, origin.dy - hSide.width / 2);
          }
          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy);
          }

          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx - vSide.width / 2, origin.dy - hSide.width / 2);
          }
          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy);
          }
          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx + vSide.width / 2, origin.dy + hSide.width / 2);
          }

          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy);
          }
          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx + vSide.width / 2, origin.dy + hSide.width / 2);
          }
          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx + vSide.width, origin.dy + hSide.width);
          }
        }

        if (checkpoint.point == ContourPoint.bottomRight || checkpoint.point == ContourPoint.rightBottom) {

          final origin = bounds.bottomRight;
          var hSide = border.bottom;
          var vSide = border.right;

          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx + vSide.width, origin.dy + hSide.width);
          }
          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx + vSide.width / 2, origin.dy + hSide.width / 2);
          }
          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy);
          }

          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx + vSide.width / 2, origin.dy + hSide.width / 2);
          }
          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy);
          }
          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx - vSide.width / 2, origin.dy - hSide.width / 2);
          }

          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy);
          }
          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx - vSide.width / 2, origin.dy - hSide.width / 2);
          }
          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx - vSide.width, origin.dy - hSide.width);
          }
        }


        if (checkpoint.point == ContourPoint.bottomLeft || checkpoint.point == ContourPoint.leftBottom) {

          final origin = bounds.bottomLeft;
          var hSide = border.bottom;
          var vSide = border.left;

          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx - vSide.width, origin.dy + hSide.width);
          }
          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx - vSide.width / 2, origin.dy + hSide.width / 2);
          }
          if (hSide.align == AnyAlign.outside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx, origin.dy);
          }

          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx - vSide.width / 2, origin.dy + hSide.width / 2);
          }
          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx, origin.dy);
          }
          if (hSide.align == AnyAlign.center && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx + vSide.width / 2, origin.dy - hSide.width / 2);
          }

          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.outer) {
            return Offset(origin.dx, origin.dy);
          }
          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.middle) {
            return Offset(origin.dx + vSide.width / 2, origin.dy - hSide.width / 2);
          }
          if (hSide.align == AnyAlign.inside && checkpoint.position == ContourPosition.inner) {
            return Offset(origin.dx + vSide.width, origin.dy - hSide.width);
          }
        }

        throw UnimplementedError();
      default:
        throw 'Should not be called with ${checkpoint.variant.name}';
    }
  }

  static double factor(ContourPosition position, AnyAlign align) {

    if (position == ContourPosition.inner && align == AnyAlign.inside) {
      return 1.0;
    }
    if (position == ContourPosition.inner && align == AnyAlign.center) {
      return 0.5;
    }
    if (position == ContourPosition.inner && align == AnyAlign.outside) {
      return 0;
    }

    if (position == ContourPosition.middle && align == AnyAlign.inside) {
      return 0.5;
    }
    if (position == ContourPosition.middle && align == AnyAlign.center) {
      return 0;
    }
    if (position == ContourPosition.middle && align == AnyAlign.outside) {
      return -0.5;
    }

    if (position == ContourPosition.outer && align == AnyAlign.inside) {
      return 0.0;
    }
    if (position == ContourPosition.outer && align == AnyAlign.center) {
      return -0.5;
    }
    if (position == ContourPosition.outer && align == AnyAlign.outside) {
      return -1.0;
    }

    throw UnimplementedError();
  }

  static Offset resolve({
    required ContourCheckpoint checkpoint,
    required Offset origin,
    required IAnySide side,
    required bool horizontal,
    required double direction,
  }) {
    final delta = side.width * factor(checkpoint.position, side.align);

    return horizontal
        ? Offset(origin.dx + delta * direction, origin.dy)
        : Offset(origin.dx, origin.dy + delta * direction);
  }

  Offset borderPointFor(Rect bounds, IAnyBorder border, ContourCheckpoint checkpoint) {
    assert(checkpoint.variant == ContourVariant.side);

    switch (checkpoint.point) {
      case ContourPoint.topCenter:
        return resolve(
          checkpoint: checkpoint,
          origin: bounds.topCenter,
          side: border.top,
          horizontal: false,
          direction: 1.0,
        );

      case ContourPoint.rightCenter:
        return resolve(
          checkpoint: checkpoint,
          origin: bounds.centerRight,
          side: border.right,
          horizontal: true,
          direction: -1.0,
        );

      case ContourPoint.bottomCenter:
        return resolve(
          checkpoint: checkpoint,
          origin: bounds.bottomCenter,
          side: border.bottom,
          horizontal: false,
          direction: -1.0,
        );

      case ContourPoint.leftCenter:
        return resolve(
          checkpoint: checkpoint,
          origin: bounds.centerLeft,
          side: border.left,
          horizontal: true,
          direction: 1.0,
        );

      default:
        throw ArgumentError(
          'pointFor should not be called with ${checkpoint.point.name}',
        );
    }
  }

}
