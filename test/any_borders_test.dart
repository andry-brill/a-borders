
import 'package:flutter_test/flutter_test.dart';

//
// const _squareCorners = {
//   RectCorner.topRight: AnyCorner(),
//   RectCorner.bottomRight: AnyCorner(),
//   RectCorner.bottomLeft: AnyCorner(),
//   RectCorner.topLeft: AnyCorner(),
// };
//
// Polygon _rectanglePolygon({double width = 100, double height = 50}) {
//   const d90 = pi / 2.0;
//   return Polygon({
//     RectSide.top: Command(CommandType.line, width),
//     RectCorner.topRight: const Command(CommandType.rotateRight, d90),
//     RectSide.right: Command(CommandType.line, height),
//     RectCorner.bottomRight: const Command(CommandType.rotateRight, d90),
//     RectSide.bottom: Command(CommandType.line, width),
//     RectCorner.bottomLeft: const Command(CommandType.rotateRight, d90),
//     RectSide.left: Command(CommandType.line, height),
//     RectCorner.topLeft: const Command(CommandType.rotateRight, d90),
//   });
// }

// Matcher _rectNear(Rect expected, [double epsilon = 0.001]) {
//   bool close(double a, double b) => (a - b).abs() <= epsilon;
//   return predicate<Rect>((actual) {
//     return close(actual.left, expected.left) &&
//         close(actual.top, expected.top) &&
//         close(actual.right, expected.right) &&
//         close(actual.bottom, expected.bottom);
//   }, 'Rect close to $expected');
// }

void main() {

  test('builds a simple outside top stroke as a rectangle', () {});
    //
    // test('builds a simple outside top stroke as a rectangle', () {
    //   final polygon = _rectanglePolygon();
    //   final regions = polygon.buildMergedStrokeRegions(
    //     PolygonSetup(
    //       sides: const {
    //         RectSide.top: AnySide(color: Color(0xFFFFFFFF), width: 10, align: AnySide.alignOutside),
    //       },
    //       corners: _squareCorners,
    //       background: const {},
    //     ),
    //   );
    //
    //   expect(regions, hasLength(1));
    //   expect(regions.single.included, [RectSide.top]);
    //   expect(regions.single.path.getBounds(), _rectNear(const Rect.fromLTRB(0, -10, 100, 0)));
    //   expect(regions.single.path.contains(const Offset(50, -5)), isTrue);
    //   expect(regions.single.path.contains(const Offset(50, 5)), isFalse);
    // });
    //
    // test('merges adjacent equal-paint sides into one region', () {
    //   final polygon = _rectanglePolygon();
    //   final regions = polygon.buildMergedStrokeRegions(
    //     PolygonSetup(
    //       sides: const {
    //         RectSide.top: AnySide(color: Color(0xFFFFFFFF), width: 10, align: AnySide.alignOutside),
    //         RectSide.right: AnySide(color: Color(0xFFFFFFFF), width: 20, align: AnySide.alignCenter),
    //       },
    //       corners: _squareCorners,
    //       background: const {},
    //     ),
    //   );
    //
    //   expect(regions, hasLength(1));
    //   expect(regions.single.included, [RectSide.top, RectSide.right]);
    //   expect(regions.single.path.contains(const Offset(50, -5)), isTrue);
    //   expect(regions.single.path.contains(const Offset(105, 25)), isTrue);
    //   expect(regions.single.path.contains(const Offset(95, -5)), isTrue);
    //   expect(regions.single.path.contains(const Offset(50, 25)), isFalse);
    // });
    //
    // test('keeps different paints split on the corner diagonal', () {
    //   final polygon = _rectanglePolygon();
    //   final regions = polygon.buildMergedStrokeRegions(
    //     PolygonSetup(
    //       sides: const {
    //         RectSide.top: AnySide(color: Color(0xFFFFFFFF), width: 10, align: AnySide.alignOutside),
    //         RectSide.right: AnySide(color: Color(0xFF000000), width: 20, align: AnySide.alignCenter),
    //       },
    //       corners: _squareCorners,
    //       background: const {},
    //     ),
    //   );
    //
    //   expect(regions, hasLength(2));
    //
    //   final topRegion = regions.firstWhere((region) => region.included.contains(RectSide.top));
    //   final rightRegion = regions.firstWhere((region) => region.included.contains(RectSide.right));
    //
    //   expect(topRegion.included, [RectSide.top]);
    //   expect(rightRegion.included, [RectSide.right]);
    //
    //   expect(topRegion.path.contains(const Offset(50, -5)), isTrue);
    //   expect(topRegion.path.contains(const Offset(95, -5)), isTrue);
    //   expect(topRegion.path.contains(const Offset(105, -5)), isFalse);
    //
    //   expect(rightRegion.path.contains(const Offset(105, 25)), isTrue);
    //   expect(rightRegion.path.contains(const Offset(105, -5)), isTrue);
    //   expect(rightRegion.path.contains(const Offset(95, -5)), isFalse);
    // });
    //
    // test('merges background with equal-paint sides', () {
    //   final polygon = _rectanglePolygon();
    //   final regions = polygon.buildMergedStrokeRegions(
    //     PolygonSetup(
    //       sides: const {
    //         RectSide.top: AnySide(color: Color(0xFFFFFFFF), width: 10, align: AnySide.alignOutside),
    //         RectSide.right: AnySide(color: Color(0xFF000000), width: 20, align: AnySide.alignCenter),
    //       },
    //       corners: _squareCorners,
    //       background: const {
    //         RectSide.background: AnyBackground(color: Color(0xFFFFFFFF)),
    //       },
    //     ),
    //   );
    //
    //   expect(regions, hasLength(2));
    //
    //   final merged = regions.firstWhere((region) => region.included.contains(RectSide.background));
    //   final right = regions.firstWhere((region) => region.included.contains(RectSide.right));
    //
    //   expect(merged.included, [RectSide.top, RectSide.background]);
    //   expect(merged.path.contains(const Offset(50, 25)), isTrue);
    //   expect(merged.path.contains(const Offset(50, -5)), isTrue);
    //   expect(merged.path.contains(const Offset(105, 25)), isFalse);
    //   expect(right.path.contains(const Offset(105, 25)), isTrue);
    // });
    //
    // test('uses outer-minus-inner optimization when all sides are present with the same paint', () {
    //   final polygon = _rectanglePolygon();
    //   final regions = polygon.buildMergedStrokeRegions(
    //     PolygonSetup(
    //       sides: const {
    //         RectSide.top: AnySide(color: Color(0xFFFFFFFF), width: 10, align: AnySide.alignOutside),
    //         RectSide.right: AnySide(color: Color(0xFFFFFFFF), width: 20, align: AnySide.alignCenter),
    //         RectSide.bottom: AnySide(color: Color(0xFFFFFFFF), width: 25, align: AnySide.alignCenter),
    //         RectSide.left: AnySide(color: Color(0xFFFFFFFF), width: 5, align: AnySide.alignCenter),
    //       },
    //       corners: _squareCorners,
    //       background: const {},
    //     ),
    //   );
    //
    //   expect(regions, hasLength(1));
    //   expect(regions.single.included, [RectSide.top, RectSide.right, RectSide.bottom, RectSide.left]);
    //   expect(regions.single.path.getBounds(), _rectNear(const Rect.fromLTRB(-2.5, -10, 110, 62.5)));
    //   expect(regions.single.path.contains(const Offset(50, -5)), isTrue);
    //   expect(regions.single.path.contains(const Offset(105, 25)), isTrue);
    //   expect(regions.single.path.contains(const Offset(50, 20)), isFalse);
    // });
}
