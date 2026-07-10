import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'liquid_glass_components.dart' show UiStyle;

const String _themeModePrefKey = 'app_theme_mode';
const String _uiStylePrefKey = 'app_ui_style';

/// Persists the user's chosen [ThemeMode] (light/dark/system) and
/// [UiStyle] (liquid glass vs solid) across launches using
/// [SharedPreferences].
class ThemeController extends ChangeNotifier {
  ThemeController({
    ThemeMode initial = ThemeMode.dark,
    UiStyle initialStyle = UiStyle.liquid,
  })  : _themeMode = initial,
        _uiStyle = initialStyle;

  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  UiStyle _uiStyle;
  UiStyle get uiStyle => _uiStyle;

  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMode = prefs.getString(_themeModePrefKey);
    final mode = ThemeMode.values.firstWhere(
      (value) => value.name == storedMode,
      orElse: () => ThemeMode.dark,
    );
    final storedStyle = prefs.getString(_uiStylePrefKey);
    final style = UiStyle.values.firstWhere(
      (value) => value.name == storedStyle,
      orElse: () => UiStyle.liquid,
    );
    return ThemeController(initial: mode, initialStyle: style);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefKey, mode.name);
  }

  Future<void> setUiStyle(UiStyle style) async {
    if (style == _uiStyle) return;
    _uiStyle = style;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uiStylePrefKey, style.name);
  }
}
