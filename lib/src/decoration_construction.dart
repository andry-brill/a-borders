part of '../any_contour.dart';

// One evaluation owns the raw layout and shares nodes by identity. These caches
// live only for this construction; prepared geometry remains bounded per tween.
class _ConstructionContext {
  final Rect bounds;
  final TextDirection? direction;
  final int index;
  final _recipes = Map<AnyDecoration, _LayerRecipe>.identity();
  _ConstructionContext(this.bounds, this.direction, this.index);

  _LayerRecipe recipe(AnyDecoration decoration) =>
      _recipes.putIfAbsent(decoration, () => decoration._recipe(this));
}

class _SlotValues {
  final List<double> values;
  _SlotValues(List<double> values) : values = List.unmodifiable(values);
  @override
  bool operator ==(Object other) =>
      other is _SlotValues && listEquals(values, other.values);
  @override
  int get hashCode => Object.hashAll(values);
}

// A node is evaluated once per distinct current context, including when shared
// ancestors receive different offsets from different branches of a nested tween.
class _LayerRecipe {
  final List<double> slots;
  final Rect Function(double, List<double>) _adjust;
  final double? Function(Rect) _ratio;
  final AnyContourSample Function(Rect, List<double>) _build;
  final _adjusted = <(double, _SlotValues), Rect>{};
  final _ratios = <Rect, double?>{};
  final _built = <(Rect, _SlotValues), AnyContourSample>{};

  _LayerRecipe(List<double> slots, this._adjust, this._ratio, this._build)
      : slots = List.unmodifiable(slots);

  double? ratio(Rect available) => _ratios.putIfAbsent(available, () {
        final value = _ratio(available);
        if (value != null && (value.isNaN || value == double.infinity)) {
          throw ArgumentError.value(
              value, 'ratio', 'Must be finite or nonpositive');
        }
        return value;
      });

  Rect adjust(double offset, List<double> values) =>
      _adjusted.putIfAbsent((offset, _SlotValues(values)), () {
        if (!offset.isFinite ||
            values.any((v) => !v.isFinite || !(offset + v).isFinite)) {
          throw ArgumentError('Effective bounds offsets must be finite.');
        }
        final result = _adjust(offset, values);
        AnyUtils.validateBounds(result);
        return result;
      });

  AnyContourSample build(Rect bounds, List<double> values) => _built
      .putIfAbsent((bounds, _SlotValues(values)), () => _build(bounds, values));
}
