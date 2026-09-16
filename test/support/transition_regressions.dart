import 'dart:ui' as ui;
import 'package:any_borders/any_borders.dart';
import 'package:flutter/painting.dart';

/// Independent filled-area/pixel expectations for explicit-to-automatic motion.
Future<int> checkTransitionRegressions() async {
  const size = Size(200, 100), origin = Offset(40, 20);
  const color = Color(0x80123456);
  const begin = AnyBoxDecoration(
      border: AnyBoxBorder(
          vertical: AnySide(width: 30, align: 1, color: color),
          outerCorners: RoundedCorner(radius: 30),
          innerCorners: RoundedCorner(radius: 30)));
  const end = AnyBoxDecoration(
      border: AnyBoxBorder(
          vertical: AnySide(width: 10, align: 1, color: color),
          corners: RoundedCorner(radius: 20),
          innerCorners: RoundedCorner(radius: 20)));
  final tween = AnyDecorationTween(begin: begin, end: end);
  var checks = 0;
  for (final dpr in [1, 2, 3]) {
    for (final t in [.25, .4999, .5, .5001, .75]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(dpr.toDouble());
      final painter = tween.lerp(t).createBoxPainter();
      painter.paint(canvas, origin, const ImageConfiguration(size: size));
      final picture = recorder.endRecording();
      final image = await picture.toImage(280 * dpr, 140 * dpr);
      picture.dispose();
      painter.dispose();
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final width = 30 - 20 * t, radius = 30 - 10 * t;
      final outer = Path()
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTRB(-width, 0, 200 + width, 100).shift(origin),
            Radius.elliptical(30, radius)));
      final inner = Path()
        ..addRRect(RRect.fromRectAndRadius(
            (Offset.zero & size).shift(origin), Radius.circular(radius)));
      bool inside(Offset p) => outer.contains(p) && !inner.contains(p);
      try {
        // Require stable coverage around each probe, excluding antialiased edges.
        for (var y = 3; y < 137; y += 3) {
          for (var x = 3; x < 277; x += 3) {
            final center = Offset(x + .5, y + .5);
            final expected = inside(center);
            if ([
              const Offset(-1.5, -1.5),
              const Offset(1.5, -1.5),
              const Offset(-1.5, 1.5),
              const Offset(1.5, 1.5)
            ].any((delta) => inside(center + delta) != expected)) continue;
            final i = ((center.dy * dpr).floor() * image.width +
                    (center.dx * dpr).floor()) *
                4;
            final alpha = bytes.getUint8(i + 3);
            if ((alpha - (expected ? 128 : 0)).abs() > 1) {
              throw StateError('Transition t=$t DPR=$dpr at $center: '
                  'alpha=$alpha, expected ${expected ? 128 : 0}');
            }
            checks++;
          }
        }
      } finally {
        image.dispose();
      }
    }
  }
  return checks;
}
