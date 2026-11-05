import 'dart:ui';
import 'dart:math' as math;

import 'any_contour.dart';

part 'src/profiles/bounded_zigzag.dart';

/// Where a profile lies relative to the original box edge.
enum AnyEdgePlacement {
  inset,
  outset,

  /// Alternates equally on both sides; depth is the full peak-to-trough distance.
  center,
}

/// Immutable geometry inserted between the endpoints of a box edge.
///
/// Implementations return interior vertices in traversal order. Local x is the
/// distance along the edge (0 to the supplied length); local y is the
/// distance inward. Do not include the edge endpoints: the box owns those
/// corners. Forward the supplied side, including its current offset metadata.
/// Corner settings belong to the returned points, independently of box corners.
///
/// Builders must be deterministic. Implement value equality and hashing so
/// decoration caching can distinguish configurations. Keeping point count and
/// order stable allows the existing decoration tween to interpolate geometry.
abstract class AnyEdgeProfile {
  const AnyEdgeProfile();

  List<AnyPoint> buildPoints(double length, AnySide side);
}

/// An explicit straight edge, also used to override inherited profiles.
/// Unlike null in a profile fallback, this stops inheritance.
class AnyStraightProfile extends AnyEdgeProfile {
  const AnyStraightProfile();

  @override
  List<AnyPoint> buildPoints(double length, AnySide side) => const [];

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Shared configuration and validation for the built-in repeating profiles.
abstract class _RepeatedProfile extends AnyEdgeProfile {
  /// Number of repeats, or alternating lobes for a centered zigzag.
  /// Must be positive.
  final int count;

  /// Nonnegative finite depth in logical units, not clamped to the box size.
  /// Centered profiles use half this distance on each side before rounding.
  final double depth;

  final AnyEdgePlacement placement;

  /// Straight space before/after the repeated section, in logical units.
  /// Null chooses the profile's automatic spacing. Centered zigzags reserve
  /// half a full wave at each automatic end; other profiles use zero.
  /// If these consume the edge, it stays straight.
  final double? startClearance;
  final double? endClearance;

  /// Source corners for generated vertices only.
  final AnyCorner corners;

  /// Null derives the boundary from [corners], not from box corner overrides.
  final AnyCorner? outerCorners;
  final AnyCorner? innerCorners;

  const _RepeatedProfile({
    required this.count,
    required this.depth,
    this.placement = AnyEdgePlacement.inset,
    this.startClearance = 0,
    this.endClearance = 0,
    this.corners = const RoundedCorner(),
    this.outerCorners,
    this.innerCorners,
  });

  double _span(double length) {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'Must be positive');
    }
    for (final entry in {
      'length': length,
      'depth': depth,
      'startClearance': startClearance,
      'endClearance': endClearance,
    }.entries) {
      final value = entry.value;
      if (value != null && (!value.isFinite || value < 0)) {
        throw ArgumentError.value(
            entry.value, entry.key, 'Must be finite and nonnegative');
      }
    }
    return length - (startClearance ?? 0) - (endClearance ?? 0);
  }

  double get _displacement =>
      placement == AnyEdgePlacement.inset ? depth : -depth;

  AnyPoint _point(double x, double y, AnySide side) => AnyPoint(
        point: Offset(x, y),
        side: side,
        shape: corners,
        outer: outerCorners,
        inner: innerCorners,
      );

  @override
  bool operator ==(Object other) =>
      other is _RepeatedProfile &&
      other.runtimeType == runtimeType &&
      other.count == count &&
      other.depth == depth &&
      other.placement == placement &&
      other.startClearance == startClearance &&
      other.endClearance == endClearance &&
      other.corners == corners &&
      other.outerCorners == outerCorners &&
      other.innerCorners == innerCorners;

  @override
  int get hashCode => Object.hash(runtimeType, count, depth, placement,
      startClearance, endClearance, corners, outerCorners, innerCorners);
}

/// Repeated rectangular indentations (or protrusions).
///
/// Each repeat spends half its length at [depth] and half on the original edge,
/// with a quarter-repeat of straight edge at each end of the repeated section.
/// [RoundedCorner.infinity] rounds both convex and concave turns as far as they
/// fit; unequal segment lengths can still leave straight portions.
/// Centered placement alternates half-depth levels and reserves a quarter-repeat
/// straight lead at each end so the box corners retain their edge directions.
/// Zero depth or exhausted clearance produces a straight edge.
class AnyStepsProfile extends _RepeatedProfile {
  const AnyStepsProfile({
    required super.count,
    required super.depth,
    super.placement,
    super.startClearance,
    super.endClearance,
    super.corners,
    super.outerCorners,
    super.innerCorners,
  });

