import 'dart:io';
import 'dart:ui' as ui;

import 'package:any_borders/any_borders.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/main.dart' as gallery;

// An external implementation exercises the public contract without depending
// on the built-in repeated-profile implementation.
class _CustomProfile extends AnyEdgeProfile {
  const _CustomProfile();

  @override
  List<AnyPoint> buildPoints(double length, AnySide side) => [
        AnyPoint(
          point: Offset(length / 2, 7),
          side: side,
          shape: const BevelCorner(radius: 2),
        ),
      ];

  @override
  bool operator ==(Object other) => other is _CustomProfile;

  @override
  int get hashCode => runtimeType.hashCode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(AnyDecorationCache.clear);

  test('specific, axis, all and straight profile fallbacks', () {
    const all = AnyStepsProfile(count: 2, depth: 8);
    const horizontal = AnyZigZagProfile(count: 3, depth: 6);
    const vertical = AnyStepsProfile(count: 4, depth: 5);
    const straight = AnyStraightProfile();
    expect(const AnyBoxBorderProfiles().resolvedProfiles,
        [straight, straight, straight, straight]);
    expect(const AnyBoxBorderProfiles(all: all).resolvedProfiles,
        [all, all, all, all]);
    const profiles = AnyBoxBorderProfiles(
        all: all, horizontal: horizontal, vertical: vertical, right: straight);
    expect(profiles.resolvedProfiles,
        [horizontal, straight, horizontal, vertical]);
    expect(() => profiles.resolvedProfiles.add(all), throwsUnsupportedError);
  });

  test('steps map onto all clockwise edges with their original side ownership',
      () {
    const sides = [
      AnySide(width: 1),
      AnySide(width: 2),
      AnySide(width: 3),
      AnySide(width: 4),
    ];
    final points = AnyBoxDecoration(
      border: AnyBoxBorder(
        top: sides[0],
        right: sides[1],
        bottom: sides[2],
        left: sides[3],
        profiles: const AnyBoxBorderProfiles(
            all: AnyStepsProfile(count: 1, depth: 10)),
      ),
    ).points(const Rect.fromLTWH(10, 20, 80, 40), null);
    const expected = [
      Offset(10, 20),
      Offset(30, 20),
      Offset(30, 30),
      Offset(70, 30),
      Offset(70, 20),
      Offset(90, 20),
      Offset(90, 30),
      Offset(80, 30),
      Offset(80, 50),
      Offset(90, 50),
      Offset(90, 60),
      Offset(70, 60),
      Offset(70, 50),
      Offset(30, 50),
      Offset(30, 60),
      Offset(10, 60),
      Offset(10, 50),
      Offset(20, 50),
      Offset(20, 30),
      Offset(10, 30),
    ];
    expect(points.map((p) => p.point), expected);
    for (var i = 0; i < points.length; i++) {
      expect(points[i].side, same(sides[i ~/ 5]));
    }
  });

  test('zigzags and clearances preserve endpoints and reflect for outset', () {
    const inset = AnyZigZagProfile(
        count: 2, depth: 9, startClearance: 10, endClearance: 30);
    const outset = AnyZigZagProfile(
        count: 2,
        depth: 9,
        startClearance: 10,
        endClearance: 30,
        placement: AnyEdgePlacement.outset);
    final a = inset.buildPoints(120, const AnySide());
    final b = outset.buildPoints(120, const AnySide());
    expect(a.map((p) => p.point), const [
      Offset(10, 0),
      Offset(30, 9),
      Offset(50, 0),
      Offset(70, 9),
      Offset(90, 0),
    ]);
    expect(
        b.map((p) => p.point), a.map((p) => Offset(p.point.dx, -p.point.dy)));
    expect(
        const AnyZigZagProfile(count: 1, depth: 9)
            .buildPoints(120, const AnySide())
            .map((p) => p.point),
        [const Offset(60, 9)]);
    expect(
        const AnyStepsProfile(
                count: 1, depth: 9, placement: AnyEdgePlacement.outset)
            .buildPoints(40, const AnySide())[1]
            .point,
        const Offset(10, -9));
  });

