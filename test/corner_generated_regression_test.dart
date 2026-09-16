import 'package:any_borders/any_borders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'corner_matrix_test.dart' show contour;

List<AnyPoint> fixture600() {
  const vertices = [
    Offset(269.9665736882554, 152.8321718698547),
    Offset(245.39028801367482, 222.8058579557179),
    Offset(184.37815451451218, 264.97018088259375),
    Offset(110.23473446130153, 263.2198024050422),
    Offset(51.280294272208806, 218.22330760831161),
    Offset(30.03342631174465, 147.1678281301453),
    Offset(54.60971198632518, 77.19414204428213),
    Offset(115.62184548548787, 35.029819117406234),
    Offset(189.76526553869851, 36.78019759495781),
    Offset(248.71970572779122, 81.77669239168841)
  ];
  const radii = [
    3.8125269444288126,
    22.503629140089377,
    10.309618567869835,
    24.028670559907766,
    9.374918140303553,
    25.401102005700988,
    9.581981208681457,
    21.827796925936656,
    4.279308152873745,
    7.343387005248745
  ];
  const widths = [
    3.0558289149530338,
    11.308954270186804,
    8.865014327236123,
    11.868513379521392,
    5.907688359553278,
    4.952502715590437,
    1.3630815787396213,
    9.997877134534727,
    4.7063246026547105,
    7.003998990434213
  ];
  const aligns = [0.0, -1.0, 0.5, -1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  return List.generate(
      vertices.length,
      (i) => AnyPoint(
          point: vertices[i],
          shape: switch (i % 3) {
            0 => RoundedCorner(radius: radii[i]),
            1 => InverseRoundedCorner(radius: radii[i]),
            _ => BevelCorner(radius: radii[i])
          },
          side: AnySide(width: widths[i], align: aligns[i])));
}

List<AnyPoint> reversePoints(List<AnyPoint> points) =>
    List.generate(points.length, (i) {
      final old = points.length - 1 - i, p = points[old];
      return AnyPoint(
          point: p.point,
          shape: p.shape.copyWith(p: p.shape.n, n: p.shape.p),
          side: points[(old - 1) % points.length].side);
    });
List<AnyPoint> fixture80() {
  const vertices = [
    Offset(54.10000067754845, 222.13314168919715),
    Offset(31.18262652658784, 133.19429380003055),
    Offset(77.86685831080285, 54.10000067754845),
    Offset(166.80570619996945, 31.18262652658784),
    Offset(245.89999932245155, 77.86685831080284),
    Offset(268.81737347341215, 166.80570619996942),
    Offset(222.13314168919715, 245.89999932245155),
    Offset(133.19429380003058, 268.8173734734122)
  ];
  const p = [
    7.309419409521624,
    6.811123123127089,
    20.462456222007532,
    24.350737494407838,
    22.14559667599859,
    27.909937125452306,
    12.57196267129996,
    15.46025494823603
  ];
  const n = [
    23.907951568525213,
    14.593156591223503,
    14.305455681483727,
    7.213860712448396,
    21.3043532731472,
    2.1054564710688703,
    9.20696222775172,
    3.6397808545927646
  ];
  const widths = [
    8.812572121327085,
    7.554184540868917,
    11.320823220341548,
    8.650297439098253,
    9.322615413457996,
    8.285538527494799,
    3.328694720326125,
    10.347828361377157
  ];
  const aligns = [0.0, 1.0, 0.5, -0.5, -1.0, 0.5, 0.5, 1.0];
  return List.generate(
      vertices.length,
      (i) => AnyPoint(
          point: vertices[i],
          shape: switch (i % 3) {
            0 => BevelCorner.elliptical(p: p[i], n: n[i]),
            1 => RoundedCorner.elliptical(p: p[i], n: n[i]),
            _ => InverseRoundedCorner.elliptical(p: p[i], n: n[i])
          },
          side: AnySide(width: widths[i], align: aligns[i])));
}

// Seed 20260915, case 280: subtracting the compound sweep from the source
// failed in PathOps despite every individual swept region being finite.
List<AnyPoint> fixture280() {
  const data = [
    (
      42.361197495625504,
      96.95390499363538,
      21.927804833300286,
      11.948849226438355,
      5.841067454657257,
      1.0
    ),
    (
      94.09809185623897,
      43.816306968129496,
      12.637669449280864,
      15.124249004224248,
      8.933967007388135,
      -1.0
    ),
    (
      167.18761509179456,
      31.23727062981284,
      4.945049256292751,
      2.1378199658187533,
      2.159353670345155,
      0.0
    ),
    (
      233.7120535478353,
      64.02156031420228,
      19.915093280174485,
      24.114674453011308,
      10.24893405458722,
      -0.5
    ),
    (
      268.26133281665415,
      129.6466916588836,
      3.9510731244515203,
      7.104900945902699,
      7.517890745214843,
      0.5
    ),
    (
      257.6388025043745,
      203.04609500636465,
      20.107286824710577,
      7.453981776239218,
      7.317501298649873,
      -1.0
    ),
    (
      205.90190814376106,
      256.18369303187046,
      9.683018909843899,
      10.875163387966598,
      1.169810307494381,
      0.5
    ),
    (
      132.81238490820544,
      268.7627293701872,
      4.758029752064525,
      25.685906858072375,
      10.79049048910016,
      -0.5
    ),
    (
      66.28794645216473,
      235.97843968579775,
      10.225672778522387,
      25.14899888333571,
      10.825875831019701,
      0.5
    ),
    (
      31.73866718334584,
      170.35330834111642,
      22.4793974886234,
      10.177962927298871,
      0.26519120879656954,
      0.0
    ),
  ];
  return List.generate(data.length, (i) {
    final d = data[i];
    return AnyPoint(
      point: Offset(d.$1, d.$2),
      shape: switch (i % 3) {
        0 => InverseRoundedCorner.elliptical(p: d.$3, n: d.$4),
        1 => BevelCorner.elliptical(p: d.$3, n: d.$4),
        _ => RoundedCorner.elliptical(p: d.$3, n: d.$4),
      },
      side: AnySide(width: d.$5, align: d.$6),
    );
  });
}

void main() {
  test('generated 280: coincident sweep subtraction preserves the interior',
      () {
    final forward = contour(fixture280());
    final reverse = contour(reversePoints(fixture280()));
    for (final c in [forward, reverse]) {
      final shape = c.pathFor(AnyShapeBase.shapeBorder);
      final inner = c.pathFor(AnyShapeBase.innerBorder);
      final outer = c.pathFor(AnyShapeBase.outerBorder);
      expect(inner.getBounds().isFinite, isTrue);
      expect(inner.contains(const Offset(150, 150)), isTrue);
      for (var x = 0.37; x < 300; x += 5) {
        for (var y = 0.73; y < 300; y += 5) {
          final p = Offset(x, y);
          if (inner.contains(p)) expect(shape.contains(p), isTrue);
          if (shape.contains(p)) expect(outer.contains(p), isTrue);
          expect(inner.contains(p),
              forward.pathFor(AnyShapeBase.innerBorder).contains(p));
        }
      }
    }
  });
  test(
      'generated 80: folded elliptical offset can be assembled in either winding',
      () {
    for (final points in [fixture80(), reversePoints(fixture80())]) {
      final c = contour(points);
      for (final base in AnyShapeBase.values)
        expect(c.pathFor(base).getBounds().isFinite, isTrue);
      final outer = c.pathFor(AnyShapeBase.outerBorder),
          inner = c.pathFor(AnyShapeBase.innerBorder);
      for (var x = 0.37; x < 300; x += 5) {
        for (var y = 0.73; y < 300; y += 5) {
          final point = Offset(x, y);
          if (inner.contains(point)) expect(c.clipPath.contains(point), isTrue);
          if (c.clipPath.contains(point)) expect(outer.contains(point), isTrue);
        }
      }
    }
  });
  test('generated 600: outer assembly retains source in either winding', () {
    for (final points in [fixture600(), reversePoints(fixture600())]) {
      final c = contour(points),
          shape = c.pathFor(AnyShapeBase.shapeBorder),
          outer = c.pathFor(AnyShapeBase.outerBorder);
      const point = Offset(81.28755287760812, 102.71432712837196);
      expect(shape.contains(point), isTrue);
      expect(outer.contains(point), isTrue);
    }
  });
}
