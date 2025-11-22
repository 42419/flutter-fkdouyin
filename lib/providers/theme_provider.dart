import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;
  void toggleManual() {
    if (mode == ThemeMode.system) {
      mode = ThemeMode.light;
    } else if (mode == ThemeMode.light) {
      mode = ThemeMode.dark;
    } else {
      mode = ThemeMode.light;
    }
    notifyListeners();
  }
  void setSystem() { mode = ThemeMode.system; notifyListeners(); }
}