  test('generated corners do not inherit box corner or boundary overrides', () {
    const profile = AnyStepsProfile(
        count: 1,
        depth: 10,
        corners: RoundedCorner.infinity(),
        innerCorners: BevelCorner(radius: 2));
    const d = AnyBoxDecoration(
        border: AnyBoxBorder(
      corners: BevelCorner(radius: 8),
      outerCorners: BevelCorner(radius: 6),
      innerCorners: RoundedCorner(radius: 3),
      topRight: RoundedCorner(radius: 4),
      profiles: AnyBoxBorderProfiles(right: profile),
    ));
    final points = d.points(const Rect.fromLTWH(0, 0, 100, 80), null);
    expect(points[0].shape, const BevelCorner(radius: 8));
    expect(points[1].shape, const RoundedCorner(radius: 4));
    expect(points[1].outer, const BevelCorner(radius: 6));
    for (final p in points.skip(2).take(4)) {
      expect(p.shape, profile.corners);
      expect(p.outer, isNull);
      expect(p.inner, profile.innerCorners);
    }
  });

  test('profiles use fitted bounds and carry current interpolated side offsets',
      () {
    AnyBoxDecoration decoration(double offset, double depth) =>
        AnyBoxDecoration(
          border: AnyBoxBorder(
            right: AnySide(offset: offset, width: 3),
            profiles: AnyBoxBorderProfiles(
                right: AnyStepsProfile(count: 2, depth: depth)),
          ),
        );
    final tween =
        AnyDecorationTween(begin: decoration(2, 10), end: decoration(6, 30));
    final points =
        tween.lerp(.5).points(const Rect.fromLTWH(0, 0, 100, 80), null);
    expect(points[1].point, const Offset(104, 0));
    expect(points[3].point, const Offset(84, 10));
    for (final p in points.skip(1).take(9)) {
      expect(p.side.offset, 4);
      expect(p.side.width, 3);
    }
    const square = AnyBoxDecoration(
        border: AnyBoxBorder(
      shape: AnyBoxShape.square,
      right: AnySide(offset: 20),
      profiles:
          AnyBoxBorderProfiles(right: AnyStepsProfile(count: 1, depth: 5)),
    ));
    final fitted = square.points(const Rect.fromLTWH(0, 0, 100, 60), null);
    expect(fitted[1].point, const Offset(90, 0));
    expect(fitted[3].point, const Offset(85, 15));
  });

  test('custom profiles preserve local corners and map to physical edges', () {
    const d = AnyBoxDecoration(
        border: AnyBoxBorder(
      bottom: AnySide(offset: 3, width: 5),
      profiles: AnyBoxBorderProfiles(bottom: _CustomProfile()),
    ));
    final points = d.points(const Rect.fromLTWH(0, 0, 100, 60), null);
    expect(points[3].point, const Offset(50, 56));
    expect(points[3].shape, const BevelCorner(radius: 2));
    expect(points[3].side.offset, 3);
    expect(points[3].side.width, 5);
  });

  test('straight and collapsed profiles keep the ordinary four-point box', () {
    for (final profile in [
      const AnyStraightProfile(),
      const AnyStepsProfile(count: 2, depth: 0),
      const AnyZigZagProfile(count: 2, depth: 0),
      const AnyStepsProfile(
          count: 2, depth: 5, startClearance: 60, endClearance: 40),
      const AnyZigZagProfile(count: 2, depth: 5, startClearance: 110),
    ]) {
      final d = AnyBoxDecoration(
          border: AnyBoxBorder(profiles: AnyBoxBorderProfiles(all: profile)));
      final points = d.points(const Rect.fromLTWH(0, 0, 100, 60), null);
      expect(points.map((p) => p.point), const [
        Offset.zero,
        Offset(100, 0),
        Offset(100, 60),
        Offset(0, 60),
      ]);
      expect(d.buildContour(Size.zero, null).clipPath.getBounds(), Rect.zero);
    }
  });

  test('invalid built-in settings fail at construction in release as well', () {
    for (final profile in [
      const AnyStepsProfile(count: 0, depth: 5),
      const AnyZigZagProfile(count: -1, depth: 5),
      const AnyStepsProfile(count: 1, depth: -1),
      const AnyZigZagProfile(count: 1, depth: double.nan),
      const AnyStepsProfile(count: 1, depth: double.infinity),
      const AnyStepsProfile(count: 1, depth: 5, startClearance: -1),
      const AnyZigZagProfile(count: 1, depth: 5, endClearance: double.infinity),
    ]) {
      expect(
          () => profile.buildPoints(100, const AnySide()), throwsArgumentError);
    }
  });

