import 'dart:math' as math;

import 'package:any_borders/any_borders.dart';
import 'package:any_borders/extras/any_tab_decoration.dart';

import 'package:flutter/material.dart';
import 'corner_inspector.dart';
import 'custom_corner.dart';

List<Widget> examples() {
  const box = [
    H('AnyBoxDecoration'),
    E(
      title: 'Any align/width\nLTRB(in:center:out:center)',
      begin: AnyBoxDecoration(
          border: AnyBoxBorder(
              left: AnySide(color: greenD, width: 10, align: AnySide.alignInside),
              top: AnySide(color: greenD, width: 20, align: AnySide.alignCenter),
              right: AnySide(color: greenD, width: 30, align: AnySide.alignOutside),
              bottom: AnySide(color: greenD, width: 40, align: AnySide.alignCenter),
              outerCorners: RoundedCorner(radius: 10),
              innerCorners: RoundedCorner(radius: 10)),
          background: AnyBackground(color: greenL)),
      end: AnyBoxDecoration(
          border: AnyBoxBorder(
              left: AnySide(color: greenD, width: 40, align: AnySide.alignOutside),
              top: AnySide(color: greenD, width: 30, align: AnySide.alignInside),
              right: AnySide(color: greenD, width: 20, align: AnySide.alignCenter),
              bottom: AnySide(color: greenD, width: 10, align: AnySide.alignOutside),
              outerCorners: RoundedCorner(radius: 10),
              innerCorners: RoundedCorner(radius: 10)),
          background: AnyBackground(color: greenL)),
    ),
    E(
      title: 'No horizontal',
      begin: AnyBoxDecoration(
        border: AnyBoxBorder(
            vertical: AnySide(color: greenD, width: 30, align: AnySide.alignOutside),
            horizontal: AnySide(color: greenL, align: AnySide.alignInside),
            outerCorners: RoundedCorner(radius: 30),
            innerCorners: RoundedCorner(radius: 30)),
      ),
      end: AnyBoxDecoration(
        border: AnyBoxBorder(
            vertical: AnySide(color: greenD, width: 10, align: AnySide.alignOutside),
            horizontal: AnySide(color: greenL, align: AnySide.alignInside),
            corners: RoundedCorner(radius: 20),
            innerCorners: RoundedCorner(radius: 20)),
      ),
    ),
    E(
      title: 'Any corner',
      begin: AnyBoxDecoration(
        border: AnyBoxBorder(
            vertical: AnySide(color: greenD, width: 20, align: AnySide.alignOutside),
            horizontal: AnySide(color: greenL, width: 20, align: AnySide.alignInside),
            topLeft: RoundedCorner(radius: 2),
            outerTopLeft: RoundedCorner(radius: 2),
            innerTopLeft: BevelCorner(radius: 30),
            topRight: InverseRoundedCorner(radius: 20),
            outerTopRight: InverseRoundedCorner(radius: 20),
            innerTopRight: BevelCorner(radius: 10),
            bottomRight: BevelCorner(radius: 20),
            outerBottomRight: BevelCorner(radius: 20),
            innerBottomRight: RoundedCorner(radius: 40),
            bottomLeft: InverseRoundedCorner(radius: 20),
            outerBottomLeft: InverseRoundedCorner(radius: 20),
            innerBottomLeft: RoundedCorner(radius: 2)),
      ),
      end: AnyBoxDecoration(
        border: AnyBoxBorder(
            vertical: AnySide(color: greenD, width: 25, align: AnySide.alignOutside),
            horizontal: AnySide(color: greenL, width: 25, align: AnySide.alignOutside),
            topLeft: RoundedCorner(radius: 2),
            outerTopLeft: RoundedCorner(radius: 2),
            innerTopLeft: BevelCorner(radius: 30),
            topRight: InverseRoundedCorner(radius: 20),
            outerTopRight: InverseRoundedCorner(radius: 20),
            innerTopRight: BevelCorner(radius: 30),
            bottomRight: BevelCorner(radius: 20),
            outerBottomRight: BevelCorner(radius: 20),
            innerBottomRight: RoundedCorner(radius: 40),
            bottomLeft: InverseRoundedCorner(radius: 20),
            outerBottomLeft: InverseRoundedCorner(radius: 20),
            innerBottomLeft: RoundedCorner(radius: 40)),
      ),
    ),
    E(
      title: 'Back+T+B',
      begin: AnyBoxDecoration(
          border: AnyBoxBorder(
              left: AnySide(color: greenD, width: 30, align: AnySide.alignInside),
              top: AnySide(color: greenL, width: 20, align: AnySide.alignOutside),
              right: AnySide(color: greenD, width: 30, align: AnySide.alignInside),
              bottom: AnySide(color: greenL, width: 20, align: AnySide.alignOutside),
              corners: RoundedCorner(radius: 50),
              outerCorners: RoundedCorner(radius: 50),
              innerTopLeft: RoundedCorner.elliptical(p: 20, n: 30),
              innerTopRight: RoundedCorner.elliptical(p: 30, n: 20),
              innerBottomRight: RoundedCorner.elliptical(p: 20, n: 30),
              innerBottomLeft: RoundedCorner.elliptical(p: 30, n: 20)),
          background: AnyBackground(color: greenL, shapeBase: AnyShapeBase.outerBorder)),
      end: AnyBoxDecoration(
          border: AnyBoxBorder(
              left:
                  AnySide(color: greenD, width: 5, align: AnySide.alignOutside),
              top:
                  AnySide(color: greenL, width: 40, align: AnySide.alignInside),
              right:
                  AnySide(color: greenD, width: 5, align: AnySide.alignOutside),
              bottom:
                  AnySide(color: greenL, width: 40, align: AnySide.alignInside),
              corners: RoundedCorner(radius: 20),
              outerCorners: RoundedCorner(radius: 20),
              innerCorners: RoundedCorner()),
          background: AnyBackground(
              color: greenL, shapeBase: AnyShapeBase.outerBorder)),
    ),
    E(
      title: 'Gradient',
      begin: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(
                gradient: gradientBG, width: 20, align: AnySide.alignCenter),
            corners: RoundedCorner(radius: 30)),
        background: AnyBackground(gradient: gradientBGL),
      ),
      end: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(
                gradient: gradientBGL, width: 10, align: AnySide.alignOutside),
            corners: BevelCorner(radius: 40)),
        background: AnyBackground(gradient: gradientBG),
      ),
    ),
    E(
      title: 'Gradient HV',
      begin: AnyBoxDecoration(
          border: AnyBoxBorder(
              horizontal: AnySide(
                  gradient: gradientBG, width: 20, align: AnySide.alignCenter),
              vertical: AnySide(
                  gradient: gradientBGL, width: 20, align: AnySide.alignCenter),
              corners: BevelCorner(radius: 30))),
      end: AnyBoxDecoration(
          border: AnyBoxBorder(
              left: AnySide(
                  gradient: gradientBGL,
                  width: 10,
                  align: AnySide.alignOutside),
              right: AnySide(
                  gradient: gradientBGL,
                  width: 10,
                  align: AnySide.alignOutside),
              top: AnySide(
                  gradient: gradientBG, width: 10, align: AnySide.alignCenter),
              bottom: AnySide(
                  gradient: gradientBG, width: 10, align: AnySide.alignCenter),
              corners: RoundedCorner(radius: 20))),
    ),
    E(
      title: 'Images',
      begin: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(
                image: marbleBlue, width: 20, align: AnySide.alignOutside),
            shape: AnyBoxShape.circle),
        background: AnyBackground(image: marbleGreen),
      ),
      end: AnyBoxDecoration(
          border: AnyBoxBorder(
              sides: AnySide(
                  image: marbleBlue, width: 20, align: AnySide.alignOutside),
              corners: BevelCorner(radius: double.infinity)),
          background: AnyBackground(image: marbleGreen)),
    ),
      E(
        title: 'Multi',
        begin: AnyBoxDecoration.multi(
          offset: 20,
            borders: [
          AnyBoxBorder(
              corners: InverseRoundedCorner(radius: 20),
              sides: AnySide(width: 20, align: AnySide.alignInside, color: greenD)),
          AnyBoxBorder(
              corners: InverseRoundedCorner(radius: 20),
              sides: AnySide(width: 10, align: AnySide.alignInside, color: greenL)),
        ]),
        end: AnyBoxDecoration.multi(borders: [
          AnyBoxBorder(
              corners: InverseRoundedCorner(radius: 28),
              sides: AnySide(width: 30, align: AnySide.alignOutside, color: greenD)),
          AnyBoxBorder(
              corners: InverseRoundedCorner(radius: 28),
              sides: AnySide(width: 15, align: AnySide.alignOutside, color: greenL)),
        ]),
      ),
  ];

  final shadows = [
    H('Shadows'),
    ...buildShadows(blurRadius: 10, colors: [greenL], images: []),
    ...buildShadows(
        blurRadius: 10,
        colors: [],
        images: [marbleBlue],
        spreadRadius: Offset(40, 40),
        corners: BevelCorner(radius: 30)),
  ];

  const custom = [
    H('Custom'),
    E(
      title: 'Tab',
      begin: AnyTabDecoration(
        background: AnyBackground(color: greenL),
        border: AnyBoxBorder(corners: RoundedCorner(radius: 30)),
      ),
      end: AnyTabDecoration(
        background: AnyBackground(color: greenD),
        border: AnyBoxBorder(corners: BevelCorner(radius: 20)),
      ),
    ),
    E(
      title: 'Crown',
      begin: CrownDecoration(
        type: CrownType.flat,
        border: AnyBorder(
            corners: BevelCorner(radius: 20),
            outerCorners: BevelCorner(radius: 20),
            innerCorners: BevelCorner(radius: 8)),
      ),
      end: CrownDecoration(
        type: CrownType.spike,
        border: AnyBorder(
            corners: RoundedCorner(radius: 20),
            outerCorners: RoundedCorner(radius: 20),
            innerCorners: RoundedCorner()),
      ),
    ),
    E(
      title: 'CustomCorner',
      begin: AnyBoxDecoration(
        border: AnyBoxBorder(
          sides: AnySide(color: greenD, width: 10, align: AnySide.alignInside),
          corners: NotchCorner(p: 40, n: 40, bend: 0.2),
        ),
      ),
      end: AnyBoxDecoration(
        border: AnyBoxBorder(
          sides: AnySide(color: greenD, width: 12, align: AnySide.alignInside),
          corners: NotchCorner(p: 30, n: 30, bend: 0.4),
        ),
      ),
    ),
  ];

  return [...box, ...shadows, ...custom];
}

