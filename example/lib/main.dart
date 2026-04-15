
import 'package:collection/collection.dart';
import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';

// import 'helpers/builders.dart';

void main() {
  runApp(const MyApp());
}

const blueLight = Colors.lightBlueAccent;
const blue = Colors.blue;

const goldLight = Colors.orangeAccent;
const gold = Colors.orange;

List<Widget> examples() {
  return [
    E2(
      title: 'Crown',
      begin: const CrownDecoration(type: CrownType.flat),
      end: const CrownDecoration(type: CrownType.spike, corners: RoundedCorner(Radius.circular(20)))
    )
  ];
}

const constraints = BoxConstraints.tightFor(width: 200, height: 100);
const double spacing = 40;

const duration = Duration(milliseconds: 500);
const curve = Curves.easeInOut;

const titleStyle = const TextStyle(color: Colors.black45);

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

    var ex = buildExamples();
    final children = ex.slices(4).map(row).toList();
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: EdgeInsetsGeometry.all(100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing,
              children: children,
        ))
      ),
    );
  }
}


class StarDecoration extends AnyDecoration {

  const StarDecoration({super.background, super.sides, super.corners, super.innerCorners});

  @override
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection) {
    // TODO: implement points
    throw UnimplementedError();
  }

}

class AntiStarDecoration extends AnyDecoration {

  const AntiStarDecoration({super.background, super.sides, super.corners, super.innerCorners});

  @override
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection) {
    // TODO: implement points
    throw UnimplementedError();
  }

}

class TabDecoration extends AnyDecoration {

  const TabDecoration({super.background, super.sides, super.corners, super.innerCorners});

  @override
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection) {
    // TODO: implement points
    throw UnimplementedError();
  }

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
  const CrownDecoration({super.background, super.corners, required this.type});

  @override
  bool operator ==(Object other) {
    return other is CrownDecoration && other.type == type && super == other ;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, type.hashCode);

  @override
  List<AnyPoint> points(Rect bounds, TextDirection? textDirection) {

    double w4 = bounds.width / 4.0;
    double w2 = bounds.width / 2.0;

    final outer = AnySide(width: 20, align: AnySide.alignOutside, color: type.light);
    final inner = AnySide(width: 20, align: AnySide.alignInside, color: type.dark);

    final subLx = bounds.left + w4;
    final subRx = bounds.right - w4;

    return [
      point(bounds.topLeft, side: inner),
      point(Offset(subLx, bounds.top + bounds.height * type.subDy), side: outer),
      point(Offset(bounds.left + w2, bounds.top + bounds.height * type.mainDy), side: outer),
      point(Offset(subRx, bounds.top + bounds.height * type.subDy), side: inner),

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

  const E1({super.key, required this.title, required this.decoration, this.border = true});

  @override
  Widget build(BuildContext context) {
    Widget result = Container(
      constraints: constraints,
      decoration: decoration,
      child: Center(child: Text(title, style: titleStyle)),
    );

    if (border) {
      result = Stack(children: [
        result,
        Positioned(child: Container(
          constraints: constraints,
          decoration: BoxDecoration(
              border: Border.all(color: Colors.black12)
          ),
        ))
      ]);
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
    if (_expanded) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
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
      ),
    );

    return result;
  }
}