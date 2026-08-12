import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

/// Persisted light/dark/system toggle for the claymorphism theme — mirrors
/// AuthProvider's SharedPreferences pattern.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    _mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  /// Cycles light -> dark -> light for the quick-toggle button in the top
  /// bar (system mode is only reachable via a future settings screen).
  Future<void> toggle() async {
    final next = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setMode(next);
  }

  bool get isDark => _mode == ThemeMode.dark;
}
