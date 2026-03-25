import 'package:any_borders/any_borders.dart';
import 'package:any_borders/geometry/border_geometry.dart';
import 'package:any_borders/geometry/checkpoints_builder.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {

  test('red 10 left - blue 10 top - red 10 right', () {

    final checkpoints = CheckpointsBuilder(AnyBorder(
        left: AnySide(width: 10, color: Colors.red),
        top: AnySide(width: 10, color: Colors.blue),
        right: AnySide(width: 10, color: Colors.red),
    )).build({ ContourTarget.top});

    const expecting = [

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner), // will be connected to first checkpoint

    ];

    expect(checkpoints, expecting);

  });

  test('red 10 left - blue 10 top - none right', () {

    final checkpoints = CheckpointsBuilder(AnyBorder(
      left: AnySide(width: 10, color: Colors.red),
      top: AnySide(width: 10, color: Colors.blue),
    )).build({ ContourTarget.top, ContourTarget.right });

    const expecting = [

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner), // will be connected to first checkpoint
    ];

    print(checkpoints);
    print(expecting);

    expect(checkpoints, expecting);


  });

}