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
- `AnyPoint` requires a shape corner, with optional inner/outer overrides and the `AnySide` painted until the next point.
- `AnyBorder` supplies side, shape-corner, optional boundary-corner, and ratio defaults to `point(...)`.
- Missing inner and outer corners derive independently from the normalized shape.
- Multiple borders paint in list order; the primary border supplies decoration effects.
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

## Multiple borders

```dart
const AnyBoxDecoration.multi(
  primaryBorderIndex: 0,
  borders: [
    AnyBoxBorder(
      corners: RoundedCorner(radius: 20),
      sides: AnySide(width: 4, align: AnySide.alignOutside,
          color: Color(0xFF1565C0)),
    ),
    AnyBoxBorder(
      corners: RoundedCorner(radius: 20),
      sides: AnySide(width: 2, align: AnySide.alignOutside,
          color: Color(0xFFFFFFFF)),
    ),
  ],
  background: AnyBackground(color: Color(0xFFE3F2FD)),
)
```

The first entry paints first. Later entries cover earlier ones: the two-pixel
white border covers two pixels of the blue border. There is no cumulative
placement. Each layer fits its own ratio and shape into the same paint size.

`border` returns the primary border; `borders` is a read-only ordered view.
`primaryBorderIndex` selects all background, clipping and shadow paths; there
is no silhouette union. Effects paint once before border layers. The three
default selectors use `shapeBorder`, so explicit outer corners do not change
the default clip or background shape.

The list must be nonempty and the primary index in range. Keep supplied lists
immutable after construction. Runtime validation happens before geometry so
constructors remain `const`. Use a zero-width single border for background-only
decoration. A single border and its equivalent one-entry multi decoration
compare equally.

`buildContours(size, direction)` returns every layer; `buildContour` returns the
primary layer. Tweens pair layers by index and animate inserted or removed
layers from/to zero width. See the [2.0 migration guide](MIGRATION.md).

An explicit boundary override and primary selection can be combined:

```dart
const AnyBoxDecoration.multi(
  primaryBorderIndex: 1,
  borders: [
    AnyBoxBorder(sides: AnySide(width: 6, color: Color(0xFF1565C0))),
    AnyBoxBorder(
      corners: RoundedCorner(radius: 20),
      outerTopLeft: BevelCorner(radius: 28),
      sides: AnySide(width: 2, color: Color(0xFFFFFFFF)),
    ),
  ],
  clipBase: AnyShapeBase.shapeBorder,
  background: AnyBackground(color: Color(0xFFE3F2FD)),
)
```

Here clipping and the background follow the second layer's rounded source;
its explicit outer bevel affects only that border's outer boundary.

## Corners

`AnyCorner` describes source geometry. `p` belongs to the ray pointing toward
the previous vertex; `n` belongs to the ray toward the next vertex. Reversing a
custom outline requires swapping `p`/`n` and moving each side setting to the
corresponding reversed edge.

| Type | Meaning of `p` / `n` | Source contacts at angle θ |
| --- | --- | --- |
| `RoundedCorner` | Ray-based scaling of a unit circular fillet | `p × cot(θ/2)`, `n × cot(θ/2)` |
| `InverseRoundedCorner` | Ray-based scaling of a circular sector centered at the vertex | `p`, `n` |
| `BevelCorner` | Straight-cut distances along the incident rays | `p`, `n` |

```dart
const RoundedCorner(radius: 24) // A genuine circle, including at 60 degrees.
const RoundedCorner.elliptical(p: 40, n: 16)
const BevelCorner(radius: 24)
const InverseRoundedCorner.elliptical(p: 32, n: 18)
```

At a right angle the ray axes are perpendicular. At other angles the elliptical
forms are affine images in the two-ray basis; `p` and `n` are not necessarily
the ellipse's principal semiaxes. Equal values produce circular rounded and
inverse-rounded source corners. Source normalization preserves their proportions
and is independent of border width.

Automatic rounded boundaries adjust the corresponding radius component: at a
convex box corner, the next side changes `p` and the previous side changes `n`.
Growing a tiny rounded radius uses a continuous taper that keeps zero sharp.
`dynamicRatio` remains the default; unequal widths can correctly produce an
elliptical boundary around a circular source.

Bevel boundaries use intersections of displaced lines. Automatic scoop boundaries
share the shape vertex as their reference center and follow the source curve's
normal. With equal widths, circular scoops are concentric: an outside distance
`d` gives radius `r-d`, and an inside distance `d` gives radius `r+d` at a convex
vertex. Elliptical scoops use parallel curves, which need not be ellipses.
Side intersections trim the curves; outward contacts use straight tangent joins.
There are no auxiliary rounded joins. Uniform thickness applies along the
surviving curved part; the sharp joins intentionally differ from round offsets.
Explicit inner/outer scoops retain their authored dimensions and are centered
at their own inner/outer side intersections, independently of the shape.

