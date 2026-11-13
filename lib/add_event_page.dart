import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'attachment_image_viewer.dart';
import 'auth_service.dart' show AppUserProfile;
import 'camera_capture_page.dart';
import 'event_calendars.dart';
import 'event_colors.dart';
import 'event_store.dart';
import 'image_prep.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// What `AddEventPage` pops with after a successful save, so the calendar
/// can select the right day and show a confirmation without re-fetching.
/// [dateCount] is how many dates the event is on (see "More dates").
typedef AddEventResult = ({DateTime date, String title, String? groupName, int dateCount});

/// Full-page replacement for the old Add Event modal. Supports both a
/// regular single-day event and a multi-day date range. Also doubles as
/// the Edit Event page — pass [existingEvent] to pre-fill every field and
/// save via `EventRepository.updateEvent` instead of `addEvent`.
class AddEventPage extends StatefulWidget {
  const AddEventPage({
    super.key,
    required this.eventRepository,
    required this.myGroups,
    required this.initialDate,
    required this.creatorProfile,
    required this.findOverlappingEvents,
    required this.suggestFreeSlot,
    this.existingEvent,
    this.seriesSiblings = const [],
    this.lguLocations = const [],
    this.handledCalendars = const [],
  });

  final EventRepository eventRepository;
  final List<BarangayGroup> myGroups;

  /// Admin-curated quick picks for the Location field (see
  /// EventRepository.listLguLocations) — empty just means "no admin
  /// locations set up yet", in which case Location falls back to a plain
  /// text field exactly as before this existed.
  final List<LguLocation> lguLocations;

  /// The superadmin-made calendars (e.g. "Sports") this user handles and
  /// may post to — each becomes a choice next to Public / Group / Personal.
  final List<EventCalendar> handledCalendars;

  /// Pre-clamped by the caller so it's never in the past. Ignored (in
  /// favor of [existingEvent]'s own dates) when editing.
  final DateTime initialDate;
  final AppUserProfile? creatorProfile;

  /// When non-null, this page edits that event instead of creating a new
  /// one — every field pre-filled, saved via `updateEvent`. Its
  /// id/createdAt/creator fields never change regardless of what's edited.
  final BarangayEvent? existingEvent;

  /// When editing ALL dates of an event on several dates: the other dates
  /// (rows) of [existingEvent]'s series. Empty when creating, when editing
  /// an ordinary event, or when editing just one date of a series.
  final List<BarangayEvent> seriesSiblings;

  /// Same-day, same-venue overlap check owned by the calendar screen
  /// (reads its live `_events`) — passed in rather than duplicated here.
  /// Only events at the given location can conflict (see `sameVenue`).
  final List<BarangayEvent> Function(String location, DateTime date, TimeOfDay start, TimeOfDay end)
      findOverlappingEvents;
  final ({TimeOfDay start, TimeOfDay end})? Function(
    String location,
    DateTime date,
    TimeOfDay desiredStart,
    TimeOfDay desiredEnd,
  ) suggestFreeSlot;

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactNumberController = TextEditingController();

  /// Sentinel dropdown value meaning "not one of the quick picks — type it
  /// manually below" (also the default when nothing's been chosen yet).
  static const _customLocationOption = '__custom__';
  String _selectedLocationOption = _customLocationOption;

  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  String _eventType = EventType.public;
  String? _colorKey;
  BarangayGroup? _selectedGroup;
  bool _isMultiDay = false;

  /// Hides the start/end time pickers and saves the event as 00:00–23:59
  /// (see `isAllDayWindow`) — the same window the per-day "All day"
  /// button uses. For a multi-day event this is the default window; a
  /// specific day can still be customized in the per-day schedule.
  bool _isAllDay = false;
  bool _saving = false;

  List<({BarangayEvent event, DateTime day})> _conflicts = const [];
  ({TimeOfDay start, TimeOfDay end})? _suggestedSlot;

  /// Per-day time-of-day overrides for a multi-day event, keyed by
  /// UTC-normalized day (matching `BarangayEvent.dayKey`) — a day missing
  /// from this map uses the default [_startTime]/[_endTime] uniformly,
  /// same as an event that's never had any overrides set.
  final Map<DateTime, ({TimeOfDay start, TimeOfDay end})> _perDayOverrides = {};

  /// "More dates": the start day (a local calendar date, like [_startDate])
  /// of each other date this event happens on, sorted. Every date copies
  /// the first one's length, times, and per-day schedule; each is saved as
  /// its own event, linked by [BarangayEvent.seriesId].
  final List<DateTime> _moreDates = [];

  /// Including the first date.
  static const _maxDates = 60;

  static const _maxAttachments = 5;

  /// Matches the file server's limit (hostinger/public_html/api). Checked
  /// after a picture has been shrunk, so a large phone photo still fits.
  static const _maxAttachmentBytes = 10 * 1024 * 1024;

  /// Already-uploaded attachments — only ever non-empty when editing
  /// (fetched in [initState]), since a brand-new event has no id yet for
  /// [EventRepository.listEventAttachments] to look up.
  List<EventAttachment> _existingAttachments = const [];

  /// Picked-but-not-yet-uploaded files for a brand-new event, held here
  /// until [_save] gets a real event id back — an existing event uploads
  /// immediately on pick instead (see [_pickAttachments]), since it
  /// already has one. Pictures are already shrunk (see [_prepareFile]).
  final List<_PendingAttachment> _pendingAttachments = [];

  bool _pickingAttachments = false;
  final Set<String> _busyAttachmentIds = {};

  /// Thumbnails for [_existingAttachments], fetched in the background as
  /// soon as each one's metadata loads (see [_loadExistingAttachments]) —
  /// a pending file needs no equivalent map, since its bytes are already
  /// here.
  final Map<String, Uint8List> _existingAttachmentThumbnails = {};

  int get _attachmentCount => _existingAttachments.length + _pendingAttachments.length;

  bool get _isEditing => widget.existingEvent != null;

  /// Editing every date of an event on several dates at once.
  bool get _editingAllDates => widget.seriesSiblings.isNotEmpty;

  /// Editing just one date of an event on several dates — its other dates
  /// are left alone, so "More dates" isn't offered.
  bool get _editingOneDate => _isEditing && widget.existingEvent!.isInSeries && !_editingAllDates;

  /// Adding or removing dates creates and deletes events, which only the
  /// person who posted the event may do (the database allows nothing else).
  bool get _canChangeDates =>
      !_isEditing ||
      (widget.existingEvent!.createdById != null &&
          widget.existingEvent!.createdById == widget.creatorProfile?.id);

  /// How many days after its start each date ends (0 = a one-day event).
  int get _spanDays => _utcDay(_endDate).difference(_utcDay(_startDate)).inDays;