  @override
  List<AnyPoint> buildPoints(double length, AnySide side) {
    final span = _span(length);
    if (span <= 0 || depth == 0) return const [];
    final startClearance = this.startClearance ?? 0;
    final pitch = span / count;
    if (placement == AnyEdgePlacement.center) {
      final centeredPitch = span / (count + .5);
      final start = startClearance + centeredPitch / 4;
      return [
        _point(start, 0, side),
        for (var i = 0; i < count; i++) ...[
          _point(start + i * centeredPitch, -depth / 2, side),
          _point(start + (i + .5) * centeredPitch, -depth / 2, side),
          _point(start + (i + .5) * centeredPitch, depth / 2, side),
          _point(start + (i + 1) * centeredPitch, depth / 2, side),
        ],
        _point(start + count * centeredPitch, 0, side),
      ];
    }
    return [
      for (var i = 0; i < count; i++) ...[
        _point(startClearance + (i + .25) * pitch, 0, side),
        _point(startClearance + (i + .25) * pitch, _displacement, side),
        _point(startClearance + (i + .75) * pitch, _displacement, side),
        _point(startClearance + (i + .75) * pitch, 0, side),
      ],
    ];
  }
}

/// Repeated triangular teeth between the original edge and [depth].
///
/// For inset/outset placement, each peak is halfway through its repeat.
/// Clearance adds straight lead-in
/// and lead-out segments. Zero depth or exhausted clearance is straight.
/// For centered placement, count is the number of alternating lobes, including
/// odd counts. [firstInside] selects the first lobe's direction. Odd counts end
/// in that same direction; even counts end in the opposite direction.
/// Null clearances reserve half a full wave (one lobe's width) at each end.
/// Infinite rounded corners use a common maximum radius that fits the entry,
/// lobes and exit, rather than fitting each peak independently. Finite corners
/// and other corner types retain the ordinary contour fitting policy.
class AnyZigZagProfile extends _RepeatedProfile {
  /// Fit fully rounded inset/outset repeats to the edge and authored depth.
  /// Requires [RoundedCorner.infinity] with the default converter. Crests touch the edge, troughs reach
  /// depth, and the repeat endpoints have tangents parallel to the edge.
  /// Deep repeats are stretched vertically to keep the curve from folding back.
  /// Centered placement already has its own symmetric fitting policy.
  final bool fitToBounds;

  /// Direction of the first centered lobe, in clockwise edge traversal order.
  /// Has no effect on inset/outset profiles, whose placement sets the direction.
  final bool firstInside;

  const AnyZigZagProfile({
    required super.count,
    required super.depth,
    super.placement,
    double? startClearance,
    double? endClearance,
    this.firstInside = true,
    this.fitToBounds = false,
    super.corners,
    super.outerCorners,
    super.innerCorners,
  }) : super(startClearance: startClearance, endClearance: endClearance);

  @override
  bool operator ==(Object other) =>
      other is AnyZigZagProfile &&
      firstInside == other.firstInside &&
      fitToBounds == other.fitToBounds &&
      super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, firstInside, fitToBounds);

  AnyCorner? _fitInfinite(
          AnyCorner? corner, double pitch, double start, double end) =>
      corner is RoundedCorner &&
              corner.runtimeType == RoundedCorner &&
              corner.p == double.infinity &&
              corner.n == double.infinity
          ? _ZigZagRoundedCorner(
              pitch: pitch,
              signedDepth: firstInside ? depth : -depth,
              start: start,
              end: end,
              converter: corner.converter)
          : corner;

  @override
  List<AnyPoint> buildPoints(double length, AnySide side) {
    final span = _span(length);
    if (fitToBounds &&
        (placement == AnyEdgePlacement.center ||
            corners.runtimeType != RoundedCorner ||
            (corners as RoundedCorner).converter != CornerConverter.base ||
            corners.p != double.infinity ||
            corners.n != double.infinity)) {
      throw ArgumentError(
          'fitToBounds requires RoundedCorner.infinity() with the default converter '
          'and inset or outset placement.');
    }
    if (span <= 0 || depth == 0) return const [];
    if (fitToBounds) {
      final pitch = span / count;
      final shape =
          _FittedZigZagCorner(p: pitch / 2, n: pitch / 2, depth: _displacement);
      return [
        for (var i = 0; i < count; i++)
          AnyPoint(
              point: Offset((startClearance ?? 0) + (i + .5) * pitch, 0),
              side: side,
              shape: shape,
              outer: outerCorners,
              inner: innerCorners),
      ];
    }
    if (placement == AnyEdgePlacement.center) {
      // Each automatic end reserves one lobe width (half a full wave).
      final automaticEnds =
          (startClearance == null ? 1 : 0) + (endClearance == null ? 1 : 0);
      final pitch = span / (count + automaticEnds);
      final start = startClearance ?? pitch;
      final end = endClearance ?? pitch;
      final shape = _fitInfinite(corners, pitch, start, end)!;
      final outer = _fitInfinite(outerCorners, pitch, start, end);
      final inner = _fitInfinite(innerCorners, pitch, start, end);
      AnyPoint centeredPoint(double x, double y) => AnyPoint(
            point: Offset(x, y),
            side: side,
            shape: shape,
            outer: outer,
            inner: inner,
          );
      final sign = firstInside ? 1.0 : -1.0;
      return [
        if (start > 0) centeredPoint(start, 0),
        for (var i = 0; i < count; i++)
          centeredPoint(
              start + (i + .5) * pitch, (i.isEven ? sign : -sign) * depth / 2),
        if (end > 0) centeredPoint(length - end, 0),
      ];
    }
    final pitch = span / count;
    final start = startClearance ?? 0;
    final end = endClearance ?? 0;
    return [
      if (start > 0) _point(start, 0, side),
      for (var i = 0; i < count; i++) ...[
        _point(start + (i + .5) * pitch, _displacement, side),
        if (i < count - 1) _point(start + (i + 1) * pitch, 0, side),
      ],
      if (end > 0) _point(length - end, 0, side),
    ];
  }
}

