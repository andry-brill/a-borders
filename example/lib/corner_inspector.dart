import 'dart:math' as math;
import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';

/// Inspect the canonical curves used by both complete paths and side fills.
class CornerInspector extends StatefulWidget {
  const CornerInspector({super.key});
  @override
  State<CornerInspector> createState() => _CornerInspectorState();
}

class _CornerInspectorState extends State<CornerInspector> {
  int type = 0;
  double angle = 90, p = 30, n = 20, width = 8, nextWidth = 8, align = 0;
  bool reflex = false, reported = false;
  @override
  Widget build(BuildContext context) {
    final corner = switch (type) {
      0 => RoundedCorner.elliptical(p: p, n: n),
      1 => InverseRoundedCorner.elliptical(p: p, n: n),
      _ => BevelCorner.elliptical(p: p, n: n),
    };
    Widget slider(
            String label, double value, double max, ValueChanged<double> update,
            {double min = 0}) =>
        SizedBox(
            width: 280,
            child: Row(children: [
              SizedBox(
                  width: 110,
                  child: Text('$label ${value.toStringAsFixed(1)}')),
              Expanded(
                  child: Slider(
                      value: value,
                      min: min,
                      max: max,
                      onChanged: (v) => setState(() => update(v))))
            ]));
    return Scaffold(
        appBar: AppBar(title: const Text('Corner geometry inspector')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 12, runSpacing: 8, children: [
                            for (var i = 0; i < 3; i++)
                              ChoiceChip(
                                  label: Text([
                                    'Rounded',
                                    'Inverse rounded',
                                    'Bevel'
                                  ][i]),
                                  selected: type == i && !reported,
                                  onSelected: (_) => setState(() {
                                        type = i;
                                        reported = false;
                                      })),
                            FilterChip(
                                label:
                                    const Text('Reported mixed-alignment box'),
                                selected: reported,
                                onSelected: (v) =>
                                    setState(() => reported = v)),
                          ]),
                          const SizedBox(height: 12),
                          const Text(
                              'Blue: shape   Orange: outer   Green: inner\nCrosses: curve centers   Dots and short lines: curve points and tangents'),
                          SizedBox(
                              height: 440,
                              width: double.infinity,
                              child: CustomPaint(
                                  painter: _InspectorPainter(
                                      corner: corner,
                                      angle: angle,
                                      width: width,
                                      nextWidth: nextWidth,
                                      align: align,
                                      reflex: reflex,
                                      reported: reported))),
                          if (!reported) ...[
                            Wrap(spacing: 20, children: [
                              slider('Angle', angle, 175, (v) => angle = v,
                                  min: 5),
                              slider('Previous p', p, 60, (v) => p = v),
                              slider('Next n', n, 60, (v) => n = v),
                              slider('Previous width', width, 60,
                                  (v) => width = v),
                              slider('Next width', nextWidth, 60,
                                  (v) => nextWidth = v),
                              slider('Alignment', align, 1, (v) => align = v,
                                  min: -1),
                            ]),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Reflex vertex'),
                                value: reflex,
                                onChanged: (v) => setState(() => reflex = v)),
                            const Text(
                                'Alignment: −1 inside, 0 centered, +1 outside. For a circular source set p = n.\n'
                                'Automatic inverse corners keep the shape center: outside reduces a circular scoop radius; inside increases it. Sharp joins connect the arc to the shifted sides. Explicit inverse corners use their own side intersection.'),
                          ] else
                            const Text(
                                'Source radius 10. Left: 10 inside; top: 20 centered; right: 30 outside; bottom: 40 centered.\n'
                                'The inner radius is explicitly 10, matching the original example. Outer dimensions use the corrected axes and sharp-limit taper.'),
                        ])))));
  }
}

