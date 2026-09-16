# Migrating to any_borders 2.0.0

## Custom corner providers

Custom corners now require an `AnyCorner.geometry` provider. Move descriptor
`resolve` overrides to `AnyCornerGeometry.resolve`, and boundary construction
to its `buildBoundary` hook (or provider `resolveBoundary` when customizing
early returns). The descriptor resolution methods remain nonvirtual calling
conveniences; the engine no longer dispatches through overrides of them.

Built-in constructors and existing imports are unchanged. Providers select
optional local geometry guarantees; conservative custom geometry retains general
assembly. See [the custom-corner guide](CUSTOM_CORNERS.md) and its tested example.

## Shape, inner, and outer corners

In 1.x, `corners` and `topLeft`/`topRight`/`bottomRight`/`bottomLeft` described
outer border corners. In 2.0, they describe the source shape. The shape remains
stable when border widths, alignment, or explicit boundary corners change.

| Boundary | Default corner | Box override example | AnyPoint field |
| --- | --- | --- | --- |
| Shape | `corners` | `topLeft` | required `shape` |
| Outer | `outerCorners` | `outerTopLeft` | optional `outer` |
| Inner | `innerCorners` | `innerTopLeft` | optional `inner` |

`left`, `top`, `right`, `bottom`, `horizontal`, and `vertical` still configure
sides. `circle` and `pill` now provide infinite rounded shape corners.

An omitted inner or outer corner is derived directly from the normalized shape
corner using adjacent inside or outside distances. Explicit overrides affect
only their own boundary. They are not required to contain one another, so they
can still produce deliberate artistic shapes.

```dart
const AnyBoxBorder(
  corners: RoundedCorner(radius: 20),
  sides: AnySide(width: 4, align: AnySide.alignOutside),
  outerTopLeft: BevelCorner(radius: 26), // One explicit boundary exception.
)
```

Here the automatic inner radius is 20 and the other outer radii are 24. The
explicit outer top-left does not change the source or inner corner.

To preserve a 1.x outer corner, move its setting to `outerCorners` or the
corresponding `outer*` field and supply the desired shape corner separately.
For exact 1.x appearance, also specify the old inner corner explicitly when
needed: deriving from shape can differ from the old outer-to-inner conversion,
especially for asymmetric bevels and normalized corners. There is no universal
mechanical radius rename that preserves every old configuration.

The “Any corner”, “Back+T+B”, and crown examples explicitly author both inner
and outer boundaries to retain their former design. The crown also translates
its old perpendicular dimensions into ray contact distances: a bevel uses
`oldDimension / sin(theta)`, and a rounded fillet uses
`oldDimension / (1 + cos(theta))` to retain its contact positions. Rounded curves
at non-right angles still use the corrected circular construction.

When both boundary roles are explicit, painted side partitions connect their
split points directly and do not depend on the shape corner. An explicit
straight-vertex boundary uses a single averaged shifted anchor, preserving
sloping transitions between differently aligned sides. Reversing tab helpers
continue to connect their two shifted side contacts.

Direct point construction now requires `shape`:

```dart
const AnyPoint(
  point: Offset(0, 0),
  shape: RoundedCorner(radius: 20),
  side: AnySide(width: 4),
  // outer and inner are optional.
)
```

## Backgrounds, clipping, and shadows

`AnyBackground.shapeBase`, `AnyDecoration.clipBase`, and
`AnyDecoration.shadowBase` now default to `AnyShapeBase.shapeBorder`.

* `shapeBorder`: source vertices with the directly resolved shape corners.
* `outerBorder`: resolved outside boundary of the selected border.
* `innerBorder`: resolved inside boundary of the selected border.
* `zeroBorder`: legacy zero-offset boundary derived from the resolved outer
  corners. It is not an alias for `shapeBorder`; outer overrides and conversion
  policies can make the paths differ.

