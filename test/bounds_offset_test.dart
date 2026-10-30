import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/any_extras.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _layout = Size(24, 14);
const _circleBounds = Rect.fromLTRB(0, -5, 24, 19);

AnyBoxDecoration _circle(double vertical, {double horizontal = 0}) =>
    AnyBoxDecoration(
        border: AnyBoxBorder(
            shape: AnyBoxShape.circle,
            horizontal: AnySide(offset: vertical),
            vertical: AnySide(offset: horizontal)));

void _rectNear(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 1e-5));
  expect(actual.top, closeTo(expected.top, 1e-5));
  expect(actual.right, closeTo(expected.right, 1e-5));
  expect(actual.bottom, closeTo(expected.bottom, 1e-5));
}

class _RawShape extends AnyDecoration {
  final int slotCount;
  final bool verticalScalar;
  final bool invalidBounds;
  static final discovered = <Rect>[];
  static int builds = 0;
  const _RawShape(
      {super.border,
      super.offset,
      this.slotCount = 1,
      this.verticalScalar = false,
      this.invalidBounds = false});

  @override
  List<double> sideOffsetsForBorder(
      Rect bounds, TextDirection? direction, AnyBorder border) {
    discovered.add(bounds);
    return List.filled(slotCount,
        verticalScalar ? 0 : bounds.width / 10 + border.sides.offset);
  }

