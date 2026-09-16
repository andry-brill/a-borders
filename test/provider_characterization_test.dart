import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/main.dart' as gallery;
import 'support/direct_geometry_fixtures.dart';

// Static cases retain the provider-relocation baseline; gallery cases track the
// current authored examples and prepared transitions. Two 32-bit streams and
// the byte length compact exact, ordered JSON doubles without rounding them.
String signature(Object value) {
  final bytes = utf8.encode(jsonEncode(value));
  var a = 0x811c9dc5, b = 0x12345678;
  for (final byte in bytes) {
    a = ((a ^ byte) * 16777619) & 0xffffffff;
    b = ((b ^ byte) * 65599) & 0xffffffff;
  }
  return '${bytes.length}:${a.toRadixString(16)}:${b.toRadixString(16)}';
}

Object cornerData(AnyResolvedCorner corner) => [
      corner.source.runtimeType.toString(),
      corner.source.p,
      corner.source.n,
      corner.parameters?.runtimeType.toString(),
      corner.parameters?.p,
      corner.parameters?.n,
      corner.previousExtent,
      corner.nextExtent,
      corner.center?.dx,
      corner.center?.dy,
      corner.circleRadius,
      corner.tolerance,
      for (final s in corner.segments)
        [
          s.start.dx,
          s.start.dy,
          s.control1.dx,
          s.control1.dy,
          s.control2.dx,
          s.control2.dy,
          s.end.dx,
          s.end.dy,
          s.from,
          s.to,
          s.isLine,
        ],
    ];

void main() {
  test('canonical geometry, ownership and work characterization', () {
    final actual = <String, Object>{};
    void capture(String name, List<AnyContour> Function() build) {
      final work = GeometryDiagnostics();
      final data = work.run(() {
        final contours = build();
        return [
          for (final c in contours)
            [
              for (final band in [
                c.shapeCorners,
                c.outerCorners,
                c.innerCorners,
                c.zeroCorners,
              ])
                signature(band.map(cornerData).toList()),
              for (final merge in [false, true])
                (() {
                  final r = c.regions(backgroundMerge: merge);
                  final paths = [
                    if (r.background != null) r.background!.$2,
                    ...r.regions.map((e) => e.$2),
                  ];
                  return [
                    paths.length,
                    for (final path in paths)
                      [
                        path.fillType.name,
                        path.getBounds().toString(),
                        signature([
                          for (var y = -17; y <= 137; y += 7)
                            for (var x = -19; x <= 239; x += 7)
                              path.contains(Offset(x + 0.37, y + 0.61)),
                        ]),
                      ],
                  ];
                })(),
            ],
        ];
      });
      actual[name] = {
        'geometry': data,
        'work': {for (final kind in GeometryWork.values) kind.name: work[kind]},
      };
    }

    for (final fixture in directGeometryFixtures()) {
      capture(fixture.name, () => [fixture.build()]);
    }
    for (final (index, example)
        in gallery.examples().whereType<gallery.E>().indexed) {
      for (final t in [0.1, 0.5, 0.9]) {
        capture(
            '[$index] ${example.title} t=$t',
            () => AnyDecorationTween(begin: example.begin, end: example.end)
                .lerp(t)
                .buildContours(const Size(200, 100), TextDirection.ltr));
      }
    }
    for (final sign in [-1.0, 1.0]) {
      for (final angle in [30, 90, 150]) {
        final a = sign * angle * math.pi / 180;
        final u = Offset(math.cos(a), math.sin(a));
        final frame = AnyCornerFrame(
          vertex: const Offset(17, -31),
          previousRay: u,
          nextRay: const Offset(1, 0),
          previousNormal: Offset(u.dy, -u.dx),
          nextNormal: const Offset(0, 1),
          winding: 1,
        );
        for (final c in <AnyCorner>[
          for (final converter in CornerConverter.values) ...[
            RoundedCorner.elliptical(p: 30, n: 10, converter: converter),
            BevelCorner.elliptical(p: 30, n: 10, converter: converter),
          ],
          const RoundedCorner.elliptical(p: .001, n: 1000),
          const InverseRoundedCorner(radius: 20),
          const InverseRoundedCorner.elliptical(p: 30, n: 10),
          const InverseRoundedCorner(),
          const BevelCorner.elliptical(p: 0, n: 20),
        ].indexed) {
          final source = c.$2.resolve(frame);
          actual['corner $sign $angle ${c.$1}'] = signature([
            cornerData(source),
            for (final d in [
              (0.0, 0.0),
              (-4.0, -8.0),
              (3.0, 3.0),
              (30.0, 30.0)
            ])
              cornerData(c.$2.resolveBoundary(source,
                  previousDistance: d.$1, nextDistance: d.$2)),
          ]);
        }
      }
    }
    final file = File('test/fixtures/provider_geometry.json');
    if (Platform.environment['CAPTURE_PROVIDER_BASELINE'] == '1') {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(actual));
    } else {
      final expected =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(actual.keys, expected.keys);
      for (final key in actual.keys) {
        expect(actual[key], expected[key], reason: key);
      }
    }
  });
}
