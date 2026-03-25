
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


class _ExamplePageState extends State<_ExamplePage> {

  static List<List<AnyDecoration>> examples = [
    [
      AnyDecoration(
        border: AnyBorder(
            sides: AnySide(width: 10.0, color: Colors.blue)
        ),
        color: Colors.lightBlueAccent
      ),
      AnyDecoration(
          border: AnyBorder(
              sides: AnySide(width: 10.0, color: Colors.blue)
          ),
          color: Colors.blue
      ),
      AnyDecoration(
          border: AnyBorder(
              sides: AnySide(width: 10.0, color: Colors.blue)
          ),
      )
    ],
    [
      AnyDecoration(
          border: AnyBorder(
              sides: AnySide(width: 10.0, color: Colors.blue),
              corners: AnyRoundedCorner(Radius.circular(20))
          ),
          color: Colors.lightBlueAccent
      ),
      AnyDecoration(
          border: AnyBorder(
              sides: AnySide(width: 10.0, color: Colors.blue),
              corners: AnyRoundedCorner(Radius.circular(20))
          ),
          color: Colors.blue
      ),
      AnyDecoration(
        border: AnyBorder(
            sides: AnySide(width: 10.0, color: Colors.blue),
            corners: AnyRoundedCorner(Radius.circular(20))
        ),
      )
    ]
  ];

  Widget row(List<AnyDecoration> decorations) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 20,
      children: decorations.map((el) => Container(
        constraints: BoxConstraints.tightFor(width: 200, height: 100),
        decoration: el,
        child: Center(child: Text("AnyBorder", style: TextStyle(color: Colors.black12),)),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 30,
              children: examples.map(row).toList(),
          ),
        ),
    );
  }
}
