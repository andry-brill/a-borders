## 2.0.0 (unreleased)

### New

- Add a NotchCorner example to the gallery's Custom section, animating its
  two-segment corner into a straight bevel through the custom `bend` setting.
- Lazy, reusable animation preparation owned by `AnyDecorationTween`. Retain one
  point context per layer and reuse fixed frames, normalized source settings,
  and unchanged source curves. Prepare requested explicit/automatic boundary
  transitions through provider parameter shortcuts or matched canonical cubics.
- Optional `AnyCornerGeometry.prepareTransition` and `AnyCornerTransition`
  contracts let custom providers specialize interpolation without engine edits.
- Add finite `double offset = 0.0` to decorations and borders, including box and
  tab constructors. Negative values inset and positive values outset; each
  layer passes `decoration.offset + border.offset` to `buildPoints`. Builders
  displace outline vertices before corner normalization and resolution, keeping
  configured corner profiles. Border widths apply to the displaced source;
  primary-layer effects follow its paths. Include offsets in interpolation,
  equality, and cache identity. Add `offsetPoints` for polygon edge construction.
  Cover fixed corner radii, independent layers, empty insets, custom builders
  and providers, and native/CanvasKit pixels at DPR 1/2/3.
- Independent source, inner, and outer corner roles. `AnyPoint.shape` defines
  the source; optional boundary overrides derive independently when omitted.
  `outerCorners` and per-corner `outer*` box settings support authored outer
  boundaries.
- `AnyShapeBase.shapeBorder` selects the directly resolved source for
  backgrounds, clipping, and shadows.
- Const `.multi(borders: ..., primaryBorderIndex: ...)` constructors for base,
  box, and tab decorations. Borders paint in order, each with its own geometry
  and ratio; the primary layer supplies decoration-level paths.
- `buildContours` exposes all layers. Layer-aware interpolation handles
  independent ratios and inserted/removed borders.
- Public `AnyCornerGeometry` providers, selected by the required
  `AnyCorner.geometry` getter. Built-ins pair with `RoundedCornerGeometry`,
  `BevelCornerGeometry`, and `InverseRoundedCornerGeometry`. Custom providers
  can supply canonical geometry, immutable continuation state, and optional
  local optimization guarantees through the same contract.
- Immutable `AnyResolvedCorner` and canonical `AnyCornerSegment` lines/cubics
  expose contacts, parameter intervals, points, tangents, and exact subdivision.
- Support for empty and disconnected automatic interiors, with disjoint painted
  side ownership.
- A corner inspector, a complete public-API custom-corner example, analytic
  and generated fixtures, topology/animation regressions, DPR 1/2/3 raster
  coverage, architecture checks, and standalone native/browser benchmarks.
  Current usage and extension contracts are documented in the
  [README](README.md).

### Changed

- Remove the midpoint jump when compatible inner/outer corner overrides appear
  or disappear. The first “No horizontal” outer corner now moves from `p/n`
  radii 30/30 to 20/30 continuously. Zero boundaries retain independently prepared endpoint
  semantics; incompatible filled-area topology keeps the existing fallback.
- Refresh gallery characterization for the current 18 examples and update the
  animation widget test to use an existing row. Against the captured baseline,
  only the three “No horizontal” animation records change; the other 128 records
  retain identical geometry, ownership, and deterministic work counts. No raster
  golden files change.
- Record five interleaved warmed native runs with identical SDK, dependencies,
  and indexed gallery inputs. Persistent-gallery median CPU geometry time is
  4.228 ms before and 4.234 ms after preparation, within timing variation.
  Reusable cases improve; the changing-aspect-ratio Images case adds 0.012 ms.
  Fresh five-sample tweens add 8.2% in the short gallery benchmark. Visible
  CanvasKit animation remains approximately 60 displayed frames/second; callback
  timings overlap across three runs. Pass 234 Flutter tests, analysis, and
  CanvasKit coverage including 58,812 transition pixel checks at DPR 1/2/3.
  Publish raw runs, spreads, and separate visible Chrome measurements in the
  [benchmark record](test/benchmarks/prepared_transition_results.json).
- **Source semantics:** `AnyBorder.corners` and unprefixed box corner fields
  describe the source shape instead of the outer boundary. Background, clip,
  and shadow selectors default to `shapeBorder`; outer-derived `zeroBorder`
  remains independently selectable.
- **Geometry API:** named signed distances and resolved geometry replace
  positional conversion and descriptor-level path methods. Point builders
  receive a border index; caches store ordered contour lists. Descriptor
  `resolve`/`resolveBoundary` methods are nonvirtual forwarding conveniences.