class _InspectorPainter extends CustomPainter {
  final AnyCorner corner;
  final double angle, width, nextWidth, align;
  final bool reflex, reported;
  const _InspectorPainter(
      {required this.corner,
      required this.angle,
      required this.width,
      required this.nextWidth,
      required this.align,
      required this.reflex,
      required this.reported});
  static const blue = Color(0xff1565c0),
      orange = Color(0xffd45b15),
      green = Color(0xff14825c);
  void label(Canvas canvas, String text, Offset point, Color color) {
    final painter = TextPainter(
        text:
            TextSpan(text: text, style: TextStyle(color: color, fontSize: 12)),
        textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(canvas, point);
  }

  void drawCorner(Canvas canvas, AnyResolvedCorner c, Color color) {
    final path = Path();
    c.appendTo(path, moveTo: true);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    if (c.center case final center?) {
      canvas.drawLine(center - const Offset(4, 0), center + const Offset(4, 0),
          Paint()..color = color);
      canvas.drawLine(center - const Offset(0, 4), center + const Offset(0, 4),
          Paint()..color = color);
    }
    for (final t in [0.0, 0.5, 1.0]) {
      final point = c.pointAt(t), tangent = c.tangentAt(t);
      canvas.drawCircle(point, 2.5, Paint()..color = color);
      canvas.drawLine(
          point - tangent * 9, point + tangent * 9, Paint()..color = color);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width / 620, size.height / 440);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    if (reported) {
      const decoration = AnyBoxDecoration(
          border: AnyBoxBorder(
              corners: RoundedCorner(radius: 10),
              innerCorners: RoundedCorner(radius: 10),
              left: AnySide(width: 10, align: -1),
              top: AnySide(width: 20, align: 0),
              right: AnySide(width: 30, align: 1),
              bottom: AnySide(width: 40, align: 0)));
      final c =
          decoration.buildContour(const Size(210, 110), TextDirection.ltr);
      canvas.scale(1.6);
      canvas.translate(-105, -55);
      for (final entry in [
        (AnyShapeBase.outerBorder, orange, c.outerCorners),
        (AnyShapeBase.innerBorder, green, c.innerCorners),
        (AnyShapeBase.shapeBorder, blue, c.shapeCorners)
      ]) {
        canvas.drawPath(
            c.pathFor(entry.$1),
            Paint()
              ..color = entry.$2
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        for (final corner in entry.$3) {
          drawCorner(canvas, corner, entry.$2);
        }
      }
      label(canvas, 'top: 20 centered', const Offset(45, -37), orange);
      label(canvas, 'bottom: 40 centered', const Offset(35, 140), orange);
    } else {
      canvas.translate(-70, reflex ? 35 : -55);
      final theta = angle * math.pi / 180 * (reflex ? -1 : 1),
          u = Offset(math.cos(theta), math.sin(theta)),
          v = const Offset(1, 0);
      final f = AnyCornerFrame(
          vertex: Offset.zero,
          previousRay: u,
          nextRay: v,
          previousNormal: Offset(u.dy, -u.dx),
          nextNormal: const Offset(0, 1),
          winding: 1);
      final source = corner.geometry.resolve(corner, f),
          outer = corner.geometry.resolveBoundary(source,
              previousDistance: -width * (1 + align) / 2,
              nextDistance: -nextWidth * (1 + align) / 2),
          inner = corner.geometry.resolveBoundary(source,
              previousDistance: width * (1 - align) / 2,
              nextDistance: nextWidth * (1 - align) / 2);
      canvas.drawLine(Offset.zero, u * 210, Paint()..color = Colors.black26);
      canvas.drawLine(Offset.zero, v * 210, Paint()..color = Colors.black26);
      label(canvas, 'previous', u * 220, Colors.black87);
      label(canvas, 'next', v * 220, Colors.black87);
      for (final entry in [(outer, orange), (inner, green), (source, blue)]) {
        drawCorner(canvas, entry.$1, entry.$2);
      }
      label(
          canvas,
          'source contacts: ${source.previousExtent.toStringAsFixed(3)} / ${source.nextExtent.toStringAsFixed(3)}',
          const Offset(-160, 180),
          blue);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InspectorPainter oldDelegate) => true;
}
