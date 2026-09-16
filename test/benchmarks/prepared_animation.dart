// Identical before/after harness; each tween survives all measured frames.
import 'dart:convert';
import 'package:any_borders/any_borders.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../example/lib/main.dart' as gallery;

void main() {
  test('persistent animation transitions', () {
    final examples = gallery.examples().whereType<gallery.E>().toList();
    final tweens = [
      for (final e in examples) AnyDecorationTween(begin: e.begin, end: e.end)
    ];
    void frame(AnyDecorationTween tween, double t) {
      final contours =
          tween.lerp(t).buildContours(const Size(200, 100), TextDirection.ltr);
      for (final c in contours) {
        c.regions(backgroundMerge: contours.length == 1);
      }
    }

    // Exercise both sides of the midpoint without measuring exact endpoint caches.
    final times = List.generate(60, (i) => (i + 0.5) / 60);
    for (var warm = 0; warm < 5; warm++) {
      for (final tween in tweens) {
        for (final t in times) {
          frame(tween, t);
        }
      }
    }
    final rows = <Object>[];
    var total = 0;
    for (var i = 0; i < tweens.length; i++) {
      final watch = Stopwatch()..start();
      for (var repeat = 0; repeat < 5; repeat++) {
        for (final t in times) {
          frame(tweens[i], t);
        }
      }
      final elapsed = watch.elapsedMicroseconds;
      total += elapsed;
      rows.add({
        'index': i,
        'title': examples[i].title,
        'microsecondsPerFrame': elapsed / 300
      });
    }
    print('TRANSITION_BENCHMARK ${jsonEncode({
          'rows': rows,
          'galleryMicrosecondsPerFrame': total / 300
        })}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
