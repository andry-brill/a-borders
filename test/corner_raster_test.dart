import 'dart:ui' as ui;
import 'package:any_borders/any_borders.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final dpr in [1, 2, 3]) {
    test('translucent corner partitions have continuous coverage at DPR $dpr',
        () async {
      for (final corner in [
        const RoundedCorner(radius: 20),
        const BevelCorner.elliptical(p: 30, n: 20),
        const InverseRoundedCorner(radius: 20)
      ]) {
        final decoration = AnyBoxDecoration(
            border: AnyBoxBorder(
                corners: corner,
                top: const AnySide(
                    width: 12, align: 0, color: Color(0x80ff0000)),
                right: const AnySide(
                    width: 12, align: 0, color: Color(0x8000ff00)),
                bottom: const AnySide(
                    width: 12, align: 0, color: Color(0x800000ff)),
                left: const AnySide(
                    width: 12, align: 0, color: Color(0x80ffff00))));
        final c =
            decoration.buildContour(const Size(100, 100), TextDirection.ltr);
        final ring = Path.combine(
            PathOperation.difference,
            c.pathFor(AnyShapeBase.outerBorder),
            c.pathFor(AnyShapeBase.innerBorder));
        final recorder = ui.PictureRecorder(),
            canvas = Canvas(recorder)
              ..scale(dpr.toDouble())
              ..translate(10, 10);
        final painter = decoration.createBoxPainter();
        painter.paint(
            canvas,
            Offset.zero,
            const ImageConfiguration(
                size: Size(100, 100), textDirection: TextDirection.ltr));
        final picture = recorder.endRecording(),
            image = await picture.toImage(120 * dpr, 120 * dpr);
        final bytes =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final p = Offset((x + 0.5) / dpr - 10, (y + 0.5) / dpr - 10);
            if ([
              p,
              p + Offset(1 / dpr, 0),
              p - Offset(1 / dpr, 0),
              p + Offset(0, 1 / dpr),
              p - Offset(0, 1 / dpr),
              p + Offset(1 / dpr, 1 / dpr),
              p + Offset(-1 / dpr, 1 / dpr),
              p + Offset(1 / dpr, -1 / dpr),
              p - Offset(1 / dpr, 1 / dpr)
            ].every(ring.contains)) {
              // Skia quantizes independently rasterized antialias masks; allow six
              // alpha levels, while the former source-over seam lost sixteen.
              expect(bytes.getUint8((y * image.width + x) * 4 + 3),
                  closeTo(128, 6),
                  reason: '${corner.runtimeType} pixel=$x,$y');
            }
          }
        }
        painter.dispose();
        picture.dispose();
        image.dispose();
      }
    });
  }
}
