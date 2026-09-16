import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:any_borders/any_borders.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import '../example/lib/main.dart' as example;

List<example.E> reportedExamples() => example
    .examples()
    .whereType<example.E>()
    .where((e) => ['Any corner', 'Back+T+B', 'Crown'].contains(e.title))
    .toList();
AnyContour contour(AnyDecoration d) =>
    d.buildContour(const Size(200, 100), TextDirection.ltr);
void near(Offset actual, Offset expected) {
  expect((actual - expected).distance, lessThan(0.001));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'reported inverse showcase authors circular outer scoops at both endpoints',
      () {
    final e = reportedExamples().first;
    for (final entry in [
      (e.begin, const Offset(220, 0)),
      (e.end, const Offset(225, -25))
    ]) {
      final c = contour(entry.$1),
          corner = c.outerCorners[1],
          center = entry.$2;
      expect(corner.parameters, const InverseRoundedCorner(radius: 20));
      near(corner.center!, center);
      for (var i = 1; i < 20; i++) {
        final angle = i * math.pi / 40,
            direction = Offset(-math.cos(angle), math.sin(angle));
        final point = center + direction * 20;
        expect((corner.pointAt(i / 20) - point).distance, lessThan(0.001));
        expect(
            c
                .pathFor(AnyShapeBase.outerBorder)
                .contains(center + direction * 19.5),
            isFalse);
        expect(
            c
                .pathFor(AnyShapeBase.outerBorder)
                .contains(center + direction * 20.5),
            isTrue);
      }
      expect(
          entry.$1
              .points(Offset.zero & const Size(200, 100), TextDirection.ltr)
              .every((p) => p.outer != null && p.inner != null),
          isTrue);
    }
  });
  test(
      'reported crown retains its authored flat valleys and sloped lower outline',
      () {
    final e = reportedExamples().last,
        c = contour(e.begin),
        root2 = math.sqrt(2);
    // Independent intersections: a 45-degree side moved outward by 20 meets
    // its zero-offset neighbor at (50-10 sqrt(2),50-10 sqrt(2)). The authored
    // bevel consumes 20 along each ray at this right-angle valley.
    final y = 50 - 20 * root2;
    near(c.outerCorners[1].start, Offset(y, y));
    near(c.outerCorners[1].end, Offset(50, y));
    near(c.outerCorners[2].start, Offset(100 - 10 * root2, -10 * root2));
    near(c.outerCorners[2].end, Offset(100 + 10 * root2, -10 * root2));
    near(c.outerCorners[6].start, const Offset(150, 110));
    near(c.outerCorners[7].start, const Offset(50, 110));
    near(c.innerCorners[6].start, const Offset(150, 90));
    near(c.innerCorners[7].start, const Offset(50, 90));
    final dark = c
        .regions(backgroundMerge: false)
        .regions
        .singleWhere((r) => r.$1.color == example.greenD)
        .$2;
    expect(dark.contains(const Offset(100, 100)), isTrue);
    expect(dark.contains(const Offset(100, 85)), isFalse);
  });
  test(
      'all reported examples keep independent explicit roles through animation',
      () {
    for (final e in reportedExamples()) {
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final d = AnyDecorationTween(begin: e.begin, end: e.end).lerp(t),
            c = contour(d);
        expect(
            d
                .points(Offset.zero & const Size(200, 100), TextDirection.ltr)
                .every((p) => p.outer != null && p.inner != null),
            isTrue);
        final outer = c.pathFor(AnyShapeBase.outerBorder),
            inner = c.pathFor(AnyShapeBase.innerBorder);
        final expected = Path.combine(PathOperation.xor, outer, inner);
        final regions =
            c.regions(backgroundMerge: false).regions.map((r) => r.$2).toList();
        for (var x = -24.73; x < 225; x += 4) {
          for (var y = -80.31; y < 125; y += 4) {
            final point = Offset(x, y);
            expect(regions.where((p) => p.contains(point)).length,
                expected.contains(point) ? 1 : 0,
                reason: '${e.title}, t=$t, point=$point');
          }
        }
      }
    }
  });
  for (final dpr in [1, 2, 3]) {
    test('reported authored examples at DPR $dpr', () async {
      final recorder = ui.PictureRecorder(),
          canvas = Canvas(recorder)..scale(dpr.toDouble());
      canvas.drawColor(const Color(0xfff4f9fb), BlendMode.src);
      final examples = reportedExamples();
      for (var row = 0; row < examples.length; row++) {
        for (var col = 0; col < 2; col++) {
          final e = examples[row],
              d = col == 0 ? e.begin : e.end,
              painter = d.createBoxPainter();
          painter.paint(
              canvas,
              Offset(45 + col * 320.0, 100 + row * 240.0),
              ImageConfiguration(
                  size: const Size(200, 100),
                  textDirection: TextDirection.ltr,
                  devicePixelRatio: dpr.toDouble()));
          painter.dispose();
        }
      }
      final picture = recorder.endRecording(),
          image = await picture.toImage(650 * dpr, 720 * dpr);
      picture.dispose();
      await expectLater(
          (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List(),
          matchesGoldenFile('goldens/reported_examples_${dpr}x.png'));
      image.dispose();
    });
  }
}
