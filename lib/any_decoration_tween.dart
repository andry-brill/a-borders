import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

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
              return _TweenBorder(index, a, lerpDouble(a.offset, b.offset, t)!);
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
  List<AnyPoint> buildPoints(
          Rect bounds,
          TextDirection? textDirection,
          covariant _TweenBorder border,
          double offset,
          List<double> sideOffsets) =>
      _layer(bounds, textDirection, border.index, offset, sideOffsets)
          .points(t);

  @override
  List<double> sideOffsetsForBorder(Rect bounds, TextDirection? textDirection,
      covariant _TweenBorder border) {
    final (from, to) =
        _endpointSideOffsets(bounds, textDirection, border.index);
    return List<double>.unmodifiable(from.length == to.length
        ? [
            for (var i = 0; i < from.length; i++)
              lerpDouble(from[i], to[i], t)!,
          ]
        // Different shapes retain separate construction slots. Keeping both
        // layouts also lets a saved tween sample be another tween's endpoint.
        : [...from, ...to]);
  }

  @override
  AnyContour buildContourForBorder(
          Rect bounds, TextDirection? textDirection, int index) =>
      _layer(
              bounds,
              textDirection,
              index,
              offset + borders[index].offset,
              sideOffsetsForBorder(
                  bounds, textDirection, borders[index] as _TweenBorder))
          .build(t,
              background: index == primaryBorderIndex ? background : null,
              backgroundBase: background?.shapeBase ?? AnyShapeBase.shapeBorder,
              clipBase: clipBase,
              shadowBase: shadowBase);

  (List<double>, List<double>) _endpointSideOffsets(
      Rect bounds, TextDirection? direction, int index) {
    final a = index < beginDecoration.borders.length
        ? beginDecoration
        : endDecoration;
    final b = index < endDecoration.borders.length ? endDecoration : a;
    return (
      a.sideOffsetsForBorder(bounds, direction, a.borders[index]),
      b.sideOffsetsForBorder(bounds, direction, b.borders[index]),
    );
  }

  AnyContourTransition _layer(Rect bounds, TextDirection? direction, int index,
      double offset, List<double> sideOffsets) {
    final (from, to) = _endpointSideOffsets(bounds, direction, index);
    final matching = from.length == to.length;
    return prepared.layer(
        bounds,
        direction,
        index,
        offset,
        matching ? sideOffsets : sideOffsets.sublist(0, from.length),
        matching ? sideOffsets : sideOffsets.sublist(from.length),
        (decoration, offsets) => decoration.buildPoints(
            bounds, direction, decoration.borders[index], offset, offsets));
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

// A sampled tween carries explicit layer identity even when endpoint borders
// are equal or shared instances. Endpoint builders receive their original
// borders, including custom subclasses, rather than this internal metadata.
class _TweenBorder extends AnyBorder {
  final int index;
  final AnyBorder source;

  _TweenBorder(this.index, this.source, double offset)
      : super(
          sides: source.sides,
          corners: source.corners,
          outerCorners: source.outerCorners,
          innerCorners: source.innerCorners,
          ratio: source.ratio,
          offset: offset,
        );

  @override
  List<AnySide> get resolvedSides => source.resolvedSides;

  @override
  bool operator ==(Object other) =>
      other is _TweenBorder &&
      other.index == index &&
      other.source == source &&
      super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, index, source);
}

// Per-tween, bounded preparation: at most one current point context per layer.
// Sampled decorations keep their original plan when the Tween is retargeted.
class _DecorationTransition {
  final AnyDecoration begin, end;
  final _layers = <int,
      (
    (Rect, TextDirection?, double, List<double>, List<double>),
    AnyContourTransition
  )>{};
  _DecorationTransition(this.begin, this.end);

  AnyContourTransition layer(
      Rect bounds,
      TextDirection? direction,
      int index,
      double offset,
      List<double> fromSideOffsets,
      List<double> toSideOffsets,
      List<AnyPoint> Function(AnyDecoration, List<double>) build) {
    final cached = _layers[index];
    if (cached != null &&
        cached.$1.$1 == bounds &&
        cached.$1.$2 == direction &&
        cached.$1.$3 == offset &&
        listEquals(cached.$1.$4, fromSideOffsets) &&
        listEquals(cached.$1.$5, toSideOffsets)) {
      cached.$2.reusePointContext = true;
      return cached.$2;
    }
    final hasBegin = index < begin.borders.length;
    final hasEnd = index < end.borders.length;
    final from = List<double>.unmodifiable(fromSideOffsets);
    final to = List<double>.unmodifiable(toSideOffsets);
    final key = (bounds, direction, offset, from, to);
    // Current uniform and side displacements reach both endpoint builders
    // before corner construction and exhausted-outline checks.
    var a = build(hasBegin ? begin : end, from);
    var b = build(hasEnd ? end : begin, to);
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
