import 'dart:ui' as ui;

import 'package:any_borders/any_borders.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

// Shared by the native regression test and the standalone browser check.
// Use numeric pixel expectations, so neither backend is the other's oracle.
Future<int> checkFillRegressions() async {
  const background = Color(0xff99bb88), border = Color(0xff223355);
  const size = Size(100, 80), origin = Offset(30, 20);
  var checks = 0;
  final tileRecorder = ui.PictureRecorder();
  Canvas(tileRecorder).drawColor(border, BlendMode.src);
  final tilePicture = tileRecorder.endRecording();
  final tile = await tilePicture.toImage(2, 2);
  tilePicture.dispose();
  try {
    for (final corner in const [
      RoundedCorner(radius: 20),
      BevelCorner(radius: 20),
      InverseRoundedCorner(radius: 20)
    ]) {
      for (final mode in [
        'solid',
        'border gradient',
        'background gradient',
        'image',
        'shadow'
      ]) {
        final decoration = AnyBoxDecoration(
          enableCache: false,
          background: AnyBackground(
            color: mode == 'background gradient' ? null : background,
            gradient: mode == 'background gradient'
                ? const LinearGradient(colors: [background, background])
                : null,
          ),
          border: AnyBoxBorder(
            corners: corner,
            sides: AnySide(
              width: 6,
              color:
                  mode == 'border gradient' || mode == 'image' ? null : border,
              gradient: mode == 'border gradient'
                  ? const LinearGradient(colors: [border, border])
                  : null,
              image: mode == 'image' ? _TileImage(tile) : null,
            ),
          ),
          shadows: mode == 'shadow'
              ? const [AnyShadow(color: Color(0xff000000), blurRadius: 4)]
              : const [],
        );
        for (final dpr in [1, 2, 3]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..scale(dpr.toDouble());
          final painter = decoration.createBoxPainter(() {});
          painter.paint(
              canvas,
              origin,
              const ImageConfiguration(
                  size: size, textDirection: TextDirection.ltr));
          final picture = recorder.endRecording();
          final image = await picture.toImage(160 * dpr, 120 * dpr);
          try {
            final bytes =
                (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
            for (final sample in [
              (80, 60, const [153, 187, 136, 255]),
              (33, 60, const [34, 51, 85, 255]),
            ]) {
              final x = ((sample.$1 + 0.5) * dpr).floor();
              final y = ((sample.$2 + 0.5) * dpr).floor();
              final actual = List.generate(
                  4, (i) => bytes.getUint8((y * image.width + x) * 4 + i));
              for (var i = 0; i < 4; i++) {
                if ((actual[i] - sample.$3[i]).abs() > 1) {
                  throw StateError('${corner.runtimeType} $mode DPR $dpr '
                      'at (${sample.$1}, ${sample.$2}): '
                      'expected ${sample.$3}, got $actual');
                }
              }
              checks++;
            }
          } finally {
            image.dispose();
            picture.dispose();
            painter.dispose();
          }
        }
      }
    }
  } finally {
    tile.dispose();
  }
  return checks;
}

// Shared native/CanvasKit coverage oracles for the optimized multi-fill painter.
// Constant-alpha fills must retain that alpha across side seams. A separate
// varying-alpha gradient checks interpolation against its analytic linear ramp.
Future<int> checkSideFillRegressions() async {
  var checks = 0;
  for (final corner in const [
    RoundedCorner(radius: 20),
    BevelCorner(radius: 20),
    InverseRoundedCorner(radius: 20)
  ]) {
    for (final mode in ['solid', 'gradient', 'alpha gradient']) {
      final sides = List.generate(4, (i) {
        final rgb = 0x224466 + i * 0x201111;
        return AnySide(
            width: 12,
            color: Color(0x80000000 + rgb),
            gradient: mode == 'solid'
                ? null
                : LinearGradient(colors: [
                    Color((mode == 'alpha gradient' ? 0x40000000 : 0x80000000) +
                        rgb),
                    Color((mode == 'alpha gradient' ? 0xc0000000 : 0x80000000) +
                        rgb)
                  ]));
      });
      final decoration = AnyBoxDecoration(
          enableCache: false,
          border: AnyBoxBorder(
              corners: corner,
              top: sides[0],
              right: sides[1],
              bottom: sides[2],
              left: sides[3]));
      final contour =
          decoration.buildContour(const Size(100, 80), TextDirection.ltr);
      final outer = contour.pathFor(AnyShapeBase.outerBorder),
          inner = contour.pathFor(AnyShapeBase.innerBorder);
      final regionPaths = contour
          .regions(backgroundMerge: false)
          .regions
          .map((r) => r.$2)
          .toList();
      final topBounds = contour
          .regions(backgroundMerge: false)
          .regions
          .singleWhere((r) => r.$1 == sides[0])
          .$2
          .getBounds();
      for (final dpr in [1, 2, 3]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..scale(dpr.toDouble())
          ..translate(10, 10);
        final painter = decoration.createBoxPainter();
        painter.paint(
            canvas,
            Offset.zero,
            const ImageConfiguration(
                size: Size(100, 80), textDirection: TextDirection.ltr));
        final picture = recorder.endRecording(),
            image = await picture.toImage(120 * dpr, 100 * dpr);
        try {
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          // Compare the complete image with the preserved custom-fill grouped
          // route, including CanvasKit's corner-junction coverage quantization.
          final groupedSides = sides.map((s) => _GroupedSide(s)).toList();
          final grouped = AnyBoxDecoration(
              enableCache: false,
              border: AnyBoxBorder(
                  corners: corner,
                  top: groupedSides[0],
                  right: groupedSides[1],
                  bottom: groupedSides[2],
                  left: groupedSides[3]));
          final oldRecorder = ui.PictureRecorder(),
              oldCanvas = Canvas(oldRecorder)
                ..scale(dpr.toDouble())
                ..translate(10, 10);
          final oldPainter = grouped.createBoxPainter();
          oldPainter.paint(
              oldCanvas,
              Offset.zero,
              const ImageConfiguration(
                  size: Size(100, 80), textDirection: TextDirection.ltr));
          final oldPicture = oldRecorder.endRecording(),
              oldImage = await oldPicture.toImage(120 * dpr, 100 * dpr);
          try {
            final previous = (await oldImage.toByteData(
                format: ui.ImageByteFormat.rawRgba))!;
            for (var i = 0; i < bytes.lengthInBytes; i += 4) {
              final a = bytes.getUint8(i + 3), b = previous.getUint8(i + 3);
              for (var channel = 0; channel < 4; channel++) {
                final current = channel == 3
                    ? a.toDouble()
                    : bytes.getUint8(i + channel) * a / 255;
                final old = channel == 3
                    ? b.toDouble()
                    : previous.getUint8(i + channel) * b / 255;
                if ((current - old).abs() > 2) {
                  throw StateError(
                      '$corner $mode DPR $dpr pixel=${i ~/ 4} channel=$channel: $current vs grouped $old');
                }
              }
            }
            checks++;
          } finally {
            oldImage.dispose();
            oldPicture.dispose();
            oldPainter.dispose();
          }
          if (mode == 'alpha gradient') {
            for (final logicalX in [40, 50, 60]) {
              final x = (logicalX + 10) * dpr, y = 16 * dpr;
              final localX = (x + 0.5) / dpr - 10;
              final expected =
                  64 + 128 * (localX - topBounds.left) / topBounds.width;
              final actual = bytes.getUint8((y * image.width + x) * 4 + 3);
              if ((actual - expected).abs() > 1) {
                throw StateError(
                    '$corner alpha gradient DPR $dpr x=$localX: $actual vs $expected');
              }
              checks++;
            }
          } else {
            for (var y = 0; y < image.height; y++) {
              for (var x = 0; x < image.width; x++) {
                final p = Offset((x + 0.5) / dpr - 10, (y + 0.5) / dpr - 10);
                final neighborhood = [
                  for (final dx in [-1, 0, 1])
                    for (final dy in [-1, 0, 1]) p + Offset(dx / dpr, dy / dpr)
                ];
                final safelyInside = neighborhood
                    .every((q) => outer.contains(q) && !inner.contains(q));
                if (!safelyInside) continue;
                // CanvasKit has a pre-existing DPR-3 diagonal seam deficit in
                // both grouped and direct rendering (e.g. alpha 111 vs 128).
                // The full-image comparison above preserves those seam pixels.
                // Assert analytic alpha in side interiors on web, and across
                // the whole seam on native, using the unchanged six-level bound.
                if (kIsWeb &&
                    !regionPaths.any(
                        (path) => neighborhood.every(path.contains))) continue;
                final alpha = bytes.getUint8((y * image.width + x) * 4 + 3);
                if ((alpha - 128).abs() > 6) {
                  throw StateError(
                      '$corner $mode seam DPR $dpr at $p: alpha=$alpha');
                }
                checks++;
              }
            }
          }
        } finally {
          image.dispose();
          picture.dispose();
          painter.dispose();
        }
      }
    }
  }
  return checks;
}

class _GroupedSide extends AnySide {
  _GroupedSide(AnySide s)
      : super(width: s.width, color: s.color, gradient: s.gradient);
}

// An already loaded tile keeps this test focused on the region's image clip,
// independent of networking, assets, and image-provider scheduling.
class _TileImage extends DecorationImage {
  final ui.Image tile;
  _TileImage(this.tile) : super(image: const AssetImage('unused'));

  @override
  DecorationImagePainter createPainter(VoidCallback onChanged) =>
      _TilePainter(tile);
}

class _TilePainter implements DecorationImagePainter {
  final ui.Image tile;
  _TilePainter(this.tile);

  @override
  void paint(Canvas canvas, Rect rect, Path? clipPath,
      ImageConfiguration configuration,
      {double blend = 1, BlendMode blendMode = BlendMode.srcOver}) {
    canvas.save();
    if (clipPath != null) canvas.clipPath(clipPath);
    canvas.drawImageRect(tile, const Rect.fromLTWH(0, 0, 2, 2), rect, Paint());
    canvas.restore();
  }

  @override
  void dispose() {}
}
