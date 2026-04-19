import 'dart:math';

import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

const blueLight = Colors.lightBlueAccent;
const blue = Colors.blue;

const goldLight = Colors.orange;
const gold = Colors.deepOrange;

const alpha33 = Color(0x662196F3);
const alpha99 = Color(0x992196F3);

const gradientBG = LinearGradient(colors: [blue, gold]);
const gradientBGL = LinearGradient(colors: [blueLight, goldLight], begin: Alignment.topCenter, end: Alignment.bottomCenter);

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

const confetti = const DecorationImage(
  image: AssetImage('images/confetti.png'),
  fit: BoxFit.cover,
  repeat: ImageRepeat.repeat,
);

List<Widget> examples() {
  return [
    Header('AnyBoxDecoration'),
    E2(
      title: 'L10:inside T20:center\nR30:outside B40:center' ,
      begin: AnyBoxDecoration(
        left: AnySide(color: alpha99, width: 10, align: AnySide.alignInside),
        top: AnySide(color: alpha99, width: 20, align: AnySide.alignCenter),
        right: AnySide(color: alpha99, width: 30, align: AnySide.alignOutside),
        bottom: AnySide(color: alpha99, width: 40, align: AnySide.alignCenter),
        background: AnyBackground(color: alpha33)
      ),
      end: AnyBoxDecoration(
          left: AnySide(color: alpha99, width: 40, align: AnySide.alignOutside),
          top: AnySide(color: alpha99, width: 30, align: AnySide.alignInside),
          right: AnySide(color: alpha99, width: 20, align: AnySide.alignCenter),
          bottom: AnySide(color: alpha99, width: 10, align: AnySide.alignOutside),
          background: AnyBackground(color: alpha33)
      ),
    ),
    E2(
      title: 'Back+T+B' ,
      begin: AnyBoxDecoration(
          left: AnySide(color: blue, width: 30, align: AnySide.alignInside),
          top: AnySide(color: blueLight, width: 20, align: AnySide.alignOutside),
          right: AnySide(color: blue, width: 30, align: AnySide.alignInside),
          bottom: AnySide(color: blueLight, width: 20, align: AnySide.alignOutside),
          background: AnyBackground(color: blueLight)
      ),
      end: AnyBoxDecoration(
          left: AnySide(color: blue, width: 30, align: AnySide.alignOutside),
          top: AnySide(color: blueLight, align: AnySide.alignInside),
          right: AnySide(color: blue, width: 30, align: AnySide.alignOutside),
          bottom: AnySide(color: blueLight, align: AnySide.alignInside),
          background: AnyBackground(color: blueLight)
      ),
    ),
    E2(
      title: 'No background\nRounded' ,
      begin: AnyBoxDecoration(
          vertical: AnySide(color: blue, width: 30, align: AnySide.alignInside),
          horizontal: AnySide(color: blueLight, width: 20, align: AnySide.alignOutside),
          corners: RoundedCorner(radius: 40)
      ),
      end: AnyBoxDecoration(
          vertical: AnySide(color: blue, width: 30, align: AnySide.alignOutside),
          horizontal: AnySide(color: blueLight, align: AnySide.alignInside),
          corners: RoundedCorner(radius: 10)
      ),
    ),
    E2(
      title: 'Gradient' ,
      begin: AnyBoxDecoration(
          sides: AnySide(gradient: gradientBG, width: 20, align: AnySide.alignCenter),
          corners: BevelCorner(radius: 30)
      ),
      end: AnyBoxDecoration(
          sides: AnySide(gradient: gradientBGL, width: 20, align: AnySide.alignOutside),
          corners: RoundedCorner(radius: 40)
      ),
    ),
    E2(
      title: 'Gradient HV' ,
      begin: AnyBoxDecoration(
          left: AnySide(gradient: gradientBGL, width: 20, align: AnySide.alignCenter),
          right: AnySide(gradient: gradientBGL, width: 20, align: AnySide.alignCenter),
          top: AnySide(gradient: gradientBG, width: 20, align: AnySide.alignCenter),
          bottom: AnySide(gradient: gradientBG, width: 20, align: AnySide.alignCenter),
          corners: BevelCorner(radius: 30)
      ),
      end: AnyBoxDecoration(
          left: AnySide(gradient: gradientBGL, width: 10, align: AnySide.alignInside),
          right: AnySide(gradient: gradientBGL, width: 10, align: AnySide.alignInside),
          top: AnySide(gradient: gradientBG, width: 40, align: AnySide.alignCenter),
          bottom: AnySide(gradient: gradientBG, width: 40, align: AnySide.alignCenter),
          corners: RoundedCorner(radius: 50)
      ),
    ),
    E2(
      title: 'Images' ,
      begin: AnyBoxDecoration(
          sides: AnySide(image: marbleBlue, width: 20, align: AnySide.alignInside),
          background: AnyBackground(image: marbleGreen),
          corners: BevelCorner(radius: 30)
      ),
      end: AnyBoxDecoration(
          sides: AnySide(image: marbleBlue, width: 20, align: AnySide.alignOutside),
          background: AnyBackground(image: marbleGreen),
          corners: BevelCorner(radius: double.infinity)
      ),
    ),
    E2(
      title: 'Images' ,
      begin: AnyBoxDecoration(
          sides: AnySide(image: marbleBlue, width: 20, align: AnySide.alignInside),
          background: AnyBackground(image: marbleGreen),
          corners: RoundedCorner(radius:30)
      ),
      end: AnyBoxDecoration(
          sides: AnySide(image: marbleBlue, width: 20, align: AnySide.alignOutside),
          background: AnyBackground(image: marbleGreen),
          corners: RoundedCorner(radius: double.infinity)
      ),
    ),
    Stack(children: [
      SizedBox(width: w, height: h, child:
      DecoratedBox(decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(width: 20, color: alpha33, strokeAlign: AnySide.alignOutside), vertical: BorderSide(width: 20, color: alpha33, strokeAlign: AnySide.alignOutside)),
        borderRadius: BorderRadiusGeometry.only(topLeft: Radius.elliptical(80, 40))
      ),
    )),
    E2(
      title: 'BoxDecoration elliptical\nDiff when Outer' ,
      begin: AnyBoxDecoration(
          sides: AnySide(color: alpha99, width: 20, align: AnySide.alignOutside),
          topLeft: RoundedCorner.elliptical(n: 80, p: 40)
      ),
      end: AnyBoxDecoration(
          sides: AnySide(color: alpha99, width: 20, align: AnySide.alignInside),
          topLeft: RoundedCorner.elliptical(n: 80, p: 40)
      ),
    ),
    ]),
    Header('Shadows'),
    ...buildShadows(blurRadius: 10, colors: [blueLight], images: []),
    ...buildShadows(blurRadius: 10, colors: [], images: [marbleBlue], spreadRadius: Offset(40, 40)),
    Header('Custom (experimental)'),
    E2(
      title: 'Crown',
      begin: CrownDecoration(
          type: CrownType.flat,
          corners: BevelCorner(radius: 0),
      ),
      end: CrownDecoration(
        type: CrownType.spike,
        corners: RoundedCorner(radius: 20),
      ),
    ),
    E2(
      title: 'CrownInv',
      begin: CrownDecoration(type: CrownType.spike, corners: InverseRoundedCorner(radius: 10),),
      end: CrownDecoration(
        type: CrownType.flat,
      ),
    ),
    E2(
      title: 'Tab',
      begin: TabDecoration(
          offset: 20,
          background: AnyBackground(color: alpha99),
          corners: RoundedCorner(radius: 20),
          sides: AnySide(width: 20, color: alpha33, align: AnySide.alignOutside)
      ),
      end: TabDecoration(offset: 30),
    ),
  ];
}