Choose `zeroBorder` explicitly where the old outer-derived path is intended.
Using it alone does not restore 1.x auto-derived inner corners.

## Multiple independent borders

The existing const single-border constructor remains available. Base, box, and
tab decorations also expose const `.multi(...)` constructors:

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

The first border paints first. The second covers the inner two pixels of its
four-pixel outside stroke, leaving two visible blue pixels and two white pixels.
For four visible blue pixels plus two white pixels, use widths six and two.
Translucent layers blend normally where they overlap. Layers are not
automatically displaced to sit beside one another.

Each border fits its own ratio and shape into the same paint size.
`primaryBorderIndex` defaults to zero and selects the border for **all**
background, clip, and shadow boundary selectors. Effects paint once, before the
ordered border layers. Changing the primary index does not change paint order
and does not combine silhouettes. Tab layers derive their tab offsets from
their own shape corners.

`border` returns the primary border; `borders` is a read-only ordered view.
Constructor lists must remain immutable after construction, including lists
passed without `const`. An empty list is invalid: use a zero-width single border
for a background-only decoration. The primary index must be in range.

To preserve const construction, a negative primary index has a constructor
assertion; list emptiness and the upper index bound are validated before point
or contour construction (Dart const assertions cannot read list length).

## Custom decorations and geometry access

The abstract `AnyDecoration` remains abstract. Its named constructor is available
to subclasses. `buildPoints` gains a required third positional `borderIndex`;
pass it to each `point(...)` helper call. For custom per-layer settings, use
`borders[borderIndex]`, not the primary `border` getter.

```dart
class DiamondDecoration extends AnyDecoration {
  const DiamondDecoration({super.border, super.background});

  const DiamondDecoration.multi({
    required super.borders,
    super.primaryBorderIndex,
    super.background,
  }) : super.multi();

  @override
  List<AnyPoint> buildPoints(
      Rect bounds, TextDirection? textDirection, int borderIndex) => [
    point(bounds.topCenter, borderIndex: borderIndex),
    point(bounds.centerRight, borderIndex: borderIndex),
    point(bounds.bottomCenter, borderIndex: borderIndex),
    point(bounds.centerLeft, borderIndex: borderIndex),
  ];

  @override
  bool operator ==(Object other) =>
      other is DiamondDecoration && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, DiamondDecoration);
}
```

`point(...)` resolves shape from the selected border when omitted. Its inner
and outer defaults stay nullable until geometry resolution. Explicit point
values take precedence over the border defaults.

* `points(bounds, direction, borderIndex: i)` selects a point list; omitting the
  index selects the primary layer. Bounds are already supplied by the caller.
* `buildContours(size, direction)` fits and returns every contour in paint order.
* `buildContour(size, direction)` returns the primary contour.
* `AnyDecorationCache.get/put` now exchange `List<AnyContour>`. Cached collections
  are read-only and retain the existing LRU limit/clear behavior.

Single-border and equivalent one-layer multi decorations compare equally.
Equality includes ordered layers, primary index, and all corner fields. Custom
subclasses still need equality/hash implementations for fields they add.

## Animation

`AnyDecorationTween` matches borders by list index. Missing layers grow from or
shrink to zero width while retaining their endpoint shape and fill configuration.
Ratios interpolate independently. Changing the primary index switches its
selection at the midpoint. Exact endpoint decorations are returned at zero and
one; intermediate contours are not cached.

Point-count mismatches retain the midpoint-switch fallback. Optional inner and
outer overrides retain nullable midpoint selection, and different corner types
retain the existing shrink/switch/grow transition. Reordering a list therefore
changes which layers are paired; there are no layer identifiers.

## Corrected corner geometry

`RoundedCorner(radius: r)` now means a true circular fillet at non-right angles.
Its contacts lie `r × cot(θ/2)` units along its rays. Elliptical rounded corners
scale that unit fillet along the previous and next rays. Bevel and scoop source
contacts remain `p`/`n` units along the rays. At 90° the source definitions
retain their previous meaning.

