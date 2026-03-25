

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/geometry/border_geometry.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';


void main() {

  test('empty decoration and border', () {

    final decoration =  AnyDecoration(
        border: AnyBorder(),
    );

    final bounds = Rect.fromLTRB(0, 0, 200, 100);
    final geometry = BorderGeometry.resolve(bounds, decoration.border);

    final regions = geometry.buildVisibleRegions(decoration);
    expect(regions.length, equals(0));

    for (var clip in AnyShapeBase.values) {

      final clipPath = geometry.pathForShapeBase(clip);
      final metrics = clipPath.computeMetrics().toList();
      final bounds = clipPath.getBounds();

      expect(bounds, equals(bounds));
      expect(metrics.length, equals(1));
      expect(metrics[0].length, equals(600));
      expect(metrics[0].isClosed, equals(true));
    }

  });

  test('background color and empty border', () {

    final decoration = AnyDecoration(
      border: AnyBorder(),
      color: Colors.blue
    );

    final bounds = Rect.fromLTRB(0, 0, 200, 100);
    final geometry = BorderGeometry.resolve(bounds, decoration.border);

    final regions = geometry.buildVisibleRegions(decoration);
    expect(regions.length, equals(1));

    final background = regions.first;
    expect(background.debugLabel, equals('background'));
    expect(background.path.getBounds(), equals(bounds));

    final backgroundMetrics = background.path.computeMetrics().toList();
    expect(backgroundMetrics.length, equals(1));
    expect(backgroundMetrics[0].length, equals(600));
    expect(backgroundMetrics[0].isClosed, equals(true));

    for (var clip in AnyShapeBase.values) {

      final clipPath = geometry.pathForShapeBase(clip);
      final metrics = clipPath.computeMetrics().toList();
      final bounds = clipPath.getBounds();

      expect(bounds, equals(bounds));
      expect(metrics.length, equals(1));
      expect(metrics[0].length, equals(600));
      expect(metrics[0].isClosed, equals(true));
    }

  });

  test('no background and border sides inside red', () {

    final decoration = AnyDecoration(
        border: AnyBorder(sides: AnySide(width: 10, color: Colors.blue, align: AnyAlign.inside)),
    );

    final bounds = Rect.fromLTRB(0, 0, 200, 100);
    final geometry = BorderGeometry.resolve(bounds, decoration.border);

    final regions = geometry.buildVisibleRegions(decoration);
    expect(regions.length, equals(1));

    final border = regions.first;
    expect(border.debugLabel, allOf(contains('top'), contains('left'), contains('bottom'), contains('right')));
    expect(border.path.getBounds(), equals(bounds));

    final borderMetrics = border.path.computeMetrics().toList();
    expect(borderMetrics.length, equals(2));
    expect(borderMetrics[0].length, equals(600));
    expect(borderMetrics[0].isClosed, isTrue);
    expect(borderMetrics[1].length, equals(520)); // as inside
    expect(borderMetrics[1].isClosed, isTrue);

    expect(border.path.contains(bounds.center), isFalse);

    expect(border.path.contains(bounds.topLeft), isTrue);
    expect(border.path.contains(bounds.topRight), isTrue);
    expect(border.path.contains(bounds.topCenter), isTrue);
    expect(border.path.contains(bounds.centerLeft), isTrue);
    expect(border.path.contains(bounds.centerRight), isTrue);
    expect(border.path.contains(bounds.bottomCenter), isTrue);
    expect(border.path.contains(bounds.bottomLeft), isTrue);
    expect(border.path.contains(bounds.bottomRight), isTrue);

    final Map<AnyShapeBase, (Rect, double)> expecting = {
      AnyShapeBase.zeroBorder: (bounds, 600),
      AnyShapeBase.outerBorder: (bounds, 600),
      AnyShapeBase.innerBorder: (bounds.inflate(-10), 520),
    };

    for (var entry in expecting.entries) {

      final clip = entry.key;
      final (bounds, length) = entry.value;

      final clipPath = geometry.pathForShapeBase(clip);
      final metrics = clipPath.computeMetrics().toList();
      final clipBounds = clipPath.getBounds();

      expect(clipBounds, equals(bounds));
      expect(metrics.length, equals(1));
      expect(metrics[0].length, equals(length));
      expect(metrics[0].isClosed, equals(true));
    }


  });

  test('no background and border sides center red', () {
    final decoration = AnyDecoration(
      border: AnyBorder(
        sides: AnySide(width: 10, color: Colors.blue, align: AnyAlign.center),
      ),
    );

    final bounds = Rect.fromLTRB(0, 0, 200, 100);
    final geometry = BorderGeometry.resolve(bounds, decoration.border);

    final regions = geometry.buildVisibleRegions(decoration);
    expect(regions.length, equals(1));

    final border = regions.first;
    expect(
      border.debugLabel,
      allOf(contains('top'), contains('left'), contains('bottom'), contains('right')),
    );
    expect(border.path.getBounds(), equals(Rect.fromLTRB(-5.0, -5.0, 205.0, 105.0)));

    final borderMetrics = border.path.computeMetrics().toList();
    expect(borderMetrics.length, equals(2));
    expect(borderMetrics[0].length, equals(640));
    expect(borderMetrics[0].isClosed, isTrue);
    expect(borderMetrics[1].length, equals(560)); // as center
    expect(borderMetrics[1].isClosed, isTrue);

    expect(border.path.contains(bounds.center), isFalse);

    expect(border.path.contains(bounds.topLeft), isTrue);
    expect(border.path.contains(bounds.topRight), isTrue);
    expect(border.path.contains(bounds.topCenter), isTrue);
    expect(border.path.contains(bounds.centerLeft), isTrue);
    expect(border.path.contains(bounds.centerRight), isTrue);
    expect(border.path.contains(bounds.bottomCenter), isTrue);
    expect(border.path.contains(bounds.bottomLeft), isTrue);
    expect(border.path.contains(bounds.bottomRight), isTrue);

    final Map<AnyShapeBase, (Rect, double)> expecting = {
      AnyShapeBase.zeroBorder: (bounds, 600),
      AnyShapeBase.outerBorder: (bounds.inflate(5), 640),
      AnyShapeBase.innerBorder: (bounds.inflate(-5), 560),
    };

    for (var entry in expecting.entries) {
      final clip = entry.key;
      final (bounds, length) = entry.value;

      final clipPath = geometry.pathForShapeBase(clip);
      final metrics = clipPath.computeMetrics().toList();
      final clipBounds = clipPath.getBounds();

      expect(clipBounds, equals(bounds));
      expect(metrics.length, equals(1));
      expect(metrics[0].length, equals(length));
      expect(metrics[0].isClosed, equals(true));
    }
  });

  test('no background and border sides outside red', () {

    final decoration = AnyDecoration(
      border: AnyBorder(
        sides: AnySide(width: 10, color: Colors.blue, align: AnyAlign.outside),
      ),
    );

    final bounds = Rect.fromLTRB(0, 0, 200, 100);
    final geometry = BorderGeometry.resolve(bounds, decoration.border);

    final regions = geometry.buildVisibleRegions(decoration);
    expect(regions.length, equals(1));

    final border = regions.first;
    expect(
      border.debugLabel,
      allOf(contains('top'), contains('left'), contains('bottom'), contains('right')),
    );
    expect(border.path.getBounds(), equals(Rect.fromLTRB(-10.0, -10.0, 210.0, 110.0)));

    final borderMetrics = border.path.computeMetrics().toList();
    expect(borderMetrics.length, equals(2));
    expect(borderMetrics[0].length, equals(680));
    expect(borderMetrics[0].isClosed, isTrue);
    expect(borderMetrics[1].length, equals(600)); // as outside
    expect(borderMetrics[1].isClosed, isTrue);

    expect(border.path.contains(bounds.center), isFalse);

    // Use points clearly in the outside border region (not exactly on the inner edge).
    expect(border.path.contains(const Offset(-5, -5)), isTrue);
    expect(border.path.contains(const Offset(205, -5)), isTrue);
    expect(border.path.contains(const Offset(100, -5)), isTrue);
    expect(border.path.contains(const Offset(-5, 50)), isTrue);
    expect(border.path.contains(const Offset(205, 50)), isTrue);
    expect(border.path.contains(const Offset(100, 105)), isTrue);
    expect(border.path.contains(const Offset(-5, 105)), isTrue);
    expect(border.path.contains(const Offset(205, 105)), isTrue);

    final Map<AnyShapeBase, (Rect, double)> expecting = {
      AnyShapeBase.zeroBorder: (bounds, 600),
      AnyShapeBase.outerBorder: (bounds.inflate(10), 680),
      AnyShapeBase.innerBorder: (bounds, 600),
    };

    for (var entry in expecting.entries) {
      final clip = entry.key;
      final (bounds, length) = entry.value;

      final clipPath = geometry.pathForShapeBase(clip);
      final metrics = clipPath.computeMetrics().toList();
      final clipBounds = clipPath.getBounds();

      expect(clipBounds, equals(bounds));
      expect(metrics.length, equals(1));
      expect(metrics[0].length, equals(length));
      expect(metrics[0].isClosed, equals(true));
    }
  });

  test('background and border sides same and diff fill', () {

    final bounds = Rect.fromLTRB(0, 0, 200, 100);

    final decorationDiff = AnyDecoration(
      border: AnyBorder(
        sides: AnySide(width: 10, color: Colors.blueAccent, align: AnyAlign.outside),
      ),
      color: Colors.blue
    );

    final geometryDiff = BorderGeometry.resolve(bounds, decorationDiff.border);

    final regionsDiff = geometryDiff.buildVisibleRegions(decorationDiff);
    expect(regionsDiff.length, equals(2));

    final decorationSame = AnyDecoration(
        border: AnyBorder(
          sides: AnySide(width: 10, color: Colors.blue, align: AnyAlign.outside),
        ),
        color: Colors.blue
    );

    final geometrySame = BorderGeometry.resolve(bounds, decorationSame.border);
    final regionsSame = geometrySame.buildVisibleRegions(decorationSame);
    expect(regionsSame.length, equals(1));

    final boundsSame = bounds.inflate(10);
    final border = regionsSame.first;
    expect(border.debugLabel, allOf(contains('background'), contains('top'), contains('left'), contains('bottom'), contains('right')));
    expect(border.path.getBounds(), equals(boundsSame));

    expect(border.path.contains(boundsSame.center), isTrue);
    expect(border.path.contains(boundsSame.topLeft), isTrue);
    expect(border.path.contains(boundsSame.bottomRight), isTrue);


  });
}