import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract class IAnyFill {
  Color? get color;
  Gradient? get gradient;
  DecorationImage? get image;
  BlendMode? get blendMode;
  bool get isAntiAlias;
  bool isSameAs(IAnyFill other);
}

mixin MAnyFill implements IAnyFill {
  @override
  bool isSameAs(IAnyFill? other) {
    if (other == null) return false;
    return color == other.color &&
        gradient == other.gradient &&
        image == other.image &&
        blendMode == other.blendMode &&
        isAntiAlias == other.isAntiAlias;
  }
}

extension EAnyFill on IAnyFill {
  bool get hasFill => color != null || gradient != null || image != null;
  bool get hasBaseFill => color != null || gradient != null;
}

const double _epsilon = 1.0e-6;
const double _startAngle = math.pi;
const double _midAngle = math.pi * 1.25;
const double _endAngle = math.pi * 1.5;
const double _quarterSweep = math.pi * 0.5;

bool _nearZero(double value, [double epsilon = _epsilon]) =>
    value.abs() <= epsilon;

double _clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

double _lerpDouble(double a, double b, double t) => a + ((b - a) * t);

T? _pickLerpObject<T>(T? a, T? b, double t) {
  if (a == b) return a;
  return t < 0.5 ? a : b;
}

bool _pickLerpBool(bool a, bool b, double t) {
  if (a == b) return a;
  return t < 0.5 ? a : b;
}

AnyCorner _resolveFiniteCorner(AnyCorner corner, double maxRx, double maxRy) {
  final rawX = corner.radius.x;
  final rawY = corner.radius.y;

  final rx = rawX.isFinite ? math.max(0.0, rawX) : math.max(0.0, maxRx);
  final ry = rawY.isFinite ? math.max(0.0, rawY) : math.max(0.0, maxRy);

  return AnyCorner(Radius.elliptical(rx, ry));
}

Rect _fitRectToRatio(Rect rect, double? ratio) {
  if (ratio == null || ratio <= 0.0) {
    return rect;
  }

  var width = rect.width;
  var height = width / ratio;

  if (height > rect.height) {
    height = rect.height;
    width = height * ratio;
  }

  return Rect.fromLTWH(
    rect.left + (rect.width - width) / 2.0,
    rect.top + (rect.height - height) / 2.0,
    width,
    height,
  );
}

/// NB! No negative values support.
///
/// For rounded corners the implementation uses cubic Bézier segments.
/// If the geometric corner angle is greater than 90°, the rounded corner is
/// split into several Bézier segments.
class AnyCorner {
  final Radius radius;

  const AnyCorner([this.radius = Radius.zero]);

  @override
  bool operator ==(Object other) {
    return other is AnyCorner && other.radius == radius;
  }

  @override
  int get hashCode => radius.hashCode;
}

class AnySide with MAnyFill {
  static const double alignInside = -1;
  static const double alignCenter = 0;
  static const double alignOutside = 1;

  static double alignBase = alignInside;

  final double width;
  final double? _align;

  /// Align means align relative to the corresponding side, not the whole shape.
  double get align => _align ?? alignBase;

  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;
  @override
  final bool isAntiAlias;

  const AnySide({
    this.width = 0.0,
    double? align,
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.isAntiAlias = true,
  })  : _align = align,
        assert(width >= 0.0),
        assert(align == null || (align >= -1.0 && align <= 1.0));

  AnySide copyWith({
    double? width,
    double? align,
    Color? color,
    Gradient? gradient,
    DecorationImage? image,
    BlendMode? blendMode,
    bool? isAntiAlias,
  }) {
    return AnySide(
      width: width ?? this.width,
      align: align ?? this.align,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      image: image ?? this.image,
      blendMode: blendMode ?? this.blendMode,
      isAntiAlias: isAntiAlias ?? this.isAntiAlias,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AnySide &&
        other.width == width &&
        other.align == align &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.isAntiAlias == isAntiAlias;
  }

  @override
  int get hashCode => Object.hash(
    width,
    align,
    color,
    gradient,
    image,
    blendMode,
    isAntiAlias,
  );
}

class AnyBackground extends AnySide {
  final AnyShapeBase shapeBase;

  const AnyBackground({
    super.color,
    super.gradient,
    super.image,
    super.blendMode,
    super.isAntiAlias,
    this.shapeBase = AnyShapeBase.zeroBorder,
  }) : super(width: double.infinity, align: AnySide.alignCenter);

  @override
  bool operator ==(Object other) {
    return other is AnyBackground &&
        super == other &&
        other.shapeBase == shapeBase;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, shapeBase);
}

class AnyPoint {
  final AnyCorner outer;
  final AnyCorner inner;

  final Offset point;
  final AnySide side;

  const AnyPoint({
    required this.outer,
    AnyCorner? inner,
    required this.point,
    required this.side,
  }) : inner = inner ?? outer;

