import 'dart:ui' as ui;

import 'package:any_borders/any_borders.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = Color(0xFF0000FF);
const _red = Color(0xFFFF0000);
const _white = Color(0xFFFFFFFF);
const _size = Size(100, 60);
const _origin = Offset(12, 12);

AnyBoxBorder _border(AnySide side) =>
    AnyBoxBorder(corners: const RoundedCorner(radius: 20), sides: side);

Future<ui.Image> _render(AnyDecoration decoration,
    {bool clipChild = false, int dpr = 1}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(dpr.toDouble())
    ..drawColor(_white, BlendMode.src);
  final painter = decoration.createBoxPainter(() {});
  painter.paint(canvas, _origin,
      const ImageConfiguration(size: _size, textDirection: TextDirection.ltr));
  if (clipChild) {
    canvas.save();
    canvas.clipPath(decoration.getClipPath(_origin & _size, TextDirection.ltr));
    canvas.drawRect(_origin & _size, Paint()..color = _red);
    canvas.restore();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(124 * dpr, 84 * dpr);
  picture.dispose();
  painter.dispose();
  return image;
}

Future<List<int>> _pixel(ui.Image image, int x, int y) async {
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final scale = image.width / 124;
  final i = (((y + 0.5) * scale).floor() * image.width +
          ((x + 0.5) * scale).floor()) *
      4;
  return List.generate(4, (channel) => bytes.getUint8(i + channel));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('later opaque layers cover earlier layers at the shared shape',
      () async {
    final decoration = AnyBoxDecoration.multi(borders: [
      _border(
          const AnySide(width: 4, align: AnySide.alignOutside, color: _blue)),
      _border(
          const AnySide(width: 2, align: AnySide.alignOutside, color: _red)),
    ]);
    final image = await _render(decoration);
    expect(await _pixel(image, 9, 42), [0, 0, 255, 255]);
    expect(await _pixel(image, 11, 42), [255, 0, 0, 255]);
    image.dispose();
    final reversed = await _render(
        AnyBoxDecoration.multi(borders: decoration.borders.reversed.toList()));
    expect(await _pixel(reversed, 11, 42), [0, 0, 255, 255]);
    reversed.dispose();
  });

  test('translucent overlapping borders composite in list order', () async {
    final image = await _render(AnyBoxDecoration.multi(borders: [
      _border(const AnySide(
          width: 4, align: AnySide.alignOutside, color: Color(0x800000FF))),
      _border(const AnySide(
          width: 2, align: AnySide.alignOutside, color: Color(0x80FF0000))),
    ]));
    final pixel = await _pixel(image, 11, 42);
    for (final pair in [(pixel[0], 191), (pixel[1], 63), (pixel[2], 127)]) {
      expect(pair.$1, closeTo(pair.$2, 1));
    }
    image.dispose();
  });

  test('gradient layers retain separate paint bounds and order', () async {
    final image = await _render(AnyBoxDecoration.multi(borders: [
      _border(const AnySide(
          width: 4,
          align: AnySide.alignOutside,
          gradient: LinearGradient(colors: [_blue, _blue]))),
      _border(const AnySide(
          width: 2,
          align: AnySide.alignOutside,
          gradient: LinearGradient(colors: [_red, _red]))),
    ]));
    expect(await _pixel(image, 9, 42), [0, 0, 255, 255]);
    expect(await _pixel(image, 11, 42), [255, 0, 0, 255]);
    image.dispose();
  });

  test('background paints once even when later layers share its fill',
      () async {
    final image = await _render(const AnyBoxDecoration.multi(
        background: AnyBackground(color: Color(0x800000FF)),
        borders: [AnyBoxBorder(), AnyBoxBorder()],
        primaryBorderIndex: 1));
    expect(await _pixel(image, 60, 42), [127, 127, 255, 255]);
    image.dispose();
  });

  test('identical gradients on different layers keep independent bounds',
      () async {
    final bounds = <Rect>[];
    final gradient = _BoundsGradient(bounds);
    final image = await _render(AnyBoxDecoration.multi(borders: [
      _border(
          AnySide(width: 4, align: AnySide.alignOutside, gradient: gradient)),
      _border(
          AnySide(width: 2, align: AnySide.alignOutside, gradient: gradient)),
    ]));
    expect(bounds, [
      const Rect.fromLTWH(8, 8, 108, 68),
      const Rect.fromLTWH(10, 10, 104, 64)
    ]);
    image.dispose();
  });

  test('shadows, background, inner shadows, and layers paint in order once',
      () async {
    final events = <String>[];
    final paths = <Path>[];
    final image = await _render(AnyBoxDecoration.multi(
      primaryBorderIndex: 1,
      borders: [
        AnyBoxBorder(sides: _TrackingSide(events, 'first')),
        AnyBoxBorder(ratio: 1, sides: _TrackingSide(events, 'second'))
      ],
      background: _TrackingBackground(events),
      shadows: [
        _TrackingShadow(events, paths, BlurStyle.inner),
        _TrackingShadow(events, paths, BlurStyle.normal)
      ],
    ));
    expect(events, ['normal', 'background', 'inner', 'first', 'second']);
    expect(paths.map((p) => p.getBounds()),
        everyElement(const Rect.fromLTWH(32, 12, 60, 60)));
    image.dispose();
  });

  test(
      'images share and dispose one painter across independently clipped layers',
      () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(_blue, BlendMode.src);
    final picture = recorder.endRecording();
    final tile = await picture.toImage(2, 2);
    picture.dispose();
    final events = <String>[];
    final imageFill = _TrackingImage(tile, events);
    final image = await _render(AnyBoxDecoration.multi(borders: [
      _border(AnySide(width: 4, align: AnySide.alignOutside, image: imageFill)),
      _border(AnySide(
          width: 2,
          align: AnySide.alignOutside,
          image: imageFill,
          color: _red)),
    ]));
    expect(await _pixel(image, 9, 42), [0, 0, 255, 255]);
    expect(await _pixel(image, 11, 42), [255, 0, 0, 255]);
    expect(await _pixel(image, 60, 42), [255, 255, 255, 255]);
    expect(events, ['create', 'image', 'image', 'dispose']);
    image.dispose();
    tile.dispose();
  });

  test('shape clipping follows primary rather than an explicit outer corner',
      () async {
    final image = await _render(
        const AnyBoxDecoration.multi(borders: [
          AnyBoxBorder(),
          AnyBoxBorder(
              corners: RoundedCorner(radius: 20), outerCorners: RoundedCorner())
        ], primaryBorderIndex: 1),
        clipChild: true);
    expect(await _pixel(image, 13, 13), [255, 255, 255, 255]);
    expect(await _pixel(image, 60, 42), [255, 0, 0, 255]);
    image.dispose();
  });

  for (final dpr in [1, 2, 3]) {
    test('image layers and clipped children at DPR $dpr', () async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(_blue, BlendMode.src);
      final picture = recorder.endRecording(),
          bitmap = await picture.toImage(2, 2);
      picture.dispose();
      for (final corner in [
        const RoundedCorner(radius: 20),
        const BevelCorner(radius: 20),
        const InverseRoundedCorner(radius: 20)
      ]) {
        final events = <String>[], fill = _TrackingImage(bitmap, events);
        final image = await _render(
            AnyBoxDecoration.multi(enableCache: false, borders: [
              AnyBoxBorder(
                  corners: corner,
                  sides: AnySide(width: 4, align: 1, image: fill)),
              AnyBoxBorder(
                  corners: corner,
                  sides: AnySide(width: 2, align: 1, image: fill))
            ]),
            clipChild: true,
            dpr: dpr);
        expect(await _pixel(image, 9, 42), [0, 0, 255, 255]);
        expect(await _pixel(image, 60, 42), [255, 0, 0, 255]);
        expect(await _pixel(image, 13, 13), [255, 255, 255, 255]);
        expect(events, ['create', 'image', 'image', 'dispose']);
        image.dispose();
      }
      bitmap.dispose();
    });
  }

  test('layered rounded, bevel, and scoop rendering and clipping', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(_white, BlendMode.src);
    const shapes = <AnyCorner>[
      RoundedCorner(radius: 18),
      BevelCorner(radius: 18),
      InverseRoundedCorner(radius: 18)
    ];
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        final origin = Offset(20.0 + 160 * col, 24.0 + 120 * row);
        const size = Size(120, 64);
        final shape = shapes[col];
        final decoration = AnyBoxDecoration.multi(
          primaryBorderIndex: row == 0 ? 0 : 1,
          borders: [
            AnyBoxBorder(
                corners: shape,
                sides: const AnySide(
                    width: 8,
                    align: AnySide.alignOutside,
                    color: Color(0xFF153F4F))),
            AnyBoxBorder(
                corners: shape,
                sides: const AnySide(
                    width: 4,
                    align: AnySide.alignOutside,
                    gradient: LinearGradient(
                        colors: [Color(0xFF63DCC6), Color(0xFF3696DD)]))),
            AnyBoxBorder(
                corners: shape,
                sides: const AnySide(
                    width: 2,
                    align: AnySide.alignOutside,
                    color: Color(0xFFFFFFFF))),
          ],
          background: const AnyBackground(color: Color(0xFFE6F3F1)),
        );
        final painter = decoration.createBoxPainter(() {});
        painter.paint(
            canvas,
            origin,
            const ImageConfiguration(
                size: size, textDirection: TextDirection.ltr));
        painter.dispose();
        if (row == 1) {
          canvas.save();
          canvas.clipPath(
              decoration.getClipPath(origin & size, TextDirection.ltr));
          for (var x = 0; x < 120; x += 12) {
            canvas.drawRect(Rect.fromLTWH(origin.dx + x, origin.dy, 6, 64),
                Paint()..color = const Color(0xFF9DDCCF));
          }
          canvas.restore();
        }
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(480, 240);
    picture.dispose();
    await expectLater(
        (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List(),
        matchesGoldenFile('goldens/multi_borders.png'));
    image.dispose();
  });
}

