
import 'package:collection/collection.dart';
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

final c1 = Colors.blue[100];
final c2 = Colors.blue[300];
final c3 = Colors.blue[500];
final c4 = Colors.blue[700];
final c5 = Colors.blue[900];

const w1 = 10.0;
const w2 = 20.0;
const w3 = 30.0;
const w4 = 40.0;

class _ExamplePageState extends State<_ExamplePage> {

  static List<(String,AnyDecoration)> examples =
    [
      ('Empty', AnyDecoration(
        border: AnyBorder(),
      )),
      ('Background', AnyDecoration(
          border: AnyBorder(),
          color: c1
      )),
      ('', AnyDecoration(
          border: AnyBorder(
              sides: AnySide(width: 10.0, color: Colors.blue)
          ),

      ),
      )
  ];

  Widget row(List<(String, AnyDecoration)> decorations) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: decorations.map((el) => Container(
        constraints: BoxConstraints.tightFor(width: 200, height: 100),
        decoration: el.$2,
        child: Center(child: Text(el.$1, style: TextStyle(color: Colors.black12),)),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 30,
          children: examples.slices(3).map(row).toList(),
      ),
    );
  }
}
