

import 'dart:ui';

import 'package:flutter/foundation.dart';


class PathDebugger implements Path {

  final String name;
  final Path path;

  const PathDebugger(
    this.name,
    this.path
  );

  static Path unwrap(Path path) {
    return path is PathDebugger ? path.path : path;
  }

  void _log(String message) {
    debugPrint(message);
  }

  PathDebugger _wrap(String suffix, Path path) => PathDebugger('$name.$suffix', path);

  @override
  PathFillType get fillType => path.fillType;

  @override
  set fillType(PathFillType value) {
    _log('$name.fillType = $value;');
    path.fillType = value;
  }

  @override
  void moveTo(double x, double y) {
    _log('$name.moveTo($x, $y);');
    path.moveTo(x, y);
  }

  @override
  void lineTo(double x, double y) {
    _log('$name.lineTo($x, $y);');
    path.lineTo(x, y);
  }

  @override
  void relativeMoveTo(double dx, double dy) {
    _log('$name.relativeMoveTo($dx, $dy);');
    path.relativeMoveTo(dx, dy);
  }

  @override
  void relativeLineTo(double dx, double dy) {
    _log('$name.relativeLineTo($dx, $dy);');
    path.relativeLineTo(dx, dy);
  }

  @override
  void quadraticBezierTo(double x1, double y1, double x2, double y2) {
    _log('$name.quadraticBezierTo($x1, $y1, $x2, $y2);');
    path.quadraticBezierTo(x1, y1, x2, y2);
  }

  @override
  void relativeQuadraticBezierTo(double x1, double y1, double x2, double y2) {
    _log('$name.relativeQuadraticBezierTo($x1, $y1, $x2, $y2);');
    path.relativeQuadraticBezierTo(x1, y1, x2, y2);
  }

  @override
  void conicTo(double x1, double y1, double x2, double y2, double w) {
    _log('$name.conicTo($x1, $y1, $x2, $y2, $w);');
    path.conicTo(x1, y1, x2, y2, w);
  }

  @override
  void relativeConicTo(double x1, double y1, double x2, double y2, double w) {
    _log('$name.relativeConicTo($x1, $y1, $x2, $y2, $w);');
    path.relativeConicTo(x1, y1, x2, y2, w);
  }

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    _log('$name.cubicTo($x1, $y1, $x2, $y2, $x3, $y3);');
    path.cubicTo(x1, y1, x2, y2, x3, y3);
  }

  @override
  void relativeCubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    _log('$name.relativeCubicTo($x1, $y1, $x2, $y2, $x3, $y3);');
    path.relativeCubicTo(x1, y1, x2, y2, x3, y3);
  }

  @override
  void arcTo(Rect rect, double startAngle, double sweepAngle, bool forceMoveTo) {
    _log('$name.arcTo($rect, $startAngle, $sweepAngle, $forceMoveTo);');
    path.arcTo(rect, startAngle, sweepAngle, forceMoveTo);
  }

  @override
  void arcToPoint(
    Offset arcEnd, {
    Radius radius = Radius.zero,
    double rotation = 0.0,
    bool largeArc = false,
    bool clockwise = true,
  }) {
    _log('$name.arcToPoint($arcEnd, radius: $radius, rotation: $rotation, largeArc: $largeArc, clockwise: $clockwise);');
    path.arcToPoint(
      arcEnd,
      radius: radius,
      rotation: rotation,
      largeArc: largeArc,
      clockwise: clockwise,
    );
  }

  @override
  void addRect(Rect rect) {
    _log('$name.addRect($rect);');
    path.addRect(rect);
  }

  @override
  void addRRect(RRect rrect) {
    _log('$name.addRRect($rrect);');
    path.addRRect(rrect);
  }

  @override
  void addOval(Rect oval) {
    _log('$name.addOval($oval);');
    path.addOval(oval);
  }

  @override
  void addArc(Rect oval, double startAngle, double sweepAngle) {
    _log('$name.addArc($oval, $startAngle, $sweepAngle);');
    path.addArc(oval, startAngle, sweepAngle);
  }

  @override
  void addPolygon(List<Offset> points, bool close) {
    _log('$name.addPolygon(${points.length} points, $close);');
    path.addPolygon(points, close);
  }

  @override
  void addPath(Path path, Offset offset, {Float64List? matrix4}) {
    _log('$name.addPath($path, $offset, matrix4: ${matrix4 != null ? "Float64List(${matrix4.length})" : "null"});');
    this.path.addPath(path, offset, matrix4: matrix4);
  }

  @override
  void extendWithPath(Path path, Offset offset, {Float64List? matrix4}) {
    _log('$name.extendWithPath($path, $offset, matrix4: ${matrix4 != null ? "Float64List(${matrix4.length})" : "null"});');
    this.path.extendWithPath(path, offset, matrix4: matrix4);
  }

  @override
  void close() {
    _log('$name.close();');
    path.close();
  }

  @override
  void reset() {
    _log('$name.reset();');
    path.reset();
  }

  @override
  bool contains(Offset point) {
    final result = path.contains(point);
    _log('$name.contains($point) -> $result;');
    return result;
  }

  @override
  Rect getBounds() {
    final result = path.getBounds();
    _log('$name.getBounds() -> $result;');
    return result;
  }

  @override
  Path shift(Offset offset) {
    _log('$name.shift($offset);');
    return _wrap('shift', path.shift(offset));
  }

  @override
  Path transform(Float64List matrix4) {
    _log('$name.transform(Float64List(${matrix4.length}));');
    return _wrap('transform', path.transform(matrix4));
  }

  @override
  PathMetrics computeMetrics({bool forceClosed = false}) {
    _log('$name.computeMetrics(forceClosed: $forceClosed);');
    return path.computeMetrics(forceClosed: forceClosed);
  }

  @override
  String toString() => 'PathDebugger($name, path: $path)';

  @override
  void addRSuperellipse(RSuperellipse rsuperellipse) {
    _log('$name.addRSuperellipse(RSuperellipse($rsuperellipse));');
    return path.addRSuperellipse(rsuperellipse);
  }

  @override
  void relativeArcToPoint(Offset arcEndDelta, {Radius radius = Radius.zero, double rotation = 0.0, bool largeArc = false, bool clockwise = true}) {
    _log('$name.relativeArcToPoint(Offset($arcEndDelta), radius=$radius, rotation=$rotation, largeArc=$largeArc, clockwise=$clockwise);');
    return path.relativeArcToPoint(arcEndDelta, radius: radius, rotation: rotation, largeArc: largeArc, clockwise: clockwise);
  }
}