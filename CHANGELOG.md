
## 2.0.0 (unreleased)

* **Breaking for custom corners:** require `AnyCorner.geometry`. Move custom
  resolution overrides into `AnyCornerGeometry`; descriptor resolution methods
  are nonvirtual conveniences. Add stateless `RoundedCornerGeometry`,
  `BevelCornerGeometry`, and `InverseRoundedCornerGeometry`, with the same public
  extension contract available to custom implementations. See [CUSTOM_CORNERS.md](CUSTOM_CORNERS.md).
* Isolate the generic geometry engine from concrete corner dependencies. Retain
  the existing formulas, direct/general routes, canonical segments, tolerances,
  lazy resolution, caches and painter. Add exact characterization signatures,
  dependency checks and an independent custom-provider example. No golden changes.
* Validate the provider relocation with 199 Flutter tests, a clean analyzer,
  and CanvasKit DPR 1/2/3 checks. Settled native and Chrome timings stay within
  overlapping observed spreads. The original short-warm-up ordinary median
  rises 10.1%; preserve both protocols and all raw comparisons in
  [GEOMETRY.md](GEOMETRY.md#provider-relocation-measurements-2026-09-16).

* Restore direct analytic cubic construction for ordinary arcs and certified
  direct rings/side polygons, retaining numerical scoop offsets and general
  topology handling for folds, crossings and split interiors. Preserve all v2
  APIs, boundary policies, canonical subdivision, lazy resolution and cache behavior.
* Reduce four distinct solid/gradient side fills from five temporary layers to
  one shared coverage layer. Keep image/custom fill groups and normal composition
  between border layers, including existing CanvasKit rasterization behavior.
* Add scoped work diagnostics, forced-general comparisons, mixed-geometry
  regressions, DPR 1/2/3 painter comparisons and standalone CanvasKit checks.
  Five warmed native runs reduce median ordinary geometry work by 85.9% and
  the full gallery by 57.9%; fallback fixtures show no consistent regression.
  See [GEOMETRY.md](GEOMETRY.md) for measurements, route selection and the six
  individually reviewed edge-pixel golden changes from that earlier optimization.
  The direct-construction optimization itself requires no migration; custom
  corner providers introduced above require the documented extension migration.
* **Breaking:** `AnyPoint.shape` is required. Inner and outer corners are now
  optional and derive independently from the resolved shape corner.
* **Breaking:** `AnyBorder.corners` and the unprefixed box corner fields describe
  the shape. Added `outerCorners` and per-corner `outer*` overrides.
* Added `AnyShapeBase.shapeBorder` as the default for backgrounds, clips, and
  shadows. The legacy outer-derived `zeroBorder` remains separately selectable.
* Added const `.multi(borders: ..., primaryBorderIndex: ...)` constructors for
  base, box, and tab decorations. Later layers paint over earlier layers; the
  primary layer supplies decoration-level paths.
* **Breaking:** custom point builders receive a border index, and `point(...)`
  requires that index. Added `buildContours`; the cache now stores ordered
  contour collections. `buildContour` returns the primary contour.
* Added layer-aware interpolation, including width transitions for inserted and
  removed layers, and per-layer ratio fitting.
* Corrected rounded radius/side pairing and asymmetric bevel line intersections.
  `dynamicRatio` remains the default; rounded growth tapers continuously to zero.
* Made circular fillets truly circular at arbitrary angles and fixed winding
  invariance. Normalize source corners proportionally using physical contacts.
* Automatic inverse boundaries share the shape's center. Uniform circular
  offsets are concentric; elliptical boundaries follow source normals.
  Trim side intersections and use sharp tangent joins without auxiliary round
  arcs. Explicit inner/outer scoops retain their own side-intersection centers.
* Preserve both offset contacts at collinear/backtracking helper vertices,
  including the closing bottom edge of tabs.
* Preserve automatic boundary area through certified direct construction and
  general swept-region unions/differences, allowing empty or split interiors.
  Preserve disjoint painted side ownership.
* **Breaking:** corner descriptors now resolve to immutable `AnyResolvedCorner`
  instances; named signed distances replace the positional conversion contract.
* Connect painted side partitions directly between outer/inner corner splits;
  explicit boundary fills no longer kink through or depend on the shape corner.
* Distinguish authored straight-vertex anchors from reversing tab helpers.
  Migrated the mixed-corner, background, and crown showcases to explicit inner
  and outer corners, with numeric and DPR 1/2/3 rendering regressions.
* Combine antialiased coverage for distinct source-over side fills within each
  layer, preventing the native translucent source-over seam; see the documented
  CanvasKit DPR-3 rasterization limitation.
* Unified corner curve subdivision across full paths and side regions, and
  dispose shared image painters when their decoration painter is disposed.
* Added independent analytic fixtures, 1,000 seeded generated cases, topology
  and animation regressions, DPR 1/2/3 raster tests, and a corner inspector.
* Reduced animation work with lazy boundary bands, local curve-sample reuse,
  bounded curve intersection checks, uniform-fill and non-collapsed box fast
  paths. Tween contours remain outside the shared LRU cache.
* Build example rows on demand and preserve their selected endpoint when they
  return onscreen. Added intermediate-frame and geometry-work regressions, plus
  an explicitly runnable geometry benchmark.
* Preserve boolean-result holes on CanvasKit so borders do not cover solid,
  gradient, or image backgrounds and shadow interiors. Surface golden comparison
  failures reliably in plain asynchronous image tests.

See [MIGRATION.md](MIGRATION.md) for the 1.x upgrade guide.

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
