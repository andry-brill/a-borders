import 'dart:ui' as ui;

import 'package:any_borders/any_borders.dart';
import 'package:flutter/painting.dart';

/// Independent pixel expectations shared by native and standalone CanvasKit runs.
Future<int> checkPathOffsetRegressions() async {
  const size = Size(100, 60), origin = Offset(20, 20);
  const white = Color(0xffffffff), blue = Color(0xff0000ff);
  const green = Color(0xff00ff00), red = Color(0x80ff0000);
  const layered = AnyBoxDecoration.multi(
      offset: 2,
      borders: [
        AnyBoxBorder(offset: -6),
        AnyBoxBorder(offset: 4, sides: AnySide(width: 4, color: blue)),
        AnyBoxBorder(offset: -10, sides: AnySide(width: 3, color: red)),
      ],
      background: AnyBackground(color: green));
  const shadow = AnyBoxDecoration.multi(
      offset: 2,
      primaryBorderIndex: 1,
      borders: [AnyBoxBorder(offset: 10), AnyBoxBorder(offset: -6)],
      shadows: [AnyShadow(color: Color(0xff000000), offset: Offset(6, 0))]);
  const roundedOut = AnyBoxDecoration(
      offset: 8,
      border: AnyBoxBorder(corners: RoundedCorner(radius: 20)),
      background: AnyBackground(color: green));
  const roundedIn = AnyBoxDecoration(
      offset: -8,
      border: AnyBoxBorder(corners: RoundedCorner(radius: 20)),
      background: AnyBackground(color: green));
  const empty = AnyBoxDecoration(
      offset: -31,
      border: AnyBoxBorder(sides: AnySide(width: 80, align: 1, color: blue)),
      background: AnyBackground(color: green),
      shadows: [AnyShadow(color: Color(0xff000000), offset: Offset(6, 0))]);
  var checks = 0;
  for (final dpr in [1, 2, 3]) {
    for (final mode in [
      'layers',
      'shadow',
      'clip',
      'roundedOut',
      'roundedIn',
      'empty'
    ]) {
      final d = switch (mode) {
        'layers' => layered,
        'roundedOut' => roundedOut,
        'roundedIn' => roundedIn,
        'empty' => empty,
        _ => shadow,
      };
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..scale(dpr.toDouble())
        ..drawColor(white, BlendMode.src);
      final painter = d.createBoxPainter(() {});
      if (mode == 'clip') {
        canvas.clipPath(d.getClipPath(origin & size, TextDirection.ltr));
        canvas.drawPaint(Paint()..color = green);
      } else {
        painter.paint(
            canvas,
            origin,
            const ImageConfiguration(
                size: size, textDirection: TextDirection.ltr));
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(140 * dpr, 100 * dpr);
      picture.dispose();
      painter.dispose();
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final probes = mode == 'layers'
          ? <(int, int, List<int>)>[
              (15, 50, [0, 0, 255, 255]),
              (19, 50, [255, 255, 255, 255]),
              (25, 50, [0, 255, 0, 255]),
              (29, 50, [128, 127, 0, 255]),
              (35, 50, [0, 255, 0, 255]),
              (119, 50, [255, 255, 255, 255]),
              (124, 50, [0, 0, 255, 255]),
              (70, 15, [0, 0, 255, 255]),
              (70, 19, [255, 255, 255, 255]),
              (70, 25, [0, 255, 0, 255]),
              (70, 29, [128, 127, 0, 255]),
            ]
          : mode == 'shadow'
              ? <(int, int, List<int>)>[
                  (120, 50, [0, 0, 0, 255]),
                  (25, 50, [255, 255, 255, 255]),
                  (70, 23, [255, 255, 255, 255]),
                  (70, 25, [0, 0, 0, 255]),
                ]
              : mode == 'clip'
                  ? <(int, int, List<int>)>[
                      (25, 50, [0, 255, 0, 255]),
                      (23, 50, [255, 255, 255, 255]),
                      (70, 25, [0, 255, 0, 255]),
                      (70, 23, [255, 255, 255, 255]),
                      (117, 50, [255, 255, 255, 255]),
                    ]
                  : mode == 'roundedOut'
                      ? <(int, int, List<int>)>[
                          // Radius 20 at (32,32), not radius 28 at (40,40).
                          (19, 19, [0, 255, 0, 255]),
                          (15, 15, [255, 255, 255, 255]),
                          (70, 13, [0, 255, 0, 255]),
                          (70, 10, [255, 255, 255, 255]),
                        ]
                      : mode == 'roundedIn'
                          ? <(int, int, List<int>)>[
                              // Radius 20 at (48,48), not radius 12 at (40,40).
                              (32, 32, [255, 255, 255, 255]),
                              (36, 36, [0, 255, 0, 255]),
                              (70, 30, [0, 255, 0, 255]),
                              (70, 25, [255, 255, 255, 255]),
                            ]
                          : <(int, int, List<int>)>[
                              (15, 50, [255, 255, 255, 255]),
                              (30, 50, [255, 255, 255, 255]),
                              (70, 50, [255, 255, 255, 255]),
                              (125, 50, [255, 255, 255, 255]),
                            ];
      try {
        for (final (x, y, expected) in probes) {
          final index = (((y + 0.5) * dpr).floor() * image.width +
                  ((x + 0.5) * dpr).floor()) *
              4;
          final actual =
              List.generate(4, (channel) => bytes.getUint8(index + channel));
          for (var channel = 0; channel < 4; channel++) {
            if ((actual[channel] - expected[channel]).abs() > 1) {
              throw StateError('Offset $mode DPR $dpr at ($x,$y): '
                  'expected $expected, actual $actual');
            }
          }
          checks++;
        }
      } finally {
        image.dispose();
      }
    }
  }
  return checks + await _checkSideOffsetPixels();
}

Future<int> _checkSideOffsetPixels() async {
  const size = Size(100, 60), origin = Offset(20, 20);
  const white = Color(0xffffffff), green = Color(0xff00ff00);
  const blue = Color(0xff0000ff);
  const border = AnyBoxBorder(
      top: AnySide(offset: 8, width: 4, color: blue),
      right: AnySide(offset: -6, width: 4, color: blue),
      bottom: AnySide(offset: -4, width: 4, color: blue),
      left: AnySide(offset: 3, width: 4, color: blue));
  const asymmetric =
      AnyBoxDecoration(border: border, background: AnyBackground(color: green));
  const shadow = AnyBoxDecoration(
      border: AnyBoxBorder(
          top: AnySide(offset: 8),
          right: AnySide(offset: -6),
          bottom: AnySide(offset: -4),
          left: AnySide(offset: 3)),
      shadows: [AnyShadow(color: Color(0xff000000), offset: Offset(6, 0))]);
  final tween = AnyDecorationTween(
      begin: const AnyBoxDecoration(background: AnyBackground(color: green)),
      end: const AnyBoxDecoration(
          border: AnyBoxBorder(right: AnySide(offset: -120)),
          background: AnyBackground(color: green)));
  final fixtures = <(String, AnyDecoration, bool, List<(int, int, List<int>)>)>[
    (
      'asymmetric',
      asymmetric,
      false,
      [
        (15, 50, [255, 255, 255, 255]),
        (19, 50, [0, 0, 255, 255]),
        (23, 50, [0, 255, 0, 255]),
        (112, 50, [0, 0, 255, 255]),
        (115, 50, [255, 255, 255, 255]),
        (70, 14, [0, 0, 255, 255]),
        (70, 17, [0, 255, 0, 255]),
        (70, 10, [255, 255, 255, 255]),
        (70, 74, [0, 0, 255, 255]),
        (70, 77, [255, 255, 255, 255]),
      ]
    ),
    (
      'asymmetricClip',
      asymmetric,
      true,
      [
        (19, 50, [0, 255, 0, 255]),
        (15, 50, [255, 255, 255, 255]),
        (113, 50, [0, 255, 0, 255]),
        (115, 50, [255, 255, 255, 255]),
        (70, 13, [0, 255, 0, 255]),
        (70, 10, [255, 255, 255, 255]),
      ]
    ),
    (
      'asymmetricShadow',
      shadow,
      false,
      [
        (119, 50, [0, 0, 0, 255]),
        (121, 50, [255, 255, 255, 255]),
        (21, 50, [255, 255, 255, 255]),
        (25, 50, [0, 0, 0, 255]),
        (70, 13, [0, 0, 0, 255]),
        (70, 10, [255, 255, 255, 255]),
      ]
    ),
    (
      'beforeSideCollapse',
      tween.lerp(.8),
      false,
      [
        (21, 50, [0, 255, 0, 255]),
        (25, 50, [255, 255, 255, 255]),
      ]
    ),
    (
      'afterSideCollapse',
      tween.lerp(.9),
      false,
      [
        (21, 50, [255, 255, 255, 255]),
        (25, 50, [255, 255, 255, 255]),
      ]
    ),
  ];
  var checks = 0;
  for (final dpr in [1, 2, 3]) {
    for (final (name, decoration, clip, probes) in fixtures) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..scale(dpr.toDouble())
        ..drawColor(white, BlendMode.src);
      final painter = decoration.createBoxPainter();
      if (clip) {
        canvas
            .clipPath(decoration.getClipPath(origin & size, TextDirection.ltr));
        canvas.drawPaint(Paint()..color = green);
      } else {
        painter.paint(
            canvas,
            origin,
            const ImageConfiguration(
                size: size, textDirection: TextDirection.ltr));
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(140 * dpr, 100 * dpr);
      picture.dispose();
      painter.dispose();
      try {
        final bytes =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        for (final (x, y, expected) in probes) {
          final index = (((y + .5) * dpr).floor() * image.width +
                  ((x + .5) * dpr).floor()) *
              4;
          final actual =
              List.generate(4, (channel) => bytes.getUint8(index + channel));
          if (List.generate(4, (i) => (actual[i] - expected[i]).abs())
              .any((d) => d > 1)) {
            throw StateError('Side offset $name DPR $dpr at ($x,$y): '
                'expected $expected, actual $actual');
          }
          checks++;
        }
      } finally {
        image.dispose();
      }
    }
  }
  return checks;
}