  static List<AnyPoint>? lerp(List<AnyPoint>? a, List<AnyPoint>? b, double t) {
    if (a == null || b == null) return null;
    if (identical(a, b)) return a;
    if (a.length != b.length) return null;

    return List<AnyPoint>.generate(a.length, (index) {
      final pa = a[index];
      final pb = b[index];

      return AnyPoint(
        point: Offset(
          _lerpDouble(pa.point.dx, pb.point.dx, t),
          _lerpDouble(pa.point.dy, pb.point.dy, t),
        ),
        outer: AnyCorner(
          Radius.elliptical(
            _lerpDouble(pa.outer.radius.x, pb.outer.radius.x, t),
            _lerpDouble(pa.outer.radius.y, pb.outer.radius.y, t),
          ),
        ),
        inner: AnyCorner(
          Radius.elliptical(
            _lerpDouble(pa.inner.radius.x, pb.inner.radius.x, t),
            _lerpDouble(pa.inner.radius.y, pb.inner.radius.y, t),
          ),
        ),
        side: AnySide(
          width: _lerpDouble(pa.side.width, pb.side.width, t),
          align: _lerpDouble(pa.side.align, pb.side.align, t),
          color: _pickLerpObject(pa.side.color, pb.side.color, t),
          gradient: _pickLerpObject(pa.side.gradient, pb.side.gradient, t),
          image: _pickLerpObject(pa.side.image, pb.side.image, t),
          blendMode: _pickLerpObject(pa.side.blendMode, pb.side.blendMode, t),
          isAntiAlias:
          _pickLerpBool(pa.side.isAntiAlias, pb.side.isAntiAlias, t),
        ),
      );
    }, growable: false);
  }
}

enum AnyShapeBase {
  /// Shape of the element based on corner points only, ignoring side widths.
  zeroBorder,

  /// Contour built on the outer edge of side widths.
  outerBorder,

  /// Contour built on the inner edge of side widths.
  innerBorder,
}

class AnyRegions {
  final (IAnyFill, Path)? background;
  final List<(IAnyFill, Path)> regions;

  const AnyRegions({
    this.background,
    this.regions = const [],
  });
}

/// Small shared cache for contours.
///
/// Keyed by decoration instance. The cached contour is reusable only if its
/// local size and text direction still match.
class IDecorationCache {

  static int limit = 1000;

  static final LinkedHashMap<AnyDecoration, AnyContour> _contours = LinkedHashMap<AnyDecoration, AnyContour>();

  static AnyContour? get(
      AnyDecoration decoration,
      Size size,
      TextDirection? textDirection,
      ) {
    final contour = _contours[decoration];
    if (contour == null) return null;
    if (!contour.canReuseFor(size, textDirection)) return null;

    // This decoration becomes the most recently used one (so will not be removed in case of limit)
    _contours.remove(decoration);
    _contours[decoration] = contour;
    return contour;
  }

  static void put(AnyDecoration decoration, AnyContour contour) {
    _contours.remove(decoration);
    _contours[decoration] = contour;

    while (_contours.length > limit) {
      _contours.remove(_contours.keys.first);
    }
  }

  static void clear() {
    _contours.clear();
  }
}


class AnyContour {
  final Size size;
  final TextDirection? textDirection;
  final AnyShapeBase shadowBase;
  final AnyShapeBase clipBase;
  final AnyShapeBase backgroundBase;
  final IAnyFill? background;

  AnyContour({
    required this.size,
    required this.textDirection,
    required this.background,
    required this.backgroundBase,
    required this.clipBase,
    required this.shadowBase,
    required List<AnyPoint> points,
  }) {
    if (points.length < 3) {
      throw ArgumentError('At least 3 points are required to build a contour.');
    }
    _prepare(points);
  }

  bool canReuseFor(Size otherSize, TextDirection? otherTextDirection) {
    return size == otherSize && textDirection == otherTextDirection;
  }

  int _count = 0;

  Float64List _px = Float64List(0);
  Float64List _py = Float64List(0);

  Float64List _sdx = Float64List(0);
  Float64List _sdy = Float64List(0);
  Float64List _slen = Float64List(0);

  Float64List _inx = Float64List(0);
  Float64List _iny = Float64List(0);

  Float64List _inside = Float64List(0);
  Float64List _outside = Float64List(0);

  Float64List _outerRx = Float64List(0);
  Float64List _outerRy = Float64List(0);
  Float64List _innerRx = Float64List(0);
  Float64List _innerRy = Float64List(0);

  Float64List _m00 = Float64List(0);
  Float64List _m01 = Float64List(0);
  Float64List _m10 = Float64List(0);
  Float64List _m11 = Float64List(0);

  Float64List _cornerSin = Float64List(0);
  Int32List _cornerSegments = Int32List(0);
  Uint8List _cornerParallel = Uint8List(0);
  Uint8List _sideHasWidth = Uint8List(0);
  Uint8List _sidePainted = Uint8List(0);

  List<AnySide> _sides = List<AnySide>.empty(growable: false);

