import 'dart:math' as math;

import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';
import 'example_animation.dart';

/// One full gallery row, painted with a single retained decoration renderer.
class RepeatedBordersExample extends StatefulWidget {
  const RepeatedBordersExample({super.key});

  static const count = 500;
  static const boxSize = Size(64, 40);

  @override
  State<RepeatedBordersExample> createState() => _RepeatedBordersExampleState();
}

const greenD = Color(0xFF2E685F);
const blueD = Color(0xFF57B7CF);

class _RepeatedBordersExampleState extends State<RepeatedBordersExample>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;
  final _repaint = ValueNotifier<int>(0);
  // Normalized positions remain the same when resizing or rebuilding the page.
  final _positions = List<Offset>.unmodifiable(() {
    final random = math.Random(42);
    return List.generate(RepeatedBordersExample.count,
        (_) => Offset(random.nextDouble(), random.nextDouble()));
  }());
  final _beginRotations = _randomRotations(43);
  final _endRotations = _randomRotations(44);

  static List<double> _randomRotations(int seed) {
    final random = math.Random(seed);
    const maxAngle = 17 * math.pi / 180;
    return List<double>.unmodifiable(List.generate(RepeatedBordersExample.count,
        (_) => (random.nextDouble() * 2 - 1) * maxAngle));
  }

  final _decoration = AnyBoxDecoration(
    background: AnyBackground(
      color: blueD.withValues(alpha: 0.1),
    ),
    border: AnyBoxBorder(
      sides: AnySide(
        color: greenD.withValues(alpha: 0.15),
        width: 2,
        align: AnySide.alignInside,
      ),
      corners: const RoundedCorner(radius: 4),
      profiles: const AnyBoxBorderProfiles(
        horizontal: AnyZigZagProfile(
          count: 5,
          depth: 2,
          startClearance: 4,
          endClearance: 4,
          fitToBounds: true,
          corners: RoundedCorner.infinity(),
        ),
        vertical: AnyZigZagProfile(
          count: 3,
          depth: 2,
          startClearance: 4,
          endClearance: 4,
          fitToBounds: true,
          corners: RoundedCorner.infinity(),
        ),
      ),
    ),
  );

  AnyDecorationRenderer? _renderer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ExampleToggleBus.duration,
      value: ExampleToggleBus.instance.expanded ? 1 : 0,
    );
    _animation =
        CurvedAnimation(parent: _controller, curve: ExampleToggleBus.curve);
    ExampleToggleBus.instance.addListener(_toggle);
  }

  void _toggle() {
    if (ExampleToggleBus.instance.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final configuration = createLocalImageConfiguration(
      context,
      size: RepeatedBordersExample.boxSize,
    );
    if (_renderer?.configuration == configuration) return;
    _renderer?.dispose();
    _renderer = _decoration.resolveRenderer(
      configuration,
      onChanged: () => _repaint.value++,
    );
  }

  @override
  void dispose() {
    ExampleToggleBus.instance.removeListener(_toggle);
    _animation.dispose();
    _controller.dispose();
    _renderer?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 75),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('500 wave rectangles · green + blue at 5% opacity'),
          const SizedBox(height: 16),
          RepaintBoundary(
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox(
                height: 300,
                child: ClipRect(
                  child: CustomPaint(
                    painter: _RepeatedBordersPainter(
                      _renderer!,
                      _positions,
                      _beginRotations,
                      _endRotations,
                      _animation,
                      _repaint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepeatedBordersPainter extends CustomPainter {
  _RepeatedBordersPainter(this.renderer, this.positions, this.beginRotations,
      this.endRotations, this.animation, Listenable repaint)
      : super(repaint: Listenable.merge([repaint, animation]));

  final AnyDecorationRenderer renderer;
  final List<Offset> positions;
  final List<double> beginRotations;
  final List<double> endRotations;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final width = math.max(
        0.0, size.width - RepeatedBordersExample.boxSize.width - inset * 2);
    final height = math.max(
        0.0, size.height - RepeatedBordersExample.boxSize.height - inset * 2);
    final center = Offset(RepeatedBordersExample.boxSize.width / 2,
        RepeatedBordersExample.boxSize.height / 2);
    final t = animation.value;
    for (var i = 0; i < positions.length; i++) {
      final point = positions[i];
      canvas.save();
      try {
        canvas.translate(inset + point.dx * width + center.dx,
            inset + point.dy * height + center.dy);
        canvas.rotate(
            beginRotations[i] + (endRotations[i] - beginRotations[i]) * t);
        renderer.paint(canvas, -center);
      } finally {
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_RepeatedBordersPainter oldDelegate) =>
      renderer != oldDelegate.renderer ||
      positions != oldDelegate.positions ||
      beginRotations != oldDelegate.beginRotations ||
      endRotations != oldDelegate.endRotations ||
      animation != oldDelegate.animation;
}