  test('profile values distinguish cache keys and multi-border geometry', () {
    AnyBoxBorder border(double depth) => AnyBoxBorder(
        profiles: AnyBoxBorderProfiles(
            right: AnyStepsProfile(count: 2, depth: depth)));
    final a = AnyBoxDecoration(border: border(10));
    final sameValue = AnyBoxDecoration(border: border(10));
    final b = AnyBoxDecoration(border: border(20));
    expect(a, sameValue);
    expect(a.hashCode, sameValue.hashCode);
    expect(a, isNot(b));
    final first = a.buildContours(const Size(100, 80), null);
    expect(sameValue.buildContours(const Size(100, 80), null).single,
        same(first.single));
    final second = b.buildContour(const Size(100, 80), null);
    expect(first.single.clipPath.contains(const Offset(85, 20)), isTrue);
    expect(second.clipPath.contains(const Offset(85, 20)), isFalse);
    final layers = AnyBoxDecoration.multi(
        borders: [border(10), border(20)], primaryBorderIndex: 1);
    expect(layers.buildContours(const Size(100, 80), null), hasLength(2));
    expect(
        layers
            .buildContour(const Size(100, 80), null)
            .clipPath
            .contains(const Offset(85, 20)),
        isFalse);
    expect(const AnyStepsProfile(count: 2, depth: 10),
        isNot(const AnyZigZagProfile(count: 2, depth: 10)));
    expect(
        const AnyStepsProfile(count: 2, depth: 10),
        isNot(const AnyStepsProfile(
            count: 2, depth: 10, corners: RoundedCorner.infinity())));
  });

  test(
      'sharp notches and rounded turns share the normal contour/effects pipeline',
      () {
    for (final corner in [
      const RoundedCorner(),
      const RoundedCorner.infinity()
    ]) {
      final d = AnyBoxDecoration(
        border: AnyBoxBorder(
          sides: const AnySide(width: 3, color: Color(0xff102030)),
          profiles: AnyBoxBorderProfiles(
              right: AnyStepsProfile(count: 2, depth: 20, corners: corner)),
        ),
        background: const AnyBackground(color: Color(0xffffaacc)),
        clipBase: AnyShapeBase.shapeBorder,
        shadowBase: AnyShapeBase.shapeBorder,
      );
      final contour = d.buildContour(const Size(100, 80), null);
      for (final path in [
        contour.clipPath,
        contour.shadowPath,
        contour.backgroundPath!
      ]) {
        expect(path.contains(const Offset(90, 20)), isFalse);
        expect(path.contains(const Offset(70, 20)), isTrue);
        expect(path.contains(const Offset(90, 40)), isTrue);
      }
      // Resolve both offset boundaries and the filled border bands too.
      expect(contour.pathFor(AnyShapeBase.outerBorder).getBounds().isEmpty,
          isFalse);
      expect(contour.pathFor(AnyShapeBase.innerBorder).getBounds().isEmpty,
          isFalse);
      expect(contour.regions(backgroundMerge: false).regions, isNotEmpty);
    }
  });

  test('count changes retain the existing complete-sample midpoint fallback',
      () {
    AnyBoxDecoration d(int count) => AnyBoxDecoration(
            border: AnyBoxBorder(
          profiles: AnyBoxBorderProfiles(
              right: AnyStepsProfile(count: count, depth: 10)),
        ));
    final tween = AnyDecorationTween(begin: d(2), end: d(3));
    const rect = Rect.fromLTWH(0, 0, 100, 80);
    expect(tween.lerp(.49).points(rect, null), hasLength(12));
    expect(tween.lerp(.51).points(rect, null), hasLength(16));
  });

  test('centered profiles use equal inward and outward half-depths', () {
    const side = AnySide(width: 3);
    for (final profile in [
      const AnyZigZagProfile(
          count: 2, depth: 20, placement: AnyEdgePlacement.center),
      const AnyStepsProfile(
          count: 2, depth: 20, placement: AnyEdgePlacement.center),
    ]) {
      final points = profile.buildPoints(80, side);
      expect(points.map((p) => p.point.dy).toSet(), containsAll([-10.0, 10.0]));
      for (var i = 0; i < points.length; i++) {
        final opposite = points[points.length - 1 - i].point;
        expect(points[i].point, Offset(80 - opposite.dx, -opposite.dy));
        expect(points[i].side, same(side));
      }
      final shape = AnyBoxDecoration(
          border: AnyBoxBorder(
        profiles: AnyBoxBorderProfiles(top: profile),
      )).buildContour(const Size(80, 60), null).clipPath;
      expect(shape.getBounds(), const Rect.fromLTRB(0, -10, 80, 60));
      expect(shape.contains(const Offset(40, 30)), isTrue);
    }
    expect(
        const AnyZigZagProfile(
                count: 2, depth: 20, placement: AnyEdgePlacement.center)
            .buildPoints(80, side)
            .map((p) => p.point),
        const [
          Offset(20, 0),
          Offset(30, 10),
          Offset(50, -10),
          Offset(60, 0),
        ]);
  });