  void _prepare(List<AnyPoint> points) {
    _count = points.length;

    _px = Float64List(_count);
    _py = Float64List(_count);
    _sdx = Float64List(_count);
    _sdy = Float64List(_count);
    _slen = Float64List(_count);
    _inx = Float64List(_count);
    _iny = Float64List(_count);
    _inside = Float64List(_count);
    _outside = Float64List(_count);
    _outerRx = Float64List(_count);
    _outerRy = Float64List(_count);
    _innerRx = Float64List(_count);
    _innerRy = Float64List(_count);
    _m00 = Float64List(_count);
    _m01 = Float64List(_count);
    _m10 = Float64List(_count);
    _m11 = Float64List(_count);
    _cornerSin = Float64List(_count);
    _cornerSegments = Int32List(_count);
    _cornerParallel = Uint8List(_count);
    _sideHasWidth = Uint8List(_count);
    _sidePainted = Uint8List(_count);
    _sides = List<AnySide>.generate(
      _count,
          (index) => points[index].side,
      growable: false,
    );

    var signedAreaTwice = 0.0;

    for (var i = 0; i < _count; i++) {
      final point = points[i];
      final next = points[(i + 1) % _count];
      final side = point.side;

      _px[i] = point.point.dx;
      _py[i] = point.point.dy;

      _outerRx[i] = math.max(0.0, point.outer.radius.x);
      _outerRy[i] = math.max(0.0, point.outer.radius.y);
      _innerRx[i] = math.max(0.0, point.inner.radius.x);
      _innerRy[i] = math.max(0.0, point.inner.radius.y);

      final inside = side.width * (1.0 - side.align) / 2.0;
      final outside = side.width * (1.0 + side.align) / 2.0;
      _inside[i] = inside;
      _outside[i] = outside;
      _sideHasWidth[i] = side.width > _epsilon ? 1 : 0;
      _sidePainted[i] = side.width > _epsilon && side.hasFill ? 1 : 0;

      signedAreaTwice +=
          (point.point.dx * next.point.dy) - (point.point.dy * next.point.dx);
    }

    final isClockwise = signedAreaTwice > 0.0;

    for (var i = 0; i < _count; i++) {
      final next = (i + 1) % _count;
      final dx = _px[next] - _px[i];
      final dy = _py[next] - _py[i];
      final length = math.sqrt(dx * dx + dy * dy);
      if (length <= _epsilon) {
        throw ArgumentError('Side $i has zero length.');
      }

      final ux = dx / length;
      final uy = dy / length;
      _sdx[i] = ux;
      _sdy[i] = uy;
      _slen[i] = length;

      if (isClockwise) {
        _inx[i] = -uy;
        _iny[i] = ux;
      } else {
        _inx[i] = uy;
        _iny[i] = -ux;
      }
    }

    for (var corner = 0; corner < _count; corner++) {
      final prev = _wrap(corner - 1);

      final npx = _inx[prev];
      final npy = _iny[prev];
      final nnx = _inx[corner];
      final nny = _iny[corner];

      final det = (npx * nny) - (npy * nnx);
      if (_nearZero(det)) {
        _cornerParallel[corner] = 1;
        _m00[corner] = 0.0;
        _m01[corner] = 0.0;
        _m10[corner] = 0.0;
        _m11[corner] = 0.0;
      } else {
        _cornerParallel[corner] = 0;
        _m00[corner] = nny / det;
        _m01[corner] = -npy / det;
        _m10[corner] = -nnx / det;
        _m11[corner] = npx / det;
      }

      final cross = (_sdx[prev] * _sdy[corner]) - (_sdy[prev] * _sdx[corner]);
      final sinTurn = cross.abs();
      _cornerSin[corner] = sinTurn;

      final ux = -_sdx[prev];
      final uy = -_sdy[prev];
      final vx = _sdx[corner];
      final vy = _sdy[corner];
      final dot = _clampDouble((ux * vx) + (uy * vy), -1.0, 1.0);
      final angle = math.acos(dot);
      final segments = math.max(1, (angle / (math.pi / 2.0)).ceil());
      _cornerSegments[corner] = segments;
    }

    _normalizeBand(_outerRx, _outerRy);
    _normalizeBand(_innerRx, _innerRy);
  }

  Path? _clipPath;
  Path get clipPath => _clipPath ??= _buildContourPath(clipBase);

  Path? _shadowPath;
  Path get shadowPath => _shadowPath ??= _buildContourPath(shadowBase);

  Path? _backgroundPath;
  Path? get backgroundPath {
    final backgroundFill = background;
    if (backgroundFill == null || !backgroundFill.hasFill) return null;
    return _backgroundPath ??= _buildContourPath(backgroundBase);
  }

  AnyRegions? _regionsMerged;
  AnyRegions? _regionsSeparate;

  /// If [backgroundMerge] is true, side regions with the same fill as
  /// [background] are appended to the background path instead of being returned
  /// as separate regions.
  AnyRegions regions({required bool backgroundMerge}) {
    if (backgroundMerge) {
      return _regionsMerged ??= _buildRegions(true);
    }
    return _regionsSeparate ??= _buildRegions(false);
  }

  Path shiftedClipPath(Offset offset) =>
      offset == Offset.zero ? clipPath : clipPath.shift(offset);

  Path shiftedShadowPath(Offset offset) =>
      offset == Offset.zero ? shadowPath : shadowPath.shift(offset);

