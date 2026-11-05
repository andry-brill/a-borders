import 'dart:ui' as ui;

import 'package:any_borders/any_borders.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _configuration = ImageConfiguration(
  size: Size(64, 40),
  textDirection: TextDirection.rtl,
  devicePixelRatio: 2,
);

// Mutable counters and failure injection belong only to this test probe.
// ignore: must_be_immutable
class _ProbeDecoration extends AnyBoxDecoration {
  _ProbeDecoration()
      : super(
          enableCache: false,
          background: const AnyBackground(color: Color(0xff22aa44)),
        );

  int paints = 0;
  int disposals = 0;
  bool fail = false;
  bool changeDuringPaint = false;
  late VoidCallback changed;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    changed = onChanged!;
    return _ProbePainter(this, super.createBoxPainter(onChanged));
  }
}

class _ProbePainter extends BoxPainter {
  _ProbePainter(this.owner, this.delegate);
  final _ProbeDecoration owner;
  final BoxPainter delegate;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    owner.paints++;
    if (owner.fail) throw StateError('recording failed');
    delegate.paint(canvas, offset, configuration);
    if (owner.changeDuringPaint) {
      owner.changeDuringPaint = false;
      owner.changed();
    }
  }

  @override
  void dispose() {
    owner.disposals++;
    delegate.dispose();
    super.dispose();
  }
}

// Supplies real DecorationImagePainter notifications without network or assets.
class _TestCompleter extends ImageStreamCompleter {
  void emit(ui.Image image) => setImage(ImageInfo(image: image));
}

class _StreamProvider extends ImageProvider<_StreamProvider> {
  final completer = _TestCompleter();

  @override
  Future<_StreamProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  void resolveStreamForKey(ImageConfiguration configuration, ImageStream stream,
      _StreamProvider key, ImageErrorListener handleError) {
    stream.setCompleter(completer);
  }
}

