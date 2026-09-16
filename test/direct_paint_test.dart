import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:any_borders/any_borders.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

class _CustomSide extends AnySide {
  const _CustomSide() : super(width: 12, color: const Color(0x80994411));
}

class _Image extends DecorationImage {
  _Image() : super(image: const AssetImage('unused'));
  @override
  DecorationImagePainter createPainter(VoidCallback onChanged) =>
      _ImagePainter();
}

class _ImagePainter implements DecorationImagePainter {
  @override
  void paint(Canvas canvas, Rect rect, Path? clipPath,
      ImageConfiguration configuration,
      {double blend = 1, BlendMode blendMode = BlendMode.srcOver}) {
    canvas.save();
    if (clipPath != null) canvas.clipPath(clipPath);
    canvas.drawRect(rect, Paint()..color = const Color(0x80337799));
    canvas.restore();
  }

  @override
  void dispose() {}
}

Future<(ByteData, GeometryDiagnostics)> render(
    String mode, int dpr, bool legacy) async {
  final work = GeometryDiagnostics(legacyPainter: legacy);
  return work.run(() async {
    final sides = List.generate(
        4,
        (i) => AnySide(
            width: 12,
            color: Color(0x80224466 + i * 0x00201111),
            isAntiAlias: mode != 'noAA',
            blendMode: mode == 'blend' ? BlendMode.multiply : null,
            gradient: mode == 'gradient'
                ? LinearGradient(colors: [
                    Color(0x40224466 + i * 0x00201111),
                    Color(0xc0224466 + i * 0x00201111)
                  ])
                : null));
    if (mode == 'mixed' || mode == 'image') {
      sides[0] =
          AnySide(width: 12, image: _Image(), color: const Color(0x40663399));
    }
    if (mode == 'mixed' || mode == 'custom') sides[1] = const _CustomSide();
    final decoration = AnyBoxDecoration(
        enableCache: false,
        border: AnyBoxBorder(
            corners: const RoundedCorner(radius: 24),
            top: sides[0],
            right: sides[1],
            bottom: sides[2],
            left: sides[3]));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(dpr.toDouble())
      ..drawColor(const Color(0xffffffff), BlendMode.src);
    final painter = decoration.createBoxPainter(() {});
    painter.paint(
        canvas,
        const Offset(12, 12),
        const ImageConfiguration(
            size: Size(120, 90), textDirection: TextDirection.ltr));
    final picture = recorder.endRecording();
    final image = await picture.toImage(144 * dpr, 114 * dpr);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    picture.dispose();
    painter.dispose();
    return (bytes, work);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in [
    'solid',
    'gradient',
    'image',
    'custom',
    'mixed',
    'blend',
    'noAA'
  ]) {
    for (final dpr in [1, 2, 3]) {
      test('$mode DPR $dpr preserves grouped composition', () async {
        final (a, work) = await render(mode, dpr, false);
        final (b, legacy) = await render(mode, dpr, true);
        final layers = mode == 'blend'
            ? 0
            : mode == 'mixed'
                ? 3
                : mode == 'image' || mode == 'custom'
                    ? 2
                    : 1;
        expect(work[GeometryWork.layer], layers);
        expect(legacy[GeometryWork.layer], mode == 'blend' ? 0 : 5);
        expect(a.lengthInBytes, b.lengthInBytes);
        for (var i = 0; i < a.lengthInBytes; i++) {
          // Removing the intermediate 8-bit surface also removes its rounding
          // of interpolated gradient alpha and premultiplied color (two levels).
          expect((a.getUint8(i) - b.getUint8(i)).abs(),
              lessThanOrEqualTo(mode == 'gradient' ? 2 : 1),
              reason: 'pixel=${i ~/ 4} channel=${i % 4}');
        }
      });
    }
  }
}
