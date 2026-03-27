
import 'package:collection/collection.dart';
import 'package:example/helpers/builders.dart';
import 'package:flutter/material.dart';
import 'package:any_borders/any_borders.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sparklines Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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

final c = Colors.blue[400];
final cl = Colors.amber[200];
final ct = Colors.purple[300];
final cr = Colors.red[300];
final cb = Colors.green[400];

const w0 = 00.0;
const w1 = 10.0;
const w2 = 20.0;
const w3 = 30.0;
const w4 = 40.0;

final generator = ExampleGenerator([

  ChangeGroup('BACK', [Change('N', (d) => d.color = null), Change('C', (d) => d.color = c)]),

  ChangeGroup('TOP', [
    Change('ALG:INN', (d) => d.border.top.align = AnyAlign.inside),
    Change('ALG:CEN', (d) => d.border.top.align = AnyAlign.center),
    Change('ALG:OUT', (d) => d.border.top.align = AnyAlign.outside),
  ]),
  ChangeGroup('TOP', [
    Change('W0', (d) => d.border.top.width = w0),
    Change('W1', (d) => d.border.top.width = w1),
  ]),
  ChangeGroup('TOP', [
    Change('C', (d) => d.border.top.color = c),
    Change('CT', (d) => d.border.top.color = ct),
  ]),

  ChangeGroup('RIGHT', [
    Change('ALG:INN', (d) => d.border.right.align = AnyAlign.inside),
    Change('ALG:CEN', (d) => d.border.right.align = AnyAlign.center),
    Change('ALG:OUT', (d) => d.border.right.align = AnyAlign.outside),
  ]),
  ChangeGroup('RIGHT', [
    Change('W0', (d) => d.border.right.width = w0),
    Change('W1', (d) => d.border.right.width = w1),
    Change('W2', (d) => d.border.right.width = w2),
  ]),
  ChangeGroup('RIGHT', [
    Change('C', (d) => d.border.right.color = c),
    Change('CT', (d) => d.border.right.color = ct),
    Change('CR', (d) => d.border.right.color = cr),
  ]),
]);


class _ExamplePageState extends State<_ExamplePage> {

  final examples = generator.build();

  // TODO add nice examples instead of
  static List<(String,AnyDecoration)> nice =
    [
      ('empty', AnyDecoration(
        border: AnyBorder(),
      )),

      ('border-all', AnyDecoration(
        border: AnyBorder(
            sides: AnySide(width: w1, color:c)
        ),
      )),

      ('back', AnyDecoration(
          border: AnyBorder(),
          color: c
      )),


      ('border-top', AnyDecoration(
        border: AnyBorder(
            top: AnySide(width: w1, color:ct)
        ),
        color: c
      )),
      ('border-top-center', AnyDecoration(
        border: AnyBorder(
            top: AnySide(width: w1, color:ct, align: AnyAlign.center)
        ),
        color: c
      )),
      ('border-top-outside', AnyDecoration(
        border: AnyBorder(
            top: AnySide(width: w1, color:ct, align: AnyAlign.outside)
        ),
        color: c
      )),

      ('back-border-top', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct)
          ),
          color: ct
      )),
      ('back-border-top-center', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.center)
          ),
          color: ct
      )),
      ('back-border-top-outside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.outside)
          ),
          color: ct
      )),

      // line

      ('border-top-right', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct),
              right: AnySide(width: w1, color:ct)
          ),
          color: c
      )),
      ('border-top-right-center', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.center),
              right: AnySide(width: w1, color:ct, align: AnyAlign.center)
          ),
          color: c
      )),
      ('border-top-right-outside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.outside),
              right: AnySide(width: w1, color:ct, align: AnyAlign.outside)
          ),
          color: c
      )),

      ('border-top-inside-right-outside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct),
              right: AnySide(width: w1, color:ct, align: AnyAlign.outside)
          ),
          color: c
      )),
      ('border-top-inside-right-center', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct),
              right: AnySide(width: w1, color:ct, align: AnyAlign.center)
          ),
          color: c
      )),

      ('border-top-center-right-inside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.center),
              right: AnySide(width: w1, color:ct)
          ),
          color: c
      )),

      ('border-top-center-right-outside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.center),
              right: AnySide(width: w1, color:ct, align: AnyAlign.outside)
          ),
          color: c
      )),

      ('border-top-outside-right-inside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.outside),
              right: AnySide(width: w1, color:ct)
          ),
          color: c
      )),

      ('border-top-outside-right-center', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.outside),
              right: AnySide(width: w1, color:ct, align: AnyAlign.center)
          ),
          color: c
      )),


      ('back-border-top-right', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct),
              right: AnySide(width: w1, color:ct)
          ),
          color: ct
      )),
      ('back-border-top-right-center', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.center),
              right: AnySide(width: w1, color:ct, align: AnyAlign.center)
          ),
          color: ct
      )),
      ('back-border-top-right-outside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.outside),
              right: AnySide(width: w1, color:ct, align: AnyAlign.outside)
          ),
          color: ct
      )),

      ('back-border-top-inside-right-outside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct),
              right: AnySide(width: w1, color:ct, align: AnyAlign.outside)
          ),
          color: ct
      )),
      ('back-border-top-inside-right-center', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct),
              right: AnySide(width: w1, color:ct, align: AnyAlign.center)
          ),
          color: ct
      )),

      ('back-border-top-center-right-inside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.center),
              right: AnySide(width: w1, color:ct)
          ),
          color: ct
      )),

      ('back-border-top-center-right-outside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.center),
              right: AnySide(width: w1, color:ct, align: AnyAlign.outside)
          ),
          color: ct
      )),

      ('back-border-top-outside-right-inside', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.outside),
              right: AnySide(width: w1, color:ct)
          ),
          color: ct
      )),

      ('back-border-top-outside-right-center', AnyDecoration(
          border: AnyBorder(
              top: AnySide(width: w1, color:ct, align: AnyAlign.outside),
              right: AnySide(width: w1, color:ct, align: AnyAlign.center)
          ),
          color: ct
      )),


    ];

  Widget row(List<(String, AnyDecoration)> decorations) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: w4,
      children: decorations.map((el) => Container(
        constraints: BoxConstraints.tightFor(width: 200, height: 100),
        decoration: el.$2,
        child: Center(child: Text(el.$1, style: const TextStyle(color: Colors.black45),)),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: EdgeInsetsGeometry.all(100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: w4,
              children: examples.slices(4).map(row).toList(),
        ))
      ),
    );
  }
}