  test(
      'centered zigzags support odd counts, either first direction and auto ends',
      () {
    for (final count in [1, 3, 4, 7]) {
      for (final firstInside in [true, false]) {
        final profile = AnyZigZagProfile(
            count: count,
            depth: 20,
            placement: AnyEdgePlacement.center,
            firstInside: firstInside);
        final points = profile.buildPoints(180, const AnySide());
        final pitch = 180 / (count + 2);
        expect(points, hasLength(count + 2));
        expect(points.first.point, Offset(pitch, 0));
        expect(points.last.point, Offset(180 - pitch, 0));
        for (var i = 0; i < count; i++) {
          expect(points[i + 1].point.dx, closeTo(pitch * (i + 1.5), 1e-10));
          expect(
              points[i + 1].point.dy, (i.isEven == firstInside ? 1 : -1) * 10);
        }
      }
    }
    const a = AnyZigZagProfile(
        count: 7, depth: 20, placement: AnyEdgePlacement.center);
    const b = AnyZigZagProfile(
        count: 7,
        depth: 20,
        placement: AnyEdgePlacement.center,
        firstInside: false);
    expect(a, isNot(b));
    expect({a, b}, hasLength(2));
    final explicit = const AnyZigZagProfile(
            count: 3,
            depth: 20,
            placement: AnyEdgePlacement.center,
            startClearance: 12,
            endClearance: 18)
        .buildPoints(180, const AnySide());
    expect(explicit.first.point, const Offset(12, 0));
    expect(explicit.last.point, const Offset(162, 0));
    final mixed = const AnyZigZagProfile(
            count: 3,
            depth: 20,
            placement: AnyEdgePlacement.center,
            startClearance: 20)
        .buildPoints(180, const AnySide());
    expect(mixed.first.point, const Offset(20, 0));
    expect(mixed.last.point, const Offset(140, 0)); // Automatic half-wave = 40.
    final zero = const AnyZigZagProfile(
            count: 3,
            depth: 20,
            placement: AnyEdgePlacement.center,
            startClearance: 0,
            endClearance: 0)
        .buildPoints(180, const AnySide());
    expect(zero, hasLength(3));
  });

  test('infinite zigzag radii remain uniform through retargeting and reversal',
      () {
    AnyBoxDecoration decoration(double depth, {bool firstInside = true}) =>
        AnyBoxDecoration(
            border: AnyBoxBorder(
          corners: const RoundedCorner(radius: 5),
          profiles: AnyBoxBorderProfiles(
              top: AnyZigZagProfile(
            count: 7,
            depth: depth,
            firstInside: firstInside,
            placement: AnyEdgePlacement.center,
            corners: const RoundedCorner.infinity(),
          )),
        ));
    final a = decoration(8), b = decoration(32);
    final saved = AnyDecorationTween(begin: a, end: b).lerp(.35);
    final retargeted = AnyDecorationTween(begin: saved, end: decoration(18));
    final reversed =
        AnyDecorationTween(begin: a, end: decoration(8, firstInside: false));
    for (final width in [160.0, 240.0]) {
      for (final t in [.1, .3, .5, .7, .9]) {
        for (final tween in [retargeted, reversed]) {
          final contour = tween.lerp(t).buildContour(Size(width, 80), null);
          final peaks = contour.shapeCorners.skip(2).take(7).toList();
          final amplitudes = peaks
              .map((peak) =>
                  List.generate(21, (i) => peak.pointAt(i / 20).dy.abs())
                      .reduce((a, b) => a > b ? a : b))
              .toList();
          for (final amplitude in amplitudes) {
            expect(amplitude, closeTo(amplitudes.first, .001),
                reason: 'width=$width t=$t');
          }
          expect(contour.clipPath.contains(Offset(width / 2, 40)), isTrue);
        }
      }
    }
  });

