import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Shared toggle and timing for every animated gallery example.
class ExampleToggleBus extends ChangeNotifier {
  ExampleToggleBus._();

  static final ExampleToggleBus instance = ExampleToggleBus._();
  static const duration = Duration(milliseconds: 1000);
  static const curve = Curves.easeInOut;

  bool expanded = false;

  void toggleAll() {
    expanded = !expanded;
    notifyListeners();
  }
}