  AnyRegions shiftedRegions({
    required Offset offset,
    required bool backgroundMerge,
  }) {
    if (offset == Offset.zero) {
      return regions(backgroundMerge: backgroundMerge);
    }

    final source = regions(backgroundMerge: backgroundMerge);
    return AnyRegions(
      background: source.background == null
          ? null
          : (source.background!.$1, source.background!.$2.shift(offset)),
      regions: List<(IAnyFill, Path)>.generate(
        source.regions.length,
            (index) => (
        source.regions[index].$1,
        source.regions[index].$2.shift(offset),
        ),
        growable: false,
      ),
    );
  }

  AnyRegions _buildRegions(bool backgroundMerge) {
    final backgroundFill = background;
    final backgroundSource = backgroundPath;
    final backgroundTarget = backgroundSource == null ? null : Path.from(backgroundSource);

    final regionFills = <IAnyFill>[];
    final regionPaths = <Path>[];

    for (var sideIndex = 0; sideIndex < _count; sideIndex++) {
      if (_sidePainted[sideIndex] == 0) continue;

      final side = _sides[sideIndex];
      if (backgroundTarget != null &&
          backgroundMerge &&
          backgroundFill != null &&
          side.isSameAs(backgroundFill)) {
        _appendSidePolygon(backgroundTarget, sideIndex);
        continue;
      }

      var targetIndex = -1;
      for (var i = 0; i < regionFills.length; i++) {
        if (regionFills[i].isSameAs(side)) {
          targetIndex = i;
          break;
        }
      }

      if (targetIndex < 0) {
        targetIndex = regionFills.length;
        regionFills.add(side);
        regionPaths.add(Path());
      }

      _appendSidePolygon(regionPaths[targetIndex], sideIndex);
    }

    final regions = <(IAnyFill, Path)>[];
    for (var i = 0; i < regionFills.length; i++) {
      regions.add((regionFills[i], regionPaths[i]));
    }

    return AnyRegions(
      background: backgroundTarget != null && backgroundFill != null
          ? (backgroundFill, backgroundTarget)
          : null,
      regions: regions,
    );
  }

  void _normalizeBand(Float64List rx, Float64List ry) {
    for (var side = 0; side < _count; side++) {
      final startCorner = side;
      final endCorner = _wrap(side + 1);

      final startSin = _cornerSin[startCorner];
      final endSin = _cornerSin[endCorner];

      final startConsumption =
      startSin <= _epsilon ? 0.0 : ry[startCorner] / startSin;
      final endConsumption =
      endSin <= _epsilon ? 0.0 : rx[endCorner] / endSin;
      final total = startConsumption + endConsumption;

      if (total <= _slen[side] + _epsilon || total <= _epsilon) {
        continue;
      }

      final scale = _slen[side] / total;
      ry[startCorner] *= scale;
      rx[endCorner] *= scale;
    }

    for (var i = 0; i < _count; i++) {
      if (rx[i] <= _epsilon) rx[i] = 0.0;
      if (ry[i] <= _epsilon) ry[i] = 0.0;
    }
  }

  int _wrap(int index) {
    final mod = index % _count;
    return mod < 0 ? mod + _count : mod;
  }

  bool _canRound(int corner, Float64List rx, Float64List ry) {
    return _cornerParallel[corner] == 0 &&
        rx[corner] > _epsilon &&
        ry[corner] > _epsilon &&
        _cornerSin[corner] > _epsilon;
  }

  double _offsetForBase(int side, AnyShapeBase base) {
    return switch (base) {
      AnyShapeBase.zeroBorder => 0.0,
      AnyShapeBase.outerBorder => -_outside[side],
      AnyShapeBase.innerBorder => _inside[side],
    };
  }

  Path _buildContourPath(AnyShapeBase base) {
    final path = Path();
    final rx = base == AnyShapeBase.innerBorder ? _innerRx : _outerRx;
    final ry = base == AnyShapeBase.innerBorder ? _innerRy : _outerRy;

    final prev0 = _wrap(-1);
    final dPrev0 = _offsetForBase(prev0, base);
    final dNext0 = _offsetForBase(0, base);

    _moveToCornerPoint(path, 0, dPrev0, dNext0, rx, ry, _startAngle);
    _appendCornerArc(path, 0, dPrev0, dNext0, rx, ry, _startAngle, _endAngle);

    for (var corner = 1; corner < _count; corner++) {
      final prev = _wrap(corner - 1);
      final dPrev = _offsetForBase(prev, base);
      final dNext = _offsetForBase(corner, base);

      _lineToCornerPoint(path, corner, dPrev, dNext, rx, ry, _startAngle);
      _appendCornerArc(
        path,
        corner,
        dPrev,
        dNext,
        rx,
        ry,
        _startAngle,
        _endAngle,
      );
    }

    path.close();
    return path;
  }

