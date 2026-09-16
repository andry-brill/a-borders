// Standalone browser regression runner, independent of package:test's host.
// From example/: flutter run -d chrome -t ../test/browser_fill_main.dart
import 'package:flutter/material.dart';

import 'support/fill_regressions.dart';
import 'support/path_offset_regressions.dart';
import 'support/transition_regressions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String result;
  try {
    final count = await checkFillRegressions();
    final sideCount = await checkSideFillRegressions();
    final offsetCount = await checkPathOffsetRegressions();
    final transitionCount = await checkTransitionRegressions();
    result =
        'PASS: $count border-hole checks, $sideCount multi-fill coverage checks, '
        '$offsetCount path-offset checks, and $transitionCount transition checks. '
        'Solid, gradient, image, and shadow fills preserve holes; side seams and '
        'varying gradient alpha retain coverage at DPR 1, 2, 3.';
  } catch (error, stack) {
    result = 'FAIL: $error\n$stack';
  }
  print(result);
  runApp(MaterialApp(
    home: Scaffold(
        body: Padding(
      padding: const EdgeInsets.all(24),
      child: SelectableText(result),
    )),
  ));
}
