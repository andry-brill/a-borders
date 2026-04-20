import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';

List<Widget> examples() {
  const box = [
    H('AnyBoxDecoration'),
    E(
      title: 'Any align/width\nLTRB(in:center:out:center)',
      begin: AnyBoxDecoration(
          left: AnySide(color: greenD, width: 10, align: AnySide.alignInside),
          top: AnySide(color: greenD, width: 20, align: AnySide.alignCenter),
          right: AnySide(color: greenD, width: 30, align: AnySide.alignOutside),
          bottom: AnySide(color: greenD, width: 40, align: AnySide.alignCenter),
          corners: RoundedCorner(radius: 10),
          innerCorners: RoundedCorner(radius: 10),
          background: AnyBackground(color: greenL)),
      end: AnyBoxDecoration(
          left: AnySide(color: greenD, width: 40, align: AnySide.alignOutside),
          top: AnySide(color: greenD, width: 30, align: AnySide.alignInside),
          right: AnySide(color: greenD, width: 20, align: AnySide.alignCenter),
          bottom:
              AnySide(color: greenD, width: 10, align: AnySide.alignOutside),
          corners: RoundedCorner(radius: 10),
          innerCorners: RoundedCorner(radius: 10),
          background: AnyBackground(color: greenL)),
    ),
    E(
      title: 'No horizontal',
      begin: AnyBoxDecoration(
        vertical:
            AnySide(color: greenD, width: 30, align: AnySide.alignOutside),
        horizontal: AnySide(color: greenL, align: AnySide.alignInside),
        corners: RoundedCorner(radius: 30),
        innerCorners: RoundedCorner(radius: 30),
      ),
      end: AnyBoxDecoration(
        vertical:
            AnySide(color: greenD, width: 10, align: AnySide.alignOutside),
        horizontal: AnySide(color: greenL, align: AnySide.alignInside),
        corners: RoundedCorner(radius: 20),
        innerCorners: RoundedCorner(radius: 20),
      ),
    ),
    E(
      title: 'Any corner',
      begin: AnyBoxDecoration(
        vertical:
            AnySide(color: greenD, width: 20, align: AnySide.alignOutside),
        horizontal:
            AnySide(color: greenL, width: 20, align: AnySide.alignInside),
        topLeft: RoundedCorner(radius: 2),
        innerTopLeft: BevelCorner(radius: 30),
        topRight: InverseRoundedCorner(radius: 20),
        innerTopRight: BevelCorner(radius: 10),
        bottomRight: BevelCorner(radius: 20),
        innerBottomRight: RoundedCorner(radius: 40),
        bottomLeft: InverseRoundedCorner(radius: 20),
        innerBottomLeft: RoundedCorner(radius: 2),
      ),
      end: AnyBoxDecoration(
        vertical:
            AnySide(color: greenD, width: 25, align: AnySide.alignOutside),
        horizontal:
            AnySide(color: greenL, width: 25, align: AnySide.alignOutside),
        topLeft: RoundedCorner(radius: 2),
        innerTopLeft: BevelCorner(radius: 30),
        topRight: InverseRoundedCorner(radius: 20),
        innerTopRight: BevelCorner(radius: 30),
        bottomRight: BevelCorner(radius: 20),
        innerBottomRight: RoundedCorner(radius: 40),
        bottomLeft: InverseRoundedCorner(radius: 20),
        innerBottomLeft: RoundedCorner(radius: 40),
      ),
    ),
    E(
      title: 'Back+T+B',
      begin: AnyBoxDecoration(
          left: AnySide(color: greenD, width: 30, align: AnySide.alignInside),
          top: AnySide(color: greenL, width: 20, align: AnySide.alignOutside),
          right: AnySide(color: greenD, width: 30, align: AnySide.alignInside),
          bottom:
              AnySide(color: greenL, width: 20, align: AnySide.alignOutside),
          background: AnyBackground(color: greenL),
          corners: RoundedCorner(radius: 50)),
      end: AnyBoxDecoration(
          left: AnySide(color: greenD, width: 5, align: AnySide.alignOutside),
          top: AnySide(color: greenL, width: 40, align: AnySide.alignInside),
          right: AnySide(color: greenD, width: 5, align: AnySide.alignOutside),
          bottom: AnySide(color: greenL, width: 40, align: AnySide.alignInside),
          background: AnyBackground(color: greenL),
          corners: RoundedCorner(radius: 20)),
    ),
    E(
      title: 'Gradient',
      begin: AnyBoxDecoration(
          sides: AnySide(
              gradient: gradientBG, width: 20, align: AnySide.alignCenter),
          background: AnyBackground(gradient: gradientBGL),
          corners: RoundedCorner(radius: 30)),
      end: AnyBoxDecoration(
          sides: AnySide(
              gradient: gradientBGL, width: 10, align: AnySide.alignOutside),
          background: AnyBackground(gradient: gradientBG),
          corners: BevelCorner(radius: 40)),
    ),
    E(
      title: 'Gradient HV',
      begin: AnyBoxDecoration(
          horizontal: AnySide(
              gradient: gradientBG, width: 20, align: AnySide.alignCenter),
          vertical: AnySide(
              gradient: gradientBGL, width: 20, align: AnySide.alignCenter),
          corners: BevelCorner(radius: 30)),
      end: AnyBoxDecoration(
          left: AnySide(
              gradient: gradientBGL, width: 10, align: AnySide.alignOutside),
          right: AnySide(
              gradient: gradientBGL, width: 10, align: AnySide.alignOutside),
          top: AnySide(
              gradient: gradientBG, width: 10, align: AnySide.alignCenter),
          bottom: AnySide(
              gradient: gradientBG, width: 10, align: AnySide.alignCenter),
          corners: RoundedCorner(radius: 20)),
    ),
    E(
      title: 'Images',
      begin: AnyBoxDecoration(
          sides: AnySide(
              image: marbleBlue, width: 20, align: AnySide.alignOutside),
          background: AnyBackground(image: marbleGreen),
          circle: true),
      end: AnyBoxDecoration(
          sides: AnySide(
              image: marbleBlue, width: 20, align: AnySide.alignOutside),
          background: AnyBackground(image: marbleGreen),
          corners: BevelCorner(radius: double.infinity)),
    ),
    Stack(children: [
      SizedBox(
          width: w,
          height: h,
          child: DecoratedBox(
            decoration: BoxDecoration(
                border: Border.symmetric(
                    horizontal: BorderSide(
                        width: 20,
                        color: alpha33,
                        strokeAlign: AnySide.alignOutside),
                    vertical: BorderSide(
                        width: 20,
                        color: alpha33,
                        strokeAlign: AnySide.alignOutside)),
                borderRadius: BorderRadiusGeometry.only(
                    topLeft: Radius.elliptical(80, 40))),
          )),
      E(
        title: 'BoxDecoration elliptical\nDiff when Outer',
        begin: AnyBoxDecoration(
            sides:
                AnySide(color: alpha99, width: 20, align: AnySide.alignOutside),
            topLeft: RoundedCorner.elliptical(n: 80, p: 40)),
        end: AnyBoxDecoration(
            sides:
                AnySide(color: alpha99, width: 20, align: AnySide.alignInside),
            topLeft: RoundedCorner.elliptical(n: 80, p: 40)),
      ),
    ]),
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
      begin: TabDecoration(
        offset: 30,
        background: AnyBackground(color: greenL),
        top: RoundedCorner(radius: 30),
      ),
      end: TabDecoration(
        offset: 20,
        background: AnyBackground(color: greenL),
        top: BevelCorner(radius: 20),
      ),
    ),
    E(
      title: 'Crown',
      begin: CrownDecoration(
        type: CrownType.flat,
        corners: BevelCorner(radius: 20),
      ),
      end: CrownDecoration(
        type: CrownType.spike,
        corners: RoundedCorner(radius: 20),
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
        sides: AnySide(color: greenD, width: 5, align: AnySide.alignCenter),
        corners: corners,
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
        sides: AnySide(color: greenD, width: 2, align: AnySide.alignCenter),
        corners: corners,
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
        sides: AnySide(color: greenD, width: 5, align: AnySide.alignCenter),
        corners: corners,
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
        sides: AnySide(color: greenD, width: 2, align: AnySide.alignCenter),
        corners: corners,
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
        sides: AnySide(color: greenD, width: 5, align: AnySide.alignCenter),
        corners: corners,
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
        sides: AnySide(color: greenD, width: 2, align: AnySide.alignCenter),
        corners: corners,
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
        sides: AnySide(color: greenD, width: 5, align: AnySide.alignCenter),
        corners: corners,
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
        sides: AnySide(color: greenD, width: 2, align: AnySide.alignCenter),
        corners: corners,
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

class TabDecoration extends AnyDecoration {
  final double offset;

  final AnyCorner top;
  final AnyCorner? topInner;

  const TabDecoration(
      {super.background,
      super.sides,
      required this.top,
      this.topInner,
      required this.offset})
      : assert(offset > 0.0);

  @override
  List<AnyPoint> buildPoints(Rect bounds, TextDirection? textDirection) {
    final c = top.copyWith(p: offset, n: offset);
    final xL = bounds.left + offset;
    final xR = bounds.right - offset;

    return [
      point(bounds.bottomLeft),
      point(Offset(xL, bounds.bottom), outer: c, inner: c),
      point(Offset(xL, bounds.top), outer: top, inner: topInner),
      point(Offset(xR, bounds.top), outer: top, inner: topInner),
      point(Offset(xR, bounds.bottom), outer: c, inner: c),
      point(bounds.bottomRight),
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is TabDecoration &&
        other.offset == offset &&
        other.top == top &&
        other.topInner == topInner &&
        super == other;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, offset, top, topInner);
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
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsetsGeometry.only(bottom: spacing, top: spacing),
            child: Center(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            )),
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
