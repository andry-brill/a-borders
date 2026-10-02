## 2.1.0

- Added signed `AnySide.offset`, defaulting to `0.0`, with copying, equality,
  hashing, and interpolation. Selected side offsets add to decoration and
  border offsets; positive values outset and negative values inset the outline.
- Box and tab builders support independent side displacements before corner
  construction. Existing whole-side fallback rules are preserved, and outline
  collapse is checked after all offset contributions are combined.
- Tweens interpolate side offsets before endpoint point construction, preserving
  the geometric collapse threshold and endpoint offsets on added/removed layers.
  Preparation includes the current side-offset context and reuses unchanged values.
- Added `AnyBorder.resolvedSides` as the standard ordered side list, with box
  fallback resolution shared by box and tab builders. `sideOffsetsForBorder`
  derives offsets centrally and can be overridden for custom construction layouts.
- **Breaking:** consolidated ordinary and animated point construction into
  `buildPoints(bounds, textDirection, border, offset, sideOffsets)`.
  The third argument is the selected `AnyBorder`; the fifth `List<double>`
  argument is required. `point` and `sideOffsetsForBorder` also accept the
  border directly. There are no compatibility aliases or dispatch paths for
  the previous builder signature.
- Migrated built-in shapes and the crown example to the single builder contract.
  Custom decorations remain responsible for their displacement geometry.

### Custom-decoration migration from 2.0.0

Replace the third `int borderIndex` argument with `AnyBorder border` and add the
required fifth positional `List<double> sideOffsets` argument to every
`buildPoints` override. Forward all five arguments when calling `super.buildPoints`.
Use `point(..., border: border)` and read per-layer settings directly from the
supplied border. Box/tab overrides can use `covariant AnyBoxBorder border`.
`points(..., borderIndex: i)` still selects a layer by index; tween matching and
preparation retain indices internally, including for repeated equal borders.
Each endpoint builder receives its original border object during animation.
Use the supplied current side-offset slots when constructing vertices, rather
than reading authored side offsets again. Add each slot to the supplied scalar
offset before corner fitting and collapse checks; carry that slot in the returned
point's `AnySide.offset`.

`AnyBorder.resolvedSides` provides one shared-side slot. `AnyBoxBorder` resolves
top, right, bottom, left slots for both boxes and tabs. Custom borders can
override `resolvedSides`; decorations with different construction layouts can
override `sideOffsetsForBorder`. Matching slot layouts interpolate before either
endpoint builder runs. Unequal layouts keep their endpoint offsets through the
same builder contract and retain normal point-topology interpolation.

