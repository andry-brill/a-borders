// From example/: flutter run --profile -d chrome -t ../test/benchmarks/browser_animation.dart
// A fixed visible subset of the real gallery, without scroll/load variability.
import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';
import '../../example/lib/main.dart' as demo;

void main() => runApp(const MaterialApp(home: _AnimationScene()));

class _AnimationScene extends StatefulWidget {
  const _AnimationScene();
  @override
  State<_AnimationScene> createState() => _AnimationSceneState();
}

class _AnimationSceneState extends State<_AnimationScene>
    with SingleTickerProviderStateMixin {
  late final controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  late final examples = demo.examples().whereType<demo.E>().toList();
  late final selected = [
    for (final i in [0, 2, 3, 4, 6, 11]) examples[i]
  ];
  late final tweens = [
    for (final e in selected) AnyDecorationTween(begin: e.begin, end: e.end)
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title:
                const Text('Border animation profile — six gallery examples')),
        body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => Center(
                    child: Wrap(spacing: 48, runSpacing: 64, children: [
                  for (var i = 0; i < tweens.length; i++)
                    Container(
                        width: 200,
                        height: 120,
                        decoration: tweens[i].lerp(controller.value),
                        alignment: Alignment.center,
                        child: Text(selected[i].title,
                            textAlign: TextAlign.center)),
                ]))),
      );
}
