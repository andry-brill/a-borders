import 'dart:convert';
import 'dart:ui' as ui;
import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../example/lib/main.dart' as example;
import '../example/lib/repeated_borders.dart';

class _Images extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    // The animation test needs a decoded asset, not the demo's marble pixels.
    return ByteData.sublistView(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='));
  }
}

class _RotationCanvas extends Fake implements Canvas {
  final angles = <double>[];
  final pictures = <ui.Picture>[];

  @override
  void save() {}
  @override
  void restore() {}
  @override
  void translate(double dx, double dy) {}
  @override
  void rotate(double radians) => angles.add(radians);
  @override
  void drawPicture(ui.Picture picture) => pictures.add(picture);
}

void main() {
  testWidgets('repeated borders fill a row and join the shared animation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        DefaultAssetBundle(bundle: _Images(), child: const example.MyApp()));
    await tester.pumpAndSettle();
    final demo = find.byType(RepeatedBordersExample);
    await tester.scrollUntilVisible(demo, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final expectedWidth =
        example.rowLimit * example.w + (example.rowLimit - 1) * example.spacing;
    expect(tester.getSize(demo).width, expectedWidth);
    final canvas =
        find.descendant(of: demo, matching: find.byType(CustomPaint));
    expect(tester.getSize(canvas), Size(expectedWidth, 300));
    expect(find.text('500 wave rectangles · green + blue at 5% opacity'),
        findsOneWidget);

    final painter = tester.widget<CustomPaint>(canvas).painter!;
    _RotationCanvas sample() {
      final recording = _RotationCanvas();
      painter.paint(recording, tester.getSize(canvas));
      return recording;
    }

    var repaints = 0;
    void onRepaint() => repaints++;
    painter.addListener(onRepaint);
    final begin = sample();
    expect(begin.angles, hasLength(500));
    expect(begin.pictures.toSet(), hasLength(1));
    await tester.ensureVisible(canvas);
    await tester.tap(canvas);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final quarter = sample();
    await tester.pump(const Duration(milliseconds: 250));
    final middle = sample();
    await tester.pumpAndSettle();
    final end = sample();
    expect(repaints, greaterThan(0));
    expect(end.angles, isNot(orderedEquals(begin.angles)));
    for (var i = 0; i < 500; i++) {
      final delta = end.angles[i] - begin.angles[i];
      expect(
          quarter.angles[i],
          closeTo(
              begin.angles[i] + delta * example.curve.transform(0.25), 1e-10));
      expect(middle.angles[i], closeTo(begin.angles[i] + delta * 0.5, 1e-10));
    }
    expect(quarter.pictures.toSet().single, same(begin.pictures.first));
    expect(end.pictures.toSet().single, same(begin.pictures.first));
    // A second common toggle reverses the rotation animation as well.
    await tester.tap(canvas);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final reverse = sample();
    for (var i = 0; i < 500; i++) {
      expect(reverse.angles[i], closeTo(middle.angles[i], 1e-10));
    }
    await tester.pumpAndSettle();
    expect(sample().angles, orderedEquals(begin.angles));
    painter.removeListener(onRepaint);

    // Isolate the demo when checking narrower layouts: the existing gallery's
    // other rows intentionally retain their four fixed-width examples.
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RepeatedBordersExample())));
    await tester.binding.setSurfaceSize(const Size(900, 700));
    await tester.pumpAndSettle();
    expect(tester.getSize(canvas), const Size(900, 300));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery paints intermediate states and retires offscreen rows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        DefaultAssetBundle(bundle: _Images(), child: const example.MyApp()));
    await tester.pumpAndSettle();
    final first = find
        .byWidgetPredicate((w) => w is example.E && w.title == 'No horizontal');
    AnyDecoration decoration(Finder e) => tester
        .widget<DecoratedBox>(
            find.descendant(of: e, matching: find.byType(DecoratedBox)).first)
        .decoration as AnyDecoration;
    final widget = tester.widget<example.E>(first);
    expect(decoration(first), widget.begin);
    expect(find.byType(example.E).evaluate().length, lessThan(21));
    await tester.tap(find.text('No horizontal'));
    await tester.pump();
    final widths = <double>[];
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 160));
      final d = decoration(first);
      expect(d.enableCache, isFalse);
      widths.add(d
          .buildContours(const Size(200, 100), TextDirection.ltr)
          .last
          .sides
          .last
          .width);
    }
    expect(widths.first, lessThan(30));
    expect(widths.last, greaterThan(10));
    for (var i = 1; i < widths.length; i++) {
      expect(widths[i], lessThan(widths[i - 1]));
    }
    await tester.pumpAndSettle();
    expect(decoration(first), widget.end);
    await tester.scrollUntilVisible(find.text('Crown'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(first, findsNothing);
    final crown =
        find.byWidgetPredicate((w) => w is example.E && w.title == 'Crown');
    expect(decoration(crown), tester.widget<example.E>(crown).end);
    // Leave the shared gallery toggle in its initial state for other tests.
    await tester.tap(find.text('Crown'));
    await tester.pumpAndSettle();
    expect(decoration(crown), tester.widget<example.E>(crown).begin);
    expect(tester.takeException(), isNull);
  });
}