  void _appendSidePolygon(Path path, int sideIndex) {
    final prevSide = _wrap(sideIndex - 1);
    final nextSide = _wrap(sideIndex + 1);
    final startCorner = sideIndex;
    final endCorner = _wrap(sideIndex + 1);

    final prevHasWidth = _sideHasWidth[prevSide] != 0;
    final nextHasWidth = _sideHasWidth[nextSide] != 0;

    final startOuterFrom = prevHasWidth ? _midAngle : _startAngle;
    final endOuterTo = nextHasWidth ? _midAngle : _endAngle;
    final endInnerFrom = nextHasWidth ? _midAngle : _endAngle;
    final startInnerTo = prevHasWidth ? _midAngle : _startAngle;

    final startOuterPrev = -_outside[prevSide];
    final startOuterNext = -_outside[sideIndex];
    final endOuterPrev = -_outside[sideIndex];
    final endOuterNext = -_outside[nextSide];

    final startInnerPrev = _inside[prevSide];
    final startInnerNext = _inside[sideIndex];
    final endInnerPrev = _inside[sideIndex];
    final endInnerNext = _inside[nextSide];

    _moveToCornerPoint(
      path,
      startCorner,
      startOuterPrev,
      startOuterNext,
      _outerRx,
      _outerRy,
      startOuterFrom,
    );

    _appendCornerArc(
      path,
      startCorner,
      startOuterPrev,
      startOuterNext,
      _outerRx,
      _outerRy,
      startOuterFrom,
      _endAngle,
    );

    _lineToCornerPoint(
      path,
      endCorner,
      endOuterPrev,
      endOuterNext,
      _outerRx,
      _outerRy,
      _startAngle,
    );

    _appendCornerArc(
      path,
      endCorner,
      endOuterPrev,
      endOuterNext,
      _outerRx,
      _outerRy,
      _startAngle,
      endOuterTo,
    );

    _lineToCornerPoint(
      path,
      endCorner,
      endInnerPrev,
      endInnerNext,
      _innerRx,
      _innerRy,
      endInnerFrom,
    );

    _appendCornerArc(
      path,
      endCorner,
      endInnerPrev,
      endInnerNext,
      _innerRx,
      _innerRy,
      endInnerFrom,
      _startAngle,
    );

    _lineToCornerPoint(
      path,
      startCorner,
      startInnerPrev,
      startInnerNext,
      _innerRx,
      _innerRy,
      _endAngle,
    );

    _appendCornerArc(
      path,
      startCorner,
      startInnerPrev,
      startInnerNext,
      _innerRx,
      _innerRy,
      _endAngle,
      startInnerTo,
    );

    path.close();
  }

  void _moveToCornerPoint(
      Path path,
      int corner,
      double dPrev,
      double dNext,
      Float64List rx,
      Float64List ry,
      double angle,
      ) {
    final (x, y) = _cornerPoint(corner, dPrev, dNext, rx, ry, angle);
    path.moveTo(x, y);
  }

  void _lineToCornerPoint(
      Path path,
      int corner,
      double dPrev,
      double dNext,
      Float64List rx,
      Float64List ry,
      double angle,
      ) {
    final (x, y) = _cornerPoint(corner, dPrev, dNext, rx, ry, angle);
    path.lineTo(x, y);
  }

  (double, double) _cornerPoint(
      int corner,
      double dPrev,
      double dNext,
      Float64List rx,
      Float64List ry,
      double angle,
      ) {
    if (!_canRound(corner, rx, ry)) {
      return _sharpCornerPoint(corner, dPrev, dNext);
    }

    final localX = dPrev + rx[corner] + rx[corner] * math.cos(angle);
    final localY = dNext + ry[corner] + ry[corner] * math.sin(angle);
    return _worldPointFromDistanceSpace(corner, localX, localY);
  }

  (double, double) _sharpCornerPoint(int corner, double dPrev, double dNext) {
    if (_cornerParallel[corner] == 0) {
      return _worldPointFromDistanceSpace(corner, dPrev, dNext);
    }

    final prev = _wrap(corner - 1);
    final x1 = _px[corner] + _inx[prev] * dPrev;
    final y1 = _py[corner] + _iny[prev] * dPrev;
    final x2 = _px[corner] + _inx[corner] * dNext;
    final y2 = _py[corner] + _iny[corner] * dNext;
    return ((x1 + x2) * 0.5, (y1 + y2) * 0.5);
  }

  (double, double) _worldPointFromDistanceSpace(
      int corner,
      double dPrev,
      double dNext,
      ) {
    return (
    _px[corner] + (_m00[corner] * dPrev) + (_m01[corner] * dNext),
    _py[corner] + (_m10[corner] * dPrev) + (_m11[corner] * dNext),
    );
  }

