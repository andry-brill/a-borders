import 'dart:convert';
import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../example/lib/main.dart' as example;

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

void main() {
  testWidgets('gallery paints intermediate states and retires offscreen rows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        DefaultAssetBundle(bundle: _Images(), child: const example.MyApp()));
    await tester.pumpAndSettle();
    final first = find.byWidgetPredicate(
        (w) => w is example.E && w.title == 'Add a border layer');
    AnyDecoration decoration(Finder e) => tester
        .widget<DecoratedBox>(
            find.descendant(of: e, matching: find.byType(DecoratedBox)).first)
        .decoration as AnyDecoration;
    final widget = tester.widget<example.E>(first);
    expect(decoration(first), widget.begin);
    expect(find.byType(example.E).evaluate().length, lessThan(21));
    await tester.tap(find.text('Add a border layer'));
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
          .first
          .width);
    }
    expect(widths.first, greaterThan(0));
    expect(widths.last, lessThan(4));
    for (var i = 1; i < widths.length; i++) {
      expect(widths[i], greaterThan(widths[i - 1]));
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
