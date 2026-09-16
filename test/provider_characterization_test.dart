import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/src/geometry_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/main.dart' as gallery;
import 'support/direct_geometry_fixtures.dart';

// Only discrete point-in-path samples are hashed. Floating-point geometry is
// stored numerically so platform roundoff can be compared and diagnosed.
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

// These bounds cover arithmetic roundoff, not curve approximation. They remain
// far below the 0.001 minimum construction tolerance. Comparing numbers avoids
// both platform-dependent decimal hashes and rounding-bin boundary failures.
void _expectSnapshot(Object? actual, Object? expected, String location) {
  if (actual is double && expected is double) {
    expect(actual.isFinite, isTrue, reason: location);
    expect(expected.isFinite, isTrue, reason: location);
    final roundoff = math.max(1e-12, expected.abs() * 1e-14);
    expect(actual, closeTo(expected, roundoff), reason: location);
  } else if (actual is List && expected is List) {
    expect(actual.length, expected.length, reason: '$location.length');
    for (var i = 0; i < expected.length; i++) {
      _expectSnapshot(actual[i], expected[i], '$location[$i]');
    }
  } else if (actual is Map && expected is Map) {
    expect(actual.keys.toList(), expected.keys.toList(),
        reason: '$location.keys');
    for (final key in expected.keys) {
      _expectSnapshot(actual[key], expected[key], '$location.$key');
    }
  } else {
    expect(actual, expected, reason: location);
  }
}

// Keep each corner's numeric data on one line rather than expanding thousands
// of individual coordinates. The enclosing records remain indented JSON.
String _encodeSnapshot(Object? value, [String indent = '']) {
  final childIndent = '$indent  ';
  if (value is Map && value.isNotEmpty) {
    final entries =
        value.entries.map((entry) => '$childIndent${jsonEncode(entry.key)}: '
            '${_encodeSnapshot(entry.value, childIndent)}');
    return '{\n${entries.join(',\n')}\n$indent}';
  }
  if (value is List && value.isNotEmpty && value.first is! String) {
    final entries = value
        .map((entry) => '$childIndent${_encodeSnapshot(entry, childIndent)}');
    return '[\n${entries.join(',\n')}\n$indent]';
  }
  return jsonEncode(value);
}

void main() {
  test('numeric snapshots accept roundoff across decimal boundaries', () {
    _expectSnapshot([1.0000000000500001, -0.0, 1000.000000000001],
        [1.00000000005, 0.0, 1000.0], 'roundoff');
    // Actual Windows/Linux control-point values from the CI reproduction.
    _expectSnapshot(114.50314901626047, 114.50314901626048, 'rounded box');
  });

  test('numeric snapshots reject coordinate changes and nonfinite values', () {
    for (final pair in [
      (1e-11, 0.0),
      (1000.0000000001, 1000.0),
      (double.nan, 0.0),
      (double.infinity, double.infinity),
    ]) {
      expect(() => _expectSnapshot(pair.$1, pair.$2, 'coordinate'),
          throwsA(isA<TestFailure>()));
    }
  });

  test('snapshot structure, fill samples and work counts stay exact', () {
    for (final pair in <(Object, Object)>[
      ([1.0], [1.0, 1.0]),
      ('evenOdd', 'nonZero'),
      ([false], [true]),
      ({'fit': 1}, {'fit': 0}),
      ({'from': 0.0}, {'to': 0.0}),
    ]) {
      expect(() => _expectSnapshot(pair.$1, pair.$2, 'structure'),
          throwsA(isA<TestFailure>()));
    }
  });

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
                band.map(cornerData).toList(),
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
          final source = c.$2.geometry.resolve(c.$2, frame);
          actual['corner $sign $angle ${c.$1}'] = [
            cornerData(source),
            for (final d in [
              (0.0, 0.0),
              (-4.0, -8.0),
              (3.0, 3.0),
              (30.0, 30.0)
            ])
              cornerData(c.$2.geometry.resolveBoundary(source,
                  previousDistance: d.$1, nextDistance: d.$2)),
          ];
        }
      }
    }
    final file = File('test/fixtures/provider_geometry.json');
    if (Platform.environment['CAPTURE_PROVIDER_BASELINE'] == '1') {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(_encodeSnapshot(actual));
    } else {
      final expected =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _expectSnapshot(actual, expected, 'snapshot');
    }
  });
}