The corrected rounded converter pairs `p` with the **next** side's distance and
`n` with the **previous** side's distance. `dynamicRatio` stays the default.
A circular source with unequal adjacent border distances can legitimately have
an elliptical boundary; the source itself stays circular. Rounded growth close
to zero now tapers continuously to preserve a sharp zero-radius limit.

Bevels use world-space line intersections, fixing asymmetric conversion drift.
Automatic inverse boundaries share the shape vertex as their reference center.
For equal side distances at a convex vertex, a circular scoop's outer radius
is `r-outside` and its inner radius is `r+inside`. Surviving arcs are concentric
and have uniform radial spacing. Elliptical scoops use normal offsets rather
than translated or resized ellipses. Unequal distances interpolate between the
adjacent sides over the source angular parameter. Contacts are trimmed or use
straight tangent joins; no auxiliary rounded joins are added. Exhausted arcs
become sharp joins and filled interiors can still empty or split.

An explicit inner/outer inverse corner keeps its authored dimensions and its
center at that boundary's side intersection. It never supplies the origin of
the other automatic boundary. To retain the earlier fixed-size shifted-scoop
appearance, set both `innerCorners` and `outerCorners` explicitly.

`zeroBorder` continues to be the legacy outer-derived boundary. Its conversion
now uses corrected formulas, so it does not preserve erroneous 1.x coordinates.
Use `shapeBorder` whenever the intended boundary is the source shape.

## Advanced corner API

The descriptor's old `convert`, `pointAt`, `appendArc`, and side-consumption
methods have been replaced by resolved geometry:

```dart
final contour = decoration.buildContour(size, TextDirection.ltr);
final corner = contour.shapeCorners.first; // AnyResolvedCorner
final contact = corner.previousExtent;     // Physical ray consumption.
final midpoint = corner.pointAt(0.5);        // Evaluates canonical segments.
final tangent = corner.tangentAt(0.5);
final path = Path();
corner.appendTo(path, from: 0, to: 0.371, moveTo: true);
corner.appendTo(path, from: 0.371, to: 1);    // Same curve, exact subdivision.
```

`shapeCorners`, `outerCorners`, `innerCorners`, and `zeroCorners` now contain
immutable `AnyResolvedCorner` instances. Use `corner.source` for the normalized
source descriptor and `corner.parameters` only when one descriptor represents
the resolved curve. Automatic offset scoops have null parameters because their
center/trim/joins cannot be represented by a descriptor at the shifted vertex.
Their `center` reports the source reference center, and `circleRadius` reports
the circular arc radius when applicable (zero after exhaustion).
Use `contour.pathFor(base)` for the final filled area; concatenating local
corner paths does not perform collapse cleanup.

A custom `AnyCorner` selects its required `AnyCornerGeometry` provider through
`geometry`. Implement `resolve(corner, frame)` and `buildBoundary(...)` on the
provider; keep descriptor resolution conveniences nonvirtual. See the
[provider migration](#custom-corner-providers). Distances are positive toward material and
negative outward. Frames contain unit rays and material-facing unit normals,
with winding and convexity tracked separately. Construct `AnyResolvedCorner`
with an ordered list of `AnyCornerSegment` lines/cubics spanning parameter
interval `[0, 1]`. Adjacent segments must meet; the constructor copies the list
and rejects invalid intervals or non-finite control points. `split` and
`appendTo` preserve the original cubic through de Casteljau subdivision.

Source normalization uses actual contacts, resolves infinity before geometry,
and scales both dimensions of an affected corner together. Derived curves are
trimmed rather than rescaled to fit. Numerical subdivision exhaustion raises a
diagnostic error instead of returning earlier geometry. See [GEOMETRY.md](GEOMETRY.md)
for detailed policies, the supported input contract, and the independent test map.