List<E> buildShadows(
    {required List<Color> colors,
    required List<DecorationImage> images,
    double blurRadius = 3.0,
    Offset spreadRadius = const Offset(20, 20),
    Offset shadowOffset = const Offset(15, 15),
    AnyCorner corners = const RoundedCorner(radius: 40)}) {
  final beginColor = colors.firstOrNull;
  final endColor = colors.lastOrNull;

  final beginImage = images.firstOrNull;
  final endImage = images.lastOrNull;

  return [
    E(
      title: 'Normal',
      begin: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(color: greenD, width: 5, align: AnySide.alignCenter),
            corners: corners),
        shadows: [
          AnyShadow(
            color: beginColor,
            image: beginImage,
            spreadRadius: spreadRadius,
            blurRadius: blurRadius,
          )
        ],
      ),
      end: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(color: greenD, width: 2, align: AnySide.alignCenter),
            corners: corners),
        shadows: [
          AnyShadow(
            color: endColor,
            image: endImage,
            spreadRadius: spreadRadius,
            blurRadius: blurRadius * 2,
            offset: shadowOffset,
          )
        ],
      ),
    ),
    E(
      title: 'Inner',
      begin: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(color: greenD, width: 5, align: AnySide.alignCenter),
            corners: corners),
        shadows: [
          AnyShadow(
            style: BlurStyle.inner,
            color: beginColor,
            image: beginImage,
            spreadRadius: spreadRadius,
            blurRadius: blurRadius,
          )
        ],
      ),
      end: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(color: greenD, width: 2, align: AnySide.alignCenter),
            corners: corners),
        shadows: [
          AnyShadow(
            style: BlurStyle.inner,
            color: endColor,
            image: endImage,
            spreadRadius: spreadRadius,
            blurRadius: blurRadius * 2,
            offset: shadowOffset,
          )
        ],
      ),
    ),
    E(
      title: 'Outer',
      begin: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(color: greenD, width: 5, align: AnySide.alignCenter),
            corners: corners),
        shadows: [
          AnyShadow(
            style: BlurStyle.outer,
            color: beginColor,
            image: beginImage,
            spreadRadius: spreadRadius,
            blurRadius: blurRadius,
          )
        ],
      ),
      end: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(color: greenD, width: 2, align: AnySide.alignCenter),
            corners: corners),
        shadows: [
          AnyShadow(
            style: BlurStyle.outer,
            color: endColor,
            image: endImage,
            spreadRadius: spreadRadius,
            blurRadius: blurRadius * 2,
            offset: shadowOffset,
          )
        ],
      ),
    ),
    E(
      title: 'Solid',
      begin: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(color: greenD, width: 5, align: AnySide.alignCenter),
            corners: corners),
        shadows: [
          AnyShadow(
            style: BlurStyle.solid,
            color: beginColor,
            image: beginImage,
            spreadRadius: spreadRadius,
            blurRadius: blurRadius,
          )
        ],
      ),
      end: AnyBoxDecoration(
        border: AnyBoxBorder(
            sides: AnySide(color: greenD, width: 2, align: AnySide.alignCenter),
            corners: corners),
        shadows: [
          AnyShadow(
            style: BlurStyle.solid,
            color: endColor,
            image: endImage,
            spreadRadius: spreadRadius,
            blurRadius: blurRadius * 2,
            offset: shadowOffset,
          )
        ],
      ),
    ),
  ];
}

