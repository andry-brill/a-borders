// Run explicitly; timing is not a correctness assertion in the regular suite:
// flutter test test/benchmarks/animation_geometry.dart --reporter expanded
// Add --dart-define=SETTLED_GEOMETRY_BENCHMARK=true to compare steady-state
// JIT throughput after moving hot functions between libraries/classes. Apply
// this same harness and setting to both versions; keep short-warmup data too.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:any_borders/any_borders.dart';
import '../../example/lib/main.dart' as demo;
import '../support/direct_geometry_fixtures.dart';

void main() {
  const settled = bool.fromEnvironment('SETTLED_GEOMETRY_BENCHMARK');
  const samples = settled ? 300 : 30;
  test('isolated geometry benchmark', () {
    final fixtures = directGeometryFixtures();
    if (settled) {
      for (var warm = 0; warm < 1000; warm++) {
        for (final fixture in fixtures) {
          fixture.build().regions(backgroundMerge: false);
        }
      }
    }
    for (var pass = 0; pass < 3; pass++) {
      var ordinary = 0, fallback = 0;
      for (final fixture in fixtures) {
        final watch = Stopwatch()..start();
        for (var sample = 0; sample < samples; sample++) {
          fixture.build().regions(backgroundMerge: false);
        }
        final elapsed = watch.elapsedMicroseconds;
        if (fixture.ordinary) {
          ordinary += elapsed;
        } else {
          fallback += elapsed;
        }
        if (pass == 2)
          print(
              'Fixture ${fixture.name}: ${(elapsed / (samples * 1000)).toStringAsFixed(3)} ms');
      }
      if (pass == 2)
        print(
            'Fixtures ordinary=${(ordinary / (samples * 1000)).toStringAsFixed(3)} ms, '
            'fallback=${(fallback / (samples * 1000)).toStringAsFixed(3)} ms');
    }
  });
  test('animated gallery geometry benchmark', () {
    final examples = demo.examples().whereType<demo.E>().toList();
    if (settled) {
      for (var warm = 0; warm < 100; warm++) {
        for (final e in examples) {
          final tween = AnyDecorationTween(begin: e.begin, end: e.end);
          for (final t in [0.1, 0.3, 0.5, 0.7, 0.9]) {
            final contours = tween
                .lerp(t)
                .buildContours(const Size(200, 100), TextDirection.ltr);
            for (final c in contours) {
              c.regions(backgroundMerge: contours.length == 1);
            }
          }
        }
      }
    }
    // Two warm-up passes precede the report. Each sample creates a fresh tween
    // contour, including all layer geometry and final filled regions. This
    // measures CPU geometry work, not GPU raster time or achieved frame rate.
    for (var pass = 0; pass < 3; pass++) {
      var total = 0;
      for (final (index, e) in examples.indexed) {
        final tween = AnyDecorationTween(begin: e.begin, end: e.end);
        var build = 0, regions = 0;
        for (final t in [0.1, 0.3, 0.5, 0.7, 0.9]) {
          final watch = Stopwatch()..start();
          final contours = tween
              .lerp(t)
              .buildContours(const Size(200, 100), TextDirection.ltr);
          build += watch.elapsedMicroseconds;
          watch.reset();
          for (final c in contours) {
            c.regions(backgroundMerge: contours.length == 1);
          }
          regions += watch.elapsedMicroseconds;
          watch.stop();
        }
        total += build + regions;
        if (pass == 2) {
          print('[$index] ${e.title.replaceAll('\n', ' ')}: '
              'build=${(build / 5000).toStringAsFixed(3)} ms, '
              'regions=${(regions / 5000).toStringAsFixed(3)} ms');
        }
      }
      print('Pass $pass: ${(total / 5000).toStringAsFixed(3)} ms per '
          '${examples.length}-example geometry frame');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
