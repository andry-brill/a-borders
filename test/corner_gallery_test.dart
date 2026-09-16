import 'dart:ui' as ui;
import 'package:any_borders/any_borders.dart';
import 'package:any_borders/extras/any_tab_decoration.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'corner_topology_test.dart' show outlined;

Future<ui.Image> gallery(int dpr) async {
  final recorder = ui.PictureRecorder(),
      canvas = Canvas(recorder)..scale(dpr.toDouble());
  canvas.drawColor(const Color(0xfff4f7fa), BlendMode.src);
  const corners = <AnyCorner>[
    RoundedCorner.elliptical(p: 30, n: 20),
    BevelCorner.elliptical(p: 30, n: 20),
    InverseRoundedCorner.elliptical(p: 30, n: 20)
  ];
  for (var col = 0; col < 3; col++) {
    final corner = corners[col], origin = Offset(40 + col * 190.0, 40);
    final decoration = AnyBoxDecoration.multi(borders: [
      AnyBoxBorder(
          corners: corner,
          sides: const AnySide(width: 16, align: 1, color: Color(0xff174358))),
      AnyBoxBorder(
          corners: corner,
          sides: const AnySide(
              width: 8,
              align: 1,
              gradient: LinearGradient(
                  colors: [Color(0xff57d7c2), Color(0xff358dd2)]))),
      AnyBoxBorder(
          corners: corner,
          sides: const AnySide(width: 2, align: 1, color: Color(0xffffffff))),
    ], background: const AnyBackground(color: Color(0xffd2e9e6)));
    final painter = decoration.createBoxPainter();
    painter.paint(
        canvas,
        origin,
        ImageConfiguration(
            size: const Size(120, 80),
            devicePixelRatio: dpr.toDouble(),
            textDirection: TextDirection.ltr));
    canvas.save();
    canvas.clipPath(decoration.getClipPath(
        origin & const Size(120, 80), TextDirection.ltr));
    for (var x = 0; x < 120; x += 12)
      canvas.drawRect(Rect.fromLTWH(origin.dx + x, origin.dy, 5, 80),
          Paint()..color = const Color(0xffb3d5d0));
    canvas.restore();
    painter.dispose();
    // A 60-degree source fillet / asymmetric cut / scoop.
    final c = outlined(
        const [Offset(0, 0), Offset(150, 0), Offset(75, 129.9038105676658)],
        corner,
        10);
    canvas.save();
    canvas.translate(25 + col * 190.0, 175);
    canvas.drawPath(c.pathFor(AnyShapeBase.shapeBorder),
        Paint()..color = const Color(0xffd2e9e6));
    canvas.drawPath(
        Path.combine(
            PathOperation.difference,
            c.pathFor(AnyShapeBase.outerBorder),
            c.pathFor(AnyShapeBase.innerBorder)),
        Paint()..color = const Color(0xff174358));
    canvas.drawPath(
        c.pathFor(AnyShapeBase.shapeBorder),
        Paint()
          ..color = const Color(0xff358dd2)
          ..style = PaintingStyle.stroke);
    canvas.restore();
  }
  final neck = outlined(const [
    Offset(0, 0),
    Offset(60, 0),
    Offset(60, 20),
    Offset(100, 20),
    Offset(100, 0),
    Offset(160, 0),
    Offset(160, 60),
    Offset(100, 60),
    Offset(100, 40),
    Offset(60, 40),
    Offset(60, 60),
    Offset(0, 60)
  ], const RoundedCorner(), 12);
  expect(neck.pathFor(AnyShapeBase.innerBorder).computeMetrics().length, 2);
  canvas.save();
  canvas.translate(20, 360);
  canvas.drawPath(neck.pathFor(AnyShapeBase.shapeBorder),
      Paint()..color = const Color(0xff174358));
  canvas.drawPath(neck.pathFor(AnyShapeBase.innerBorder),
      Paint()..color = const Color(0xff57d7c2));
  canvas.restore();
  final empty = outlined(
      const [Offset(0, 0), Offset(100, 0), Offset(100, 70), Offset(0, 70)],
      const InverseRoundedCorner(radius: 18),
      55);
  expect(empty.pathFor(AnyShapeBase.innerBorder).computeMetrics(), isEmpty);
  canvas.save();
  canvas.translate(250, 355);
  canvas.drawPath(empty.pathFor(AnyShapeBase.outerBorder),
      Paint()..color = const Color(0xff174358));
  canvas.restore();
  const tab = AnyTabDecoration(
      border: AnyBoxBorder(
          corners: RoundedCorner(radius: 18),
          sides: AnySide(
              width: 10,
              align: 0,
              gradient: LinearGradient(
                  colors: [Color(0xff57d7c2), Color(0xff358dd2)]))),
      background: AnyBackground(color: Color(0xffd2e9e6)));
  final painter = tab.createBoxPainter();
  painter.paint(
      canvas,
      const Offset(430, 355),
      const ImageConfiguration(
          size: Size(100, 70), textDirection: TextDirection.ltr));
  painter.dispose();
  final picture = recorder.endRecording(),
      image = await picture.toImage(580 * dpr, 450 * dpr);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final dpr in [1, 2, 3]) {
    test('corner gallery with clipping, layers and topology at DPR $dpr',
        () async {
      final image = await gallery(dpr);
      await expectLater(
          (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List(),
          matchesGoldenFile('goldens/corner_geometry_${dpr}x.png'));
      image.dispose();
    });
  }
}
