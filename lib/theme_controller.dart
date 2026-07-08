import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModePrefKey = 'app_theme_mode';

/// Persists the user's chosen [ThemeMode] (light/dark/system) across
/// launches using [SharedPreferences].
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initial = ThemeMode.dark}) : _themeMode = initial;

  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeModePrefKey);
    final mode = ThemeMode.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => ThemeMode.dark,
    );
    return ThemeController(initial: mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefKey, mode.name);
  }
}
