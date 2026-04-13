
import 'package:collection/collection.dart';
import 'package:example/next.dart';
import 'package:flutter/material.dart';

import 'helpers/builders.dart';

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
    Change('INN', (d) => d.top.align = AnySide.alignInside),
    Change('CEN', (d) => d.top.align = AnySide.alignCenter),
    Change('OUT', (d) => d.top.align = AnySide.alignOutside),
  ]),
  ChangeGroup('TOP', [
    Change('W0', (d) => d.top.width = w0),
    Change('W1', (d) => d.top.width = w1),
  ]),
  ChangeGroup('TOP', [
    Change('C', (d) => d.top.color = c),
    Change('CT', (d) => d.top.color = ct),
  ]),

  ChangeGroup('RIGHT', [
    Change('INN', (d) => d.right.align = AnySide.alignInside),
    Change('CEN', (d) => d.right.align = AnySide.alignCenter),
    Change('OUT', (d) => d.right.align = AnySide.alignOutside),
  ]),
  ChangeGroup('RIGHT', [
    Change('W0', (d) => d.right.width = w0),
    Change('W1', (d) => d.right.width = w1),
    Change('W2', (d) => d.right.width = w2),
  ]),
  ChangeGroup('RIGHT', [
    Change('C', (d) => d.right.color = c),
    Change('CT', (d) => d.right.color = ct),
    Change('CR', (d) => d.right.color = cr),
  ]),
]);


class _ExamplePageState extends State<_ExamplePage> {

  final examples = generator.build();

  // TODO add nice examples instead of
  // static List<(String,AnyDecoration)> nice =
  //   [
  //     ('empty', AnyDecoration(
  //       border: AnyBorder(),
  //     )),
  //
  //     ('border-all', AnyDecoration(
  //       border: AnyBorder(
  //           sides: AnySide(width: w1, color:c)
  //       ),
  //     )),
  //
  //     ('back', AnyDecoration(
  //         border: AnyBorder(),
  //         color: c
  //     )),
  //
  //
  //     ('border-top', AnyDecoration(
  //       border: AnyBorder(
  //           top: AnySide(width: w1, color:ct)
  //       ),
  //       color: c
  //     )),
  //     ('border-top-center', AnyDecoration(
  //       border: AnyBorder(
  //           top: AnySide(width: w1, color:ct, align: AnySide.center)
  //       ),
  //       color: c
  //     )),
  //     ('border-top-outside', AnyDecoration(
  //       border: AnyBorder(
  //           top: AnySide(width: w1, color:ct, align: AnySide.outside)
  //       ),
  //       color: c
  //     )),
  //
  //     ('back-border-top', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct)
  //         ),
  //         color: ct
  //     )),
  //     ('back-border-top-center', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.center)
  //         ),
  //         color: ct
  //     )),
  //     ('back-border-top-outside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.outside)
  //         ),
  //         color: ct
  //     )),
  //
  //     // line
  //
  //     ('border-top-right', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct),
  //             right: AnySide(width: w1, color:ct)
  //         ),
  //         color: c
  //     )),
  //     ('border-top-right-center', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.center),
  //             right: AnySide(width: w1, color:ct, align: AnySide.center)
  //         ),
  //         color: c
  //     )),
  //     ('border-top-right-outside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.outside),
  //             right: AnySide(width: w1, color:ct, align: AnySide.outside)
  //         ),
  //         color: c
  //     )),
  //
  //     ('border-top-inside-right-outside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct),
  //             right: AnySide(width: w1, color:ct, align: AnySide.outside)
  //         ),
  //         color: c
  //     )),
  //     ('border-top-inside-right-center', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct),
  //             right: AnySide(width: w1, color:ct, align: AnySide.center)
  //         ),
  //         color: c
  //     )),
  //
  //     ('border-top-center-right-inside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.center),
  //             right: AnySide(width: w1, color:ct)
  //         ),
  //         color: c
  //     )),
  //
  //     ('border-top-center-right-outside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.center),
  //             right: AnySide(width: w1, color:ct, align: AnySide.outside)
  //         ),
  //         color: c
  //     )),
  //
  //     ('border-top-outside-right-inside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.outside),
  //             right: AnySide(width: w1, color:ct)
  //         ),
  //         color: c
  //     )),
  //
  //     ('border-top-outside-right-center', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.outside),
  //             right: AnySide(width: w1, color:ct, align: AnySide.center)
  //         ),
  //         color: c
  //     )),
  //
  //
  //     ('back-border-top-right', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct),
  //             right: AnySide(width: w1, color:ct)
  //         ),
  //         color: ct
  //     )),
  //     ('back-border-top-right-center', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.center),
  //             right: AnySide(width: w1, color:ct, align: AnySide.center)
  //         ),
  //         color: ct
  //     )),
  //     ('back-border-top-right-outside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.outside),
  //             right: AnySide(width: w1, color:ct, align: AnySide.outside)
  //         ),
  //         color: ct
  //     )),
  //
  //     ('back-border-top-inside-right-outside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct),
  //             right: AnySide(width: w1, color:ct, align: AnySide.outside)
  //         ),
  //         color: ct
  //     )),
  //     ('back-border-top-inside-right-center', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct),
  //             right: AnySide(width: w1, color:ct, align: AnySide.center)
  //         ),
  //         color: ct
  //     )),
  //
  //     ('back-border-top-center-right-inside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.center),
  //             right: AnySide(width: w1, color:ct)
  //         ),
  //         color: ct
  //     )),
  //
  //     ('back-border-top-center-right-outside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.center),
  //             right: AnySide(width: w1, color:ct, align: AnySide.outside)
  //         ),
  //         color: ct
  //     )),
  //
  //     ('back-border-top-outside-right-inside', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.outside),
  //             right: AnySide(width: w1, color:ct)
  //         ),
  //         color: ct
  //     )),
  //
  //     ('back-border-top-outside-right-center', AnyDecoration(
  //         border: AnyBorder(
  //             top: AnySide(width: w1, color:ct, align: AnySide.outside),
  //             right: AnySide(width: w1, color:ct, align: AnySide.center)
  //         ),
  //         color: ct
  //     )),
  //
  //
  //   ];

