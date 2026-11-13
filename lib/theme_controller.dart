import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart' show AppAuthService;
import 'liquid_glass_components.dart' show UiStyle;
import 'responsive_scale.dart' show DisplayMode;
import 'seasonal_theme.dart';

const String _themeModePrefKey = 'app_theme_mode';
const String _uiStylePrefKey = 'app_ui_style';
const String _displayModePrefKey = 'app_display_mode';
const String _languagePrefKey = 'app_language';
const String _reminderPreferencePrefKey = 'app_reminder_preference';
const String _calendarCellStylePrefKey = 'app_calendar_cell_style';
const String _seasonConfigPrefKey = 'app_season_config';
const String _seasonPrefPrefKey = 'app_season_pref';

/// A person's own choice about seasonal themes, kept on the device.
enum SeasonPref { on, noEffects, off }

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

/// How the Month/Week grid shows a day's events: small colored [dots]
/// (the original look), or Google-Calendar-style [titles] (the default) — a colored
/// chip per event, with date-range events drawn as one bar across the
/// days they span. Synced to `profiles.calendar_cell_style` like the
/// appearance settings, so the choice follows the user across sessions
/// and devices.
enum CalendarCellStyle { dots, titles }

CalendarCellStyle? _calendarCellStyleFromName(String? name) {
  for (final value in CalendarCellStyle.values) {
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
    // On by default: every event someone can see gets a reminder unless
    // they turn it off (matches profiles.reminder_preference's default).
    ReminderPreference initialReminderPreference = ReminderPreference.oneHour,
    // Event titles by default (matches profiles.calendar_cell_style).
    CalendarCellStyle initialCalendarCellStyle = CalendarCellStyle.titles,
    // No seasons unless asked for, so a test's look doesn't depend on the
    // date it runs; the real app starts from [load], which defaults to the
    // automatic seasons.
    SeasonConfig initialSeasonConfig = SeasonConfig.off,
    SeasonPref initialSeasonPref = SeasonPref.on,
    DateTime Function() now = DateTime.now,
  })  : _seasonConfig = initialSeasonConfig,
        _seasonPref = initialSeasonPref,
        _now = now,
        _themeMode = initial,
        _uiStyle = initialStyle,
        _displayMode = initialDisplayMode,
        _language = _sanitizeLanguage(initialLanguage),
        _reminderPreference = initialReminderPreference,
        _calendarCellStyle = initialCalendarCellStyle;

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

  CalendarCellStyle _calendarCellStyle;
  CalendarCellStyle get calendarCellStyle => _calendarCellStyle;

  SeasonConfig _seasonConfig;
  SeasonPref _seasonPref;
  SeasonPref get seasonPref => _seasonPref;
  final DateTime Function() _now;

  /// The seasonal look to show now, or null for the regular one.
  Season? get activeSeason => _seasonPref == SeasonPref.off ? null : _seasonConfig.seasonOn(_now());
  bool get seasonEffects => _seasonPref == SeasonPref.on;

  /// Reads the superadmin's seasonal setting from the server. Set once in
  /// main(); null in tests.
  Future<Object?> Function()? seasonConfigFetcher;

  /// Picks up a season change made in the portal (called at launch and each
  /// time the app comes back to the front). Offline or failing, the last
  /// saved setting stays.
  Future<void> refreshSeasonConfig() async {
    final fetch = seasonConfigFetcher;
    if (fetch == null) return;
    try {
      final config = SeasonConfig.fromJson(await fetch());
      final encoded = jsonEncode(config.toJson());
      if (encoded == jsonEncode(_seasonConfig.toJson())) return;
      _seasonConfig = config;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seasonConfigPrefKey, encoded);
    } catch (_) {}
  }

  Future<void> setSeasonPref(SeasonPref pref) async {
    if (pref == _seasonPref) return;
    _seasonPref = pref;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seasonPrefPrefKey, pref.name);
  }

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
    String? calendarCellStyle,
  }) async {
    final mode = _themeModeFromName(themeMode);
    final style = _uiStyleFromName(uiStyle);
    final lang = (language != null && supportedLanguageCodes.contains(language)) ? language : null;
    final display = _displayModeFromName(displayMode);
    final reminder = _reminderPreferenceFromDbValue(reminderPreference);
    final cellStyle = _calendarCellStyleFromName(calendarCellStyle);

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
    if (cellStyle != null && cellStyle != _calendarCellStyle) {
      _calendarCellStyle = cellStyle;
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
    if (cellStyle != null) await prefs.setString(_calendarCellStylePrefKey, cellStyle.name);
  }

  /// Writes every synced setting's current value to the signed-in user's
  /// profile (a no-op until [attachAuthService]).
  void _saveToProfile() {
    unawaited(_authService?.savePreferences(
      themeMode: _themeMode.name,
      uiStyle: _uiStyle.name,
      language: _language,
      displayMode: _displayMode.name,
      reminderPreference: _reminderPreference.dbValue,
      calendarCellStyle: _calendarCellStyle.name,
    ));
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
    final storedCalendarCellStyle = prefs.getString(_calendarCellStylePrefKey);
    var seasonConfig = const SeasonConfig();
    try {
      final stored = prefs.getString(_seasonConfigPrefKey);
      if (stored != null) seasonConfig = SeasonConfig.fromJson(jsonDecode(stored));
    } catch (_) {}
    final storedSeasonPref = prefs.getString(_seasonPrefPrefKey);
    return ThemeController(
      initialSeasonConfig: seasonConfig,
      initialSeasonPref: SeasonPref.values.firstWhere(
        (value) => value.name == storedSeasonPref,
        orElse: () => SeasonPref.on,
      ),
      initial: mode,
      initialStyle: style,
      initialDisplayMode: displayMode,
      initialLanguage: _sanitizeLanguage(storedLanguage),
      initialReminderPreference:
          _reminderPreferenceFromDbValue(storedReminderPreference) ?? ReminderPreference.oneHour,
      initialCalendarCellStyle:
          _calendarCellStyleFromName(storedCalendarCellStyle) ?? CalendarCellStyle.titles,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefKey, mode.name);
    _saveToProfile();
  }

  Future<void> setUiStyle(UiStyle style) async {
    if (style == _uiStyle) return;
    _uiStyle = style;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uiStylePrefKey, style.name);
    _saveToProfile();
  }

  Future<void> setLanguage(String language) async {
    final sanitized = _sanitizeLanguage(language);
    if (sanitized == _language) return;
    _language = sanitized;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, sanitized);
    _saveToProfile();
  }

  Future<void> setDisplayMode(DisplayMode mode) async {
    if (mode == _displayMode) return;
    _displayMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayModePrefKey, mode.name);
    _saveToProfile();
  }

  Future<void> setCalendarCellStyle(CalendarCellStyle style) async {
    if (style == _calendarCellStyle) return;
    _calendarCellStyle = style;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calendarCellStylePrefKey, style.name);
    _saveToProfile();
  }

  Future<void> setReminderPreference(ReminderPreference preference) async {
    if (preference == _reminderPreference) return;
    _reminderPreference = preference;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderPreferencePrefKey, preference.dbValue);
    _saveToProfile();
  }
}