  @override
  Rect adjustBounds(Rect bounds, TextDirection? direction, AnyBorder border,
      double offset, List<double> slots) {
    if (invalidBounds) return const Rect.fromLTRB(0, 0, double.infinity, 10);
    if (verticalScalar) {
      return Rect.fromLTRB(bounds.left, bounds.top - offset, bounds.right,
          bounds.bottom + offset);
    }
    return super.adjustBounds(bounds, direction, border, offset, slots);
  }

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
      AnyBorder border, List<double> slots) {
    builds++;
    return [
      for (final vertex in [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomRight,
        bounds.bottomLeft
      ])
        point(vertex,
            border: border,
            side:
                border.sides.copyWith(offset: slots.isEmpty ? 0 : slots.first))
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is _RawShape &&
      other.slotCount == slotCount &&
      other.verticalScalar == verticalScalar &&
      other.invalidBounds == invalidBounds &&
      super == other;
  @override
  int get hashCode =>
      Object.hash(super.hashCode, slotCount, verticalScalar, invalidBounds);
}

class _RejectOffsets extends _RawShape {
  const _RejectOffsets({super.offset});
  @override
  List<double> sideOffsetsForBorder(
          Rect bounds, TextDirection? direction, AnyBorder border) =>
      const [];
  @override
  Rect adjustBounds(Rect bounds, TextDirection? direction, AnyBorder border,
      double offset, List<double> slots) {
    if (offset != 0)
      throw UnsupportedError('Only zero bounds adjustments are supported.');
    return bounds;
  }
}

// Synchronous image fixture exercises the decoration image painter's supplied
// region and clip, with nonuniform pixels to expose incorrect fit coordinates.
class _ImageFill extends DecorationImage {
  final ui.Image imagePixels;
  _ImageFill(this.imagePixels) : super(image: const AssetImage('unused'));
  @override
  DecorationImagePainter createPainter(VoidCallback onChanged) =>
      _ImagePainter(imagePixels);
}

class _ImagePainter implements DecorationImagePainter {
  final ui.Image pixels;
  _ImagePainter(this.pixels);
  @override
  void paint(Canvas canvas, Rect rect, Path? clipPath,
      ImageConfiguration configuration,
      {double blend = 1, BlendMode blendMode = BlendMode.srcOver}) {
    canvas.save();
    if (clipPath != null) canvas.clipPath(clipPath);
    canvas.drawImageRect(
        pixels, const Rect.fromLTWH(0, 0, 2, 2), rect, Paint());
    canvas.restore();
  }

  @override
  void dispose() {}
}

Future<List<int>> _paintBytes(AnyDecoration decoration, Size size,
    Offset origin, int dpr, bool clip) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr.toDouble());
  final painter = decoration.createBoxPainter();
  if (clip)
    canvas.clipPath(decoration.getClipPath(origin & size, TextDirection.ltr));
  painter.paint(canvas, origin,
      ImageConfiguration(size: size, textDirection: TextDirection.ltr));
  final picture = recorder.endRecording();
  final image = await picture.toImage(60 * dpr, 60 * dpr);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return bytes.buffer.asUint8List().toList();
  } finally {
    image.dispose();
    picture.dispose();
    painter.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    AnyDecorationCache.clear();
    _RawShape.discovered.clear();
    _RawShape.builds = 0;
  });

  test('24 by 14 plus vertical 7 produces a centered circle of diameter 24',
      () {
    final d = _circle(7);
    final c = d.buildContour(_layout, TextDirection.ltr);
    _rectNear(c.clipPath.getBounds(), _circleBounds);
    expect(d.points(Offset.zero & _layout, null).map((p) => p.point), [
      _circleBounds.topLeft,
      _circleBounds.topRight,
      _circleBounds.bottomRight,
      _circleBounds.bottomLeft
    ]);
    for (final corner in c.shapeCorners) {
      _rectNear(
          Rect.fromCircle(center: corner.center!, radius: corner.circleRadius!),
          _circleBounds);
    }
    for (var i = 0; i < 32; i++) {
      final angle = 2 * math.pi * i / 32;
      final ray = Offset(math.cos(angle), math.sin(angle));
      expect(c.clipPath.contains(const Offset(12, 7) + ray * 11.9), isTrue);
      expect(c.clipPath.contains(const Offset(12, 7) + ray * 12.1), isFalse);
    }
    const origin = Offset(31, 42);
    _rectNear(d.getClipPath(origin & _layout, TextDirection.rtl).getBounds(),
        _circleBounds.shift(origin));
    expect(d.points(origin & _layout, TextDirection.rtl).first.point,
        _circleBounds.topLeft + origin);
  });

  test(
      'asymmetric adjustments move the fitted center; insets constrain both axes',
      () {
    const topOnly = AnyBoxDecoration(
        border:
            AnyBoxBorder(shape: AnyBoxShape.circle, top: AnySide(offset: 14)));
    _rectNear(topOnly.buildContour(_layout, null).clipPath.getBounds(),
        const Rect.fromLTRB(0, -12, 24, 12));
    _rectNear(_circle(-2).buildContour(_layout, null).clipPath.getBounds(),
        const Rect.fromLTRB(7, 2, 17, 12));
    _rectNear(
        _circle(7, horizontal: -4)
            .buildContour(_layout, null)
            .clipPath
            .getBounds(),
        const Rect.fromLTRB(4, -1, 20, 15));
  });

  test('rectangles, pills, squares and explicit ratios fit adjusted bounds',
      () {
    for (final shape in AnyBoxShape.values) {
      final d = AnyBoxDecoration(
          border:
              AnyBoxBorder(shape: shape, horizontal: const AnySide(offset: 7)));
      final expected =
          shape == AnyBoxShape.circle || shape == AnyBoxShape.square
              ? _circleBounds
              : const Rect.fromLTRB(0, -7, 24, 21);
      _rectNear(d.buildContour(_layout, null).clipPath.getBounds(), expected);
    }
    for (final ratio in <double?>[null, 0, -1, 2]) {
      final d = AnyBoxDecoration(
          border:
              AnyBoxBorder(ratio: ratio, horizontal: const AnySide(offset: 7)));
      _rectNear(
          d.buildContour(_layout, null).clipPath.getBounds(),
          ratio == 2
              ? const Rect.fromLTRB(0, 1, 24, 13)
              : const Rect.fromLTRB(0, -7, 24, 21));
    }
    const combined = AnyBoxDecoration(
        offset: 3,
        border: AnyBoxBorder(
            offset: -1,
            shape: AnyBoxShape.circle,
            horizontal: AnySide(offset: 5),
            vertical: AnySide(offset: -2)));
    _rectNear(combined.buildContour(_layout, null).clipPath.getBounds(),
        _circleBounds);
  });

  test(
      'layers fit independently and all primary boundary selectors follow the fitted source',
      () {
    for (final base in AnyShapeBase.values) {
      final d = AnyBoxDecoration.multi(
          primaryBorderIndex: 1,
          clipBase: base,
          shadowBase: base,
          background:
              AnyBackground(shapeBase: base, color: const Color(0xff123456)),
          borders: const [
            AnyBoxBorder(shape: AnyBoxShape.square),
            AnyBoxBorder(
                shape: AnyBoxShape.circle, horizontal: AnySide(offset: 7))
          ]);
      final layers = d.buildContours(_layout, null);
      _rectNear(
          layers.first.clipPath.getBounds(), const Rect.fromLTRB(5, 0, 19, 14));
      for (final path in [
        layers[1].clipPath,
        layers[1].shadowPath,
        layers[1].backgroundPath!
      ]) {
        _rectNear(path.getBounds(), _circleBounds);
      }
      expect(layers.first.backgroundPath, isNull);
    }
  });

  test(
      'width and alignment extend the fitted source without consuming fit space',
      () {
    for (final align in [-1.0, 0.0, 1.0]) {
      final d = AnyBoxDecoration(
          enableCache: false,
          border: AnyBoxBorder(
              shape: AnyBoxShape.circle,
              sides: AnySide(width: 4, align: align),
              horizontal: AnySide(offset: 7, width: 4, align: align)));
      final c = d.buildContour(_layout, null);
      _rectNear(c.pathFor(AnyShapeBase.shapeBorder).getBounds(), _circleBounds);
      _rectNear(c.pathFor(AnyShapeBase.outerBorder).getBounds(),
          _circleBounds.inflate(2 * (1 + align)));
      _rectNear(c.pathFor(AnyShapeBase.innerBorder).getBounds(),
          _circleBounds.deflate(2 * (1 - align)));
      final general = GeometryDiagnostics(forceGeneralRegions: true).run(
          () => d.buildContour(_layout, null).regions(backgroundMerge: false));
      final direct = c.regions(backgroundMerge: false);
      for (var i = 0; i < direct.regions.length; i++) {
        for (var x = -4.3; x < 28; x += 1.7) {
          for (var y = -9.3; y < 23; y += 1.7) {
            expect(direct.regions[i].$2.contains(Offset(x, y)),
                general.regions[i].$2.contains(Offset(x, y)));
          }
        }
      }
    }
  });

  test(
      'exhausted available bounds never build points or revive through border width',
      () {
    for (final v in [-7.0, -8.0, -100.0]) {
      final c = AnyBoxDecoration(
              border: AnyBoxBorder(
                  shape: AnyBoxShape.circle,
                  sides: const AnySide(width: 40, align: 1),
                  horizontal: AnySide(offset: v, width: 40, align: 1)))
          .buildContour(_layout, null);
      expect(c.count, 0);
      for (final base in AnyShapeBase.values) {
        expect(c.pathFor(base).computeMetrics(), isEmpty);
      }
    }
    const _RawShape(offset: -100).buildContour(_layout, null);
    expect(_RawShape.builds, 0);
  });

  test(
      'custom hooks use raw discovery, reject unsupported layouts and validate results',
      () {
    const raw = Rect.fromLTWH(10, 20, 24, 14);
    const d = _RawShape(border: AnyBorder(ratio: 1));
    final points = d.points(raw, TextDirection.rtl);
    expect(_RawShape.discovered, [raw]);
    expect(points.first.side.offset, 2.4);
    expect(points.first.point.dx, closeTo(12.6, 1e-8));
    expect(points.first.point.dy, closeTo(17.6, 1e-8));
    expect(() => const _RawShape(slotCount: 2).points(raw, null),
        throwsUnsupportedError);
    expect(() => const _RejectOffsets(offset: 1).points(raw, null),
        throwsUnsupportedError);
    expect(const _RejectOffsets().points(raw, null), hasLength(4));
    expect(() => const _RawShape(invalidBounds: true).points(raw, null),
        throwsArgumentError);
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity
    ]) {
      expect(() => _circle(value).buildContour(_layout, null),
          throwsArgumentError);
    }
    expect(
        () => const AnyBoxDecoration(offset: 1e308)
            .points(const Rect.fromLTWH(1e308, 0, 10, 10), null),
        throwsArgumentError);
    // Nonfinite unused defaults are replaced by finite selected sides.
    const unused = AnyBoxDecoration(
        border: AnyBoxBorder(
            shape: AnyBoxShape.circle,
            sides: AnySide(offset: double.infinity),
            horizontal: AnySide(offset: 7),
            vertical: AnySide()));
    _rectNear(
        unused.buildContour(_layout, null).clipPath.getBounds(), _circleBounds);
  });

  test(
      'circle animation fits current available bounds across the limiting axis',
      () {
    final a = _circle(0), b = _circle(10);
    for (final reverse in [false, true]) {
      final tween =
          AnyDecorationTween(begin: reverse ? b : a, end: reverse ? a : b);
      expect(tween.lerp(0), same(tween.begin));
      expect(tween.lerp(1), same(tween.end));
      for (final u in [0.0, .25, .49999, .5, .50001, .75, 1.0]) {
        final d = tween.lerp(reverse ? 1 - u : u);
        final diameter = math.min(24.0, 14 + 20 * u);
        final expected = Rect.fromCenter(
            center: const Offset(12, 7), width: diameter, height: diameter);
        _rectNear(d.buildContour(_layout, null).clipPath.getBounds(), expected);
        expect(d.points(Offset.zero & _layout, null).first.point.dx,
            closeTo(expected.left, 1e-8));
      }
    }
  });

  test('inset animation collapses and recovers at the geometric threshold', () {
    final a = _circle(0), b = _circle(-14);
    for (final reverse in [false, true]) {
      final tween =
          AnyDecorationTween(begin: reverse ? b : a, end: reverse ? a : b);
      for (final u in [.1, .49999, .5, .50001, .9]) {
        final c = tween.lerp(reverse ? 1 - u : u).buildContour(_layout, null);
        if (u >= .5) {
          expect(c.count, 0);
        } else {
          expect(c.clipPath.getBounds().width, closeTo(14 - 28 * u, 1e-5));
        }
      }
    }
  });

  test('ratio interpolation uses adjusted aspect for unconstrained endpoints',
      () {
    const a =
        AnyBoxDecoration(border: AnyBoxBorder(horizontal: AnySide(offset: 7)));
    const b = AnyBoxDecoration(
        border: AnyBoxBorder(ratio: 1, horizontal: AnySide(offset: 7)));
    final c = AnyDecorationTween(begin: a, end: b)
        .lerp(.5)
        .buildContour(_layout, null);
    final ratio = (24 / 28 + 1) / 2;
    _rectNear(
        c.clipPath.getBounds(),
        Rect.fromCenter(
            center: const Offset(12, 7), width: 24, height: 24 / ratio));
  });

  test(
      'nested samples retain ratio recipes and discover slots from each raw layout',
      () {
    final first = AnyDecorationTween(
        begin: const _RawShape(border: AnyBorder(ratio: 1)),
        end: const _RawShape(
            border: AnyBorder(ratio: 2, sides: AnySide(offset: 4))));
    final saved = first.lerp(.25);
    final retargeted = AnyDecorationTween(
        begin: saved,
        end: const _RawShape(
            border: AnyBorder(ratio: 3, sides: AnySide(offset: 8))));
    final middle = retargeted.lerp(.5);
    first.end = const _RawShape(border: AnyBorder(ratio: 10));
    for (final size in [_layout, const Size(40, 20)]) {
      final raw = const Offset(8, 11) & size;
      _RawShape.discovered.clear();
      final points = middle.points(raw, TextDirection.rtl);
      expect(_RawShape.discovered, everyElement(raw));
      final slot = size.width / 10 + 4.5;
      final available = raw.inflate(slot);
      const ratio = 2.125; // lerp(lerp(1, 2, .25), 3, .5)
      final width = math.min(available.width, available.height * ratio);
      final expected = Rect.fromCenter(
          center: raw.center, width: width, height: width / ratio);
      _rectNear(Rect.fromPoints(points[0].point, points[2].point), expected);
      expect(points.first.side.offset, closeTo(slot, 1e-8));
      final original = saved.points(raw, null);
      final savedSlot = size.width / 10 + 1;
      final savedAvailable = raw.inflate(savedSlot);
      final savedWidth =
          math.min(savedAvailable.width, savedAvailable.height * 1.25);
      _rectNear(
          Rect.fromPoints(original[0].point, original[2].point),
          Rect.fromCenter(
              center: raw.center,
              width: savedWidth,
              height: savedWidth / 1.25));
    }
  });

  test(
      'prepared geometry reuses equal fitted contexts despite different scalar adjustments',
      () {
    final tween = AnyDecorationTween(
        begin: const _RawShape(
            verticalScalar: true, offset: 7, border: AnyBorder(ratio: 1)),
        end: const _RawShape(
            verticalScalar: true, offset: 20, border: AnyBorder(ratio: 1)));
    for (final t in [.125, .25, .5, .75]) {
      _rectNear(tween.lerp(t).buildContour(_layout, null).clipPath.getBounds(),
          _circleBounds);
    }
    expect(_RawShape.builds, 2);
    tween.lerp(.9).buildContour(_layout, TextDirection.rtl);
    expect(_RawShape.builds, 4);
    tween.lerp(.9).buildContour(const Size(40, 14), TextDirection.rtl);
    expect(_RawShape.builds, 6);
  });

  test(
      'shared cache identity includes offsets and matches single/multi construction',
      () {
    final a = _circle(7), b = _circle(8);
    final sameA = AnyBoxDecoration.multi(borders: a.borders);
    final first = a.buildContours(_layout, null);
    expect(sameA, a);
    expect(sameA.hashCode, a.hashCode);
    expect(sameA.buildContours(_layout, null), same(first));
    expect(b.buildContours(_layout, null), isNot(same(first)));
    _rectNear(
        b.buildContour(_layout, null).clipPath.getBounds(), _circleBounds);
  });

  test(
      'tab helpers use the offset-adjusted ratio-fitted construction rectangle',
      () {
    for (final outward in [true, false]) {
      final actual = AnyTabDecoration(
          offsetOutward: outward,
          border: const AnyBoxBorder(
              ratio: 1,
              horizontal: AnySide(offset: 7),
              corners: RoundedCorner(radius: 3)));
      final reference = AnyTabDecoration(
          offsetOutward: outward,
          border: const AnyBoxBorder(corners: RoundedCorner(radius: 3)));
      expect(actual.points(Offset.zero & _layout, null).map((p) => p.point),
          reference.points(_circleBounds, null).map((p) => p.point));
    }
  });

  test(
      'expanded circle fill, border, shadow and clipping match explicit geometry at DPR 1/2/3',
      () async {
    for (final dpr in [1, 2, 3]) {
      for (final clip in [false, true]) {
        for (final style in BlurStyle.values) {
          AnyBoxDecoration fixture(bool expanded) => AnyBoxDecoration(
                  border: AnyBoxBorder(
                      shape: AnyBoxShape.circle,
                      sides: const AnySide(
                          width: 2, align: 0, color: Color(0xff0033ff)),
                      horizontal: AnySide(
                          offset: expanded ? 7 : 0,
                          width: 2,
                          align: 0,
                          color: const Color(0xff0033ff))),
                  background: const AnyBackground(
                      gradient: LinearGradient(
                          colors: [Color(0xffff3300), Color(0xff33ff00)])),
                  shadows: [
                    AnyShadow(
                        color: const Color(0x99000000),
                        offset: const Offset(3, 2),
                        blurRadius: 2,
                        style: style,
                        offsetClip: true)
                  ]);
          Future<List<int>> render(bool expanded) async {
            final d = fixture(expanded);
            final origin =
                expanded ? const Offset(15, 20) : const Offset(15, 15);
            final size = expanded ? _layout : const Size(24, 24);
            return _paintBytes(d, size, origin, dpr, clip);
          }

          expect(await render(true), await render(false),
              reason: 'DPR $dpr, clip $clip, shadow $style');
        }
      }
    }
  });
  test(
      'image regions and clips follow the expanded fitted contour at DPR 1/2/3',
      () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawColor(const Color(0xffff0000), BlendMode.src)
      ..drawRect(const Rect.fromLTWH(1, 0, 1, 2),
          Paint()..color = const Color(0xff0000ff));
    final picture = recorder.endRecording();
    final tile = await picture.toImage(2, 2);
    picture.dispose();
    try {
      AnyBoxDecoration fixture(bool expanded) => AnyBoxDecoration(
          background: AnyBackground(image: _ImageFill(tile)),
          border: AnyBoxBorder(
              shape: AnyBoxShape.circle,
              sides: AnySide(width: 3, image: _ImageFill(tile)),
              horizontal: AnySide(
                  offset: expanded ? 7 : 0,
                  width: 3,
                  image: _ImageFill(tile))));
      for (final dpr in [1, 2, 3]) {
        expect(
            await _paintBytes(
                fixture(true), _layout, const Offset(15, 20), dpr, false),
            await _paintBytes(fixture(false), const Size(24, 24),
                const Offset(15, 15), dpr, false));
      }
    } finally {
      tile.dispose();
    }
  });

  test(
      'authored corners and unequal widths are resolved on the new fitted bounds',
      () {
    AnyBoxDecoration fixture(bool expanded) => AnyBoxDecoration(
        enableCache: false,
        border: AnyBoxBorder(
            ratio: expanded ? 1 : null,
            corners: const RoundedCorner(radius: 5),
            outerTopLeft: const BevelCorner(radius: 7),
            innerBottomRight: const RoundedCorner(radius: 2),
            top: AnySide(offset: expanded ? 7 : 0, width: 2, align: 1),
            bottom: AnySide(offset: expanded ? 7 : 0, width: 4),
            right: const AnySide(width: 1),
            left: const AnySide(width: 3, align: 0)));
    final actual = fixture(true).buildContour(_layout, null);
    final expected = fixture(false).buildContour(const Size(24, 24), null);
    for (final base in AnyShapeBase.values) {
      final a = actual.pathFor(base),
          b = expected.pathFor(base).shift(const Offset(0, -5));
      for (var x = -4.3; x < 28; x += 1.3) {
        for (var y = -9.3; y < 23; y += 1.3) {
          expect(a.contains(Offset(x, y)), b.contains(Offset(x, y)));
        }
      }
    }
  });

  test(
      'inserted and removed ratio layers keep their endpoint bounds adjustments',
      () {
    const single = AnyBoxDecoration();
    const multi = AnyBoxDecoration.multi(primaryBorderIndex: 1, borders: [
      AnyBoxBorder(),
      AnyBoxBorder(
          shape: AnyBoxShape.circle,
          sides: AnySide(width: 4),
          horizontal: AnySide(offset: 7, width: 4))
    ]);
    for (final reverse in [false, true]) {
      final tween = AnyDecorationTween(
          begin: reverse ? multi : single, end: reverse ? single : multi);
      for (final t in [.25, .5, .75]) {
        final c = tween.lerp(t).buildContours(_layout, null)[1];
        _rectNear(
            c.pathFor(AnyShapeBase.shapeBorder).getBounds(), _circleBounds);
        expect(c.sides.first.width, 4 * (reverse ? 1 - t : t));
      }
    }
  });
}