// Keep the layout recipe with an automatic corner. Interpolating just its fitted
// radius is incorrect: the maximum is nonlinear in depth and would make the end
// peaks shrink independently midway through a depth animation.
class _ZigZagRoundedCorner extends AnyCorner {
  final double pitch, signedDepth, start, end;
  final CornerConverter converter;

  _ZigZagRoundedCorner(
      {required this.pitch,
      required this.signedDepth,
      required this.start,
      required this.end,
      required this.converter,
      double? p,
      double? n})
      : super(
            p: p ?? _radius(pitch, signedDepth.abs(), start, end),
            n: n ?? _radius(pitch, signedDepth.abs(), start, end));

  static double _radius(double pitch, double depth, double start, double end) {
    if (depth == 0 || pitch == 0) return 0;
    final slope = depth / pitch;
    final diagonal = Offset(pitch, depth).distance;
    final entryContact = depth / (diagonal + pitch);
    // The peak and entry turn have circular contact scales tan(theta) and
    // tan(theta/2). Together they must fit on the half-length entry diagonal.
    var radius = (diagonal / 2) / (slope + entryContact);
    for (final clearance in [start, end]) {
      if (clearance > 0 && radius * entryContact > clearance) {
        radius = clearance / entryContact;
      }
    }
    return radius;
  }

  @override
  AnyCornerGeometry get geometry => const _ZigZagRoundedGeometry();

  // Type-changing corner transitions intentionally shrink the actual fitted
  // curve. Such a scaled curve is no longer an automatic-radius recipe.
  @override
  AnyCorner operator *(double factor) => RoundedCorner.elliptical(
      p: p * factor, n: n * factor, converter: converter);

  @override
  AnyCorner copyWith({double? p, double? n}) => _ZigZagRoundedCorner(
      pitch: pitch,
      signedDepth: signedDepth,
      start: start,
      end: end,
      converter: converter,
      p: p ?? this.p,
      n: n ?? this.n);

  @override
  AnyCorner lerpTo(covariant _ZigZagRoundedCorner other, double t) =>
      _ZigZagRoundedCorner(
        pitch: lerpDouble(pitch, other.pitch, t)!,
        signedDepth: lerpDouble(signedDepth, other.signedDepth, t)!,
        start: lerpDouble(start, other.start, t)!,
        end: lerpDouble(end, other.end, t)!,
        converter: t < .5 ? converter : other.converter,
      );

  @override
  bool operator ==(Object other) =>
      other is _ZigZagRoundedCorner &&
      pitch == other.pitch &&
      signedDepth == other.signedDepth &&
      start == other.start &&
      end == other.end &&
      converter == other.converter &&
      p == other.p &&
      n == other.n;

  @override
  int get hashCode =>
      Object.hash(pitch, signedDepth, start, end, converter, p, n);
}

class _ZigZagRoundedGeometry extends RoundedCornerGeometry {
  const _ZigZagRoundedGeometry();

  @override
  AnyResolvedCorner resolve(AnyCorner settings, AnyCornerFrame frame) {
    final corner = settings as _ZigZagRoundedCorner;
    final rounded = super.resolve(
        RoundedCorner.elliptical(
            p: corner.p, n: corner.n, converter: corner.converter),
        frame);
    return resolved(corner, frame, rounded.segments,
        parameters: rounded.parameters,
        center: rounded.center,
        circleRadius: rounded.circleRadius,
        tolerance: rounded.tolerance);
  }
}