enum CrownType {
  flat(0, 0.5, greenL, greenD),
  spike(-0.5, 0.25, blueL, blueD);

  final double mainDy, subDy;
  final Color light, dark;

  const CrownType(this.mainDy, this.subDy, this.light, this.dark);
}

class CrownDecoration extends AnyDecoration {
  final CrownType type;

  const CrownDecoration({
    super.background,
    super.border,
    super.offset,
    required this.type,
  });

  @override
  bool operator ==(Object other) {
    return other is CrownDecoration && other.type == type && super == other;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, type.hashCode);

  @override
  List<AnyPoint> buildPoints(
      Rect bounds, TextDirection? textDirection, int borderIndex, double offset) {
    final w4 = bounds.width / 4.0;
    final w2 = bounds.width / 2.0;

    final outer = AnySide(
      width: 20,
      align: AnySide.alignOutside,
      color: type.light,
    );
    final inner = AnySide(
      width: 20,
      align: AnySide.alignInside,
      color: type.dark,
    );

    final subLx = bounds.left + w4;
    final subRx = bounds.right - w4;

    final vertices = [
      bounds.topLeft,
      Offset(subLx, bounds.top + bounds.height * type.subDy),
      Offset(bounds.left + w2, bounds.top + bounds.height * type.mainDy),
      Offset(subRx, bounds.top + bounds.height * type.subDy),
      bounds.topRight,
      bounds.bottomRight,
      Offset(subRx, bounds.bottom),
      Offset(subLx, bounds.bottom),
      bounds.bottomLeft,
    ];
    final sideSettings = [
      inner,
      outer,
      outer,
      inner,
      outer,
      outer,
      inner,
      outer,
      outer
    ];
    final border = borders[borderIndex];
    return offsetPoints(List.generate(vertices.length, (i) {
      // This showcase authors both boundaries. Its valley, tip and lower
      // corners are distinct design choices, independent of the shape band.
      final AnyCorner innerCorner;
      if (i == 0 || i == 4) {
        innerCorner =
            (border.innerCorners ?? border.corners).copyWith(p: 0, n: 0);
      } else if (i == 1 || i == 3) {
        innerCorner = type == CrownType.flat
            ? BevelCorner(radius: 20 * (3 - math.sqrt(2)))
            : const RoundedCorner(radius: 40);
      } else {
        innerCorner = border.innerCorners ?? const RoundedCorner();
      }
      AnyCorner contacts(AnyCorner corner) {
        // The original drawing specified perpendicular corner dimensions.
        // Translate those authored dimensions into 2.0 ray-based parameters
        // to preserve its contact positions, including at non-right angles.
        final u = vertices[(i - 1) % vertices.length] - vertices[i];
        final v = vertices[(i + 1) % vertices.length] - vertices[i];
        final denominator = u.distance * v.distance;
        final sine = (u.dx * v.dy - u.dy * v.dx).abs() / denominator;
        final cosine = (u.dx * v.dx + u.dy * v.dy) / denominator;
        if (sine < 1e-9) return corner.copyWith(p: 0, n: 0);
        final factor = corner is RoundedCorner ? 1 / (1 + cosine) : 1 / sine;
        return corner * factor;
      }

      return point(vertices[i],
          borderIndex: borderIndex,
          side: sideSettings[i],
          outer: contacts(border.outerCorners ?? border.corners),
          inner: contacts(innerCorner));
    }), offset);
  }
}

