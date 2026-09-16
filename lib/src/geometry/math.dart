import 'dart:math' as math;
import 'dart:ui';

double geometryDot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
double geometryCross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
Offset geometryUnit(Offset a) => a.distance == 0 ? Offset.zero : a / a.distance;
Offset geometryLeft(Offset a) => Offset(-a.dy, a.dx);
double geometryAngle(Offset a, Offset b) =>
    math.atan2(geometryCross(a, b), geometryDot(a, b));
const double geometryAngleTolerance = 1e-10;

Offset geometryLineMeeting(
    Offset a, Offset u, Offset b, Offset v, Offset fallback) {
  final det = geometryCross(u, v);
  if (det.abs() <= geometryAngleTolerance * u.distance * v.distance)
    return fallback;
  return a + u * (geometryCross(b - a, v) / det);
}

(double, double, Offset)? geometryIntersection(
    Offset a, Offset b, Offset c, Offset d) {
  final ab = b - a, cd = d - c, det = geometryCross(ab, cd);
  if (det.abs() < 1e-12) return null;
  final t = geometryCross(c - a, cd) / det, u = geometryCross(c - a, ab) / det;
  if (t <= 1e-8 || t >= 1 - 1e-8 || u <= 1e-8 || u >= 1 - 1e-8) return null;
  return (t, u, a + ab * t);
}
