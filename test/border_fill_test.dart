import 'dart:ui' as ui;
import 'package:any_borders/any_borders.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fill_regressions.dart';

const _background = Color(0xff99bb88);
const _border = Color(0xff223355);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fill interiors remain visible across paint types and DPRs', () async {
    expect(await checkFillRegressions(), 90);
  });
  test('multi-fill seams and varying alpha retain analytic coverage', () async {
    expect(await checkSideFillRegressions(), greaterThan(1000));
  });
  for (final corner in [
    const RoundedCorner(radius: 20),
    const BevelCorner(radius: 20),
    const InverseRoundedCorner(radius: 20)
  ]) {
    test(
        '${corner.runtimeType} uniform border retains its hole after translation',
        () {
      final c = AnyBoxDecoration(
              enableCache: false,
              background: const AnyBackground(color: _background),
              border: AnyBoxBorder(
                  corners: corner,
                  sides: const AnySide(width: 6, color: _border)))
          .buildContour(const Size(100, 80), TextDirection.ltr);
      final regions = c.regions(backgroundMerge: false);
      expect(regions.background!.$2.contains(const Offset(50, 40)), isTrue);
      expect(regions.regions.single.$2.contains(const Offset(50, 40)), isFalse);
      final shifted = regions.withOffset(const Offset(30, 20));
      expect(shifted.regions.single.$2.contains(const Offset(80, 60)), isFalse);
      expect(shifted.regions.single.$2.contains(const Offset(33, 60)), isTrue);
    });
  }

  test('border painting leaves the solid background visible at the center',
      () async {
    final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
    final painter = const AnyBoxDecoration(
            background: AnyBackground(color: _background),
            border: AnyBoxBorder(
                corners: RoundedCorner(radius: 20),
                sides: AnySide(width: 6, color: _border)))
        .createBoxPainter();
    painter.paint(
        canvas,
        const Offset(30, 20),
        const ImageConfiguration(
            size: Size(100, 80), textDirection: TextDirection.ltr));
    final picture = recorder.endRecording(),
        image = await picture.toImage(160, 120);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    List<int> pixel(int x, int y) =>
        List.generate(4, (i) => bytes.getUint8((y * 160 + x) * 4 + i));
    expect(pixel(80, 60), [153, 187, 136, 255]);
    expect(pixel(33, 60), [34, 51, 85, 255]);
    image.dispose();
    picture.dispose();
    painter.dispose();
  });
}