  static DateTime _utcDay(DateTime day) => DateTime.utc(day.year, day.month, day.day);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Public needs the Public events admin permission; Group needs an
  /// lgu_member/admin role; Personal is open to everyone signed in. A null [AddEventPage.creatorProfile]
  /// (no session) gets the least-privilege default — Personal only — though
  /// in practice nothing would save without a session anyway, since the
  /// server-side RLS check requires auth.uid() regardless of event_type.
  bool get _canCreatePublic => widget.creatorProfile?.canCreatePublicEvents ?? false;
  bool get _canCreateGroupEvent => widget.creatorProfile?.canCreateGroupEvents ?? false;

  /// The existing event's own type is always included even if the editor
  /// (e.g. a group admin editing someone else's event) couldn't
  /// independently create that type — editing shouldn't force a type
  /// change nobody asked for.
  ///
  /// Values are an [EventType], or [calendarValue] of a calendar this user
  /// handles (see [AddEventPage.handledCalendars]).
  List<String> get _allowedEventTypes => {
        if (_canCreatePublic) EventType.public,
        if (_canCreateGroupEvent) EventType.shared,
        EventType.personal,
        for (final calendar in widget.handledCalendars) calendarValue(calendar.id),
        if (widget.existingEvent != null) _typeValueOf(widget.existingEvent!),
      }.toList();

  static String _typeValueOf(BarangayEvent event) =>
      event.eventType == EventType.calendar && event.calendarId != null
          ? calendarValue(event.calendarId!)
          : event.eventType;

  /// The calendar picked as this event's type, or null for a plain type.
  String? get _calendarId => calendarIdFromValue(_eventType);

  /// The display name for a calendar type value — from the handled list,
  /// or (when editing an event in a calendar this user doesn't handle) the
  /// event's own stored name.
  String _calendarName(String calendarId) {
    for (final calendar in widget.handledCalendars) {
      if (calendar.id == calendarId) return calendar.name;
    }
    return widget.existingEvent?.calendarName ?? 'Calendar';
  }

  EventCalendar? _handledCalendar(String calendarId) {
    for (final calendar in widget.handledCalendars) {
      if (calendar.id == calendarId) return calendar;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEvent;
    if (existing != null) {
      _titleController.text = existing.title;
      // A blank "Other" location comes back as an empty field, not the
      // literal placeholder text, so re-saving keeps it "Other".
      _locationController.text = existing.location == unspecifiedLocation ? '' : existing.location;
      _selectedLocationOption = widget.lguLocations.any((loc) => loc.name == existing.location)
          ? existing.location
          : _customLocationOption;
      _descriptionController.text = existing.description;
      _startDate = DateTime(existing.startTime.year, existing.startTime.month, existing.startTime.day);
      _endDate = DateTime(existing.endTime.year, existing.endTime.month, existing.endTime.day);
      _startTime = TimeOfDay.fromDateTime(existing.startTime);
      _endTime = TimeOfDay.fromDateTime(existing.endTime);
      _eventType = _typeValueOf(existing);
      _colorKey = existing.colorKey;
      _contactNumberController.text = existing.contactNumber ?? '';
      _isMultiDay = existing.isMultiDay;
      _isAllDay = existing.isAllDay;
      for (final group in widget.myGroups) {
        if (group.id == existing.groupId) {
          _selectedGroup = group;
          break;
        }
      }
      for (final override in existing.dailyOverrides) {
        _perDayOverrides[override.day] = (
          start: TimeOfDay(hour: override.startMinutes ~/ 60, minute: override.startMinutes % 60),
          end: TimeOfDay(hour: override.endMinutes ~/ 60, minute: override.endMinutes % 60),
        );
      }
      for (final sibling in widget.seriesSiblings) {
        _moreDates.add(DateTime(sibling.startTime.year, sibling.startTime.month, sibling.startTime.day));
      }
      _moreDates.sort();
      // Every date of an event on several dates shares its home date's files.
      unawaited(_loadExistingAttachments(existing.homeId));
    } else {
      // Callers pass a UTC-midnight day key (e.g. DayDetailPage.date);
      // re-read it as a plain local calendar date so the past-date check
      // against local [_today] doesn't reject "today" on a device west of
      // UTC, where UTC midnight is still yesterday evening.
      final initial = widget.initialDate;
      _startDate = DateTime(initial.year, initial.month, initial.day);
      _endDate = _startDate;
      _eventType = _allowedEventTypes.first;
      _selectedGroup = widget.myGroups.isNotEmpty ? widget.myGroups.first : null;
      _contactNumberController.text = widget.creatorProfile?.phoneNumber ?? '';
    }
    _recomputeConflicts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  static const _allDayStart = TimeOfDay(hour: allDayStartMinutes ~/ 60, minute: allDayStartMinutes % 60);
  static const _allDayEnd = TimeOfDay(hour: allDayEndMinutes ~/ 60, minute: allDayEndMinutes % 60);

  /// [_startTime]/[_endTime], or 00:00–23:59 while [_isAllDay] is on —
  /// the pickers' own values are kept untouched underneath, so turning
  /// All day back off restores whatever times were picked before.
  TimeOfDay get _effectiveStartTime => _isAllDay ? _allDayStart : _startTime;
  TimeOfDay get _effectiveEndTime => _isAllDay ? _allDayEnd : _endTime;

  /// What the location will be saved as — blank means [unspecifiedLocation].
  String get _effectiveLocation {
    final typed = _locationController.text.trim();
    return typed.isEmpty ? unspecifiedLocation : typed;
  }

  String _formatClock(DateTime time) => formatDateTime12Hour(time);

  /// "9:00 AM–10:00 AM", or "All day" for an all-day event.
  String _eventTimeLabel(BarangayEvent event) => event.isAllDay
      ? AppLocalizations.of(context)!.allDayButton
      : '${_formatClock(event.startTime)}–${_formatClock(event.endTime)}';

  DateTime get _startDateTime => DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _effectiveStartTime.hour,
        _effectiveStartTime.minute,
      );

  DateTime get _endDateTime => DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _effectiveEndTime.hour,
        _effectiveEndTime.minute,
      );

  /// This form's own time-of-day window for [day] — the per-day override
  /// in [_perDayOverrides] if that specific day has been customized,
  /// otherwise the default window (see [_effectiveStartTime]) applied
  /// uniformly.
  ({TimeOfDay start, TimeOfDay end}) _windowForFormDay(DateTime day) {
    final normalized = DateTime.utc(day.year, day.month, day.day);
    return _perDayOverrides[normalized] ?? (start: _effectiveStartTime, end: _effectiveEndTime);
  }

