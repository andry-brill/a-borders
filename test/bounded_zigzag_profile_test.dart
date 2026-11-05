import 'dart:io';
import 'dart:ui' as ui;

import 'package:any_borders/any_borders.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import '../example/lib/main.dart' as gallery;

AnyBoxDecoration wave(double depth, {double align = -1}) => AnyBoxDecoration(
      border: AnyBoxBorder(
        corners: const RoundedCorner(radius: 16),
        sides: AnySide(width: 3, align: align, color: const Color(0xff000000)),
        profiles: AnyBoxBorderProfiles(
          horizontal: AnyZigZagProfile(
              fitToBounds: true,
              corners: const RoundedCorner.infinity(),
              count: 7,
              depth: depth,
              startClearance: 16,
              endClearance: 16),
          vertical: AnyZigZagProfile(
              fitToBounds: true,
              corners: const RoundedCorner.infinity(),
              count: 3,
              depth: depth,
              startClearance: 16,
              endClearance: 16),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wave source stays inside and touches all four rectangle bounds', () {
    final contour = wave(5).buildContour(const Size(200, 100), null);
    const rect = Rect.fromLTWH(0, 0, 200, 100);
    expect(contour.clipPath.getBounds(), rect);
    expect(contour.pathFor(AnyShapeBase.outerBorder).getBounds(), rect);
    expect(contour.shapeCorners.where((c) => c.frame.parallel), hasLength(20));
    for (final c in contour.shapeCorners) {
      for (var i = 0; i <= 40; i++) {
        final p = c.pointAt(i / 40);
        expect(p.dx, inInclusiveRange(-1e-8, 200 + 1e-8));
        expect(p.dy, inInclusiveRange(-1e-8, 100 + 1e-8));
      }
      if (c.frame.parallel) {
        final start = c.start - c.frame.vertex;
        final middle = c.pointAt(.5) - c.frame.vertex;
        final end = c.end - c.frame.vertex;
        double inward(Offset p) =>
            p.dx * c.frame.nextNormal.dx + p.dy * c.frame.nextNormal.dy;
        expect(inward(start), closeTo(0, 1e-8));
        expect(inward(end), closeTo(0, 1e-8));
        expect(inward(middle), closeTo(5, 1e-8));
        expect((c.tangentAt(0) - c.frame.nextRay).distance, lessThan(1e-8));
        expect((c.tangentAt(.5) - c.frame.nextRay).distance, lessThan(1e-8));
        expect((c.tangentAt(1) - c.frame.nextRay).distance, lessThan(1e-8));
      }
    }
    // Corner-to-wave and wave-to-wave joins have both matching contacts/tangents.
    final corners = contour.shapeCorners;
    for (var i = 0; i < corners.length; i++) {
      final next = corners[(i + 1) % corners.length];
      expect((corners[i].end - next.start).distance, lessThan(1e-8));
      expect((corners[i].tangentAt(1) - next.tangentAt(0)).distance,
          lessThan(1e-8));
    }
  });

  test(
      'wave boundaries follow normal offsets, including outer-to-zero continuation',
      () {
    final contour = wave(4, align: 0).buildContour(const Size(200, 100), null);
    for (var i = 0; i < contour.shapeCorners.length; i++) {
      final source = contour.shapeCorners[i];
      if (!source.frame.parallel) continue;
      for (var j = 0; j <= 20; j++) {
        final t = j / 20;
        final tangent = source.tangentAt(t);
        final inward = Offset(-tangent.dy, tangent.dx) * source.frame.winding;
        expect(
            (contour.innerCorners[i].pointAt(t) -
                    source.pointAt(t) -
                    inward * 1.5)
                .distance,
            lessThan(.001));
        expect(
            (contour.outerCorners[i].pointAt(t) -
                    source.pointAt(t) +
                    inward * 1.5)
                .distance,
            lessThan(.001));
        expect((contour.zeroCorners[i].pointAt(t) - source.pointAt(t)).distance,
            lessThan(.001));
      }
    }
    expect(contour.regions(backgroundMerge: false).regions, isNotEmpty);
  });

  test('depth animation and retargeting preserve the envelope', () {
    final tween = AnyDecorationTween(begin: wave(2), end: wave(6));
    final saved = tween.lerp(.4);
    final nested = AnyDecorationTween(begin: saved, end: wave(4));
    for (final size in [const Size(200, 100), const Size(240, 140)]) {
      for (final t in [0.0, .2, .5, .8, 1.0]) {
        for (final d in [tween.lerp(t), nested.lerp(t)]) {
          final c = d.buildContour(size, null);
          expect(c.clipPath.getBounds(), Offset.zero & size);
          expect(c.pathFor(AnyShapeBase.outerBorder).getBounds(),
              Offset.zero & size);
          expect(c.clipPath.contains(size.center(Offset.zero)), isTrue);
        }
      }
    }
  });

  test('shallow fitted zigzags use circular fillets', () {
    final source = wave(5)
        .buildContour(const Size(200, 100), null)
        .shapeCorners
        .firstWhere((c) => c.frame.parallel);
    // Horizontal repeat width is (200 - 32) / 7 = 24; half-width is 12.
    // A tangent arc pair spanning 12 horizontally and 5 vertically has R=8.45.
    const radius = (12.0 * 12 + 5.0 * 5) / (4 * 5);
    final center = source.start + source.frame.nextNormal * radius;
    for (var i = 0; i <= 20; i++) {
      expect((source.pointAt(i / 80) - center).distance, closeTo(radius, .001));
    }
  });

  test('deep fitted zigzags remain ordered and reflect for outset placement',
      () {
    for (final placement in [AnyEdgePlacement.inset, AnyEdgePlacement.outset]) {
      final d = AnyBoxDecoration(
          border: AnyBoxBorder(
        profiles: AnyBoxBorderProfiles(
            top: AnyZigZagProfile(
          count: 4,
          depth: 24,
          placement: placement,
          fitToBounds: true,
          corners: const RoundedCorner.infinity(),
        )),
      ));
      final c = d.buildContour(const Size(80, 100), null);
      expect(
          c.clipPath.getBounds(),
          Rect.fromLTRB(
              0, placement == AnyEdgePlacement.inset ? 0 : -24, 80, 100));
      for (final corner in c.shapeCorners.where((c) => c.frame.parallel)) {
        var previousX = corner.start.dx;
        for (var i = 0; i <= 80; i++) {
          final point = corner.pointAt(i / 80);
          expect(point.dx, greaterThanOrEqualTo(previousX - 1e-8));
          expect(point.dy.abs(), lessThanOrEqualTo(24 + 1e-8));
          previousX = point.dx;
        }
      }
    }
  });

  test('wave validation, collapse and value semantics', () {
    for (final p in [
      const AnyZigZagProfile(count: 2, depth: 5, fitToBounds: true),
      const AnyZigZagProfile(
          count: 2,
          depth: 5,
          fitToBounds: true,
          corners: RoundedCorner(radius: 10)),
      const AnyZigZagProfile(
          count: 2,
          depth: 5,
          fitToBounds: true,
          corners: RoundedCorner.infinity(converter: CornerConverter.equal)),
      const AnyZigZagProfile(
          count: 2,
          depth: 5,
          fitToBounds: true,
          placement: AnyEdgePlacement.center,
          corners: RoundedCorner.infinity()),
      const AnyZigZagProfile(
          fitToBounds: true,
          corners: RoundedCorner.infinity(),
          count: 0,
          depth: 5),
      const AnyZigZagProfile(
          fitToBounds: true,
          corners: RoundedCorner.infinity(),
          count: 2,
          depth: -1),
      const AnyZigZagProfile(
          fitToBounds: true,
          corners: RoundedCorner.infinity(),
          count: 2,
          depth: double.nan),
      const AnyZigZagProfile(
          fitToBounds: true,
          corners: RoundedCorner.infinity(),
          count: 2,
          depth: 5,
          startClearance: double.infinity),
    ]) {
      expect(() => p.buildPoints(100, const AnySide()), throwsArgumentError);
    }
    expect(
        const AnyZigZagProfile(
                fitToBounds: true,
                corners: RoundedCorner.infinity(),
                count: 2,
                depth: 0)
            .buildPoints(100, const AnySide()),
        isEmpty);
    expect(
        const AnyZigZagProfile(
                fitToBounds: true,
                corners: RoundedCorner.infinity(),
                count: 2,
                depth: 5,
                startClearance: 100)
            .buildPoints(100, const AnySide()),
        isEmpty);
    expect(
        AnyZigZagProfile(
            fitToBounds: true,
            corners: const RoundedCorner.infinity(),
            count: 2,
            depth: 5),
        const AnyZigZagProfile(
            fitToBounds: true,
            corners: RoundedCorner.infinity(),
            count: 2,
            depth: 5));
    expect(
        const AnyZigZagProfile(
            fitToBounds: true,
            corners: RoundedCorner.infinity(),
            count: 2,
            depth: 5),
        isNot(const AnyZigZagProfile(
            fitToBounds: true,
            corners: RoundedCorner.infinity(),
            count: 2,
            depth: 6)));
    expect(
        const AnyZigZagProfile(
            count: 2,
            depth: 5,
            fitToBounds: true,
            corners: RoundedCorner.infinity()),
        isNot(const AnyZigZagProfile(
            count: 2, depth: 5, corners: RoundedCorner.infinity())));
  });

  test('bounded wave shadow example paints the actual contour', () async {
    final example = gallery
        .examples()
        .whereType<gallery.E>()
        .singleWhere((e) => e.title == 'Bounded waves');
    final tween = AnyDecorationTween(begin: example.begin, end: example.end);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(const Color(0xfff4f9fb), BlendMode.src);
    for (var col = 0; col < 3; col++) {
      final d = tween.lerp(col / 2);
      final painter = d.createBoxPainter();
      painter.paint(
          canvas,
          Offset(30 + col * 250.0, 40),
          const ImageConfiguration(
              size: Size(200, 100), textDirection: TextDirection.ltr));
      painter.dispose();
      final contour = d.buildContour(const Size(200, 100), TextDirection.ltr);
      expect(
          contour.shadowPath.getBounds(), const Rect.fromLTWH(0, 0, 200, 100));
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(760, 190);
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    // White centers survive the shape/background construction in every frame.
    for (var col = 0; col < 3; col++) {
      final pixel = (90 * image.width + 130 + col * 250) * 4;
      expect(rgba.getUint8(pixel), 255);
      expect(rgba.getUint8(pixel + 3), 255);
    }
    const preview = String.fromEnvironment('WAVE_PROFILE_PREVIEW');
    if (preview.isNotEmpty) {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(preview).writeAsBytes(png.buffer.asUint8List());
    }
    picture.dispose();
    image.dispose();
  });
}
