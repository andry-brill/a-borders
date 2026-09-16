import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';

import 'any_contour.dart';
import 'any_shadow.dart';
import 'src/utils.dart';
import 'src/geometry/core.dart' show AnyContourTransition;

class AnyDecorationTween extends Tween<AnyDecoration> {
  _DecorationTransition? _prepared;
  AnyDecorationTween({
    required AnyDecoration super.begin,
    required AnyDecoration super.end,
  });

  @override
  AnyDecoration lerp(double t) {
    if (t <= 0.0) return begin!;
    if (t >= 1.0) return end!;

    var prepared = _prepared;
    if (prepared == null || prepared.begin != begin || prepared.end != end) {
      prepared = _prepared = _DecorationTransition(begin!, end!);
    }
    return _TweenDecoration(
      prepared: prepared,
      beginDecoration: begin!,
      endDecoration: end!,
      t: t,
    );
  }
}

class _TweenDecoration extends AnyDecoration {
  final AnyDecoration beginDecoration;
  final AnyDecoration endDecoration;
  final double t;
  final _DecorationTransition prepared;

  _TweenDecoration({
    required this.prepared,
    required this.beginDecoration,
    required this.endDecoration,
    required this.t,
  }) : super.multi(
          borders: List<AnyBorder>.generate(
            math.max(
                beginDecoration.borders.length, endDecoration.borders.length),
            (index) {
              final a = index < beginDecoration.borders.length
                  ? beginDecoration.borders[index]
                  : endDecoration.borders[index];
              final b = index < endDecoration.borders.length
                  ? endDecoration.borders[index]
                  : a;
              if (a.offset == b.offset) return a;
              // Actual point/corner settings interpolate in buildPoints. Keep
              // the generic layer metadata's offset in sync with those points.
              return AnyBorder(
                sides: a.sides,
                corners: a.corners,
                outerCorners: a.outerCorners,
                innerCorners: a.innerCorners,
                ratio: a.ratio,
                offset: lerpDouble(a.offset, b.offset, t)!,
              );
            },
            growable: false,
          ),
          primaryBorderIndex: AnyUtils.pickLerp(
            beginDecoration.primaryBorderIndex,
            endDecoration.primaryBorderIndex,
            t,
          ),
          background: AnyBackground.lerp(
            beginDecoration.background,
            endDecoration.background,
            t,
          ),
          shadows: AnyShadow.lerpList(
            beginDecoration.shadows,
            endDecoration.shadows,
            t,
          ),
          clipBase: AnyUtils.pickLerp(
            beginDecoration.clipBase,
            endDecoration.clipBase,
            t,
          ),
          shadowBase: AnyUtils.pickLerp(
            beginDecoration.shadowBase,
            endDecoration.shadowBase,
            t,
          ),
          enableCache: false,
          offset: lerpDouble(beginDecoration.offset, endDecoration.offset, t)!,
        );

  double _effectiveRatio(Size size, double? ratio) {
    if (ratio != null && ratio > 0.0) {
      return ratio;
    }

    if (size.height <= 0.0) {
      return 1.0;
    }

    return size.width / size.height;
  }

  @override
  Rect boundsForBorder(Size size, int borderIndex) {
    final a = borderIndex < beginDecoration.borders.length
        ? beginDecoration.borders[borderIndex]
        : endDecoration.borders[borderIndex];
    final b = borderIndex < endDecoration.borders.length
        ? endDecoration.borders[borderIndex]
        : a;
    final beginRatio = _effectiveRatio(size, a.ratio);
    final endRatio = _effectiveRatio(size, b.ratio);
    final lRatio = lerpDouble(beginRatio, endRatio, t)!;
    return AnyUtils.fitRatio(size, lRatio);
  }

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection,
          int borderIndex, double offset) =>
      _layer(bounds, textDirection, borderIndex, offset).points(t);

  @override
  AnyContour buildContourForBorder(
          Rect bounds, TextDirection? textDirection, int index) =>
      _layer(bounds, textDirection, index, offset + borders[index].offset)
          .build(t,
              background: index == primaryBorderIndex ? background : null,
              backgroundBase: background?.shapeBase ?? AnyShapeBase.shapeBorder,
              clipBase: clipBase,
              shadowBase: shadowBase);

  AnyContourTransition _layer(
          Rect bounds, TextDirection? direction, int index, double offset) =>
      prepared.layer(
          bounds,
          direction,
          index,
          offset,
          (decoration) =>
              decoration.buildPoints(bounds, direction, index, offset));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is _TweenDecoration &&
        other.beginDecoration == beginDecoration &&
        other.endDecoration == endDecoration &&
        other.t == t &&
        super == other;
  }

  @override
  int get hashCode => Object.hash(
        super.hashCode,
        beginDecoration,
        endDecoration,
        t,
      );
}

// Per-tween, bounded preparation: at most one current point context per layer.
// Sampled decorations keep their original plan when the Tween is retargeted.
class _DecorationTransition {
  final AnyDecoration begin, end;
  final _layers =
      <int, ((Rect, TextDirection?, double), AnyContourTransition)>{};
  _DecorationTransition(this.begin, this.end);

  AnyContourTransition layer(Rect bounds, TextDirection? direction, int index,
      double offset, List<AnyPoint> Function(AnyDecoration) build) {
    final key = (bounds, direction, offset);
    final cached = _layers[index];
    if (cached != null && cached.$1 == key) {
      cached.$2.reusePointContext = true;
      return cached.$2;
    }
    final hasBegin = index < begin.borders.length;
    final hasEnd = index < end.borders.length;
    // Current displacement reaches both builders before corner construction.
    var a = build(hasBegin ? begin : end);
    var b = build(hasEnd ? end : begin);
    List<AnyPoint> withoutWidths(List<AnyPoint> points) => [
          for (final p in points)
            AnyPoint(
                point: p.point,
                shape: p.shape,
                outer: p.outer,
                inner: p.inner,
                side: p.side.copyWith(width: 0),
                skip: p.skip)
        ];
    if (!hasBegin) a = withoutWidths(a);
    if (!hasEnd) b = withoutWidths(b);
    final result =
        AnyContourTransition(a, b, reusePointContext: cached == null);
    _layers[index] = (key, result);
    return result;
  }
}