  void _appendCornerArc(
      Path path,
      int corner,
      double dPrev,
      double dNext,
      Float64List rx,
      Float64List ry,
      double fromAngle,
      double toAngle,
      ) {
    final delta = toAngle - fromAngle;
    if (_nearZero(delta)) return;

    if (!_canRound(corner, rx, ry)) {
      final (x, y) = _sharpCornerPoint(corner, dPrev, dNext);
      path.lineTo(x, y);
      return;
    }

    final baseSegments = _cornerSegments[corner];
    final fraction = delta.abs() / _quarterSweep;
    final segmentCount = math.max(1, (baseSegments * fraction).ceil());

    final cornerRx = rx[corner];
    final cornerRy = ry[corner];
    final centerX = dPrev + cornerRx;
    final centerY = dNext + cornerRy;

    for (var i = 0; i < segmentCount; i++) {
      final t0 = i / segmentCount;
      final t1 = (i + 1) / segmentCount;
      final a0 = fromAngle + delta * t0;
      final a1 = fromAngle + delta * t1;
      final da = a1 - a0;
      final alpha = (4.0 / 3.0) * math.tan(da / 4.0);

      final cos0 = math.cos(a0);
      final sin0 = math.sin(a0);
      final cos1 = math.cos(a1);
      final sin1 = math.sin(a1);

      final p1x = centerX + cornerRx * cos0 - alpha * cornerRx * sin0;
      final p1y = centerY + cornerRy * sin0 + alpha * cornerRy * cos0;
      final p2x = centerX + cornerRx * cos1 + alpha * cornerRx * sin1;
      final p2y = centerY + cornerRy * sin1 - alpha * cornerRy * cos1;
      final p3x = centerX + cornerRx * cos1;
      final p3y = centerY + cornerRy * sin1;

      final (c1x, c1y) = _worldPointFromDistanceSpace(corner, p1x, p1y);
      final (c2x, c2y) = _worldPointFromDistanceSpace(corner, p2x, p2y);
      final (ex, ey) = _worldPointFromDistanceSpace(corner, p3x, p3y);

      path.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
    }
  }
}

class AnyShadow with MAnyFill {
  @override
  final Color? color;
  @override
  final Gradient? gradient;
  @override
  final DecorationImage? image;
  @override
  final BlendMode? blendMode;
  @override
  final bool isAntiAlias;

  final double blurRadius;
  final Offset spreadRadius;
  final Offset offset;
  final BlurStyle style;

  const AnyShadow({
    this.color,
    this.gradient,
    this.image,
    this.blendMode,
    this.blurRadius = 0.0,
    this.offset = Offset.zero,
    this.spreadRadius = Offset.zero,
    this.style = BlurStyle.normal,
    this.isAntiAlias = true,
  });

  double get blurSigma => Shadow.convertRadiusToSigma(blurRadius);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyShadow &&
        other.color == color &&
        other.gradient == gradient &&
        other.image == image &&
        other.blendMode == blendMode &&
        other.blurRadius == blurRadius &&
        other.offset == offset &&
        other.spreadRadius == spreadRadius &&
        other.style == style &&
        other.isAntiAlias == isAntiAlias;
  }

  @override
  int get hashCode => Object.hash(
    color,
    gradient,
    image,
    blendMode,
    blurRadius,
    offset,
    spreadRadius,
    style,
    isAntiAlias,
  );
}

abstract class AnyDecoration extends Decoration {
  /// Build final contour points in local coordinates for this size.
  ///
  /// Each [AnyPoint.side] belongs to the segment that starts at this point and
  /// goes to the next point.
  List<AnyPoint> points(Size size, TextDirection? textDirection);

  final AnyBackground? background;
  final List<AnyShadow> shadows;
  final AnyShapeBase clipBase;
  final AnyShapeBase? _shadowBase;

  AnyShapeBase get backgroundShapeBase =>
      background?.shapeBase ?? AnyShapeBase.zeroBorder;

  AnyShapeBase get shadowBase => _shadowBase ?? background?.shapeBase ?? clipBase;

  const AnyDecoration({
    this.shadows = const [],
    this.background,
    this.clipBase = AnyShapeBase.zeroBorder,
    AnyShapeBase? shadowBase,
  }) : _shadowBase = shadowBase;

  AnyContour buildContour(Size size, TextDirection? textDirection) {

    final cached = IDecorationCache.get(this, size, textDirection);
    if (cached != null) {
      return cached;
    }

    final contour = AnyContour(
      size: size,
      textDirection: textDirection,
      points: points(size, textDirection),
      background: background,
      backgroundBase: backgroundShapeBase,
      clipBase: clipBase,
      shadowBase: shadowBase,
    );

    IDecorationCache.put(this, contour);
    return contour;
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _AnyDecorationPainter(this, onChanged);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    final contour = buildContour(rect.size, textDirection);
    return contour.shiftedClipPath(rect.topLeft);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyDecoration &&
        other.shadowBase == shadowBase &&
        other.clipBase == clipBase &&
        other.background == background &&
        listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode =>
      Object.hash(clipBase, shadowBase, background, Object.hashAll(shadows));
}

class _AnyDecorationPainter extends BoxPainter {
  _AnyDecorationPainter(this.decoration, super.onChanged);

  final AnyDecoration decoration;
  final Map<DecorationImage, DecorationImagePainter> _imagePainters =
  <DecorationImage, DecorationImagePainter>{};