class _BoundsGradient extends LinearGradient {
  final List<Rect> bounds;
  _BoundsGradient(this.bounds) : super(colors: const [_blue, _red]);
  @override
  ui.Shader createShader(Rect rect, {TextDirection? textDirection}) {
    bounds.add(rect);
    return super.createShader(rect, textDirection: textDirection);
  }
}

class _TrackingSide extends AnySide {
  final List<String> events;
  final String name;
  _TrackingSide(this.events, this.name) : super(width: 4, color: _blue);
  @override
  Paint? createBasePaint(Path path, ImageConfiguration configuration) {
    events.add(name);
    return super.createBasePaint(path, configuration);
  }
}

class _TrackingBackground extends AnyBackground {
  final List<String> events;
  _TrackingBackground(this.events) : super(color: _blue);
  @override
  Paint? createBasePaint(Path path, ImageConfiguration configuration) {
    events.add('background');
    return super.createBasePaint(path, configuration);
  }
}

class _TrackingShadow extends AnyShadow {
  final List<String> events;
  final List<Path> paths;
  _TrackingShadow(this.events, this.paths, BlurStyle style)
      : super(color: _blue, style: style);
  @override
  void paint(Canvas canvas, Path path, ImageConfiguration configuration,
      DecorationImagePainter? Function(AnyFill) painterOf) {
    events.add(style == BlurStyle.inner ? 'inner' : 'normal');
    paths.add(path);
  }
}

class _TrackingImage extends DecorationImage {
  final ui.Image bitmap;
  final List<String> events;
  _TrackingImage(this.bitmap, this.events)
      : super(image: const AssetImage('unused'));
  @override
  DecorationImagePainter createPainter(VoidCallback onChanged) {
    events.add('create');
    return _TrackingImagePainter(bitmap, events);
  }
}

class _TrackingImagePainter implements DecorationImagePainter {
  final ui.Image bitmap;
  final List<String> events;
  _TrackingImagePainter(this.bitmap, this.events);
  @override
  void paint(Canvas canvas, Rect rect, Path? clipPath,
      ImageConfiguration configuration,
      {double blend = 1, BlendMode blendMode = BlendMode.srcOver}) {
    events.add('image');
    canvas.save();
    if (clipPath != null) canvas.clipPath(clipPath);
    canvas.drawImageRect(
        bitmap,
        Rect.fromLTWH(0, 0, bitmap.width.toDouble(), bitmap.height.toDouble()),
        rect,
        Paint());
    canvas.restore();
  }

  @override
  void dispose() => events.add('dispose');
}