- **Rounded geometry:** circular fillets are circular at arbitrary angles and
  invariant under winding reversal. Source normalization uses physical contacts
  and proportional scaling. Corrected radius/side pairing and tapered growth
  preserve the sharp zero-radius limit; `dynamicRatio` remains the default.
- **Bevel and scoop boundaries:** bevels use world-space displaced-line
  intersections. Automatic inverse boundaries retain the source reference
  center, with concentric circular offsets and source-normal elliptical offsets.
  Curves trim against sides or use sharp tangent joins; explicit scoops keep
  their authored centers.
- **Topology and ownership:** automatic area is retained through direct
  construction or swept-region unions/differences. Side partitions connect
  outer/inner split points directly, independently of shape corners when both
  boundaries are authored. Crossing authored boundaries retain XOR semantics;
  distant overlapping sweeps retain first-side ownership.
- **Helper vertices:** collinear/backtracking helpers retain both shifted
  contacts, including the closing tab edge. Authored straight-vertex boundaries
  use an averaged shifted anchor. Mixed-corner, background, and crown examples
  explicitly author boundaries to preserve their intended designs.
- **Construction performance:** ordinary arcs use direct analytic cubic
  construction; certified rings and side polygons avoid general region work.
  Numerical scoop offsets and general handling remain for folds, crossings,
  and split interiors. Canonical subdivision, tolerances, lazy resolution,
  contour-local sample reuse, and shared-cache policy are preserved.
- **Provider isolation:** moved family-specific sizing, construction, boundary
  policy, and eligibility into the corresponding provider. Core geometry has
  no concrete-corner dependencies. Exact characterization covers canonical
  control points, intervals, route choices, ownership, and diagnostic counts.
  This relocation leaves painter code and golden images unchanged.
- **Painting:** accumulate antialiased source-over coverage within each border,
  including opaque fills. Four distinct image-free solid/gradient sides use
  one temporary layer instead of five. Image/custom fills retain grouped
  composition; separate border layers blend normally. Preserve CanvasKit
  boolean-result holes, and dispose shared image painters with their painter.
- **Animation and examples:** resolve only requested boundary bands and visible
  regions; intermediate tween contours bypass the shared LRU cache. Gallery
  rows build on demand and restore their selected endpoint when recreated.
  Asynchronous golden tests reliably surface comparison failures.

#### Measurements and validation

The following are separate comparisons within v2 development, not a single
v1-to-v2 benchmark. Both native comparisons used Windows Flutter tests with
Flutter 3.47.3 (`e8113bf456`), engine `06a2e2a110`, and Dart 3.13.3.
Values are milliseconds, reported as median (minimum–maximum) over five
warmed runs per version, summed across each workload.

**Direct-construction optimization — 2026-09-15**

| Native workload | Before | After | Median reduction |
| --- | ---: | ---: | ---: |
| Seven ordinary fixtures | 7.056 (6.894–8.391) | 0.998 (0.953–1.071) | 85.9% |
| Four fallback fixtures | 9.967 (9.511–12.209) | 8.911 (8.671–9.347) | 10.6% |
| Full 22-example gallery | 21.305 (20.337–22.841) | 8.971 (8.670–10.502) | 57.9% |

Each run warmed twice; isolated fixtures averaged 30 fresh constructions and
gallery entries averaged five tween positions. Ordinary and full-gallery
ranges do not overlap. No fallback fixture showed a consistent regression;
split-neck timings remained within noise.

| Chrome metric, ms | Before median (spread) | After median (spread) |
| --- | ---: | ---: |
| Per-run median animation callback | 20.099 (19.632–21.511) | 8.084 (8.003–8.659) |
| Per-run p95 animation callback | 23.793 (23.671–29.145) | 11.716 (9.898–13.509) |
| GPU-process command handling / presentation | 0.850 (0.820–0.946) | 0.837 (0.835–0.910) |
| Compositor paint submission / presentation | 0.159 (0.155–0.170) | 0.170 (0.166–0.178) |

Animation callbacks include geometry, widget/layout work, and paint submission;
their median fell 59.8%. Rendering-command costs remained similar within the
observed spread. Full per-run data and indexed gallery results are in
[direct_construction_results.json](test/benchmarks/direct_construction_results.json).

**Provider relocation — 2026-09-16**

Baseline and provider runs were interleaved, reversing pair order on alternate
runs, with identical benchmark sources and dependencies.