  /// Checks every day from [_startDate] to [_endDate] (just [_startDate]
  /// for a single-day event, since they're the same) — and the same days
  /// of every one of [_moreDates] — against
  /// [AddEventPage.findOverlappingEvents], using that day's own window
  /// from [_windowForFormDay] — each existing event's time-of-day window
  /// applies on every day *it* spans too, so a 3-day event timed 7–8 AM
  /// only conflicts with something else scheduled 7–8 AM, leaving the
  /// rest of those days free. An event conflicting on more than one
  /// spanned day is only reported once (its first conflicting day). When
  /// editing, the event being edited (any of its dates) never conflicts
  /// with itself.
  List<({BarangayEvent event, DateTime day})> _computeConflicts() {
    final seen = <String>{};
    final entries = <({BarangayEvent event, DateTime day})>[];
    final ownHomeId = widget.existingEvent?.homeId;
    for (final first in [_startDate, ..._moreDates]) {
      final offset = _utcDay(first).difference(_utcDay(_startDate)).inDays;
      for (var day = _startDate; !day.isAfter(_endDate); day = day.add(const Duration(days: 1))) {
        final window = _windowForFormDay(day);
        final date = DateTime(day.year, day.month, day.day + offset);
        for (final event in widget.findOverlappingEvents(_effectiveLocation, date, window.start, window.end)) {
          if (_isEditing && (event.id == widget.existingEvent!.id || event.homeId == ownHomeId)) continue;
          if (seen.add(event.id)) {
            entries.add((event: event, day: date));
          }
        }
      }
    }
    return entries;
  }

  void _recomputeConflicts() {
    _conflicts = _computeConflicts();
    // Suggesting a single replacement time slot only makes sense for a
    // single-day, timed event — which day/time it'd apply to for a
    // multi-day range isn't well-defined, and an all-day event has no
    // shorter slot to move to.
    _suggestedSlot = (!_isMultiDay && !_isAllDay && _conflicts.isNotEmpty)
        ? widget.suggestFreeSlot(_effectiveLocation, _startDate, _startTime, _endTime)
        : null;
  }

  void _setAllDay(bool value) {
    setState(() {
      _isAllDay = value;
      _recomputeConflicts();
    });
  }

