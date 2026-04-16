import 'dart:math';

import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

const blueLight = Colors.lightBlueAccent;
const blue = Colors.blue;

const goldLight = Colors.red;
const gold = Colors.orange;

const alpha26 = Colors.black26;
const alpha45 = Colors.black45;

List<Widget> examples() {
  return const [
    Header('AnyBoxDecoration'),
    E2(
      title: 'L10:inside T20:center\nR30:outside B40:center' ,
      begin: AnyBoxDecoration(
        left: AnySide(color: alpha45, width: 10, align: AnySide.alignInside),
        top: AnySide(color: alpha45, width: 20, align: AnySide.alignCenter),
        right: AnySide(color: alpha45, width: 30, align: AnySide.alignOutside),
        bottom: AnySide(color: alpha45, width: 40, align: AnySide.alignCenter),
        background: AnyBackground(color: alpha26)
      ),
      end: AnyBoxDecoration(
          left: AnySide(color: alpha45, width: 40, align: AnySide.alignOutside),
          top: AnySide(color: alpha45, width: 30, align: AnySide.alignInside),
          right: AnySide(color: alpha45, width: 20, align: AnySide.alignCenter),
          bottom: AnySide(color: alpha45, width: 10, align: AnySide.alignOutside),
          background: AnyBackground(color: alpha26)
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
          left: AnySide(color: blue, width: 30, align: AnySide.alignInside),
          top: AnySide(color: blueLight, width: 20, align: AnySide.alignOutside),
          right: AnySide(color: blue, width: 30, align: AnySide.alignInside),
          bottom: AnySide(color: blueLight, width: 20, align: AnySide.alignOutside),
          corners: RoundedCorner(radius: Radius.circular(40))
      ),
      end: AnyBoxDecoration(
          left: AnySide(color: blue, width: 30, align: AnySide.alignOutside),
          top: AnySide(color: blueLight, align: AnySide.alignInside),
          right: AnySide(color: blue, width: 30, align: AnySide.alignOutside),
          bottom: AnySide(color: blueLight, align: AnySide.alignInside),
          corners: RoundedCorner(radius: Radius.circular(10))
      ),
    ),
    Header('Experimental'),
    E2(
      title: 'Crown',
      begin: CrownDecoration(
          type: CrownType.flat,
          corners: BevelCorner(radius: Radius.circular(0)),
      ),
      end: CrownDecoration(
        type: CrownType.spike,
        corners: RoundedCorner(radius: Radius.circular(20)),
      ),
    ),
    E2(
      title: 'CrownInv',
      begin: CrownDecoration(type: CrownType.spike, corners: InverseRoundedCorner(radius: Radius.circular(10)),),
      end: CrownDecoration(
        type: CrownType.flat,
      ),
    ),
    E2(
      title: 'Tab',
      begin: TabDecoration(
          offset: 20,
          background: AnyBackground(color: alpha45),
          corners: RoundedCorner(radius: Radius.circular(20)),
          sides: AnySide(width: 20, color: alpha26, align: AnySide.alignOutside)
      ),
      end: TabDecoration(offset: 30),
    ),
  ];
}

const constraints = BoxConstraints.tightFor(width: 200, height: 100);
const double spacing = 100;
const rowLimit = 3;

const duration = Duration(milliseconds: 500);
const curve = Curves.easeInOut;

const titleStyle = TextStyle(color: Colors.black45);
const headerStyle = TextStyle(color: Colors.black54, fontSize: 24);

class Header extends StatelessWidget {

  final String title;
  const Header(this.title);

  @override
  Widget build(BuildContext context) => Text(title, style: headerStyle);
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
          child: Padding(
            padding: const EdgeInsets.all(100),
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
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection) {

    final offset = min(this.offset, bounds.width / 4.0);
    final c = RoundedCorner(radius: Radius.circular(offset));
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
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection) {
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