| Native workload | Before | Provider implementation |
| --- | ---: | ---: |
| Ordinary, original short warm-up | 1.030 (0.945–1.145) | 1.134 (1.018–1.194) |
| Fallback, original short warm-up | 10.066 (8.614–10.664) | 8.807 (8.611–9.176) |
| Full gallery, original short warm-up | 8.986 (8.425–9.699) | 9.192 (9.059–9.764) |
| Ordinary, settled JIT | 0.585 (0.555–0.622) | 0.603 (0.570–0.607) |
| Fallback, settled JIT | 7.070 (6.835–7.878) | 7.131 (6.924–9.837) |
| Full gallery, settled JIT | 5.458 (4.987–6.594) | 5.821 (5.168–5.983) |

The original two-pass warm-up protocol's ordinary median increased **10.1%**;
identical short-warm-up timing is not claimed. Moving hot functions changed
warm-up sensitivity. An initial eager-traits implementation also classified
temporary curves; final traits are evaluated and memoized only when requested.

The optional settled protocol applies equally to both versions: 1,000 complete
fixture warm-up cycles, 300 samples per fixture, and 100 complete gallery
warm-up cycles before the original three reported passes. Settled medians are
slightly higher, within overlapping spreads. These runs establish neither a
speedup nor a slowdown beyond that variation; timing cannot prove zero overhead.
A separate 10,000-cycle sampled VM investigation measured 0.647 ms before and
0.642 ms after, retained as diagnostic evidence rather than an acceptance run.

| Chrome metric, ms | Before median (spread) | Provider median (spread) |
| --- | ---: | ---: |
| Per-run median animation callback | 6.586 (6.153–6.602) | 6.283 (6.075–6.369) |
| Per-run p95 animation callback | 8.898 (7.393–9.341) | 7.706 (7.582–7.813) |
| GPU-process command handling / presentation | 0.706 (0.635–0.761) | 0.710 (0.686–0.730) |
| Compositor paint submission / presentation | 0.120 (0.113–0.181) | 0.114 (0.113–0.118) |

Browser ranges overlap and show no sustained rendering regression. The final
suite passed **199 Flutter tests**, a clean analyzer, and **90 border-hole checks
plus 254,400 multi-fill coverage checks** on CanvasKit at DPR 1/2/3. Canonical
geometry, ownership signatures, and deterministic work counts are unchanged.
Final and explicitly labeled initial diagnostic runs are retained in
[provider_refactor_results.json](test/benchmarks/provider_refactor_results.json).

