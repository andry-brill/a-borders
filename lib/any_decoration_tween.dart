
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
  }) : super(
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
  Rect fitRatio(Size size, double? ratio) {
    final beginRatio = _effectiveRatio(size, beginDecoration.ratio);
    final endRatio = _effectiveRatio(size, endDecoration.ratio);
    final lRatio = lerpDouble(beginRatio, endRatio, t)!;
    return super.fitRatio(size, lRatio);
  }

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection) {
    final a = beginDecoration.points(bounds, textDirection);
    final b = endDecoration.points(bounds, textDirection);
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