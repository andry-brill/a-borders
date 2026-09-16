import 'dart:math' as math;
import 'dart:ui';
import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';

// A subclass deliberately exercises the general geometry route, with the
// identical analytic corner equations and no rectangular fast-path assumptions.
class _GeneralRounded extends RoundedCorner {
  final List<(double, double)> calls;
  _GeneralRounded(this.calls, {super.p, super.n, super.converter})
      : super.elliptical();
  @override
  _GeneralRounded copyWith(
          {double? p, double? n, CornerConverter? converter}) =>
      _GeneralRounded(calls,
          p: p ?? this.p,
          n: n ?? this.n,
          converter: converter ?? this.converter);
  @override
  AnyCornerGeometry get geometry => const _GeneralRoundedGeometry();
}

class _GeneralRoundedGeometry extends RoundedCornerGeometry {
  const _GeneralRoundedGeometry();
  @override
  AnyResolvedCorner resolveBoundary(AnyResolvedCorner source,
      {required double previousDistance, required double nextDistance}) {
    (source.source as _GeneralRounded)
        .calls
        .add((previousDistance, nextDistance));
    return super.resolveBoundary(source,
        previousDistance: previousDistance, nextDistance: nextDistance);
  }
}

class _GeneralBevel extends BevelCorner {
  const _GeneralBevel({super.p, super.n, super.converter}) : super.elliptical();
  @override
  _GeneralBevel copyWith({double? p, double? n, CornerConverter? converter}) =>
      _GeneralBevel(
          p: p ?? this.p,
          n: n ?? this.n,
          converter: converter ?? this.converter);
}

void main() {
  test('shape-only painting performs no unused boundary resolutions', () {
    final calls = <(double, double)>[];
    final c = AnyBoxDecoration(
            enableCache: false,
            border: AnyBoxBorder(
                corners: _GeneralRounded(calls, p: 20, n: 20),
                sides: const AnySide(width: 4, align: 1)),
            background: const AnyBackground(color: Color(0xff00ff00)))
        .buildContour(const Size(100, 100), TextDirection.ltr);
    expect(calls, isEmpty);
    c.clipPath;
    c.shadowPath;
    expect(c.regions(backgroundMerge: false).regions, isEmpty);
    expect(calls, isEmpty);
    expect(c.innerCorners, same(c.shapeCorners));
    final outer = c.outerCorners;
    expect(calls, List.filled(4, (-4.0, -4.0)));
    expect(c.outerCorners, same(outer));
    c.zeroCorners;
    expect(calls,
        [...List.filled(4, (-4.0, -4.0)), ...List.filled(4, (4.0, 4.0))]);
    c.zeroCorners;
    expect(calls, hasLength(8));
    expect(() => outer.clear(), throwsUnsupportedError);
  });

  test('uniform fill shortcut exposes a read-only region collection', () {
    final c = const AnyBoxDecoration(
            border: AnyBoxBorder(
                corners: RoundedCorner(radius: 20),
                sides: AnySide(width: 4, color: Color(0xff00ff00))))
        .buildContour(const Size(100, 100), TextDirection.ltr);
    final regions = c.regions(backgroundMerge: false).regions;
    expect(regions, hasLength(1));
    expect(() => regions.clear(), throwsUnsupportedError);
  });

  test('rectangular shortcuts agree with general topology and side ownership',
      () {
    final random = math.Random(20260915);
    for (var caseIndex = 0; caseIndex < 180; caseIndex++) {
      final bevel = caseIndex.isEven;
      final p = caseIndex % 13 == 0 ? 0.0 : random.nextDouble() * 110;
      final n = random.nextDouble() * 110;
      final converter = CornerConverter.values[caseIndex % 3];
      final sideSettings = List.generate(
          4,
          (i) => AnySide(
              width: caseIndex % 11 == i ? 0 : random.nextDouble() * 70,
              align: random.nextDouble() * 2 - 1,
              color: Color(0xff001100 + 31 * i)));
      final rotation = random.nextDouble() * math.pi * 2;
      Offset transform(Offset p) =>
          Offset(17, -31) +
          Offset(p.dx * math.cos(rotation) - p.dy * math.sin(rotation),
              p.dx * math.sin(rotation) + p.dy * math.cos(rotation));
      final vertices = [
        Offset.zero,
        const Offset(180, 0),
        const Offset(180, 130),
        const Offset(0, 130)
      ].map(transform).toList();
      AnyContour build(bool general) {
        final AnyCorner corner = bevel
            ? general
                ? _GeneralBevel(p: p, n: n, converter: converter)
                : BevelCorner.elliptical(p: p, n: n, converter: converter)
            : general
                ? _GeneralRounded([], p: p, n: n, converter: converter)
                : RoundedCorner.elliptical(p: p, n: n, converter: converter);
        return AnyContour(
            background: null,
            backgroundBase: AnyShapeBase.shapeBorder,
            clipBase: AnyShapeBase.shapeBorder,
            shadowBase: AnyShapeBase.shapeBorder,
            points: List.generate(
                4,
                (i) => AnyPoint(
                    point: vertices[i], shape: corner, side: sideSettings[i])));
      }

      final inputs = 'seed=20260915 case=$caseIndex bevel=$bevel p=$p n=$n '
          'converter=$converter sides=${sideSettings.map((s) => (
                s.width,
                s.align
              ))} '
          'rotation=$rotation';
      List<Path> paths(bool general) {
        try {
          final c = build(general);
          return [
            c.pathFor(AnyShapeBase.outerBorder),
            c.pathFor(AnyShapeBase.innerBorder),
            ...c.regions(backgroundMerge: false).regions.map((r) => r.$2)
          ];
        } catch (error, stack) {
          fail('$inputs general=$general\n$error\n$stack');
        }
      }

      // Case 101 covers rejected compound batches; case 140 checks that
      // collapse retains the same normalization for both boundary bands.
      final pathsA = paths(false), pathsB = paths(true);
      expect(pathsA.length, pathsB.length);
      for (var sample = 0; sample < 150; sample++) {
        final point = transform(Offset(
            random.nextDouble() * 340 - 80, random.nextDouble() * 290 - 80));
        for (var path = 0; path < pathsA.length; path++) {
          expect(pathsA[path].contains(point), pathsB[path].contains(point),
              reason: '$inputs path=$path point=$point');
        }
      }
    }
  });
}