  void _setMultiDay(bool value) {
    setState(() {
      _isMultiDay = value;
      if (!value) {
        _endDate = _startDate;
        _perDayOverrides.clear();
      }
      _recomputeConflicts();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(_today) ? _today : _startDate,
      firstDate: _today,
      lastDate: DateTime.utc(2030, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _endDate = picked;
      _recomputeConflicts();
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(_today) ? _today : _startDate,
      firstDate: _today,
      lastDate: DateTime.utc(2030, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
      _recomputeConflicts();
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.utc(2030, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
      _recomputeConflicts();
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked == null) return;
    setState(() {
      _startTime = picked;
      if (!_isMultiDay && _timeToMinutes(_endTime) <= _timeToMinutes(_startTime)) {
        _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
      }
      _recomputeConflicts();
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked == null) return;
    setState(() {
      _endTime = picked;
      _recomputeConflicts();
    });
  }

  /// Whether a date starting on [start] would overlap the first date or one
  /// of [_moreDates] (each lasts [_spanDays] + 1 days).
  bool _overlapsADate(DateTime start) {
    for (final other in [_startDate, ..._moreDates]) {
      if (_utcDay(start).difference(_utcDay(other)).inDays.abs() <= _spanDays) return true;
    }
    return false;
  }

  /// Two of this event's dates overlap — possible after making the event
  /// longer or moving its first date once more dates were added.
  bool get _datesOverlap {
    final starts = [_startDate, ..._moreDates].map(_utcDay).toList()..sort();
    for (var i = 1; i < starts.length; i++) {
      if (starts[i].difference(starts[i - 1]).inDays <= _spanDays) return true;
    }
    return false;
  }

  /// Replaces whatever message is showing, so adding dates quickly doesn't
  /// queue up a line of stale messages.
  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  static final DateTime _lastPickableDate = DateTime(2030, 12, 31);

  /// A month calendar where several dates can be ticked at once; Done
  /// replaces [_moreDates] with whatever is ticked, Cancel changes nothing.
  Future<void> _pickMoreDates() async {
    final l10n = AppLocalizations.of(context)!;
    final first = _utcDay(_startDate);
    final today = _utcDay(_today);
    final last = _utcDay(_lastPickableDate);
    // Past dates (editing an older series) can't be shown but are kept.
    final picked = {for (final day in _moreDates) _utcDay(day)};
    var focused = first.isBefore(today) ? today : (first.isAfter(last) ? last : first);

    bool overlapsOther(DateTime day) => [first, ...picked]
        .any((other) => other != day && day.difference(other).inDays.abs() <= _spanDays);

    final result = await showDialog<Set<DateTime>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            title: Text(l10n.moreDatesPickHelp),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n.moreDatesPickHint,
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    TableCalendar(
                      key: const Key('add-event-more-dates-calendar'),
                      firstDay: today,
                      lastDay: last,
                      focusedDay: focused,
                      rowHeight: 44,
                      availableGestures: AvailableGestures.horizontalSwipe,
                      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        isTodayHighlighted: false,
                        selectedDecoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                        selectedTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w700),
                      ),
                      selectedDayPredicate: (day) => picked.contains(_utcDay(day)),
                      enabledDayPredicate: (day) {
                        final key = _utcDay(day);
                        if (picked.contains(key)) return true;
                        return picked.length + 1 < _maxDates && !overlapsOther(key);
                      },
                      calendarBuilders: CalendarBuilders(
                        // The first date can't be unticked here: it's set above.
                        prioritizedBuilder: (context, day, _) => _utcDay(day) == first
                            ? Center(
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colorScheme.primary, width: 2),
                                  ),
                                  child: Text('${day.day}', style: TextStyle(color: colorScheme.primary)),
                                ),
                              )
                            : null,
                      ),
                      onDaySelected: (day, focusedDay) => setDialogState(() {
                        focused = focusedDay;
                        final key = _utcDay(day);
                        if (!picked.remove(key)) picked.add(key);
                      }),
                      onPageChanged: (focusedDay) => focused = focusedDay,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        picked.length + 1 >= _maxDates
                            ? l10n.moreDatesTooMany(_maxDates)
                            : l10n.moreDatesCount(picked.length + 1),
                        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('add-event-more-dates-done'),
                onPressed: () => Navigator.pop(dialogContext, picked),
                child: Text(l10n.moreDatesDone),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _moreDates
        ..clear()
        ..addAll(result.map((day) => DateTime(day.year, day.month, day.day)))
        ..sort();
      _recomputeConflicts();
    });
  }

  /// Adds the same weekday(s) of every following week, up to a picked date
  /// — e.g. a Saturday–Sunday event repeated on every weekend of the month.
  Future<void> _repeatWeekly() async {
    final l10n = AppLocalizations.of(context)!;
    if (_spanDays >= 7) {
      _showMessage(l10n.moreDatesTooLongForWeekly);
      return;
    }
    final firstRepeat = DateTime(_startDate.year, _startDate.month, _startDate.day + 7);
    if (firstRepeat.isAfter(_lastPickableDate)) return;
    // About a month ahead, the usual case.
    var initial = DateTime(_startDate.year, _startDate.month + 1, _startDate.day);
    if (initial.isBefore(firstRepeat)) initial = firstRepeat;
    if (initial.isAfter(_lastPickableDate)) initial = _lastPickableDate;
    final until = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstRepeat,
      lastDate: _lastPickableDate,
      helpText: l10n.moreDatesRepeatUntil,
    );
    if (until == null || !mounted) return;
    var added = 0;
    var full = false;
    setState(() {
      for (var day = firstRepeat; !day.isAfter(until); day = DateTime(day.year, day.month, day.day + 7)) {
        if (_moreDates.length + 1 >= _maxDates) {
          full = true;
          break;
        }
        if (_overlapsADate(day)) continue;
        _moreDates.add(day);
        added++;
      }
      _moreDates.sort();
      _recomputeConflicts();
    });
    _showMessage(full ? l10n.moreDatesTooMany(_maxDates) : l10n.moreDatesAdded(added));
  }

  void _removeMoreDate(DateTime day) {
    setState(() {
      _moreDates.remove(day);
      _recomputeConflicts();
    });
  }

  /// "Sat, Nov 7" or "Sat, Nov 7 – Sun, Nov 8" for the date starting on
  /// [start] (with the year when it isn't this year).
  String _dateLabel(DateTime start) {
    String format(DateTime d) => DateFormat(d.year == _today.year ? 'EEE, MMM d' : 'EEE, MMM d, y').format(d);
    if (_spanDays == 0) return format(start);
    return '${format(start)} – ${format(DateTime(start.year, start.month, start.day + _spanDays))}';
  }

  String _typeHelperText() {
    final l10n = AppLocalizations.of(context)!;
    final calendarId = _calendarId;
    final base = calendarId != null
        ? l10n.typeHelperCalendar(_calendarName(calendarId))
        : switch (_eventType) {
            EventType.shared => l10n.typeHelperGroup,
            EventType.personal => l10n.typeHelperPersonal,
            _ => l10n.typeHelperPublic,
          };
    if (_allowedEventTypes.length > 1) return base;
    return '$base ${l10n.typeHelperRestrictedSuffix}';
  }

  /// Shown at save time when [_computeConflicts] still isn't empty — lets
  /// the user post anyway instead of hard-blocking, per feedback that an
  /// overlap is sometimes intentional (e.g. two departments sharing a
  /// venue). The in-form banner above stays as the earlier, softer heads-up;
  /// this dialog is the explicit "are you sure" moment right before saving.
  Future<bool?> _confirmOverlapDialog(
    List<({BarangayEvent event, DateTime day})> conflicts,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: FaIcon(FontAwesomeIcons.triangleExclamation, color: colorScheme.error),
        title: Text(
          conflicts.length == 1
              ? l10n.overlapDialogTitleOne
              : l10n.overlapDialogTitleMany(conflicts.length),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.overlapDialogBody),
              const SizedBox(height: 12),
              for (final entry in conflicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _isMultiDay || _moreDates.isNotEmpty
                        ? '• ${entry.event.title} • ${DateFormat('MMM d').format(entry.day)}, '
                            '${_eventTimeLabel(entry.event)}'
                        : '• ${entry.event.title} • ${_eventTimeLabel(entry.event)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.proceedAnyway),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final location = _effectiveLocation;
    final description = _descriptionController.text.trim();
    final contactNumber = _contactNumberController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.titleRequired)),
      );
      return;
    }

    // Skipped when editing: an existing multi-day event may already be
    // underway (started in the past, still running today or later), and
    // that's exactly the "day 1 already happened, adjust day 2" scenario
    // editing exists for — it shouldn't be blocked by this check.
    if (!_isEditing && _startDate.isBefore(_today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pastDateError)),
      );
      return;
    }

    if (!_endDateTime.isAfter(_startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isMultiDay ? l10n.endAfterStartMultiDay : l10n.endAfterStartSingleDay)),
      );
      return;
    }

    if (_eventType == EventType.shared && _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pickGroupError),
        ),
      );
      return;
    }

    if (_datesOverlap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.moreDatesSomeOverlap)),
      );
      return;
    }

    final finalConflicts = _computeConflicts();
    if (finalConflicts.isNotEmpty) {
      final proceed = await _confirmOverlapDialog(finalConflicts);
      if (!mounted || proceed != true) return;
    }

    final group = _eventType == EventType.shared ? _selectedGroup : null;
    // Filters out any override left over from a wider range the date
    // picker has since been narrowed to (or from before "Multi-day" was
    // ever toggled off and back on) — only days actually in the current
    // range are meaningful to save.
    final dailyOverrides = [
      for (final entry in _perDayOverrides.entries)
        if (!entry.key.isBefore(DateTime.utc(_startDate.year, _startDate.month, _startDate.day)) &&
            !entry.key.isAfter(DateTime.utc(_endDate.year, _endDate.month, _endDate.day)))
          DailyOverride(
            day: entry.key,
            startMinutes: _timeToMinutes(entry.value.start),
            endMinutes: _timeToMinutes(entry.value.end),
          ),
    ];

    // Only for brand-new events: an older event being edited that never
    // had a color keeps its existing fallback look rather than suddenly
    // changing color just because someone fixed a typo in it.
    if (_colorKey == null && !_isEditing) {
      _colorKey = randomEventColorKey();
    }

    setState(() => _saving = true);
    final existing = widget.existingEvent;
    final idBase = DateTime.now().microsecondsSinceEpoch;
    final eventId = existing?.id ?? idBase.toString();

    // The first date, as the form shows it. Every other date is this one
    // moved to another day (see _placed).
    final firstDate = BarangayEvent(
      id: eventId,
      title: title,
      location: location,
      startTime: _startDateTime,
      endTime: _endDateTime,
      description: description,
      createdAt: existing?.createdAt ?? DateTime.now(),
      createdByName: existing != null ? existing.createdByName : widget.creatorProfile?.displayName,
      createdByDepartment: existing != null ? existing.createdByDepartment : widget.creatorProfile?.department,
      createdById: existing != null ? existing.createdById : widget.creatorProfile?.id,
      createdByAvatarUrl: existing != null ? existing.createdByAvatarUrl : widget.creatorProfile?.avatarUrl,
      eventType: _calendarId != null ? EventType.calendar : _eventType,
      calendarId: _calendarId,
      calendarName: _calendarId != null ? _calendarName(_calendarId!) : null,
      colorKey: _colorKey,
      contactNumber: contactNumber.isEmpty ? null : contactNumber,
      groupId: group?.id,
      groupName: group?.name,
      dailyOverrides: dailyOverrides,
    );

    // One date of a series edited on its own keeps its place in the series;
    // otherwise the event is a series exactly when it has more dates.
    final asSeries = !_editingOneDate && (_moreDates.isNotEmpty || _editingAllDates);
    final homeId = existing?.homeId ?? eventId;
    final dateCount = asSeries ? 1 + _moreDates.length : 1;
    var failedDates = 0;
    try {
      final String? firstSeriesId;
      if (_editingOneDate) {
        firstSeriesId = existing!.seriesId;
      } else if (!asSeries) {
        firstSeriesId = null;
      } else if (dateCount > 1 || existing?.id != homeId) {
        // (A date that isn't the home keeps pointing at it even when it's
        // the only date left: deleting the home below hands it the chat
        // and makes it an ordinary event — see rehome_event_series.)
        firstSeriesId = homeId;
      } else {
        firstSeriesId = null;
      }
      final first = _placed(firstDate, id: eventId, startDay: _startDate, seriesId: firstSeriesId);
      // The home date goes first: the other dates can only join a series
      // whose home row already exists.
      if (existing != null) {
        await widget.eventRepository.updateEvent(first);
      } else {
        await widget.eventRepository.addEvent(first);
      }

      if (asSeries) {
        final siblingsByDay = {for (final sibling in widget.seriesSiblings) _utcDay(sibling.startTime): sibling};
        for (var i = 0; i < _moreDates.length; i++) {
          final day = _moreDates[i];
          final sibling = siblingsByDay.remove(_utcDay(day));
          try {
            if (sibling != null) {
              await widget.eventRepository.updateEvent(
                _placed(firstDate, id: sibling.id, startDay: day, seriesId: homeId, keep: sibling),
              );
            } else {
              await widget.eventRepository.addEvent(
                _placed(firstDate, id: (idBase + i + 1).toString(), startDay: day, seriesId: homeId),
              );
            }
          } catch (_) {
            failedDates++;
          }
        }
        // Dates taken off the list. The home date goes last, so its chat
        // and files move to a date that's staying.
        final removed = siblingsByDay.values.toList()..sort((a, b) => (a.id == homeId ? 1 : 0) - (b.id == homeId ? 1 : 0));
        for (final sibling in removed) {
          try {
            await widget.eventRepository.deleteEvent(sibling.id);
          } catch (_) {
            failedDates++;
          }
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.saveEventError(error.toString())),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    if (failedDates > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.moreDatesSomeFailed(failedDates))),
      );
    }

    // Uploaded now that the event has a real id — a brand-new event's id
    // was only ever a locally-generated placeholder until addEvent above
    // actually succeeded. A failed upload here doesn't undo the
    // already-saved event; the user can just re-add the file via Edit.
    // Every date shares the home date's files.
    var failedUploads = 0;
    for (final file in _pendingAttachments) {
      try {
        await widget.eventRepository.uploadEventAttachment(homeId, file.name, file.bytes, mimeType: file.mimeType);
      } catch (_) {
        failedUploads++;
      }
    }
    if (failedUploads > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.attachmentsSomeFailed(failedUploads))),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop<AddEventResult>((
      date: DateTime.utc(_startDate.year, _startDate.month, _startDate.day),
      title: title,
      groupName: group?.name,
      dateCount: dateCount,
    ));
  }

  /// [template] (the form's first date) moved to start on [startDay],
  /// keeping its length, clock times and per-day schedule. [keep] is an
  /// existing date being updated: its own creation details stay.
  static BarangayEvent _placed(
    BarangayEvent template, {
    required String id,
    required DateTime startDay,
    required String? seriesId,
    BarangayEvent? keep,
  }) {
    final offset = _utcDay(startDay).difference(_utcDay(template.startTime)).inDays;
    DateTime shift(DateTime t) => DateTime(t.year, t.month, t.day + offset, t.hour, t.minute);
    return BarangayEvent(
      id: id,
      title: template.title,
      location: template.location,
      startTime: shift(template.startTime),
      endTime: shift(template.endTime),
      description: template.description,
      createdAt: keep?.createdAt ?? template.createdAt,
      createdByName: keep != null ? keep.createdByName : template.createdByName,
      createdByDepartment: keep != null ? keep.createdByDepartment : template.createdByDepartment,
      createdById: keep != null ? keep.createdById : template.createdById,
      createdByAvatarUrl: keep != null ? keep.createdByAvatarUrl : template.createdByAvatarUrl,
      eventType: template.eventType,
      calendarId: template.calendarId,
      calendarName: template.calendarName,
      colorKey: template.colorKey,
      contactNumber: template.contactNumber,
      groupId: template.groupId,
      groupName: template.groupName,
      dailyOverrides: [
        for (final o in template.dailyOverrides)
          DailyOverride(
            day: DateTime.utc(o.day.year, o.day.month, o.day.day + offset),
            startMinutes: o.startMinutes,
            endMinutes: o.endMinutes,
          ),
      ],
      seriesId: seriesId,
    );
  }

  Future<void> _loadExistingAttachments(String eventId) async {
    try {
      final attachments = await widget.eventRepository.listEventAttachments(eventId);
      if (!mounted) return;
      setState(() => _existingAttachments = attachments);
      for (final attachment in attachments) {
        if (attachment.isImage) unawaited(_loadExistingThumbnail(attachment));
      }
    } catch (_) {
      // Section just stays empty — same "fail quiet" treatment as the
      // detail-page attachments list.
    }
  }

  Future<void> _loadExistingThumbnail(EventAttachment attachment) async {
    try {
      final bytes = await widget.eventRepository.downloadEventAttachmentBytes(attachment);
      if (!mounted) return;
      setState(() => _existingAttachmentThumbnails[attachment.id] = bytes);
    } catch (_) {
      // Falls back to the generic file icon just for this one attachment.
    }
  }

  Future<void> _viewImage(Uint8List bytes, String fileName) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentImageViewer(bytes: bytes, fileName: fileName),
      ),
    );
  }

  String? _mimeTypeForExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return null;
    }
  }

  /// A picked file ready to upload: pictures (except GIFs, which may be
  /// animated) are shrunk first — see [shrinkImageForUpload] — and renamed
  /// to .jpg when that re-encoded them.
  Future<_PendingAttachment> _prepareFile(String name, Uint8List bytes, String? extension) async {
    final mime = _mimeTypeForExtension(extension);
    if (mime == null || !mime.startsWith('image/') || mime == 'image/gif') {
      return _PendingAttachment(name: name, bytes: bytes, mimeType: mime);
    }
    final shrunk = await shrinkImageForUpload(bytes);
    if (!shrunk.reencoded) return _PendingAttachment(name: name, bytes: bytes, mimeType: mime);
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    return _PendingAttachment(name: '$base.jpg', bytes: shrunk.bytes, mimeType: 'image/jpeg');
  }

  Future<void> _pickAttachments() async {
    final l10n = AppLocalizations.of(context)!;
    if (_attachmentCount >= _maxAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.attachmentLimitReached(_maxAttachments))),
      );
      return;
    }

    setState(() => _pickingAttachments = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg', 'jpeg', 'png', 'gif', 'webp',
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        ],
      );
      final picked = result?.files ?? const [];

      for (final file in picked) {
        if (_attachmentCount >= _maxAttachments) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.attachmentLimitReached(_maxAttachments))),
            );
          }
          break;
        }
        final raw = file.bytes;
        if (raw == null) continue;
        await _addPrepared(await _prepareFile(file.name, raw, file.extension), file.name);
      }
    } catch (_) {
      // The file picker call itself failing (e.g. the browser blocked or
      // cancelled it) — everything past that point has its own catch.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.attachmentPickError)),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingAttachments = false);
    }
  }

  /// Adds one prepared file: uploaded right away when editing, otherwise
  /// held until the new event is saved.
  Future<void> _addPrepared(_PendingAttachment prepared, String shownName) async {
    final l10n = AppLocalizations.of(context)!;
    if (prepared.bytes.length > _maxAttachmentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.attachmentTooLarge(shownName))),
      );
      return;
    }
    final existing = widget.existingEvent;
    if (existing != null) {
      // Already has a real id — upload right away instead of holding
      // it in _pendingAttachments, which only exists to bridge the
      // "no id yet" gap for a brand-new event.
      try {
        await widget.eventRepository.uploadEventAttachment(
          existing.homeId,
          prepared.name,
          prepared.bytes,
          mimeType: prepared.mimeType,
        );
        await _loadExistingAttachments(existing.homeId);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.attachmentUploadError(shownName)} $error')),
          );
        }
      }
    } else if (mounted) {
      setState(() => _pendingAttachments.add(prepared));
    }
  }

  /// Takes a picture with the in-app camera and attaches it.
  Future<void> _takePhoto() async {
    final l10n = AppLocalizations.of(context)!;
    if (_attachmentCount >= _maxAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.attachmentLimitReached(_maxAttachments))),
      );
      return;
    }
    final bytes = await capturePhotoWithCamera(context);
    if (bytes == null || !mounted) return;
    setState(() => _pickingAttachments = true);
    try {
      final name = 'Photo ${DateFormat('yyyy-MM-dd HH.mm.ss').format(DateTime.now())}.jpg';
      await _addPrepared(await _prepareFile(name, bytes, 'jpg'), name);
    } finally {
      if (mounted) setState(() => _pickingAttachments = false);
    }
  }

  void _removePendingAttachment(_PendingAttachment file) {
    setState(() => _pendingAttachments.remove(file));
  }

  Future<void> _removeExistingAttachment(EventAttachment attachment) async {
    setState(() => _busyAttachmentIds.add(attachment.id));
    try {
      await widget.eventRepository.deleteEventAttachment(attachment);
      if (!mounted) return;
      setState(() {
        _existingAttachments =
            _existingAttachments.where((a) => a.id != attachment.id).toList();
        _busyAttachmentIds.remove(attachment.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyAttachmentIds.remove(attachment.id));
    }
  }

  Widget _buildPickerRow({
    required FaIconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          FaIcon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(l10n.changeButton)),
        ],
      ),
    );
  }

  Widget _buildConflictWarning() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(FontAwesomeIcons.triangleExclamation, size: 13, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _conflicts.length == 1
                        ? l10n.overlapsWithOne
                        : l10n.overlapsWithMany(_conflicts.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.error,
                        ),
                  ),
                ),
              ],
            ),
            for (final entry in _conflicts)
              Padding(
                padding: const EdgeInsets.only(left: 21, top: 3),
                child: Text(
                  _isMultiDay
                      ? '${entry.event.title} • ${DateFormat('MMM d').format(entry.day)}, '
                          '${_eventTimeLabel(entry.event)}'
                      : '${entry.event.title} • ${_eventTimeLabel(entry.event)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_isMultiDay || _isAllDay)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.adjustOverlapHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else if (_suggestedSlot != null) ...[
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _startTime = _suggestedSlot!.start;
                    _endTime = _suggestedSlot!.end;
                    _recomputeConflicts();
                  });
                },
                child: Row(
                  children: [
                    FaIcon(FontAwesomeIcons.lightbulb, size: 13, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.freeSlotSuggestion(
                          formatTimeOfDay12Hour(_suggestedSlot!.start),
                          formatTimeOfDay12Hour(_suggestedSlot!.end),
                        ),
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.noFreeSlotHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// With calendars added, the type picker can outgrow a narrow phone —
  /// then it scrolls sideways instead of overflowing; otherwise it keeps
  /// filling the panel's width as before.
  Widget _maybeScrollable({required bool crowded, required Widget child}) {
    if (!crowded) return child;
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSubPage(
      title: _isEditing ? l10n.editEventTitle : l10n.addEventTitle,
      subtitle: _isEditing ? l10n.editEventSubtitle : l10n.addEventSubtitle,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_allowedEventTypes.length > 1)
                _maybeScrollable(
                  crowded: _allowedEventTypes.length > 3,
                  child: SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                  showSelectedIcon: false,
                  segments: [
                    if (_canCreatePublic)
                      ButtonSegment<String>(
                        value: EventType.public,
                        label: Text(l10n.eventTypePublic),
                        icon: const FaIcon(FontAwesomeIcons.globe, size: 12),
                      ),
                    if (_canCreateGroupEvent)
                      ButtonSegment<String>(
                        value: EventType.shared,
                        label: Text(l10n.eventTypeGroup),
                        icon: const FaIcon(FontAwesomeIcons.userGroup, size: 12),
                      ),
                    ButtonSegment<String>(
                      value: EventType.personal,
                      label: Text(l10n.eventTypePersonal),
                      icon: const FaIcon(FontAwesomeIcons.lock, size: 12),
                    ),
                    for (final value in _allowedEventTypes)
                      if (calendarIdFromValue(value) case final calendarId?)
                        ButtonSegment<String>(
                          value: value,
                          label: Text(_calendarName(calendarId), key: Key('add-event-type-$calendarId')),
                          icon: FaIcon(
                            calendarIcon(_handledCalendar(calendarId)?.icon ?? 'tag'),
                            size: 12,
                            color: eventColorPalette[_handledCalendar(calendarId)?.colorKey],
                          ),
                        ),
                  ],
                  selected: {_eventType},
                  onSelectionChanged: (selection) => setState(() => _eventType = selection.first),
                  ),
                )
              else
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.lock,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.personalEventLabel,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                _typeHelperText(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.eventColorLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final key in eventColorPalette.keys)
                    EventColorSwatch(
                      colorKey: key,
                      selected: _colorKey == key,
                      onTap: () => setState(() => _colorKey = _colorKey == key ? null : key),
                    ),
                  _RandomColorButton(
                    tooltip: l10n.randomColorTooltip,
                    // Always lands on a different color than the current
                    // one, so each tap visibly changes something.
                    onTap: () => setState(() => _colorKey = randomEventColorKey(excluding: _colorKey)),
                  ),
                ],
              ),
              if (_colorKey == null && !_isEditing) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.randomColorHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (_eventType == EventType.shared) ...[
                const SizedBox(height: 12),
                if (widget.myGroups.isEmpty)
                  Text(
                    l10n.noGroupsYetError,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  )
                else
                  DropdownButtonFormField<BarangayGroup>(
                    initialValue: _selectedGroup,
                    decoration: InputDecoration(
                      labelText: l10n.postToGroupLabel,
                      prefixIcon: glassFieldIcon(FontAwesomeIcons.userGroup, size: 14),
                      prefixIconConstraints: glassFieldIconConstraints,
                    ),
                    items: [
                      for (final group in widget.myGroups)
                        DropdownMenuItem(value: group, child: Text(group.name)),
                    ],
                    onChanged: (group) => setState(() => _selectedGroup = group),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.eventTitleLabel,
                  hintText: l10n.eventTitleHint,
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.penToSquare, size: 14),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.lguLocations.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedLocationOption,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.detailLocation,
                    prefixIcon: glassFieldIcon(FontAwesomeIcons.locationDot, size: 14),
                    prefixIconConstraints: glassFieldIconConstraints,
                  ),
                  items: [
                    for (final location in widget.lguLocations)
                      DropdownMenuItem(
                        value: location.name,
                        child: Text(location.name, overflow: TextOverflow.ellipsis),
                      ),
                    DropdownMenuItem(
                      value: _customLocationOption,
                      child: Text(l10n.locationOtherOption, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedLocationOption = value ?? _customLocationOption;
                    _locationController.text =
                        _selectedLocationOption == _customLocationOption ? '' : _selectedLocationOption;
                    _recomputeConflicts();
                  }),
                ),
                if (_selectedLocationOption == _customLocationOption) const SizedBox(height: 12),
              ],
              if (widget.lguLocations.isEmpty || _selectedLocationOption == _customLocationOption)
                TextField(
                  key: const Key('add-event-location-field'),
                  controller: _locationController,
                  onChanged: (_) => setState(_recomputeConflicts),
                  decoration: InputDecoration(
                    labelText: widget.lguLocations.isEmpty ? l10n.detailLocation : l10n.locationCustomLabel,
                    hintText: l10n.locationHint,
                    helperText: l10n.locationOptionalHelper,
                    prefixIcon: glassFieldIcon(FontAwesomeIcons.locationDot, size: 14),
                    prefixIconConstraints: glassFieldIconConstraints,
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactNumberController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.contactNumberLabel,
                  hintText: l10n.contactNumberHint,
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.phone, size: 14),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.additionalDetailsLabel,
                  hintText: l10n.additionalDetailsHint,
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.alignLeft, size: 14),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.attachmentsSectionTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.attachmentsHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    key: const Key('add-event-attachment-button'),
                    onPressed: _pickingAttachments ? null : () => unawaited(_pickAttachments()),
                    icon: _pickingAttachments
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const FaIcon(FontAwesomeIcons.paperclip, size: 14),
                    label: Text(l10n.addAttachmentButton),
                  ),
                  TextButton.icon(
                    key: const Key('add-event-camera-button'),
                    onPressed: _pickingAttachments ? null : () => unawaited(_takePhoto()),
                    icon: const FaIcon(FontAwesomeIcons.camera, size: 14),
                    label: Text(l10n.takePhotoButton),
                  ),
                ],
              ),
              if (_existingAttachments.isNotEmpty || _pendingAttachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final attachment in _existingAttachments)
                  _AttachmentRow(
                    key: Key('existing-attachment-${attachment.id}'),
                    fileName: attachment.fileName,
                    busy: _busyAttachmentIds.contains(attachment.id),
                    onRemove: () => unawaited(_removeExistingAttachment(attachment)),
                    thumbnailBytes: _existingAttachmentThumbnails[attachment.id],
                    onTap: _existingAttachmentThumbnails[attachment.id] == null
                        ? null
                        : () => unawaited(_viewImage(
                              _existingAttachmentThumbnails[attachment.id]!,
                              attachment.fileName,
                            )),
                  ),
                for (final file in _pendingAttachments)
                  _AttachmentRow(
                    key: Key('pending-attachment-${file.name}'),
                    fileName: file.name,
                    busy: false,
                    onRemove: () => _removePendingAttachment(file),
                    thumbnailBytes: file.isImage ? file.bytes : null,
                    onTap: file.isImage ? () => unawaited(_viewImage(file.bytes, file.name)) : null,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.multiDayEventLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          l10n.multiDayEventHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: _isMultiDay, onChanged: _setMultiDay),
                ],
              ),
              const Divider(height: 20),
              if (_isMultiDay) ...[
                _buildPickerRow(
                  icon: FontAwesomeIcons.calendarDay,
                  label: l10n.startDateLabel,
                  value: DateFormat('EEEE, MMM d, yyyy').format(_startDate),
                  onTap: _pickStartDate,
                ),
                _buildPickerRow(
                  icon: FontAwesomeIcons.calendarCheck,
                  label: l10n.endDateLabel,
                  value: DateFormat('EEEE, MMM d, yyyy').format(_endDate),
                  onTap: _pickEndDate,
                ),
              ] else
                _buildPickerRow(
                  icon: FontAwesomeIcons.calendarDays,
                  label: l10n.dateLabel,
                  value: DateFormat('EEEE, MMM d, yyyy').format(_startDate),
                  onTap: _pickDate,
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.allDayEventLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          l10n.allDayEventHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('add-event-all-day-switch'),
                    value: _isAllDay,
                    onChanged: _setAllDay,
                  ),
                ],
              ),
              if (!_isAllDay) ...[
                _buildPickerRow(
                  icon: FontAwesomeIcons.clock,
                  label: _isMultiDay ? l10n.defaultStartTimeLabel : l10n.startTimeLabel,
                  value: formatTimeOfDay12Hour(_startTime),
                  onTap: _pickStartTime,
                ),
                _buildPickerRow(
                  icon: FontAwesomeIcons.hourglassStart,
                  label: _isMultiDay ? l10n.defaultEndTimeLabel : l10n.endTimeLabel,
                  value: formatTimeOfDay12Hour(_endTime),
                  onTap: _pickEndTime,
                ),
              ],
              if (_conflicts.isNotEmpty) _buildConflictWarning(),
            ],
          ),
        ),
        if (_isMultiDay) ...[
          const SizedBox(height: 16),
          _buildPerDaySchedule(),
        ],
        const SizedBox(height: 16),
        if (_editingOneDate) _buildOneDateNote() else _buildMoreDates(),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: _saving ? null : () => unawaited(_save()),
          icon: FaIcon(_isEditing ? FontAwesomeIcons.check : FontAwesomeIcons.calendarPlus, size: 14),
          label: Text(_saving ? l10n.savingButton : (_isEditing ? l10n.saveChangesButton : l10n.saveEventButton)),
        ),
      ],
    );
  }

  /// "More dates": other days this event happens on, e.g. every weekend of
  /// a month — ticked on a calendar, or every week up to a picked date. Each is
  /// a copy of the first date (same length, times and per-day schedule).
  Widget _buildMoreDates() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final count = _moreDates.length + 1;

    Widget dateRow(DateTime start, {required bool first}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            FaIcon(
              first ? FontAwesomeIcons.calendarDay : FontAwesomeIcons.calendarPlus,
              size: 14,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _dateLabel(start),
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (first)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.moreDatesFirst,
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              )
            else if (_canChangeDates)
              IconButton(
                key: Key('add-event-remove-date-${DateFormat('yyyy-MM-dd').format(start)}'),
                tooltip: l10n.moreDatesRemove,
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _removeMoreDate(start),
                icon: FaIcon(FontAwesomeIcons.xmark, size: 14, color: colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      );
    }

    return GlassPanel(
      key: const Key('add-event-more-dates'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.moreDatesTitle,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_moreDates.isNotEmpty)
                Text(
                  l10n.moreDatesCount(count),
                  key: const Key('add-event-date-count'),
                  style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.primary),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _editingAllDates ? l10n.editingAllDatesNote(count) : l10n.moreDatesHint,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (_isEditing && !_canChangeDates) ...[
            const SizedBox(height: 4),
            Text(
              l10n.moreDatesCreatorOnly,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (_moreDates.isNotEmpty) ...[
            const Divider(height: 20),
            dateRow(_startDate, first: true),
            for (final day in _moreDates) dateRow(day, first: false),
          ],
          if (_canChangeDates) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('add-event-add-date'),
                  onPressed: _saving ? null : () => unawaited(_pickMoreDates()),
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 12),
                  label: Text(l10n.moreDatesAdd),
                ),
                OutlinedButton.icon(
                  key: const Key('add-event-repeat-weekly'),
                  onPressed: _saving ? null : () => unawaited(_repeatWeekly()),
                  icon: const FaIcon(FontAwesomeIcons.repeat, size: 12),
                  label: Text(l10n.moreDatesRepeatWeekly),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Shown instead of "More dates" while editing one date of an event on
  /// several dates.
  Widget _buildOneDateNote() {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPanel(
      key: const Key('add-event-one-date-note'),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.circleInfo, size: 14, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.editingOneDateNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// Lists every day the event spans with its own time-of-day window —
  /// "Default" (using the shared start/end time above) unless customized,
  /// e.g. day 1 full day, day 2 just a half-day. Days list is capped
  /// implicitly by the date-range picker; a very long range just scrolls
  /// within the page like everything else here.
  Widget _buildPerDaySchedule() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final days = <DateTime>[];
    for (var d = _startDate; !d.isAfter(_endDate); d = d.add(const Duration(days: 1))) {
      days.add(DateTime.utc(d.year, d.month, d.day));
    }

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.perDayScheduleTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.perDayScheduleHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final day in days) _buildDayOverrideRow(day),
        ],
      ),
    );
  }

  Widget _buildDayOverrideRow(DateTime day) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final override = _perDayOverrides[day];
    final isCustom = override != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(day),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  isCustom
                      ? l10n.timeRange(
                          formatTimeOfDay12Hour(override.start), formatTimeOfDay12Hour(override.end))
                      : _isAllDay
                          ? l10n.defaultAllDaySuffix
                          : l10n.defaultTimeRangeSuffix(
                              formatTimeOfDay12Hour(_startTime), formatTimeOfDay12Hour(_endTime)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (isCustom)
            TextButton(
              onPressed: () => setState(() {
                _perDayOverrides.remove(day);
                _recomputeConflicts();
              }),
              child: Text(l10n.resetButton),
            )
          else
            TextButton(
              onPressed: () => setState(() {
                _perDayOverrides[day] = (start: _allDayStart, end: _allDayEnd);
                _recomputeConflicts();
              }),
              child: Text(l10n.allDayButton),
            ),
          TextButton(
            onPressed: () => unawaited(_customizeDay(day)),
            child: Text(isCustom ? l10n.edit : l10n.customizeButton),
          ),
        ],
      ),
    );
  }

  Future<void> _customizeDay(DateTime day) async {
    final current = _perDayOverrides[day];
    final start = await showTimePicker(
      context: context,
      initialTime: current?.start ?? _startTime,
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: current?.end ?? _endTime,
    );
    if (end == null || !mounted) return;
    setState(() {
      _perDayOverrides[day] = (start: start, end: end);
      _recomputeConflicts();
    });
  }
}

