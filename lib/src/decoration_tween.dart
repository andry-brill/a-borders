part of '../any_contour.dart';

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
    if (identical(begin, end)) return begin!;

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

  @override
  _LayerRecipe _recipe(_ConstructionContext context) {
    final index = context.index, direction = context.direction;
    final a = index < beginDecoration.borders.length
        ? beginDecoration
        : endDecoration;
    final b = index < endDecoration.borders.length ? endDecoration : a;
    final from = context.recipe(a);
    final to = context.recipe(b);
    final matching = from.slots.length == to.slots.length;
    (List<double>, List<double>) split(List<double> slots) => matching
        ? (slots, slots)
        : (
            slots.sublist(0, from.slots.length),
            slots.sublist(from.slots.length)
          );
    final slots = matching
        ? [
            for (var i = 0; i < from.slots.length; i++)
              lerpDouble(from.slots[i], to.slots[i], t)!
          ]
        : [...from.slots, ...to.slots];
    return _LayerRecipe(
      slots,
      (offset, values) {
        final (left, right) = split(values);
        final a = from.adjust(offset, left), b = to.adjust(offset, right);
        // Preserve equal rectangles exactly so t cannot perturb cache identity.
        return a == b ? a : Rect.lerp(a, b, t)!;
      },
      (available) {
        final ar = from.ratio(available), br = to.ratio(available);
        final aFits = ar != null && ar > 0;
        final bFits = br != null && br > 0;
        if (!aFits && !bFits) return null;
        return lerpDouble(aFits ? ar : available.width / available.height,
            bFits ? br : available.width / available.height, t);
      },
      (bounds, values) {
        final (left, right) = split(values);
        final transition = prepared.layer(bounds, direction, index, left, right,
            () => from.build(bounds, left), () => to.build(bounds, right));
        return AnyContourSample.animated(transition, t);
      },
    );
  }

  // Internal sampled decorations compose complete geometry through _recipe.
  // Their public points/buildContour entry points never dispatch this leaf hook.
  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? direction,
          AnyBorder border, List<double> sideOffsets) =>
      throw UnsupportedError(
          'Use points or buildContour to construct a tween sample.');

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
    (Rect, TextDirection?, List<double>, List<double>),
    AnyContourTransition
  )>{};
  _DecorationTransition(this.begin, this.end);

  AnyContourTransition layer(
      Rect bounds,
      TextDirection? direction,
      int index,
      List<double> fromSideOffsets,
      List<double> toSideOffsets,
      AnyContourSample Function() buildFrom,
      AnyContourSample Function() buildTo) {
    final cached = _layers[index];
    if (cached != null &&
        cached.$1.$1 == bounds &&
        cached.$1.$2 == direction &&
        listEquals(cached.$1.$3, fromSideOffsets) &&
        listEquals(cached.$1.$4, toSideOffsets)) {
      cached.$2.reusePointContext = true;
      return cached.$2;
    }
    final hasBegin = index < begin.borders.length;
    final hasEnd = index < end.borders.length;
    final from = List<double>.unmodifiable(fromSideOffsets);
    final to = List<double>.unmodifiable(toSideOffsets);
    final key = (bounds, direction, from, to);
    // Bounds preparation has already consumed every scalar/side adjustment.
    var a = buildFrom();
    var b = buildTo();
    AnyContourSample withoutWidths(AnyContourSample sample) =>
        AnyContourSample([
          for (final p in sample.points)
            AnyPoint(
                point: p.point,
                shape: p.shape,
                outer: p.outer,
                inner: p.inner,
                side: p.side.copyWith(width: 0),
                skip: p.skip)
        ]);
    if (!hasBegin) a = withoutWidths(a);
    if (!hasEnd) b = withoutWidths(b);
    final result =
        AnyContourTransition(a, b, reusePointContext: cached == null);
    _layers[index] = (key, result);
    return result;
  }
}
