import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';

import 'any_contour.dart';
import 'any_shadow.dart';
import 'any_utils.dart';

class AnyDecorationTween extends Tween<AnyDecoration> {
  AnyDecorationTween({
    required AnyDecoration super.begin,
    required AnyDecoration super.end,
  });

  @override
  AnyDecoration lerp(double t) {
    if (t <= 0.0) return begin!;
    if (t >= 1.0) return end!;

    return _TweenDecoration(
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

  _TweenDecoration({
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
    return super.fitRatio(size, lRatio);
  }

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection,
      int borderIndex, double offset) {
    final hasBegin = borderIndex < beginDecoration.borders.length;
    final hasEnd = borderIndex < endDecoration.borders.length;
    // Both builders use the current offset. Using their endpoint offsets would
    // interpolate already exhausted point lists and switch them at the midpoint
    // instead of letting the current outline reach its actual collapse point.
    var a = (hasBegin ? beginDecoration : endDecoration)
        .buildPoints(bounds, textDirection, borderIndex, offset);
    var b = (hasEnd ? endDecoration : beginDecoration)
        .buildPoints(bounds, textDirection, borderIndex, offset);
    List<AnyPoint> withoutWidths(List<AnyPoint> points) => points
        .map((p) => AnyPoint(
            shape: p.shape,
            outer: p.outer,
            inner: p.inner,
            point: p.point,
            side: p.side.copyWith(width: 0),
            skip: p.skip))
        .toList(growable: false);
    if (!hasBegin) {
      a = withoutWidths(a);
    }
    if (!hasEnd) {
      b = withoutWidths(b);
    }
    return AnyPoint.lerp(a, b, t)!;
  }

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