Automatic filled boundaries can become empty or split into several components.
Supported inputs are simple source outlines and the tab's collinear/backtracking
helper construction. Skip duplicate vertices; arbitrary authored self-intersecting
outlines are rejected. Parallel helper vertices resolve without a fillet.

See [geometry policies, precision, and regression tests](GEOMETRY.md). Open
**Inspect corners** in the example app to examine source/inner/outer curves,
centers, tangents, unequal widths, and the reported mixed-alignment box.

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

- `border`: primary side, shape-corner, boundary-corner, ratio, and shape configuration.
- `borders`: ordered border layers (use `.multi` to supply a list).
- `primaryBorderIndex`: the layer supplying decoration-level paths.
- `background`: fill behind the side regions.
- `shadows`: shadows painted from the configured contour.
- `clipBase`: contour band returned by `getClipPath`.
- `shadowBase`: contour band used as the source path for shadows.

Useful `AnyBoxBorder` fields:

- `sides`: default side for all edges.
- `left`, `top`, `right`, `bottom`: per-edge overrides.
- `horizontal`: fallback for top and bottom.
- `vertical`: fallback for left and right.
- `corners`: default shape corner.
- `topLeft`, `topRight`, `bottomRight`, `bottomLeft`: shape-corner overrides.
- `outerCorners`: optional default outer corner.
- `outerTopLeft`, `outerTopRight`, `outerBottomRight`, `outerBottomLeft`: outer overrides.
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
- `corners`: default shape corner for generated points.
- `outerCorners`: optional default outer corner for generated points.
- `innerCorners`: optional default inner corner for generated points.
- `ratio`: optional width / height ratio used to fit the contour inside the
  paint bounds.

Custom decoration subclasses can accept `super.border` and continue to call
`point(..., borderIndex: borderIndex)`; missing point-specific values resolve
from the selected border.

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

- `AnyShapeBase.shapeBorder`: directly resolved source shape (the default).
- `AnyShapeBase.zeroBorder`: legacy zero-offset boundary derived from outer corners.
- `AnyShapeBase.outerBorder`: the outside of aligned sides.
- `AnyShapeBase.innerBorder`: the inside of aligned sides.

```dart
const AnyBackground(
  color: Color(0xFF85AEA8),
  shapeBase: AnyShapeBase.shapeBorder,
)
```

## AnyCorner

`AnyCorner` is an immutable descriptor. `resolve(frame)` returns an
`AnyResolvedCorner`; `resolveBoundary(source, previousDistance: ...,
nextDistance: ...)` derives a boundary using named signed distances (positive
inward). Built-in descriptors resolve finite dimensions after normalization.

`AnyResolvedCorner` exposes canonical segments, actual `previousExtent` and
`nextExtent`, points, tangents, and path subdivision. `parameters` is nullable:
a custom resolved curve may not be representable by another `p`/`n` pair. The
contour's four corner collections now contain resolved corners.

Rounded and bevel descriptors support these converter policies:

- `dynamicRatio` (default): adjust the two components independently.
- `preserveRatio`: retain rounded proportions; use one weighted parallel bevel.
- `equal`: retain the authored dimensions at the shifted vertex.

These are shape-design policies, not universal constant-distance offsets.
Scoop boundaries use the shared-origin normal-offset policy described above.
See the [advanced API migration](MIGRATION.md#advanced-corner-api).

## Custom corners

Extend `AnyCorner` and select an `AnyCornerGeometry` through `geometry`.
Built-ins pair with `RoundedCornerGeometry`, `BevelCornerGeometry`, and
`InverseRoundedCornerGeometry`. The engine uses the same public contracts for
custom corners and has no concrete-corner registry.

See the [custom-corner guide](CUSTOM_CORNERS.md),
[complete NotchCorner example](example/lib/custom_corner.dart), and
[migration notes](MIGRATION.md#custom-corner-providers).

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
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection, int borderIndex) {
    return [
      point(bounds.topCenter, borderIndex: borderIndex),
      point(bounds.centerRight, borderIndex: borderIndex),
      point(bounds.bottomCenter, borderIndex: borderIndex),
      point(bounds.centerLeft, borderIndex: borderIndex),
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
`points(bounds, direction, borderIndex: i)` selects one point list; omitting the
index uses the primary border. The cache stores read-only ordered contour lists.

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
- Tab offsets derive from each layer's bottom shape corners.
- `AnyTabDecoration.multi` accepts independently configured border layers.
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

Tab helper vertices keep their side settings and skipped-point behavior.
Parallel vertices have no fillet; offset sides are connected explicitly.

