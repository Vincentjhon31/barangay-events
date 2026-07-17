import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart' show AppAuthService;
import 'liquid_glass_components.dart' show UiStyle;
import 'responsive_scale.dart' show DisplayMode;

const String _themeModePrefKey = 'app_theme_mode';
const String _uiStylePrefKey = 'app_ui_style';
const String _displayModePrefKey = 'app_display_mode';
const String _languagePrefKey = 'app_language';

/// Supported language codes — kept as a plain string (not an enum) since
/// this maps directly onto both the `profiles.language` column and
/// Flutter's own `Locale` code, with no extra translation layer needed.
const List<String> supportedLanguageCodes = ['en', 'fil'];

String _sanitizeLanguage(String? code) =>
    supportedLanguageCodes.contains(code) ? code! : 'en';

ThemeMode? _themeModeFromName(String? name) {
  for (final value in ThemeMode.values) {
    if (value.name == name) return value;
  }
  return null;
}

UiStyle? _uiStyleFromName(String? name) {
  for (final value in UiStyle.values) {
    if (value.name == name) return value;
  }
  return null;
}

/// Persists the user's chosen [ThemeMode] (light/dark/system) and
/// [UiStyle] (liquid glass vs solid) across launches using
/// [SharedPreferences] as a fast local cache, and — once
/// [attachAuthService] is called after sign-in — the user's `profiles` row,
/// so the choice follows them to other devices.
class ThemeController extends ChangeNotifier {
  ThemeController({
    ThemeMode initial = ThemeMode.dark,
    UiStyle initialStyle = UiStyle.liquid,
    DisplayMode initialDisplayMode = DisplayMode.auto,
    String initialLanguage = 'en',
  })  : _themeMode = initial,
        _uiStyle = initialStyle,
        _displayMode = initialDisplayMode,
        _language = _sanitizeLanguage(initialLanguage);

  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  UiStyle _uiStyle;
  UiStyle get uiStyle => _uiStyle;

  /// Device-specific, unlike [themeMode]/[uiStyle]/[locale] — a phone and a
  /// kiosk signed into the same account should each keep their own display
  /// size, so this is never synced to the user's profile.
  DisplayMode _displayMode;
  DisplayMode get displayMode => _displayMode;

  /// 'en' or 'fil' — see [supportedLanguageCodes]. Synced to the profile
  /// like [themeMode]/[uiStyle] (unlike [displayMode]): the same person's
  /// language choice should follow them to any device.
  String _language;
  Locale get locale => Locale(_language);

  AppAuthService? _authService;

  /// Lets future [setThemeMode]/[setUiStyle] calls sync to the signed-in
  /// user's profile. Call once after sign-in; pair with [detachAuthService]
  /// on sign-out.
  void attachAuthService(AppAuthService authService) {
    _authService = authService;
  }

  void detachAuthService() {
    _authService = null;
  }

  /// Applies a preference fetched from the user's profile (e.g. right after
  /// signing in on a new device) without writing it straight back to that
  /// same profile.
  Future<void> applyRemote({String? themeMode, String? uiStyle, String? language}) async {
    final mode = _themeModeFromName(themeMode);
    final style = _uiStyleFromName(uiStyle);
    final lang = (language != null && supportedLanguageCodes.contains(language)) ? language : null;

    var changed = false;
    if (mode != null && mode != _themeMode) {
      _themeMode = mode;
      changed = true;
    }
    if (style != null && style != _uiStyle) {
      _uiStyle = style;
      changed = true;
    }
    if (lang != null && lang != _language) {
      _language = lang;
      changed = true;
    }
    if (!changed) return;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (mode != null) await prefs.setString(_themeModePrefKey, mode.name);
    if (style != null) await prefs.setString(_uiStylePrefKey, style.name);
    if (lang != null) await prefs.setString(_languagePrefKey, lang);
  }

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
    final storedDisplayMode = prefs.getString(_displayModePrefKey);
    final displayMode = DisplayMode.values.firstWhere(
      (value) => value.name == storedDisplayMode,
      orElse: () => DisplayMode.auto,
    );
    final storedLanguage = prefs.getString(_languagePrefKey);
    return ThemeController(
      initial: mode,
      initialStyle: style,
      initialDisplayMode: displayMode,
      initialLanguage: _sanitizeLanguage(storedLanguage),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefKey, mode.name);
    unawaited(_authService?.savePreferences(
      themeMode: mode.name,
      uiStyle: _uiStyle.name,
      language: _language,
    ));
  }

  Future<void> setUiStyle(UiStyle style) async {
    if (style == _uiStyle) return;
    _uiStyle = style;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uiStylePrefKey, style.name);
    unawaited(_authService?.savePreferences(
      themeMode: _themeMode.name,
      uiStyle: style.name,
      language: _language,
    ));
  }

  /// Synced to the profile, unlike [setDisplayMode] — see [_language]'s doc.
  Future<void> setLanguage(String language) async {
    final sanitized = _sanitizeLanguage(language);
    if (sanitized == _language) return;
    _language = sanitized;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, sanitized);
    unawaited(_authService?.savePreferences(
      themeMode: _themeMode.name,
      uiStyle: _uiStyle.name,
      language: sanitized,
    ));
  }

  /// Local-only (see [_displayMode]'s doc) — no profile sync call, unlike
  /// [setThemeMode]/[setUiStyle].
  Future<void> setDisplayMode(DisplayMode mode) async {
    if (mode == _displayMode) return;
    _displayMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayModePrefKey, mode.name);
  }
}
