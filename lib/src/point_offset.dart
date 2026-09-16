import 'dart:ui';

import 'geometry/core.dart';
import 'geometry/math.dart';

// Construction-stage line offsets. No corner provider or resolved curve is
// involved: the original descriptors will be fitted to these new vertices.
List<AnyPoint> offsetContourPoints(List<AnyPoint> points, double offset) {
  if (!offset.isFinite) {
    throw ArgumentError.value(offset, 'offset', 'Must be finite');
  }
  if (offset == 0 || points.isEmpty) return points;
  final active = points.where((p) => !p.skip).toList(growable: false);
  if (active.isEmpty) return points;
  final count = active.length;
  if (count < 3) throw ArgumentError('At least 3 active points are required.');
  final directions = <Offset>[];
  var area = 0.0;
  final origin = active.first.point;
  for (var i = 0; i < count; i++) {
    final a = active[i].point, b = active[(i + 1) % count].point;
    final delta = b - a, length = delta.distance;
    if (!length.isFinite || length <= 1e-12) {
      throw ArgumentError('Offset outlines require finite, nonzero edges.');
    }
    directions.add(delta / length);
    area += geometryCross(a - origin, b - origin);
  }
  if (!area.isFinite || area.abs() < 1e-12) {
    throw ArgumentError(
        'An offset outline must enclose a finite nonzero area.');
  }
  final winding = area.sign;
  final normals = [for (final d in directions) geometryLeft(d) * winding];
  final moved = <Offset>[];
  var convex = true;
  for (var i = 0; i < count; i++) {
    final previous = (i - 1) % count;
    final frame = AnyCornerFrame(
        vertex: active[i].point,
        previousRay: -directions[previous],
        nextRay: directions[i],
        previousNormal: normals[previous],
        nextNormal: normals[i],
        winding: winding);
    if (frame.backtracking) {
      throw ArgumentError(
          'Reversing helpers need shape-specific point offsets.');
    }
    convex = convex && frame.convexity >= 0;
    final vertex = frame.shiftedVertex(-offset, -offset);
    if (!vertex.dx.isFinite || !vertex.dy.isFinite) {
      throw ArgumentError('Offset vertex exceeds finite coordinates.');
    }
    moved.add(vertex);
  }
  for (var i = 0; i < count; i++) {
    if (geometryDot(moved[(i + 1) % count] - moved[i], directions[i]) <=
        1e-12) {
      if (convex && offset < 0 && _exhausted(active, normals, offset)) {
        return const [];
      }
      throw ArgumentError(
          'Offset removes an edge; implement this topology in buildPoints.');
    }
  }
  var index = 0;
  return [
    for (final p in points)
      if (p.skip)
        p
      else
        AnyPoint(
            point: moved[index++],
            shape: p.shape,
            inner: p.inner,
            outer: p.outer,
            side: p.side),
  ];
}

// Only consulted after a convex inset loses a directed edge. This prevents a
// fully exhausted outline from reappearing as an inverted polygon.
bool _exhausted(List<AnyPoint> points, List<Offset> normals, double offset) {
  var polygon = points.map((p) => p.point).toList();
  for (var i = 0; i < points.length && polygon.isNotEmpty; i++) {
    double distance(Offset p) =>
        geometryDot(p - points[i].point, normals[i]) + offset;
    final clipped = <Offset>[];
    for (var j = 0; j < polygon.length; j++) {
      final a = polygon[j], b = polygon[(j + 1) % polygon.length];
      final da = distance(a), db = distance(b);
      if (da >= 0) clipped.add(a);
      if ((da >= 0) != (db >= 0)) {
        clipped.add(a + (b - a) * (da / (da - db)));
      }
    }
    polygon = clipped;
  }
  if (polygon.length < 3) return true;
  var area = 0.0;
  final origin = polygon.first;
  for (var i = 0; i < polygon.length; i++) {
    area += geometryCross(
        polygon[i] - origin, polygon[(i + 1) % polygon.length] - origin);
  }
  return area.abs() <= 1e-12;
}
