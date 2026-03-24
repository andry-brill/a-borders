
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Container(
            constraints: BoxConstraints.tightFor(width: 200, height: 100),
            decoration: AnyDecoration(
                border: AnyBorder(
                  sides: AnySide(width: 5.0, color: Colors.redAccent)
                ),
                color: Colors.blue
            ),
            child: Text("Hello!"),
          ),
        ),
    );
  }
}