List<E2> buildShadows({
  required List<Color> colors,
  required List<DecorationImage> images,
  double blurRadius = 3.0,
  Offset spreadRadius = const Offset(20, 20),
  Offset shadowOffset = const Offset(15, 15)
}) {
  final beginColor = colors.firstOrNull;
  final endColor = colors.lastOrNull;

  final beginImage = images.firstOrNull;
  final endImage = images.lastOrNull;

  return [
    E2(
      title: 'Normal',
      begin: AnyBoxDecoration(
        sides: AnySide(color: blue, width: 5, align: AnySide.alignCenter),
        corners: RoundedCorner(radius: 40),
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
        sides: AnySide(color: blue, width: 10, align: AnySide.alignCenter),
        corners: RoundedCorner(radius: 40),
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
    E2(
      title: 'Inner',
      begin: AnyBoxDecoration(
        sides: AnySide(color: blue, width: 5, align: AnySide.alignCenter),
        corners: RoundedCorner(radius: 40),
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
        sides: AnySide(color: blue, width: 10, align: AnySide.alignCenter),
        corners: RoundedCorner(radius: 40),
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
    E2(
      title: 'Outer',
      begin: AnyBoxDecoration(
        sides: AnySide(color: blue, width: 5, align: AnySide.alignCenter),
        corners: RoundedCorner(radius: 40),
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
        sides: AnySide(color: blue, width: 10, align: AnySide.alignCenter),
        corners: RoundedCorner(radius: 40),
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
    E2(
      title: 'Solid',
      begin: AnyBoxDecoration(
        sides: AnySide(color: blue, width: 5, align: AnySide.alignCenter),
        corners: RoundedCorner(radius: 40),
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
        sides: AnySide(color: blue, width: 10, align: AnySide.alignCenter),
        corners: RoundedCorner(radius: 40),
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

const double w = 200, h = 100;
const constraints = BoxConstraints.tightFor(width: w, height: h);
const double spacing = 100;
const rowLimit = 4;

const duration = Duration(milliseconds: 500);
const curve = Curves.easeInOut;

const titleStyle = TextStyle(color: Colors.black45);
const headerStyle = TextStyle(color: Colors.black54, fontSize: 24);

class Header extends StatelessWidget {

  final String title;
  const Header(this.title);

  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsetsGeometry.only(top: spacing / 4), child: Text(title, style: headerStyle));
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Any Border Examples',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        useMaterial3: true,
      ),
      home: const _ExamplePage(),
    );
  }
}

class _ExampleToggleBus extends ChangeNotifier {
  _ExampleToggleBus._();

  static final _ExampleToggleBus instance = _ExampleToggleBus._();

  void toggleAll() {
    notifyListeners();
  }
}

class _ExamplePage extends StatefulWidget {
  const _ExamplePage();

  @override
  State<_ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<_ExamplePage> {
  List<Widget> cache = [];

  List<Widget> buildExamples() {

    if (cache.isNotEmpty) return cache;

    // if (cache.isEmpty) {
    //   final decorations = generator.build();
    //   for (int i = 0; i < decorations.length; i++) {
    //     final el = decorations[i];
    //     cache.add(E1(title: '#$i ${el.$1}', decoration: el.$2));
    //   }
    //   return cache;
    // }

    return cache = examples();
  }

  Widget row(List<Widget> children) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {

    final ex = buildExamples();

    List<Widget> children = [];
    List<Widget> row = [];

    void flush() {
      if (row.isNotEmpty) {
        children.add(this.row(row));
        row = [];
      }
    }

    for (var e in ex) {
      if (e is Header) {
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
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing / 2.0,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}


class TabDecoration extends AnyDecoration {

  final double offset;

  const TabDecoration({
    super.background,
    super.sides,
    super.corners,
    super.innerCorners,
    required this.offset
  }) : assert(offset > 0.0);

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection) {

    final offset = min(this.offset, bounds.width / 4.0);
    final c = RoundedCorner(radius: offset);
    final xL = bounds.left + offset;
    final xR = bounds.right - offset;

    return [
      point(bounds.bottomLeft),
      point(Offset(xL, bounds.bottom), outer: c, inner: c),
      point(Offset(xL, bounds.top)),
      point(Offset(xR, bounds.top)),
      point(Offset(xR, bounds.bottom), outer: c, inner: c),
      point(bounds.bottomRight),
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is TabDecoration && other.offset == offset && super == other;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, offset);

}

enum CrownType {
  flat(0, 0.5, blueLight, blue),
  spike(-0.5, 0.25, goldLight, gold);

  final double mainDy, subDy;
  final Color light, dark;

  const CrownType(this.mainDy, this.subDy, this.light, this.dark);
}

class CrownDecoration extends AnyDecoration {
  final CrownType type;

  const CrownDecoration({
    super.background,
    super.corners,
    required this.type,
  });

  @override
  bool operator ==(Object other) {
    return other is CrownDecoration && other.type == type && super == other;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, type.hashCode);

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection) {
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

    return [
      point(bounds.topLeft, side: inner),
      point(
        Offset(subLx, bounds.top + bounds.height * type.subDy),
        side: outer,
      ),
      point(
        Offset(bounds.left + w2, bounds.top + bounds.height * type.mainDy),
        side: outer,
      ),
      point(
        Offset(subRx, bounds.top + bounds.height * type.subDy),
        side: inner,
      ),
      point(bounds.topRight, side: outer),
      point(bounds.bottomRight, side: outer),
      point(Offset(subRx, bounds.bottom), side: inner),
      point(Offset(subLx, bounds.bottom), side: outer),
      point(bounds.bottomLeft, side: outer),
    ];
  }
}

class E1 extends StatelessWidget {
  final bool border;
  final String title;
  final AnyDecoration decoration;

  const E1({
    super.key,
    required this.title,
    required this.decoration,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget result = Container(
      constraints: constraints,
      decoration: decoration,
      child: Center(child: Text(title, style: titleStyle)),
    );

    if (border) {
      result = Stack(
        children: [
          result,
          Positioned(
            child: Container(
              constraints: constraints,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
              ),
            ),
          ),
        ],
      );
    }

    return result;
  }
}

class E2 extends StatefulWidget {
  final String title;
  final AnyDecoration begin;
  final AnyDecoration end;

  const E2({
    super.key,
    required this.title,
    required this.begin,
    required this.end,
  });

  @override
  State<E2> createState() => _E2State();
}

class _E2State extends State<E2> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late AnyDecorationTween _tween;

  bool get _expanded => _controller.value >= 0.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: duration,
    );
    _animation = CurvedAnimation(parent: _controller, curve: curve);
    _tween = AnyDecorationTween(
      begin: widget.begin,
      end: widget.end,
    );
    _ExampleToggleBus.instance.addListener(_toggle);
  }

  @override
  void didUpdateWidget(covariant E2 oldWidget) {
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

    if (_expanded) {
      _controller.reverse();
    } else {
      _controller.forward();
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