  Widget row(List<(String, AnyDecoration)> decorations) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: w4,
      children: decorations.map((el) => Stack(
       children: [
         Container(
           constraints: BoxConstraints.tightFor(width: 200, height: 100),
           decoration: el.$2,
           child: Center(child: Text('#${index++} ${el.$1}', style: const TextStyle(color: Colors.black45),)),
         ),
         Positioned(child: Container(
           constraints: BoxConstraints.tightFor(width: 200, height: 100),
           decoration: BoxDecoration(
             border: Border.all(color: Colors.black12)
           ),
         ))
       ])
      ).toList(),
    );
  }

  int index = 0;
  List<int> filterTo = [];

  @override
  Widget build(BuildContext context) {

    index = 0;

    var ex = examples;
    if (filterTo.isNotEmpty) {
      ex = filterTo.map((i) => examples[i]).toList();
    }
    final children = ex.slices(4).map(row).toList();
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: EdgeInsetsGeometry.all(100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: w4,
              children: children,
        ))
      ),
    );
  }
}

/*

[
                Center(child: Container(
                  constraints: BoxConstraints.tightFor(width: 200, height:  100),
                  decoration: AnyTriDecoration(
                    base: AnySide(width: 10, color: Colors.orange),
                    f: AnyCorner(Radius.circular(20)),
                    r: AnyCorner(Radius.circular(30)),
                    background: AnyBackground(color: Colors.blue),
                    type: TriType.topLeft
                  ),
                  child: Center(child: Text("Triangle")),
              ))]

*/