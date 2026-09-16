# Custom corner geometry

Every `AnyCorner` selects an `AnyCornerGeometry` through its `geometry` getter.
The three built-ins use this same public contract. The engine has no imports,
casts, or registration table for concrete corners.

Import `package:any_borders/any_borders.dart` (or the existing
`package:any_borders/any_contour.dart`). Both export the contracts, curve types,
and built-in corner/provider pairs.

## Start with a descriptor and provider

See the complete, tested [NotchCorner example](example/lib/custom_corner.dart).
It extends `AnyCorner` directly and draws two straight segments with a bend
between its edge contacts. Its provider opts into the existing generic contour
checks; no engine changes are necessary. The example also mixes with all three
built-in corner types in [the provider tests](test/corner_provider_test.dart).

```dart
class MyCorner extends AnyCorner {
  // Keep your constructors, copyWith, lerpTo, equality and hashCode here.
  @override
  AnyCornerGeometry get geometry => const MyCornerGeometry();
}

class MyCornerGeometry extends AnyCornerGeometry {
  const MyCornerGeometry();

  @override
  AnyResolvedCorner resolve(AnyCorner corner, AnyCornerFrame frame) {
    // Return canonical lines/cubics for this normalized descriptor and frame.
    // AnyResolvedCorner(...) validates arbitrary segments and defaults to
    // conservative eligibility. See the complete example for construction.
    throw UnimplementedError();
  }

  @override
  AnyResolvedCorner buildBoundary(AnyResolvedCorner source,
      AnyCorner parameters, AnyCornerFrame shifted,
      double previousDistance, double nextDistance) {
    // Implement your boundary policy using the original source and distances.
    throw UnimplementedError();
  }
}
```

This abbreviated sketch shows the extension points, not a complete class.
The linked example implements every required member without placeholders.

## Sizing and normalization

The fixed allocator treats `p` and `n` as nonnegative dimensions whose contact
lengths are `p * contactScale` and `n * contactScale`. `contactScale(corner, frame)`
defaults to 1; rounded corners return the cotangent of the half-angle. It must
be finite and positive for nonparallel frames and remain compatible with
proportional scaling. This API retains linear contact allocation; it does not
solve arbitrary nonlinear sizing constraints.

`retainsSingleZeroExtent` defaults to false: if either component is zero, the
source consumes no edge space. Bevels override it to true. Use
`resolveDegenerate(corner, frame)` for the matching finite-dimension, parallel,
and zero-component source handling, or implement your own compatible handling.

The engine resolves positive infinity against edge budgets, scales both
components proportionally, and applies the existing common source reduction
when nonadjacent corners cross. Keep zero a valid sharp limit. Preserve extra
shape fields in `copyWith` and `lerpTo`, and override `operator *` if they also
need scaling. Descriptor equality/hashCode must include every setting that
changes geometry or provider selection. The same requirement applies to
custom decoration fields because the shared cache uses decoration equality.

## Source and boundary construction

Return ordered, finite line/cubic segments covering `[0, 1]` without gaps.
Adjacent endpoints must agree within the existing tolerance. The engine uses
exact subdivision of these canonical segments for side ownership; do not
independently fit or pack each side's half.

`AnyResolvedCorner(...)` validates segment input. The protected `resolved(...)`
builder uses the same trusted path as the built-ins. It memoizes the source
provider's `traitsFor` on first use, so unused intermediate curves are not
classified. The result's source must retain the descriptor that owns its policy.
Use it only when the provider already guarantees valid canonical segments.
`directArc(...)` and `fitCurve(...)` expose the existing fixed numerical helpers
through `AnyCornerCurve` callbacks. `frame.affine(...)` and `affineStretch(...)`
expose the shared ray-basis transform and conservative stretch bound.

The standard `resolveBoundary` implementation keeps zero-distance identity and
parallel-frame transitions, then calls `buildBoundary`. Signed distances are
positive inward. `source` retains original source identity; `parameters` is
the descriptor representing the derived curve when such a descriptor exists.
The shifted frame has already been calculated. Implement your policy in
`buildBoundary`; override the public provider method only if your geometry
needs different early-return handling.

Explicit inner/outer descriptors resolve independently at their shifted frames.
They are never normalized against each other to force nesting.

By default `resolveZeroBoundary` reconstructs the outer descriptor and applies
the return distances, preserving legacy `zeroBorder` semantics. If that would
lose important information, store immutable provider-owned data in
`geometryState` and override `resolveZeroBoundary`. The inverse-rounded provider
does this to retain the original reference curve and accumulated offsets. The
engine never examines the state's concrete type.

## Optional local guarantees

`AnyCornerTraits.none` is the default. A custom curve still renders through the
general region assembler. Omitting guarantees is a correctness-preserving choice.

| Field | Promise and remaining engine checks |
| --- | --- |
| `directCandidate` | The canonical corner is suitable for the existing ordinary-band model: ordered contacts on incident rays, compatible directed traversal and parameter ownership. The engine still checks directed spans, loops/intersections, nesting and source-to-boundary strips as needed. |
| `rectangularBand` | Stronger promise: in a convex right-angle frame this corner stays in its allocated corner region with simple traversal, and the provider's automatic boundary policies preserve nesting and nonoverlapping source strips whenever the directed spans survive. The engine may skip curve-pair searches for that rectangle. Explicit authored rings still require their existing partition certification. |
| `sharpSource` | The original source is a sharp vertex and its automatic inward policy supports the existing exhausted sharp-rectangle rule. This describes the source, not merely a collapsed derived curve. |

Set only guarantees proved for the actual result and boundary policy. Local
guarantees never establish a complete side partition by themselves. Keep
`rectangularBand` false unless the stronger rectangle conditions are established;
the NotchCorner example needs only `directCandidate`.

The protected `traitsFor(source, parameters, radius)` is convenient when a
provider's construction establishes the same conditions for all its results.
For result-dependent conditions, pass explicit traits to the validating
`AnyResolvedCorner` constructor. Rebuilding arbitrary geometry through that
constructor does not copy traits automatically.

Built-in providers preserve their existing exact-type eligibility guards.
Inheriting a built-in descriptor/provider does not automatically opt a custom
descriptor into built-in shortcuts. `isRectangularDescriptor` is consulted by
providers to assemble their local traits; the engine never calls it.

## What remains shared

Frames, edge allocation, source-crossing correction, interpolation coordination,
curve mathematics, whole-contour certification, region assembly and painting
remain fixed. There is no optimizer registry, configurable rule pipeline, or
per-decoration performance setting. Geometry providers can be shared `const`
instances; store per-resolution state on the immutable result, not the provider.

## Migrating a custom corner

1. Move the body of the descriptor's `resolve` override into
   `MyCornerGeometry.resolve(corner, frame)` and refer to the supplied descriptor.
2. Move boundary policy into `buildBoundary`, or override the provider's
   `resolveBoundary` if its early-return behavior must also be specialized.
3. Return the provider from `MyCorner.geometry` and remove descriptor resolution
   overrides. `AnyCorner.resolve` and `resolveBoundary` are now nonvirtual
   forwarding conveniences; the engine dispatches through the provider.
4. Preserve copying/scaling/interpolation and equality semantics. Start with
   conservative traits, then test any explicit opt-in against general assembly.

No legacy override adapter is provided. Existing uses of built-in corner
constructors and direct calls to their resolution conveniences remain valid.
