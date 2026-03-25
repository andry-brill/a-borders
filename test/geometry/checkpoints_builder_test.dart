import 'package:any_borders/any_borders.dart';
import 'package:any_borders/geometry/checkpoints_builder.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {

  const outerAll = [

    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),

    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),

    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),

    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomRight, variant: ContourVariant.corner),

    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomCenter, variant: ContourVariant.side),

    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.bottomLeft, variant: ContourVariant.corner),
    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftBottom, variant: ContourVariant.corner),

    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftCenter, variant: ContourVariant.side),

    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.leftTop, variant: ContourVariant.corner),
    ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner),

  ];

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

    expect(checkpoints, expecting);


  });

  test('none top - blue 10 right - red 10 bottom', () {

    final checkpoints = CheckpointsBuilder(AnyBorder(
      bottom: AnySide(width: 10, color: Colors.red),
      right: AnySide(width: 10, color: Colors.blue),
    )).build({ ContourTarget.top, ContourTarget.right });

    const expecting = [

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.corner),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightTop, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner), // will be connected to first checkpoint

    ];

    expect(checkpoints, expecting);


  });


  test('red 10 left-bottom - blue 10 top-right', () {

    final checkpoints = CheckpointsBuilder(AnyBorder(
      left: AnySide(width: 10, color: Colors.red),
      top: AnySide(width: 10, color: Colors.blue),
      right: AnySide(width: 10, color: Colors.blue),
      bottom: AnySide(width: 10, color: Colors.red),
    )).build({
      ContourTarget.top,
      ContourTarget.right
    });

    const expecting = [

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topRight, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightTop, variant: ContourVariant.corner),

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.rightBottom, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.corner),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightTop, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.split),
      ContourCheckpoint(position: ContourPosition.outer, point: ContourPoint.topLeft, variant: ContourVariant.corner), // will be connected to first checkpoint

    ];

    expect(checkpoints, expecting);

  });

  test('blue 10 left-bottom-top-right outerBorder', () {

    final checkpoints = CheckpointsBuilder(AnyBorder(
      sides: AnySide(width: 10, color: Colors.blue),
    )).build({
      ContourTarget.top,
      ContourTarget.right,
      ContourTarget.bottom,
      ContourTarget.left,
    }, base: AnyShapeBase.outerBorder);

    expect(checkpoints, outerAll);

  });



  test('blue 10 left-bottom-top-right innerBorder', () {

    final checkpoints = CheckpointsBuilder(AnyBorder(
      sides: AnySide(width: 10, color: Colors.blue),
    )).build({
      ContourTarget.top,
      ContourTarget.right,
      ContourTarget.bottom,
      ContourTarget.left,
    }, base: AnyShapeBase.innerBorder);

    const expecting = [

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topRight, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightTop, variant: ContourVariant.corner),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.rightBottom, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.bottomRight, variant: ContourVariant.corner),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.bottomCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.bottomLeft, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.leftBottom, variant: ContourVariant.corner),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.leftCenter, variant: ContourVariant.side),

      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.leftTop, variant: ContourVariant.corner),
      ContourCheckpoint(position: ContourPosition.inner, point: ContourPoint.topLeft, variant: ContourVariant.corner),

    ];

    expect(checkpoints, expecting);

  });


  test('red 10 left - outside blue 10 top - red 10 right - blue background ', () {

    // expecting to have blue background
    final checkpoints = CheckpointsBuilder(AnyBorder(
      left: AnySide(width: 10, color: Colors.red),
      top: AnySide(width: 10, color: Colors.blue, align: AnyAlign.outside),
      right: AnySide(width: 10, color: Colors.red),
    )).build({ ContourTarget.background, ContourTarget.top});

    const expecting = [
      ContourCheckpoint(position:ContourPosition.outer,point:ContourPoint.topCenter,variant:ContourVariant.side),
      ContourCheckpoint(position:ContourPosition.outer,point:ContourPoint.topRight,variant:ContourVariant.corner),
      ContourCheckpoint(position:ContourPosition.outer,point:ContourPoint.topRight,variant:ContourVariant.split),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.rightTop,variant:ContourVariant.split),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.rightTop,variant:ContourVariant.corner),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.rightCenter,variant:ContourVariant.side),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.rightBottom,variant:ContourVariant.corner),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.bottomRight,variant:ContourVariant.corner),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.bottomCenter,variant:ContourVariant.side),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.bottomLeft,variant:ContourVariant.corner),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.leftBottom,variant:ContourVariant.corner),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.leftCenter,variant:ContourVariant.side),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.leftTop,variant:ContourVariant.corner),
      ContourCheckpoint(position:ContourPosition.middle,point:ContourPoint.leftTop,variant:ContourVariant.split),
      ContourCheckpoint(position:ContourPosition.outer,point:ContourPoint.topLeft,variant:ContourVariant.split),
      ContourCheckpoint(position:ContourPosition.outer,point:ContourPoint.topLeft,variant:ContourVariant.corner)
    ];

    expect(checkpoints, expecting);

  });

}