  @override
  void paint(Canvas canvas, Offset topLeft, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    final innerShadows = <AnyShadow>[];
    final otherShadows = <AnyShadow>[];
    for (final shadow in decoration.shadows) {
      if (!shadow.hasFill) continue;
      if (shadow.style == BlurStyle.inner) {
        innerShadows.add(shadow);
      } else {
        otherShadows.add(shadow);
      }
    }

    final contour = decoration.buildContour(size, configuration.textDirection);
    final regions = contour.shiftedRegions(
      offset: topLeft,
      backgroundMerge: innerShadows.isEmpty,
    );

    final backgroundRegion = regions.background;

    Path? shadowPath;
    if (innerShadows.isNotEmpty || otherShadows.isNotEmpty) {
      shadowPath = contour.shiftedShadowPath(topLeft);
    }

    for (final shadow in otherShadows) {
      _paintShadow(canvas, shadow, shadowPath!, configuration);
    }

    if (backgroundRegion != null && backgroundRegion.$1.hasFill) {
      _paintRegion(
        canvas,
        backgroundRegion.$1,
        backgroundRegion.$2,
        configuration,
      );
    }

    for (final shadow in innerShadows) {
      _paintShadow(canvas, shadow, shadowPath!, configuration);
    }

    for (final region in regions.regions) {
      if (!region.$1.hasFill) continue;
      _paintRegion(canvas, region.$1, region.$2, configuration);
    }
  }

  void _paintRegion(
      Canvas canvas,
      IAnyFill fill,
      Path path,
      ImageConfiguration configuration,
      ) {
    if (fill.image != null) {
      final imagePainter = _imagePainters.putIfAbsent(
        fill.image!,
            () => fill.image!.createPainter(onChanged ?? () {}),
      );

      imagePainter.paint(canvas, path.getBounds(), path, configuration);
    }

    if (fill.hasBaseFill) {
      final paint = createBasePaint(fill, path, configuration);
      canvas.drawPath(path, paint);
    }
  }

  Paint createBasePaint(
      IAnyFill fill,
      Path path,
      ImageConfiguration configuration,
      ) {
    final paint = Paint()..isAntiAlias = fill.isAntiAlias;

    if (fill.blendMode != null) {
      paint.blendMode = fill.blendMode!;
    }

    if (fill.gradient != null) {
      paint.shader = fill.gradient!.createShader(
        path.getBounds(),
        textDirection: configuration.textDirection,
      );
    } else if (fill.color != null) {
      paint.color = fill.color!;
    }

    return paint;
  }

  void _paintShadow(
      Canvas canvas,
      AnyShadow shadow,
      Path path,
      ImageConfiguration configuration,
      ) {
    var targetPath = path;

    if (shadow.spreadRadius != Offset.zero) {
      final bounds = targetPath.getBounds();
      final width = bounds.width;
      final height = bounds.height;
      if (width > _epsilon && height > _epsilon) {
        final scaleX = (width + shadow.spreadRadius.dx) / width;
        final scaleY = (height + shadow.spreadRadius.dy) / height;
        final cx = bounds.center.dx;
        final cy = bounds.center.dy;

        final matrix = Matrix4.identity()
          ..translateByDouble(cx, cy, 0, 1.0)
          ..scaleByDouble(scaleX, scaleY, 1.0, 1.0)
          ..translateByDouble(-cx, -cy, 0, 1.0);

        targetPath = targetPath.transform(matrix.storage);
      }
    }

    if (shadow.offset != Offset.zero) {
      targetPath = targetPath.shift(shadow.offset);
    }

    if (shadow.image != null) {
      final imagePainter = _imagePainters.putIfAbsent(
        shadow.image!,
            () => shadow.image!.createPainter(onChanged ?? () {}),
      );

      void paintImageSource() {
        imagePainter.paint(
          canvas,
          targetPath.getBounds(),
          targetPath,
          configuration,
        );
      }

      final layerBounds = targetPath.getBounds().inflate(
        shadow.blurRadius > 0 ? shadow.blurRadius * 2.0 + 1.0 : 1.0,
      );

      final compositePaint = Paint()..isAntiAlias = shadow.isAntiAlias;
      if (shadow.blendMode != null) {
        compositePaint.blendMode = shadow.blendMode!;
      }

      final blurPaint = Paint();
      if (shadow.blurSigma > 0.0) {
        blurPaint.imageFilter = ImageFilter.blur(
          sigmaX: shadow.blurSigma,
          sigmaY: shadow.blurSigma,
          tileMode: TileMode.decal,
        );
      }

      canvas.saveLayer(layerBounds, compositePaint);

      switch (shadow.style) {
        case BlurStyle.normal:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();
          break;
        case BlurStyle.inner:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();

          canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstIn);
          paintImageSource();
          canvas.restore();
          break;
        case BlurStyle.outer:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();

          canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstOut);
          paintImageSource();
          canvas.restore();
          break;
        case BlurStyle.solid:
          canvas.saveLayer(layerBounds, blurPaint);
          paintImageSource();
          canvas.restore();

          canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstOut);
          paintImageSource();
          canvas.restore();

          paintImageSource();
          break;
      }

      canvas.restore();
    }

    if (shadow.hasBaseFill) {
      final paint = createBasePaint(shadow, targetPath, configuration)
        ..maskFilter = MaskFilter.blur(shadow.style, shadow.blurSigma);

      canvas.drawPath(targetPath, paint);
    }
  }
}

