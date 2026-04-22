## any_borders

[![Tests](https://github.com/andry-brill/a-borders/actions/workflows/test.yml/badge.svg)](https://github.com/andry-brill/a-borders/actions/workflows/test.yml)

> A unified way to create shapes with non-uniform borders and fills, along with customizable alignment, corners, and shadows.

![App Screenshot](https://raw.githubusercontent.com/andry-brill/a-borders/main/example/web/screenshot.png)

`any_borders` is a Flutter package to build a decoration from contour
points, side definitions, corner strategies, fills, backgrounds, and shadows.
The same fill model is shared by sides, backgrounds, and shadows, so borders can
use solid colors, gradients, images, or combinations of them.

> You might also like my other package: [any_sparklines](https://pub.dev/packages/any_sparklines) 

## Central idea

- `AnyDecoration` defines a contour by returning a list of `AnyPoint`s.
- `AnyPoint` carries an outer corner, an optional inner corner, and the `AnySide` painted until the next point.
- `AnyBorder` used by `point(...)`  for side, outer-corner, inner-corner, and ratio defaults.
- `AnyFill` is the shared color / gradient / image contract used by sides, backgrounds, and shadows.

## Quick Start

```dart
Container(
  width: 180,
  height: 96,
  decoration: const AnyBoxDecoration(
    border: AnyBoxBorder(
      sides: AnySide(
        color: Color(0xFF2E685F),
        width: 12,
        align: AnySide.alignCenter,
      ),
      corners: RoundedCorner(radius: 24),
    ),
    background: AnyBackground(color: Color(0xFF85AEA8)),
  ),
)
```

## Corners

All corners derive from `AnyCorner`. The constructor `radius` form creates an
even corner, while the `elliptical` constructors allow different extents along
the previous and next sides.

> Warning: contour corners with angles of `0`, `180`, or `360` degrees are
> currently unstable. Their behavior may change in future versions.

### RoundedCorner

`RoundedCorner` creates a rounded arc between neighboring sides.

```dart
const RoundedCorner(radius: 24)
const RoundedCorner.elliptical(p: 40, n: 16)
```

### BevelCorner

`BevelCorner` replaces the arc with a straight bevel segment.

```dart
const BevelCorner(radius: 24)
const BevelCorner.elliptical(p: 40, n: 16)
```

### InverseRoundedCorner (beta)

`InverseRoundedCorner` creates an inward rounded contour. This corner is marked
as beta because edge cases and conversion behavior may still change.

```dart
const InverseRoundedCorner(radius: 18)
const InverseRoundedCorner.elliptical(p: 32, n: 18)
```


## AnyFill

`AnyFill` is the shared fill API used by `AnySide`, `AnyBackground`, and
`AnyShadow`. A fill can provide:

- `color`: solid base fill.
- `gradient`: gradient base fill. If both `color` and `gradient` are set, the
  gradient is used for the base paint.
- `image`: a `DecorationImage` painted into the same path.
- `blendMode`: blend mode for the base paint.
- `isAntiAlias`: controls path anti-aliasing.

Classes that implement the fill contract use `MAnyFill`, which provides
consistent `hasFill`, `hasBaseFill`, `isSameAs`, and `createBasePaint`
behavior.

## AnyBoxDecoration

`AnyBoxDecoration` is the rectangular decoration most apps should start with.
It extends `AnyDecoration` and creates four contour points for a box. Border
geometry is configured through `border: AnyBoxBorder(...)`.

Useful fields:

- `border`: side, corner, inner-corner, ratio, and shape configuration.
- `background`: fill behind the side regions.
- `shadows`: shadows painted from the configured contour.
- `clipBase`: contour band returned by `getClipPath`.
- `shadowBase`: contour band used as the source path for shadows.

Useful `AnyBoxBorder` fields:

- `sides`: default side for all edges.
- `left`, `top`, `right`, `bottom`: per-edge overrides.
- `horizontal`: fallback for top and bottom.
- `vertical`: fallback for left and right.
- `corners`: default outer corner.
- `topLeft`, `topRight`, `bottomRight`, `bottomLeft`: per-corner outer
  overrides.
- `innerCorners`: default inner corner.
- `innerTopLeft`, `innerTopRight`, `innerBottomRight`, `innerBottomLeft`:
  per-corner inner overrides.
- `ratio`: optional width / height ratio used to fit the decoration inside the
  paint bounds.
- `shape`: convenience setting for `rectangle`, `square`, `circle`, or `pill`.

Example with independent side widths:

```dart
const AnyBoxDecoration(
  border: AnyBoxBorder(
    left: AnySide(color: Color(0xFF2E685F), width: 8),
    top: AnySide(color: Color(0xFF2E685F), width: 16),
    right: AnySide(color: Color(0xFF2E685F), width: 24),
    bottom: AnySide(color: Color(0xFF2E685F), width: 32),
    corners: RoundedCorner(radius: 20),
  ),
  background: AnyBackground(color: Color(0xFF85AEA8)),
)
```

## AnyBorder

`AnyBorder` groups the border defaults shared by all `AnyDecoration`
subclasses:

- `sides`: default side for generated points.
- `corners`: default outer corner for generated points.
- `innerCorners`: optional default inner corner for generated points.
- `ratio`: optional width / height ratio used to fit the contour inside the
  paint bounds.

Custom decoration subclasses can accept `super.border` and continue to call
`point(...)`; missing point-specific values are resolved from `border`.

## AnySide

`AnySide` describes one border segment. Width and alignment are separate:

- `width`: side thickness.
- `align`: how the side is positioned relative to the source contour.
- `AnySide.alignInside`: paint inside the contour.
- `AnySide.alignCenter`: center on the contour.
- `AnySide.alignOutside`: paint outside the contour.

Because `AnySide` implements `AnyFill`, each side can use a color, gradient,
image, blend mode, and anti-aliasing setting.

```dart
const AnySide(
  width: 20,
  align: AnySide.alignOutside,
  gradient: LinearGradient(
    colors: [Color(0xFF85AEA8), Color(0xFF2E685F)],
  ),
)
```

## AnyBackground

`AnyBackground` paints behind side regions and also implements `AnyFill`.
`shapeBase` chooses which contour band is used for the background path:

- `AnyShapeBase.zeroBorder`: the source contour points.
- `AnyShapeBase.outerBorder`: the outside of aligned sides.
- `AnyShapeBase.innerBorder`: the inside of aligned sides.

```dart
const AnyBackground(
  color: Color(0xFF85AEA8),
  shapeBase: AnyShapeBase.zeroBorder,
)
```

## AnyCorner

`AnyCorner` is the strategy interface for corner geometry. A corner defines its
extent along the previous side with `p` and along the next side with `n`.
Concrete corners handle path construction, side consumption, interpolation, and
conversion between outer, base, and inner contour bands.

For normal use, choose one of:

- `RoundedCorner`
- `BevelCorner`
- `InverseRoundedCorner` (beta)

Use `CornerConverter` on supported corners to control how corners are converted
when borders move inward or outward:

- `CornerConverter.dynamicRatio`: adjust each extent independently.
- `CornerConverter.preserveRatio`: preserve the original corner ratio.
- `CornerConverter.equal`: keep the same corner unchanged.

## Custom Decorations

Create a custom decoration by extending `AnyDecoration` and returning contour
points from `buildPoints`. This diamond uses the centers of each side:

```dart
class DiamondDecoration extends AnyDecoration {
  const DiamondDecoration({
    super.background,
    super.border,
  });

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection) {
    return [
      point(bounds.topCenter),
      point(bounds.centerRight),
      point(bounds.bottomCenter),
      point(bounds.centerLeft),
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is DiamondDecoration && super == other;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, DiamondDecoration);
}
```

Custom `AnyDecoration` subclasses should override `operator ==` and `hashCode`
for every field they add. Contour caching depends on decoration equality.

## Extras

Extras are ready-made decorations that may be useful, but are not exported by
`package:any_borders/any_borders.dart`. Import them manually through the extras
barrel or by importing a specific file:

```dart
import 'package:any_borders/any_extras.dart';
```

```dart
import 'package:any_borders/extras/any_tab_decoration.dart';
```

### AnyTabDecoration

- `AnyTabDecoration` creates a tab-like contour configured through `AnyBoxBorder`. 
- The tab offsets are derived from the bottom corner extents instead of a
separate offset.
- `offsetOutward` defaults to `true`, so the lower tab expands outside the
provided bounds. Set it to `false` to keep the tab inset inside the bounds.

```dart
const AnyTabDecoration(
  offsetOutward: true,
  border: AnyBoxBorder(
    corners: RoundedCorner(radius: 20),
  ),
  background: AnyBackground(color: Color(0xFF85AEA8)),
)
```

> Warning: contour corners with angles of `0`, `180`, or `360` degrees are
> currently unstable. Their behavior may change in future versions.

