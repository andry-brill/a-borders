import 'dart:ui';
import 'package:any_borders/any_borders.dart';

typedef GeometryFixture = ({
  String name,
  bool ordinary,
  AnyContour Function() build
});

List<GeometryFixture> directGeometryFixtures() {
  GeometryFixture box(String name, AnyBoxBorder border,
          {bool ordinary = true}) =>
      (
        name: name,
        ordinary: ordinary,
        build: () => AnyBoxDecoration(enableCache: false, border: border)
            .buildContour(const Size(200, 120), TextDirection.ltr)
      );
  GeometryFixture polygon(
          String name, List<Offset> points, AnyCorner corner, double width,
          {bool ordinary = true}) =>
      (
        name: name,
        ordinary: ordinary,
        build: () => AnyContour(
                background: null,
                backgroundBase: AnyShapeBase.shapeBorder,
                clipBase: AnyShapeBase.shapeBorder,
                shadowBase: AnyShapeBase.shapeBorder,
                points: [
                  for (var i = 0; i < points.length; i++)
                    AnyPoint(
                        point: points[i],
                        shape: corner,
                        side: AnySide(
                            width: width,
                            align: -1,
                            color: Color(0xff224466 + i * 0x110011)))
                ])
      );
  const side = AnySide(width: 8, align: 0, color: Color(0xff224466));
  return [
    box('rounded box',
        const AnyBoxBorder(corners: RoundedCorner(radius: 24), sides: side)),
    box('bevel box',
        const AnyBoxBorder(corners: BevelCorner(radius: 24), sides: side)),
    box(
        'circular scoop',
        const AnyBoxBorder(
            corners: InverseRoundedCorner(radius: 24), sides: side)),
    box(
        'distinct side fills',
        const AnyBoxBorder(
            corners: RoundedCorner(radius: 24),
            sides: side,
            top: AnySide(width: 8, color: Color(0xff992233)),
            right: AnySide(width: 8, color: Color(0xff229933)))),
    box(
        'authored boundaries',
        const AnyBoxBorder(
            corners: RoundedCorner(radius: 20),
            sides: side,
            outerCorners: RoundedCorner(radius: 28),
            innerCorners: BevelCorner(radius: 12))),
    polygon(
        'triangle',
        const [Offset(100, 0), Offset(200, 120), Offset(0, 120)],
        const RoundedCorner(radius: 12),
        4),
    polygon(
        'concave polygon',
        const [
          Offset(0, 0),
          Offset(200, 0),
          Offset(200, 60),
          Offset(100, 60),
          Offset(100, 120),
          Offset(0, 120)
        ],
        const BevelCorner(radius: 10),
        4),
    box(
        'elliptical offset',
        const AnyBoxBorder(
            corners: InverseRoundedCorner.elliptical(p: 30, n: 16),
            sides: side),
        ordinary: false),
    box(
        'unequal scoop offsets',
        const AnyBoxBorder(
            corners: InverseRoundedCorner(radius: 24),
            sides: side,
            top: AnySide(width: 16, align: 0, color: Color(0xff224466))),
        ordinary: false),
    box(
        'collapsed rounded interior',
        const AnyBoxBorder(
            corners: RoundedCorner(radius: 24),
            sides: AnySide(width: 80, align: -1, color: Color(0xff224466))),
        ordinary: false),
    polygon(
        'split neck',
        const [
          Offset(0, 0),
          Offset(60, 0),
          Offset(60, 20),
          Offset(100, 20),
          Offset(100, 0),
          Offset(160, 0),
          Offset(160, 60),
          Offset(100, 60),
          Offset(100, 40),
          Offset(60, 40),
          Offset(60, 60),
          Offset(0, 60)
        ],
        const RoundedCorner(),
        12,
        ordinary: false),
  ];
}