const greenL = Color(0xFF85AEA8);
const greenD = Color(0xFF2E685F);
const blueL = Color(0xFFC1F1FD);
const blueD = Color(0xFF57B7CF);

const alpha33 = Color(0xAA57B7CF);
const alpha99 = Color(0x882E685F);

const gradientBG = LinearGradient(colors: [greenL, greenD]);
const gradientBGL = LinearGradient(
    colors: [blueL, blueD],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter);

const marbleBlue = const DecorationImage(
  image: AssetImage('images/marble-blue.jpg'),
  fit: BoxFit.cover,
  repeat: ImageRepeat.repeat,
);

const marbleGreen = const DecorationImage(
  image: AssetImage('images/marble-green.jpg'),
  fit: BoxFit.cover,
  repeat: ImageRepeat.repeat,
);

const double w = 200, h = 100;
const constraints = BoxConstraints.tightFor(width: w, height: h);
const double spacing = 100;
const rowLimit = 4;

const duration = Duration(milliseconds: 1000);
const curve = Curves.easeInOut;

const titleStyle = TextStyle(color: alpha99);
const headerStyle =
    TextStyle(color: alpha99, fontSize: 24, fontWeight: FontWeight.w600);

class H extends StatelessWidget {
  final String title;
  const H(this.title);

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsetsGeometry.only(top: spacing / 4, bottom: spacing / 2),
      child: Text(title, style: headerStyle));
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Any Border Examples',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: blueD),
        useMaterial3: true,
      ),
      home: const _ExamplePage(),
    );
  }
}

