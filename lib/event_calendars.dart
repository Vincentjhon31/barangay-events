import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A superadmin-made calendar, e.g. a "Sports" calendar, managed from the
/// LGU-admin portal's Calendars page. The superadmin assigns the people
/// who handle it (any account). In the app:
/// - everyone sees a filter tab for it after All / Public / Group /
///   Personal, showing that calendar's events (they don't show under
///   Public);
/// - its handlers get it as a choice in Add Event, next to Public / Group /
///   Personal — only they (and the superadmin) can post to it, and any of
///   them can edit its events;
/// - a new event in it notifies everyone, like a Public event.
/// Such an event has `eventType == EventType.calendar` plus a calendarId.
/// See the "Custom calendars" block in supabase/barangay_events.sql.
class EventCalendar {
  const EventCalendar({
    required this.id,
    required this.name,
    this.icon = 'tag',
    this.colorKey,
    this.sortOrder = 0,
    this.archivedAt,
  });

  final String id;
  final String name;

  /// One of [calendarIconKeys] (shared with the portal's icon picker).
  final String icon;

  /// A key of `eventColorPalette` (lib/event_colors.dart), or null.
  final String? colorKey;
  final int sortOrder;

  /// An archived calendar's tab is hidden and nobody can post to it, but
  /// its events stay (under All), and the superadmin can restore it.
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory EventCalendar.fromSupabase(Map<String, dynamic> row) {
    final archived = row['archived_at'];
    return EventCalendar(
      id: row['id'] as String,
      name: (row['name'] as String?)?.trim() ?? '',
      icon: row['icon'] as String? ?? 'tag',
      colorKey: row['color_key'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      archivedAt: archived is String ? DateTime.tryParse(archived) : null,
    );
  }
}

/// Calendar icons, keyed by their Font Awesome name. The portal's icon
/// picker (docs/lgu-admin/index.html, CALENDAR_ICONS) offers exactly these
/// keys, so a calendar always has an icon the app can draw.
const Map<String, FaIconData> calendarIconKeys = {
  'tag': FontAwesomeIcons.tag,
  'basketball': FontAwesomeIcons.basketball,
  'futbol': FontAwesomeIcons.futbol,
  'volleyball': FontAwesomeIcons.volleyball,
  'person-running': FontAwesomeIcons.personRunning,
  'bicycle': FontAwesomeIcons.bicycle,
  'heart-pulse': FontAwesomeIcons.heartPulse,
  'syringe': FontAwesomeIcons.syringe,
  'people-group': FontAwesomeIcons.peopleGroup,
  'music': FontAwesomeIcons.music,
  'palette': FontAwesomeIcons.palette,
  'graduation-cap': FontAwesomeIcons.graduationCap,
  'book': FontAwesomeIcons.book,
  'church': FontAwesomeIcons.church,
  'broom': FontAwesomeIcons.broom,
  'seedling': FontAwesomeIcons.seedling,
  'tree': FontAwesomeIcons.tree,
  'hand-holding-heart': FontAwesomeIcons.handHoldingHeart,
  'briefcase': FontAwesomeIcons.briefcase,
  'bullhorn': FontAwesomeIcons.bullhorn,
  'shield-halved': FontAwesomeIcons.shieldHalved,
  'utensils': FontAwesomeIcons.utensils,
  'award': FontAwesomeIcons.award,
  'star': FontAwesomeIcons.solidStar,
  'heart': FontAwesomeIcons.solidHeart,
};

/// The icon for a calendar's [EventCalendar.icon] key — a tag for an
/// unknown key (e.g. one added to the portal before the app knew it).
FaIconData calendarIcon(String key) => calendarIconKeys[key] ?? FontAwesomeIcons.tag;

/// How a calendar is stored in the Calendar/Feed filter sets and in Add
/// Event's type picker, next to the plain event types ('public',
/// 'shared', 'personal').
const String calendarValuePrefix = 'cal:';

String calendarValue(String calendarId) => '$calendarValuePrefix$calendarId';

/// The calendar id inside a [calendarValue], or null for a plain type.
String? calendarIdFromValue(String value) =>
    value.startsWith(calendarValuePrefix) ? value.substring(calendarValuePrefix.length) : null;