class AnyBoxDecoration extends AnyDecoration {
  static const AnySide zeroSide = AnySide();
  static const AnyCorner cornersBase = AnyCorner();

  final AnySide? _left;
  AnySide get left => _left ?? sides;

  final AnySide? _top;
  AnySide get top => _top ?? sides;

  final AnySide? _right;
  AnySide get right => _right ?? sides;

  final AnySide? _bottom;
  AnySide get bottom => _bottom ?? sides;

  final AnySide? _sides;
  AnySide get sides => _sides ?? zeroSide;

  final AnyCorner? _topLeft;
  AnyCorner get topLeft => _topLeft ?? corners;

  final AnyCorner? _topRight;
  AnyCorner get topRight => _topRight ?? corners;

  final AnyCorner? _bottomRight;
  AnyCorner get bottomRight => _bottomRight ?? corners;

  final AnyCorner? _bottomLeft;
  AnyCorner get bottomLeft => _bottomLeft ?? corners;

  final AnyCorner? _corners;
  AnyCorner get corners => _corners ?? cornersBase;

  final AnyCorner? _innerTopLeft;
  AnyCorner get innerTopLeft => _innerTopLeft ?? innerCorners ?? topLeft;

  final AnyCorner? _innerTopRight;
  AnyCorner get innerTopRight => _innerTopRight ?? innerCorners ?? topRight;

  final AnyCorner? _innerBottomRight;
  AnyCorner get innerBottomRight => _innerBottomRight ?? innerCorners ?? bottomRight;

  final AnyCorner? _innerBottomLeft;
  AnyCorner get innerBottomLeft => _innerBottomLeft ?? innerCorners ?? bottomLeft;

  final AnyCorner? innerCorners;

  /// Width / Height.
  final double? ratio;

  const AnyBoxDecoration({
    double? ratio,
    bool circle = false,
    super.shadows,
    super.clipBase,
    super.shadowBase,
    super.background,
    AnySide? left,
    AnySide? top,
    AnySide? right,
    AnySide? bottom,
    AnySide? sides,
    AnyCorner? topLeft,
    AnyCorner? topRight,
    AnyCorner? bottomRight,
    AnyCorner? bottomLeft,
    AnyCorner? corners,
    AnyCorner? innerTopLeft,
    AnyCorner? innerTopRight,
    AnyCorner? innerBottomRight,
    AnyCorner? innerBottomLeft,
    this.innerCorners,
  })  : ratio = circle ? 1.0 : ratio,
        _corners =
        circle ? const AnyCorner(Radius.circular(double.infinity)) : corners,
        _sides = sides,
        _left = left,
        _top = top,
        _right = right,
        _bottom = bottom,
        _topLeft = topLeft,
        _topRight = topRight,
        _bottomRight = bottomRight,
        _bottomLeft = bottomLeft,
        _innerTopLeft = innerTopLeft,
        _innerTopRight = innerTopRight,
        _innerBottomRight = innerBottomRight,
        _innerBottomLeft = innerBottomLeft;

  @override
  List<AnyPoint> points(Size size, TextDirection? textDirection) {
    final fitted = _fitRectToRatio(Offset.zero & size, ratio);
    final width = fitted.width;
    final height = fitted.height;

    final tlOuter = _resolveFiniteCorner(topLeft, height, width);
    final trOuter = _resolveFiniteCorner(topRight, width, height);
    final brOuter = _resolveFiniteCorner(bottomRight, height, width);
    final blOuter = _resolveFiniteCorner(bottomLeft, width, height);

    final tlInner = _resolveFiniteCorner(innerTopLeft, height, width);
    final trInner = _resolveFiniteCorner(innerTopRight, width, height);
    final brInner = _resolveFiniteCorner(innerBottomRight, height, width);
    final blInner = _resolveFiniteCorner(innerBottomLeft, width, height);

    return <AnyPoint>[
      AnyPoint(
        point: fitted.topLeft,
        outer: tlOuter,
        inner: tlInner,
        side: top,
      ),
      AnyPoint(
        point: fitted.topRight,
        outer: trOuter,
        inner: trInner,
        side: right,
      ),
      AnyPoint(
        point: fitted.bottomRight,
        outer: brOuter,
        inner: brInner,
        side: bottom,
      ),
      AnyPoint(
        point: fitted.bottomLeft,
        outer: blOuter,
        inner: blInner,
        side: left,
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnyBoxDecoration &&
        other.ratio == ratio &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
        other.topLeft == topLeft &&
        other.topRight == topRight &&
        other.bottomRight == bottomRight &&
        other.bottomLeft == bottomLeft &&
        other.innerTopLeft == innerTopLeft &&
        other.innerTopRight == innerTopRight &&
        other.innerBottomRight == innerBottomRight &&
        other.innerBottomLeft == innerBottomLeft &&
        super == other;
  }

  @override
  int get hashCode => Object.hash(
    super.hashCode,
    ratio,
    left,
    top,
    right,
    bottom,
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
    innerTopLeft,
    innerTopRight,
    innerBottomRight,
    innerBottomLeft,
  );
}