/// A tappable color circle in the event-color picker (see [eventColorPalette]).
/// Also used by the group color picker in GroupMembersPage.
/// Tapping the already-selected swatch clears it back to "no color chosen".
class EventColorSwatch extends StatelessWidget {
  const EventColorSwatch({
    super.key,
    required this.colorKey,
    required this.selected,
    required this.onTap,
  });

  final String colorKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = eventColorPalette[colorKey]!;
    return Tooltip(
      message: eventColorNames[colorKey] ?? colorKey,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}

/// Picks a random color label — sits at the end of the swatch row,
/// same size as a swatch, so it reads as one more option in the picker.
class _RandomColorButton extends StatelessWidget {
  const _RandomColorButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: const Key('add-event-random-color'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.onSurface.withValues(alpha: 0.06),
            border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
          ),
          alignment: Alignment.center,
          child: FaIcon(FontAwesomeIcons.shuffle, size: 14, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// One file in Add Event's attachments list — already uploaded (an
/// [EventAttachment]) or still pending (a [_PendingAttachment]),
/// both rendered identically since the caller (see [AddEventPage])
/// already normalized them down to a filename, an optional thumbnail,
/// and what removing/tapping each one actually does.
class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    super.key,
    required this.fileName,
    required this.busy,
    required this.onRemove,
    this.thumbnailBytes,
    this.onTap,
  });

  final String fileName;
  final bool busy;
  final VoidCallback onRemove;

  /// Non-null only for an image whose bytes have already loaded — see
  /// [AddEventPage]'s _existingAttachmentThumbnails.
  /// A `null` here (whether it's not an image, or its thumbnail just
  /// hasn't loaded yet) falls back to the generic paperclip icon.
  final Uint8List? thumbnailBytes;

  /// Opens the full-screen viewer — only set when [thumbnailBytes] is
  /// available, so tapping a not-yet-loaded or non-image row does nothing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final bytes = thumbnailBytes;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(bytes, width: 28, height: 28, fit: BoxFit.cover),
              )
            else
              FaIcon(FontAwesomeIcons.paperclip, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (busy)
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                onPressed: onRemove,
                icon: FaIcon(FontAwesomeIcons.xmark, size: 14, color: colorScheme.error),
                tooltip: l10n.removeButton,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}

/// A picked file waiting for a brand-new event to save (see
/// [_AddEventPageState._pendingAttachments]).
class _PendingAttachment {
  const _PendingAttachment({required this.name, required this.bytes, this.mimeType});

  final String name;
  final Uint8List bytes;
  final String? mimeType;

  bool get isImage => mimeType?.startsWith('image/') == true;
}
