import 'dart:io';
import 'dart:ui';
import 'package:any_borders/any_borders.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import '../example/lib/custom_corner.dart';

class _ConservativeNotch extends NotchCorner {
  const _ConservativeNotch({super.p, super.n, super.bend});
  @override
  AnyCornerGeometry get geometry => const _ConservativeGeometry();
  @override
  _ConservativeNotch copyWith({double? p, double? n, double? bend}) =>
      _ConservativeNotch(
          p: p ?? this.p, n: n ?? this.n, bend: bend ?? this.bend);
}

class _ConservativeGeometry extends NotchCornerGeometry {
  const _ConservativeGeometry();
  @override
  AnyCornerTraits traitsFor(
          AnyCorner source, AnyCorner? parameters, double? radius) =>
      AnyCornerTraits.none;
}

class _ObservedCorner extends RoundedCorner {
  final List<int> classifications;
  _ObservedCorner(this.classifications, {super.p = 20, super.n = 20})
      : super.elliptical();
  @override
  AnyCornerGeometry get geometry => const _ObservedGeometry();
  @override
  _ObservedCorner copyWith(
          {double? p, double? n, CornerConverter? converter}) =>
      _ObservedCorner(classifications, p: p ?? this.p, n: n ?? this.n);
}

class _ObservedGeometry extends RoundedCornerGeometry {
  const _ObservedGeometry();
  @override
  AnyCornerTraits traitsFor(
      AnyCorner source, AnyCorner? parameters, double? radius) {
    (source as _ObservedCorner).classifications.add(1);
    return AnyCornerTraits.none;
  }
}

AnyContour mixedContour(AnyCorner custom) => AnyBoxDecoration(
    enableCache: false,
    border: AnyBoxBorder(
      topLeft: custom,
      topRight: const RoundedCorner(radius: 18),
      bottomRight: const BevelCorner(radius: 16),
      bottomLeft: const InverseRoundedCorner(radius: 12),
      sides: const AnySide(width: 3, color: Color(0xff123456)),
      top: const AnySide(width: 3, color: Color(0xff987654)),
    )).buildContour(const Size(180, 120), TextDirection.ltr);

void main() {
  test('local traits are lazy and memoized on the actual result', () {
    final calls = <int>[];
    final c = AnyBoxDecoration(
            enableCache: false,
            border: AnyBoxBorder(
                corners: _ObservedCorner(calls),
                sides: const AnySide(width: 4, align: 0)))
        .buildContour(const Size(180, 120), TextDirection.ltr);
    final prepared = calls.length;
    final outer = c.outerCorners;
    // Deriving an outer curve also constructs an intermediate rounded curve.
    // Neither needs local classification until the caller requests it.
    expect(calls, hasLength(prepared));
    expect(outer.first.traits, same(AnyCornerTraits.none));
    expect(calls, hasLength(prepared + 1));
    expect(outer.first.traits, same(AnyCornerTraits.none));
    expect(calls, hasLength(prepared + 1));
  });
  test('core dependency closure excludes concrete corners and composition', () {
    final visited = <String>{};
    final root = Directory.current.uri;
    void inspect(Uri uri) {
      if (!visited.add(uri.toString())) return;
      final file = File.fromUri(uri);
      final text = file.readAsStringSync();
      expect(
          text,
          isNot(matches(RegExp(
              r'\b(?:RoundedCorner|BevelCorner|InverseRoundedCorner)(?:Geometry)?\b'))),
          reason: file.path);
      for (final match
          in RegExp(r'''(?:import|export|part)\s+['"]([^'"]+)['"]''')
              .allMatches(text)) {
        final target = match[1]!;
        if (target.startsWith('dart:')) continue;
        if (target.startsWith('package:') &&
            !target.startsWith('package:any_borders/')) continue;
        final next = target.startsWith('package:any_borders/')
            ? root.resolve(
                'lib/${target.substring('package:any_borders/'.length)}')
            : uri.resolve(target);
        expect(next.path, isNot(contains('/corners/')));
        expect(next.path, isNot(endsWith('/any_contour.dart')));
        expect(next.path, isNot(endsWith('/any_borders.dart')));
        inspect(next);
      }
    }

    inspect(root.resolve('lib/src/geometry/core.dart'));
    expect(visited.length, greaterThan(5));
  });

  test('custom segments and metadata use no inherited eligibility', () {
    final c = mixedContour(const NotchCorner()).shapeCorners.first;
    expect(c.segments, hasLength(2));
    expect(c.start, const Offset(0, 20));
    expect(c.end, const Offset(20, 0));
    expect((c.pointAt(0.5) - const Offset(20 / 3, 20 / 3)).distance,
        lessThan(1e-12));
    expect(c.source, isA<NotchCorner>());
    expect(c.traits.directCandidate, true);
    expect(c.traits.rectangularBand, false);
    final rebuilt = AnyResolvedCorner(
        source: c.source,
        frame: c.frame,
        segments: c.segments,
        parameters: c.parameters);
    expect(rebuilt.traits, same(AnyCornerTraits.none));
  });

  test(
      'mixed custom geometry uses existing certification or conservative fallback',
      () {
    final directWork = GeometryDiagnostics(),
        fallbackWork = GeometryDiagnostics();
    final direct = directWork.run(() =>
        mixedContour(const NotchCorner()).regions(backgroundMerge: false));
    final fallback = fallbackWork.run(() =>
        mixedContour(const _ConservativeNotch())
            .regions(backgroundMerge: false));
    expect(directWork[GeometryWork.boolean], 0);
    expect(directWork[GeometryWork.flatten], 0);
    expect(fallbackWork[GeometryWork.assembly], greaterThan(0));
    expect(direct.regions.length, fallback.regions.length);
    for (var y = -2.0; y < 122; y += 1.31) {
      for (var x = -2.0; x < 182; x += 1.17) {
        final p = Offset(x, y);
        for (var i = 0; i < direct.regions.length; i++) {
          expect(direct.regions[i].$2.contains(p),
              fallback.regions[i].$2.contains(p),
              reason: '$p side $i');
        }
      }
    }
  });

  test('custom fields survive normalization, interpolation and cache identity',
      () {
    const a = NotchCorner(p: 300, n: 200, bend: .25);
    const b = NotchCorner(p: 150, n: 100, bend: .5);
    expect((a * .5).geometry, same(a.geometry));
    expect((a * .5 as NotchCorner).bend, .25);
    expect((a.lerpTo(b, .5)).bend, .375);
    expect(a.copyWith(bend: .4), isNot(a));
    AnyBoxDecoration decoration(NotchCorner corner) =>
        AnyBoxDecoration(border: AnyBoxBorder(corners: corner));
    final first =
        decoration(a).buildContour(const Size(100, 80), TextDirection.ltr);
    expect(first.shapeCorners.first.source, isA<NotchCorner>());
    expect((first.shapeCorners.first.source as NotchCorner).bend, a.bend);
    expect(
        first,
        same(decoration(a)
            .buildContour(const Size(100, 80), TextDirection.ltr)));
    expect(
        first,
        isNot(same(decoration(b)
            .buildContour(const Size(100, 80), TextDirection.ltr))));
    final tween = AnyDecorationTween(begin: decoration(a), end: decoration(b));
    final mid =
        tween.lerp(.5).buildContour(const Size(100, 80), TextDirection.ltr);
    expect((mid.shapeCorners.first.source as NotchCorner).bend, .375);
  });
}