See the updated [custom decoration example](README.md#custom-decorations).

## 2.0.0

Internally, geometry construction, painting, and animation preparation have been
reworked, with corner-specific behavior separated from the shared engine.

### New

- Finite `offset` values on decorations and borders, defaulting to `0.0`.
  Negative values inset the path and positive values outset it. Each layer uses
  the sum of its decoration and border offsets, preserving configured corner
  profiles. Offsets support interpolation.
- Independent source, inner, and outer corners. `AnyPoint.shape` defines the
  source; `outerCorners` and per-corner `outer*` box settings allow explicit
  outer boundaries alongside the existing inner overrides.
- `AnyShapeBase.shapeBorder` selects the source path for backgrounds, clipping,
  and shadows.
- Const `.multi(borders: ..., primaryBorderIndex: ...)` constructors on
  `AnyDecoration`, `AnyBoxDecoration`, and `AnyTabDecoration`. Borders paint in
  order with independent settings; the primary border supplies effect paths.
- `buildContours` returns all border layers. Layer-aware interpolation supports
  independent ratios and added or removed borders.
- Public `AnyCornerGeometry` providers for custom corner construction, with
  built-in `RoundedCornerGeometry`, `BevelCornerGeometry`, and
  `InverseRoundedCornerGeometry` implementations.
- `AnyResolvedCorner` and `AnyCornerSegment` expose resolved line/cubic geometry,
  contacts, points, tangents, and subdivision.
- Optional `AnyCornerGeometry.prepareTransition` and `AnyCornerTransition`
  contracts let custom providers specialize interpolation.

### Changed

- `AnyBorder.corners` and unprefixed box corner fields now describe the source
  shape instead of the outer boundary. Direct `AnyPoint` construction requires
  `shape`.
- Background, clipping, and shadow selectors now default to
  `AnyShapeBase.shapeBorder`. `zeroBorder` remains available explicitly.
- `AnyCorner.geometry` is required. Custom construction belongs in a geometry
  provider, accessed through `corner.geometry`.
- Resolved geometry and named signed boundary distances replace descriptor-level
  path methods and positional conversion calls.
- `buildPoints` receives a border index and the combined path offset. Point
  helpers accept a border index; `AnyDecorationCache.get/put` exchange ordered
  contour lists instead of a single contour.
- Removed unused corner and utility conveniences; ratio fitting, contour
  bookkeeping, and resolved interpolation helpers are internal.

### Migration

#### 1. Separate source settings from boundary overrides

In 1.x, `corners` and `topLeft`/`topRight`/`bottomRight`/`bottomLeft` described
outer corners. In 2.0 they describe the source shape, independently of border
widths, alignment, and boundary overrides.

| Role | Default setting | Box override example | `AnyPoint` field |
| --- | --- | --- | --- |
| Source shape | `corners` | `topLeft` | required `shape` |
| Outer boundary | `outerCorners` | `outerTopLeft` | optional `outer` |
| Inner boundary | `innerCorners` | `innerTopLeft` | optional `inner` |

Move authored outer settings to `outerCorners` or the corresponding `outer*`
field and choose source settings separately. If exact boundary dimensions are
required, specify both inner and outer overrides.

```dart
const AnyBoxBorder(
  corners: RoundedCorner(radius: 20),
  sides: AnySide(width: 4, align: AnySide.alignOutside),
  outerTopLeft: BevelCorner(radius: 26),
)
```

Direct point construction must supply `shape`:

```dart
const AnyPoint(
  point: Offset(0, 0),
  shape: RoundedCorner(radius: 20),
  side: AnySide(width: 4),
)
```

#### 2. Choose effect paths explicitly where needed

`AnyBackground.shapeBase`, `AnyDecoration.clipBase`, and
`AnyDecoration.shadowBase` now default to `AnyShapeBase.shapeBorder`.
Select `zeroBorder` explicitly for an outer-derived return path, or
`outerBorder` / `innerBorder` for the corresponding boundary.

```dart
const AnyBoxDecoration(
  border: AnyBoxBorder(outerCorners: RoundedCorner(radius: 24)),
  background: AnyBackground(
    color: Color(0xFF85AEA8),
    shapeBase: AnyShapeBase.zeroBorder,
  ),
  clipBase: AnyShapeBase.zeroBorder,
  shadowBase: AnyShapeBase.zeroBorder,
)
```

#### 3. Update custom point builders and cache access

Add the third positional `borderIndex` and fourth positional `double offset`
to `buildPoints`. Pass the index to every `point(...)` call. The offset already
contains `decoration.offset + border.offset`; apply it once to outline points,
not as a corner boundary distance. Custom constructors can expose `super.offset`.
If a custom shape does not support offsets, reject a nonzero value explicitly:

```dart
@override
List<AnyPoint> buildPoints(
    Rect bounds, TextDirection? textDirection, int borderIndex,
    double offset) {
  if (offset != 0) {
    throw UnsupportedError('This decoration does not support path offsets.');
  }
  return [
    point(bounds.topCenter, borderIndex: borderIndex),
    point(bounds.centerRight, borderIndex: borderIndex),
    point(bounds.bottomCenter, borderIndex: borderIndex),
    point(bounds.centerLeft, borderIndex: borderIndex),
  ];
}
```

- Read `borders[borderIndex]` for per-layer settings; the `border` getter selects
  the primary border.
- Use `points(bounds, direction, borderIndex: i)` to select a layer's points.
  Omitting the index selects the primary layer.
- Use `buildContours(size, direction)` for all contours in paint order;
  `buildContour(size, direction)` returns the primary contour.
- Update direct `AnyDecorationCache.get/put` calls to use `List<AnyContour>`.
  Stored lists are read-only.
- Preserve custom settings in copying, interpolation, equality, and `hashCode`.

See [Custom decorations](README.md#custom-decorations) for the full contract.

#### 4. Account for independent layers and interpolation

Single-border constructors remain available. For `.multi`, supply a nonempty,
immutable border list and a valid `primaryBorderIndex`. Use a zero-width border
for a background-only decoration.

Layers overlap in paint order. Backgrounds, clipping, and shadows use the
primary layer; changing the primary index does not reorder borders or combine
their outlines.

Tweens pair borders by index, so reordering the list changes interpolation
pairing. Added or removed borders animate their widths from or to zero.
Ratios interpolate per layer; primary selection switches at the midpoint.

#### 5. Replace descriptor-level geometry calls

| Earlier operation | Current API |
| --- | --- |
| Resolve a corner descriptor | `corner.geometry.resolve(corner, frame)` |
| Convert with positional distances | `corner.geometry.resolveBoundary(source, previousDistance: ..., nextDistance: ...)` |
| Evaluate a descriptor's curve | `AnyResolvedCorner.pointAt` / `tangentAt` |
| Append a descriptor arc | `AnyResolvedCorner.appendTo` with parameter range |
| Create a path for one resolved corner | Create a `Path`, then call `corner.appendTo(path, moveTo: true)` |
| Read consumed edge lengths | `previousExtent` / `nextExtent` on the resolved corner |
| Read a contour's corner collections | `shapeCorners` / `outerCorners` / `innerCorners` / `zeroCorners` contain `AnyResolvedCorner` |
| Assemble the final filled boundary | `contour.pathFor(base)` |

Boundary distances are positive inward, unlike public path offsets, which are
positive outward. See [Geometry inspection](README.md#inspecting-geometry) for
resolved-geometry usage.

`AnyCorner.isCircular` and the public `any_utils.dart` library are removed.
Use the concrete corner's contract when interpreting its dimensions. Internal
ratio fitting, contour indexing, and interpolation helpers are not extension
points; use the decoration, contour, and provider APIs above.

#### 6. Move custom construction into providers

Every custom `AnyCorner` must return an `AnyCornerGeometry` from `geometry`:

1. Move descriptor `resolve` logic into `MyCornerGeometry.resolve(corner, frame)`.
2. Move boundary construction into the provider's protected `buildBoundary` hook.
3. Remove descriptor resolution overrides and call the provider directly:
   `corner.geometry.resolve(corner, frame)` and
   `corner.geometry.resolveBoundary(source, ...)`.
4. Implement the provider's sizing contract. Preserve custom descriptor fields
   during copying, scaling, interpolation, and equality comparisons.
5. If boundary continuation needs custom state, use immutable `geometryState`
   and implement `resolveZeroBoundary`. Keep eligibility traits conservative
   unless the custom geometry meets their guarantees.

Built-in constructors and the main package entrypoints remain valid. See
[Custom corners](README.md#custom-corners) for provider responsibilities and
extension guidance.

## 1.1.2

* Added `offsetOutward` to `AnyTabDecoration` to choose between outward and inward tab offsets.

## 1.1.1

* Added `AnyTabDecoration` extras decoration.
* Added skipped contour points so decorations can keep stable point lists while avoiding collapsed zero-length sides.

## 1.1.0

* Migrated `AnyDecoration` to use a single `AnyBorder`.
* Migrated `AnyBoxDecoration` to configure sides, corners, ratio, and shape through `AnyBoxBorder`.
* Refactored cache

## 1.0.1

* Updated README.md

## 1.0.0

* Initial release