Future<ui.Image> _solidImage(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(2, 2);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> _pixels(void Function(Canvas) paint, {int dpr = 1}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr.toDouble());
  canvas.drawColor(const Color(0xffe8d5c0), BlendMode.src);
  paint(canvas);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(220 * dpr, 160 * dpr);
    try {
      final data =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('1000 instances and another frame reuse one recording', () {
    final decoration = _ProbeDecoration();
    var changes = 0;
    final renderer =
        decoration.resolveRenderer(_configuration, onChanged: () => changes++);
    expect(decoration.paints, 1); // Resolution prepares the picture eagerly.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(3, 7);
    final transform = canvas.getTransform();
    final saveCount = canvas.getSaveCount();
    for (var frame = 0; frame < 2; frame++) {
      for (var i = 0; i < 1000; i++) {
        renderer.paint(canvas, Offset(i % 50 * 2.0, i ~/ 50 * 2.0));
      }
    }
    expect(decoration.paints, 1);
    expect(canvas.getTransform(), orderedEquals(transform));
    expect(canvas.getSaveCount(), saveCount);

    decoration.changed();
    decoration.changed();
    expect(changes, 2);
    expect(decoration.paints, 1);
    renderer.paint(canvas, Offset.zero);
    renderer.paint(canvas, const Offset(4, 8));
    expect(decoration.paints, 2);
    renderer.dispose();
    renderer.dispose();
    expect(decoration.disposals, 1);
    decoration.changed();
    expect(changes, 2);
    expect(() => renderer.paint(canvas, Offset.zero), throwsStateError);
    recorder.endRecording().dispose();
  });

  test('notifications during recording survive and failed refresh can retry',
      () {
    final decoration = _ProbeDecoration()..changeDuringPaint = true;
    final renderer = decoration.resolveRenderer(_configuration);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    renderer.paint(canvas, Offset.zero);
    expect(decoration.paints, 2);
    decoration.fail = true;
    decoration.changed();
    final saveCount = canvas.getSaveCount();
    expect(() => renderer.paint(canvas, Offset.zero), throwsStateError);
    expect(canvas.getSaveCount(), saveCount);
    decoration.fail = false;
    renderer.paint(canvas, Offset.zero);
    expect(decoration.paints, 4);
    renderer.dispose();
    recorder.endRecording().dispose();
  });

  test('failed resolution releases the painter and partial picture', () {
    final pictures = <ui.Picture>[];
    ui.Picture.onCreate = pictures.add;
    addTearDown(() => ui.Picture.onCreate = null);
    final decoration = _ProbeDecoration()..fail = true;
    expect(() => decoration.resolveRenderer(_configuration), throwsStateError);
    expect(decoration.disposals, 1);
    expect(pictures, isNotEmpty);
    expect(pictures.every((picture) => picture.debugDisposed), isTrue);
  });

  test('replacing and disposing a recording releases its picture', () {
    final pictures = <ui.Picture>[];
    ui.Picture.onCreate = pictures.add;
    addTearDown(() => ui.Picture.onCreate = null);
    final decoration = _ProbeDecoration();
    final renderer = decoration.resolveRenderer(_configuration);
    final initial = pictures.single;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    decoration.changed();
    renderer.paint(canvas, Offset.zero);
    final refreshed = pictures.last;
    expect(initial.debugDisposed, isTrue);
    expect(refreshed.debugDisposed, isFalse);
    renderer.dispose();
    expect(refreshed.debugDisposed, isTrue);
    recorder.endRecording().dispose();
  });

  test('requires finite nonnegative size; empty size paints nothing', () async {
    const decoration = AnyBoxDecoration();
    for (final size in [
      null,
      const Size(double.infinity, 1),
      const Size(1, double.nan),
      const Size(-1, 10),
    ]) {
      expect(
        () => decoration.resolveRenderer(ImageConfiguration(size: size)),
        throwsArgumentError,
      );
    }
    final renderer =
        decoration.resolveRenderer(const ImageConfiguration(size: Size.zero));
    expect(await _pixels((c) => renderer.paint(c, Offset.zero)),
        orderedEquals(await _pixels((_) {})));
    renderer.dispose();
  });

  for (final style in BlurStyle.values) {
    for (final dpr in [1, 2]) {
      test('replay matches layered gradients, $style, overflow at DPR $dpr',
          () async {
        final decoration = AnyBoxDecoration.multi(
          offset: 2,
          background: const AnyBackground(color: Color(0x4022aa44)),
          shadows: [
            AnyShadow(
              color: const Color(0x60442288),
              blurRadius: 2,
              spreadRadius: const Offset(3, 2),
              offset: const Offset(-4, 3),
              style: style,
            ),
          ],
          borders: const [
            AnyBoxBorder(
              sides: AnySide(
                width: 4,
                align: AnySide.alignOutside,
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [Color(0x80339955), Color(0x40442288)],
                ),
              ),
              right: AnySide(width: 6, color: Color(0x60664422)),
              corners: RoundedCorner(radius: 6),
              profiles: AnyBoxBorderProfiles(
                horizontal: AnyZigZagProfile(
                  count: 3,
                  depth: 2,
                  startClearance: 8,
                  endClearance: 8,
                  corners: RoundedCorner.infinity(),
                ),
              ),
            ),
            AnyBoxBorder(
              sides: AnySide(
                width: 2,
                color: Color(0x5022aa44),
                blendMode: BlendMode.multiply,
              ),
              corners: BevelCorner(radius: 5),
            ),
          ],
        );
        final renderer = decoration.resolveRenderer(_configuration);
        final painter = decoration.createBoxPainter();
        const offsets = [Offset(18, 20), Offset(45, 45), Offset(130.5, 80.5)];
        void scene(Canvas canvas, bool replay) {
          canvas.translate(2, 3);
          canvas.clipRect(const Rect.fromLTWH(0, 0, 205, 145));
          for (final offset in offsets) {
            if (replay) {
              renderer.paint(canvas, offset);
            } else {
              painter.paint(canvas, offset, _configuration);
            }
          }
        }

        final actual = await _pixels((c) => scene(c, true), dpr: dpr);
        final expected = await _pixels((c) => scene(c, false), dpr: dpr);
        var largestDifference = 0;
        for (var i = 0; i < actual.length; i++) {
          final difference = (actual[i] - expected[i]).abs();
          if (difference > largestDifference) largestDifference = difference;
        }
        // Translation can introduce small float/antialias rounding differences.
        expect(largestDifference, lessThanOrEqualTo(2));
        renderer.dispose();
        painter.dispose();
      });
    }
  }

  test('late image and subsequent frames refresh; disposal removes listener',
      () async {
    final provider = _StreamProvider();
    // Keep the test's source alive while checking the renderer's own listener.
    final keepAlive = provider.completer.keepAlive();
    var changes = 0;
    final renderer = AnyBoxDecoration(
      background: AnyBackground(
        image: DecorationImage(image: provider, fit: BoxFit.fill),
      ),
    ).resolveRenderer(_configuration, onChanged: () => changes++);
    expect(provider.completer.hasListeners, isTrue);
    final unloaded = await _pixels((c) => renderer.paint(c, Offset.zero));
    for (final color in [const Color(0xff22aa44), const Color(0xffcc3344)]) {
      final previousChanges = changes;
      provider.completer.emit(await _solidImage(color));
      expect(changes, previousChanges + 1);
      final pixels = await _pixels((c) => renderer.paint(c, Offset.zero));
      expect(pixels, isNot(orderedEquals(unloaded)));
      final expected = await _pixels((c) => c.drawRect(
          Offset.zero & _configuration.size!, Paint()..color = color));
      expect(pixels, orderedEquals(expected));
    }
    renderer.dispose();
    expect(provider.completer.hasListeners, isFalse);
    keepAlive.dispose();
  });
}