  test('centered zigzags remain symmetric after rounding and animation',
      () async {
    AnyBoxDecoration decoration(double depth) => AnyBoxDecoration(
          border: AnyBoxBorder(
            corners: const RoundedCorner(radius: 10),
            sides: const AnySide(color: Color(0xFF386A64), width: 4, align: 0),
            profiles: AnyBoxBorderProfiles(
                horizontal: AnyZigZagProfile(
              count: 7,
              depth: depth,
              placement: AnyEdgePlacement.center,
              corners: const RoundedCorner.infinity(),
            )),
          ),
        );
    final tween =
        AnyDecorationTween(begin: decoration(12), end: decoration(24));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(const Color(0xfff4f9fb), BlendMode.src);
    for (var col = 0; col < 3; col++) {
      final d = tween.lerp(col / 2);
      final contour = d.buildContour(const Size(200, 100), TextDirection.ltr);
      final shape = contour.pathFor(AnyShapeBase.shapeBorder);
      expect(shape.getBounds().top, lessThan(0));
      expect(shape.getBounds().bottom, greaterThan(100));
      // Seven alternating lobes plus two clearance anchors along the top edge.
      // Check resolved curves, not just the unrounded control vertices.
      final top = contour.shapeCorners.skip(1).take(9).toList();
      expect(top.first.start.dy, closeTo(0, .001));
      expect(top.last.end.dy, closeTo(0, .001));
      expect(top.first.tangentAt(0).dy, closeTo(0, .001));
      expect(top.last.tangentAt(1).dy, closeTo(0, .001));
      expect(top.first.pointAt(.5).dy, greaterThan(0));
      final heights = <double>[];
      for (var i = 0; i < top.length; i++) {
        for (var j = 0; j <= 20; j++) {
          final p = top[i].pointAt(j / 20);
          final opposite = top[top.length - 1 - i].pointAt(1 - j / 20);
          expect((p - Offset(200 - opposite.dx, opposite.dy)).distance,
              lessThan(.001),
              reason: 'frame=$col corner=$i sample=$j');
          heights.add(p.dy);
        }
      }
      final minimum = heights.reduce((a, b) => a < b ? a : b);
      final maximum = heights.reduce((a, b) => a > b ? a : b);
      expect(maximum, greaterThan(1));
      expect(minimum, closeTo(-maximum, .001));
      for (final peak in top.skip(1).take(7)) {
        final amplitude =
            List.generate(21, (i) => peak.pointAt(i / 20).dy.abs())
                .reduce((a, b) => a > b ? a : b);
        expect(amplitude, closeTo(maximum, .001));
      }
      final origin = Offset(35 + col * 250.0, 65);
      final painter = d.createBoxPainter();
      painter.paint(
          canvas,
          origin,
          const ImageConfiguration(
              size: Size(200, 100), textDirection: TextDirection.ltr));
      painter.dispose();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(770, 230);
    const preview = String.fromEnvironment('CENTERED_PROFILE_PREVIEW');
    if (preview.isNotEmpty) {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(preview).writeAsBytes(png.buffer.asUint8List());
    }
    picture.dispose();
    image.dispose();
  });

  test('gradient profile examples paint endpoints and intermediate frames',
      () async {
    final examples = gallery
        .examples()
        .whereType<gallery.E>()
        .where((e) => e.title.startsWith('Gradient'))
        .toList();
    expect(examples, hasLength(2));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(const Color(0xfff4f4f4), BlendMode.src);
    for (var row = 0; row < examples.length; row++) {
      final e = examples[row];
      final tween = AnyDecorationTween(begin: e.begin, end: e.end);
      for (var col = 0; col < 5; col++) {
        final t = col / 4;
        final d = tween.lerp(t);
        final origin = Offset(30 + col * 240.0, 30 + row * 160.0);
        final painter = d.createBoxPainter();
        painter.paint(
            canvas,
            origin,
            const ImageConfiguration(
                size: Size(200, 100), textDirection: TextDirection.ltr));
        painter.dispose();
        final contour = d.buildContour(const Size(200, 100), TextDirection.ltr);
        expect(contour.clipPath.contains(const Offset(100, 50)), isTrue);
        expect(contour.regions(backgroundMerge: false).regions, isNotEmpty);
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1240, 340);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    for (var col = 0; col < 5; col++) {
      // Steps example: the filled center must survive all animation samples.
      final x = 130 + col * 240;
      final offset = (80 * image.width + x) * 4;
      expect(bytes.getUint8(offset), isNot(0xf4));
      expect(bytes.getUint8(offset + 3), 255);
    }
    const preview = String.fromEnvironment('PROFILE_PREVIEW');
    if (preview.isNotEmpty) {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(preview).writeAsBytes(png.buffer.asUint8List());
    }
    picture.dispose();
    image.dispose();
  });
}