class _ExampleToggleBus extends ChangeNotifier {
  _ExampleToggleBus._();

  static final _ExampleToggleBus instance = _ExampleToggleBus._();
  bool expanded = false;

  void toggleAll() {
    expanded = !expanded;
    notifyListeners();
  }
}

class _ExamplePage extends StatefulWidget {
  const _ExamplePage();

  @override
  State<_ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<_ExamplePage> {
  static late final List<Widget> _examples = examples();

  Widget row(List<Widget> children) {
    return Padding(
        padding: EdgeInsets.only(bottom: spacing * 0.75),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing,
          children: children,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final ex = _examples;

    List<Widget> children = [];
    List<Widget> row = [];

    void flush() {
      if (row.isNotEmpty) {
        children.add(this.row(row));
        row = [];
      }
    }

    for (var e in ex) {
      if (e is H) {
        flush();
        children.add(e);
      } else {
        row.add(e);
        if (row.length >= rowLimit) flush();
      }
    }

    flush();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _ExampleToggleBus.instance.toggleAll,
      child: Scaffold(
        appBar: AppBar(title: const Text('Any Borders 2.0'), actions: [
          TextButton.icon(
              icon: const Icon(Icons.architecture),
              label: const Text('Inspect corners'),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const CornerInspector()))),
        ]),
        body: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: spacing),
          addAutomaticKeepAlives: false,
          itemCount: children.length,
          itemBuilder: (context, index) => Center(
            child: SizedBox(
              width: rowLimit * w + (rowLimit - 1) * spacing,
              child: children[index],
            ),
          ),
        ),
      ),
    );
  }
}

class E extends StatefulWidget {
  final String title;
  final AnyDecoration begin;
  final AnyDecoration end;

  const E({
    super.key,
    required this.title,
    required this.begin,
    required this.end,
  });

  @override
  State<E> createState() => _EState();
}

class _EState extends State<E> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late AnyDecorationTween _tween;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: duration,
      value: _ExampleToggleBus.instance.expanded ? 1 : 0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: curve);
    _tween = AnyDecorationTween(
      begin: widget.begin,
      end: widget.end,
    );
    _ExampleToggleBus.instance.addListener(_toggle);
  }

  @override
  void didUpdateWidget(covariant E oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.begin != widget.begin || oldWidget.end != widget.end) {
      _tween = AnyDecorationTween(
        begin: widget.begin,
        end: widget.end,
      );
    }
  }

  void _toggle() {
    if (!mounted) return;

    if (_ExampleToggleBus.instance.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _ExampleToggleBus.instance.removeListener(_toggle);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final decoration = _tween.evaluate(_animation);

        return Container(
          constraints: constraints,
          decoration: decoration,
          child: Center(
            child: Text(widget.title, style: titleStyle),
          ),
        );
      },
    );
  }
}
