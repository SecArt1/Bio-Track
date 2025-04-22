import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Default theme mode

  ThemeProvider() {
    _loadThemeMode(); // Load saved preference on initialization
  }

  // --- This getter is crucial for line 47 in main.dart ---
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    _saveThemeMode(_themeMode);
    notifyListeners();
  }

  // Optional: Method to explicitly set the theme mode
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _saveThemeMode(_themeMode);
      notifyListeners();
    }
  }

  // --- Helper methods for persistence (Example using SharedPreferences) ---
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Read 'themeMode' string, default to 'system' if not found
    final themeString = prefs.getString('themeMode') ?? 'system';
    if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    // Notify listeners after loading, in case the initial state changes
    notifyListeners();
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String themeString;
    switch (mode) {
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.system:
      default:
        themeString = 'system';
        break;
    }
    await prefs.setString('themeMode', themeString);
  }
}
