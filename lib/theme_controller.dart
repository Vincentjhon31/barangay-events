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
const String _reminderPreferencePrefKey = 'app_reminder_preference';

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

DisplayMode? _displayModeFromName(String? name) {
  for (final value in DisplayMode.values) {
    if (value.name == name) return value;
  }
  return null;
}

/// Whether/when to notify the user before an event they can already see
/// starts — synced to `profiles.reminder_preference`, delivered via the
/// send-event-reminders Edge Function to this account's own FCM topic
/// (see push_notifications.dart's `userTopic`). Uses a `dbValue` rather
/// than Dart's own `.name` since '1h'/'1d' aren't valid identifiers.
enum ReminderPreference {
  off,
  oneHour,
  oneDay;

  String get dbValue => switch (this) {
        ReminderPreference.off => 'off',
        ReminderPreference.oneHour => '1h',
        ReminderPreference.oneDay => '1d',
      };
}

ReminderPreference? _reminderPreferenceFromDbValue(String? value) => switch (value) {
      'off' => ReminderPreference.off,
      '1h' => ReminderPreference.oneHour,
      '1d' => ReminderPreference.oneDay,
      _ => null,
    };

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
    ReminderPreference initialReminderPreference = ReminderPreference.off,
  })  : _themeMode = initial,
        _uiStyle = initialStyle,
        _displayMode = initialDisplayMode,
        _language = _sanitizeLanguage(initialLanguage),
        _reminderPreference = initialReminderPreference;

  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  UiStyle _uiStyle;
  UiStyle get uiStyle => _uiStyle;

  /// Synced to the profile like [themeMode]/[uiStyle]/[locale] — so a
  /// kiosk device (or a reinstall) doesn't need the size re-picked from
  /// scratch every time.
  DisplayMode _displayMode;
  DisplayMode get displayMode => _displayMode;

  /// 'en' or 'fil' — see [supportedLanguageCodes]. Synced to the profile
  /// like [themeMode]/[uiStyle] (unlike [displayMode]): the same person's
  /// language choice should follow them to any device.
  String _language;
  Locale get locale => Locale(_language);

  ReminderPreference _reminderPreference;
  ReminderPreference get reminderPreference => _reminderPreference;

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
  Future<void> applyRemote({
    String? themeMode,
    String? uiStyle,
    String? language,
    String? displayMode,
    String? reminderPreference,
  }) async {
    final mode = _themeModeFromName(themeMode);
    final style = _uiStyleFromName(uiStyle);
    final lang = (language != null && supportedLanguageCodes.contains(language)) ? language : null;
    final display = _displayModeFromName(displayMode);
    final reminder = _reminderPreferenceFromDbValue(reminderPreference);

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
    if (display != null && display != _displayMode) {
      _displayMode = display;
      changed = true;
    }
    if (reminder != null && reminder != _reminderPreference) {
      _reminderPreference = reminder;
      changed = true;
    }
    if (!changed) return;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (mode != null) await prefs.setString(_themeModePrefKey, mode.name);
    if (style != null) await prefs.setString(_uiStylePrefKey, style.name);
    if (lang != null) await prefs.setString(_languagePrefKey, lang);
    if (display != null) await prefs.setString(_displayModePrefKey, display.name);
    if (reminder != null) await prefs.setString(_reminderPreferencePrefKey, reminder.dbValue);
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
    final storedReminderPreference = prefs.getString(_reminderPreferencePrefKey);
    return ThemeController(
      initial: mode,
      initialStyle: style,
      initialDisplayMode: displayMode,
      initialLanguage: _sanitizeLanguage(storedLanguage),
      initialReminderPreference:
          _reminderPreferenceFromDbValue(storedReminderPreference) ?? ReminderPreference.off,
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
      displayMode: _displayMode.name,
      reminderPreference: _reminderPreference.dbValue,
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
      displayMode: _displayMode.name,
      reminderPreference: _reminderPreference.dbValue,
    ));
  }

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
      displayMode: _displayMode.name,
      reminderPreference: _reminderPreference.dbValue,
    ));
  }

  Future<void> setDisplayMode(DisplayMode mode) async {
    if (mode == _displayMode) return;
    _displayMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayModePrefKey, mode.name);
    unawaited(_authService?.savePreferences(
      themeMode: _themeMode.name,
      uiStyle: _uiStyle.name,
      language: _language,
      displayMode: mode.name,
      reminderPreference: _reminderPreference.dbValue,
    ));
  }

  Future<void> setReminderPreference(ReminderPreference preference) async {
    if (preference == _reminderPreference) return;
    _reminderPreference = preference;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderPreferencePrefKey, preference.dbValue);
    unawaited(_authService?.savePreferences(
      themeMode: _themeMode.name,
      uiStyle: _uiStyle.name,
      language: _language,
      displayMode: _displayMode.name,
      reminderPreference: preference.dbValue,
    ));
  }
}