Both Chrome comparisons used CanvasKit profile builds and Chrome 152.0.7977.83,
with a 1087×727 CSS viewport at DPR 1.25. Six visible gallery animations (indices
0, 2, 3, 4, 6, 11) used 200×120 logical bounds and repeating two-second
forward/reverse animation. Each version had three eight-second captures after
eight seconds of warm-up; inactive captures were rejected. GPU-process durations
measure CPU command processing, not hardware GPU execution. Native geometry
timings are not frame-rate estimates. See [benchmark commands](README.md#validation-and-benchmarks)
for reproduction.

#### Reviewed raster changes

The direct-construction optimization changed six individually inspected golden
files without relaxing existing tolerances:

- `corner_geometry_1x/2x/3x.png`: 165/286/389 edge pixels
  (0.06%/0.03%/0.02%), localized to rounded and bevel triangles; maximum channel
  deltas 39/22/43. Direct outlines bypass PathOps normalization/tessellation,
  changing edge coverage while boundary probes agree within 0.001 logical units.
- `reported_examples_1x/2x/3x.png`: 11/13/25 pixels, maximum channel deltas
  3/2/4, in rounded examples. Scoop, crown, tab, split-interior, and multiple-border
  visuals were unchanged.

The new varying-alpha gradient painter comparison permits at most two channel
levels because removing an intermediate 8-bit surface removes a rounding step.
Existing numerical and raster tolerances were unchanged. The subsequent
provider relocation required **no golden changes**.

CanvasKit's measured DPR-3 diagonal seam deficit occurs with both grouped and
optimized painting (for example, alpha 111 versus ideal 128); it was not fixed
by these changes. Browser checks compare complete premultiplied images and
independent interior alpha; native seam checks retain their six-level tolerance.

### Migration

Path offsets default to zero. Custom decoration constructors can expose
`super.offset`; custom builders must accept the fourth positional `double offset`
and apply it to their outline points. It is already the decoration-plus-border
sum. Do not pass it to corner providers as a boundary distance.

#### 1. Separate source settings from boundary overrides

In 1.x, `corners` and `topLeft`/`topRight`/`bottomRight`/`bottomLeft` described
outer corners. In 2.0 they describe the source shape, which stays independent
of widths, alignment, and boundary overrides.

| Role | Default setting | Box override example | `AnyPoint` field |
| --- | --- | --- | --- |
| Source shape | `corners` | `topLeft` | required `shape` |
| Outer boundary | `outerCorners` | `outerTopLeft` | optional `outer` |
| Inner boundary | `innerCorners` | `innerTopLeft` | optional `inner` |

To preserve an authored 1.x outer corner, move its setting to `outerCorners`
or the corresponding `outer*` field and choose the source corner separately.
For exact appearance, also author the old inner corner when necessary.
Shape-to-boundary derivation can differ from outer-to-inner conversion,
especially for asymmetric bevels and normalized corners; no universal radius
rename preserves every configuration.

```dart
const AnyBoxBorder(
  corners: RoundedCorner(radius: 20),
  sides: AnySide(width: 4, align: AnySide.alignOutside),
  outerTopLeft: BevelCorner(radius: 26),
)
```

Here the automatic inner radius is 20 and the other outer radii are 24, assuming
enough space to avoid normalization. The outer bevel affects neither source nor
inner corners. Explicit boundaries may cross; they are not resized to enforce
containment.

Direct point construction must supply `shape`:

```dart
const AnyPoint(
  point: Offset(0, 0),
  shape: RoundedCorner(radius: 20),
  side: AnySide(width: 4),
)
```

Side fields (`left`, `top`, `right`, `bottom`, `horizontal`, `vertical`) keep their
roles. Box `circle` and `pill` presets supply infinite rounded source corners.
Tab offsets derive from each layer's bottom source corners.

#### 2. Choose effect paths explicitly where needed

`AnyBackground.shapeBase`, `AnyDecoration.clipBase`, and
`AnyDecoration.shadowBase` now default to `AnyShapeBase.shapeBorder`.
Select `zeroBorder` explicitly to request the outer-derived return path:

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

This selects the old boundary role, not erroneous 1.x coordinates or old
automatic inner conversion. `outerBorder` and `innerBorder` select their
respective resolved areas. Use `shapeBorder` when the intended path is the
source shape.

#### 3. Update custom point builders and cache access

Add the third positional `borderIndex` and fourth positional `double offset`
to `buildPoints`. Pass the index to every `point(...)` call and apply the offset
once, while constructing the outline:

```dart
@override
List<AnyPoint> buildPoints(
    Rect bounds, TextDirection? textDirection, int borderIndex,
    double offset) => offsetPoints([
  point(bounds.topCenter, borderIndex: borderIndex),
  point(bounds.centerRight, borderIndex: borderIndex),
  point(bounds.bottomCenter, borderIndex: borderIndex),
  point(bounds.centerLeft, borderIndex: borderIndex),
], offset);
```

Read `borders[borderIndex]` for per-layer settings rather than the primary
`border` getter. Explicit point values take precedence over border defaults;
omitted boundary values remain nullable until resolution. The
[custom-decoration example](README.md#custom-decorations) includes single and
multi constructors.

- `points(bounds, direction, borderIndex: i)` selects a point list; omitting
  the index selects the primary layer. The caller supplies its bounds.
- `buildContours(size, direction)` fits and returns all contours in paint order.
- `buildContour(size, direction)` returns the primary contour.
- `AnyDecorationCache.get/put` exchange `List<AnyContour>`. Stored collections
  are read-only; LRU limit and clear behavior remain.
- Include new custom settings in equality/hashCode. Equality includes ordered
  layers, primary selection, and all corner fields.

#### 4. Account for independent layers and interpolation

Single-border constructors remain available. To use `.multi`, supply a nonempty,
immutable border list and an in-range primary index. Empty lists are invalid;
use a zero-width border for a background-only decoration. Negative primary
indices have constructor assertions; emptiness and the upper bound are validated
before point/contour construction so constructors can remain const.

Layers overlap rather than automatically stacking beside one another. For four
visible blue pixels plus two white pixels, paint widths six and two in that
order. All background/clip/shadow selectors use the primary layer; effects paint
once, and changing primary selection does not combine silhouettes or reorder
borders.

Tweens pair layers by index, with no layer identifiers. Inserted/removed layers
animate their widths from/to zero while retaining endpoint shape/fill settings.
Ratios interpolate per layer; primary selection switches at the midpoint.
Exact endpoints are returned at zero and one; intermediate contours bypass
the shared cache. Point-count mismatches, nullable boundary overrides, and
different-corner shrink/switch/grow transitions retain midpoint behavior.
Reordering border lists changes interpolation pairing.

#### 5. Review corrected corner geometry

Rounded radii now describe true circular fillets at non-right angles, with
contacts `r * cot(θ/2)`. Elliptical rounded corners scale that unit fillet in the
two-ray basis. Bevel and inverse source contacts remain `p`/`n` ray distances;
right-angle source definitions retain their previous meaning.

For designs authored with 1.x perpendicular dimensions, the crown example uses
`oldDimension / sin(θ)` for bevel ray contacts and
`oldDimension / (1 + cos(θ))` for rounded fillet settings to retain contact
positions. Rounded curves still use the corrected circular construction.
The “Any corner”, “Back+T+B”, and crown examples explicitly author both
boundaries to retain their designs.

Rounded conversion pairs `p` with the next side and `n` with the previous side.
Unequal widths can produce elliptical boundaries around a circular source, and
growth near zero tapers continuously. Asymmetric bevel conversion uses corrected
world-space line intersections.

Automatic scoops share the source reference center; elliptical boundaries use
normal offsets, with trimming, tangent joins, and collapse. To retain fixed-size
scoops centered at shifted boundary intersections, author both `innerCorners`
and `outerCorners` explicitly. The detailed current policies are in
[Geometry](README.md#geometry).

#### 6. Replace descriptor-level geometry calls

The old descriptor `convert`, `pointAt`, `appendArc`, and side-consumption
methods are replaced by resolved geometry:

| Earlier operation | Current API |
| --- | --- |
| Convert with positional distances | `corner.geometry.resolveBoundary(source, previousDistance: ..., nextDistance: ...)` |
| Evaluate a descriptor's curve | `AnyResolvedCorner.pointAt` / `tangentAt` |
| Append a descriptor arc | `AnyResolvedCorner.appendTo` with parameter range |
| Read consumed edge lengths | `previousExtent` / `nextExtent` on the resolved corner |
| Read a contour's corner collections | `shapeCorners` / `outerCorners` / `innerCorners` / `zeroCorners` contain `AnyResolvedCorner` |
| Assemble the final filled boundary | `contour.pathFor(base)` |

Signed distances are positive inward. `source` identifies the normalized source;
nullable `parameters` represents a derived curve only when a descriptor can
describe it. Automatic offset scoops need center/trim/join state and have null
parameters. Their `center` identifies the reference center; `circleRadius` is
the circular radius when applicable, zero after exhaustion.

Use canonical line/cubic segments spanning `[0, 1]` with finite, connected
control points. Exact subdivision preserves the curve across side pieces.
Source dimensions normalize proportionally, including infinity; derived curves
trim rather than rescale to fit. Numerical exhaustion raises a diagnostic error.
See [geometry inspection](README.md#inspecting-geometry) for a complete usage
snippet.

#### 7. Move custom construction into providers

Every custom `AnyCorner` must return an `AnyCornerGeometry` from `geometry`:

1. Move descriptor `resolve` logic into `MyCornerGeometry.resolve(corner, frame)`.
2. Move boundary construction into the protected `buildBoundary` hook. Override
   provider `resolveBoundary` only if shared zero-distance or parallel-frame
   early returns also need a custom policy.
3. Remove descriptor resolution overrides; `AnyCorner.resolve` and
   `resolveBoundary` are nonvirtual forwarding conveniences. The engine
   dispatches through the selected provider, with no legacy override adapter.
4. Implement the linear sizing contract, preserve custom fields during copying,
   scaling, and interpolation, and include them in equality/hashCode.
5. Use immutable `geometryState` and `resolveZeroBoundary` when descriptor
   reconstruction would lose continuation information. Start with conservative
   traits and test explicit shortcut guarantees against general assembly.

Built-in constructors and package imports remain valid. See
[Custom corners](README.md#custom-corners) for the full provider contract and
the [tested NotchCorner example](example/lib/custom_corner.dart).

## 1.1.2

* Added `offsetOutward` to `AnyTabDecoration` to choose between outward and inward tab offsets.

## 1.1.1

* Added `AnyTabDecoration` extras decoration.
* Added skipped contour points so decorations can keep stable point lists while avoiding collapsed zero-length sides.
* Updated README with extras import guidance and a simpler custom decoration example.

## 1.1.0

* Migrated `AnyDecoration` to use a single `AnyBorder`.
* Migrated `AnyBoxDecoration` to configure sides, corners, ratio, and shape through `AnyBoxBorder`.
* Updated examples and documentation for the new border API
* Refactored cache

## 1.0.1

* Updated README.md

## 1.0.0

* Initial release
