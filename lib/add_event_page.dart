import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'auth_service.dart' show AppUserProfile;
import 'event_store.dart';
import 'liquid_glass_components.dart';

/// What `AddEventPage` pops with after a successful save, so the calendar
/// can select the right day and show a confirmation without re-fetching.
typedef AddEventResult = ({DateTime date, String title, String? groupName});

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
  });

  final EventRepository eventRepository;
  final List<BarangayGroup> myGroups;

  /// Pre-clamped by the caller so it's never in the past. Ignored (in
  /// favor of [existingEvent]'s own dates) when editing.
  final DateTime initialDate;
  final AppUserProfile? creatorProfile;

  /// When non-null, this page edits that event instead of creating a new
  /// one — every field pre-filled, saved via `updateEvent`. Its
  /// id/createdAt/creator fields never change regardless of what's edited.
  final BarangayEvent? existingEvent;

  /// Same-day overlap check owned by the calendar screen (reads its live
  /// `_events`) — passed in rather than duplicated here.
  final List<BarangayEvent> Function(DateTime date, TimeOfDay start, TimeOfDay end)
      findOverlappingEvents;
  final ({TimeOfDay start, TimeOfDay end})? Function(
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

  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  String _eventType = EventType.public;
  BarangayGroup? _selectedGroup;
  bool _isMultiDay = false;
  bool _saving = false;

  List<({BarangayEvent event, DateTime day})> _conflicts = const [];
  ({TimeOfDay start, TimeOfDay end})? _suggestedSlot;

  /// Per-day time-of-day overrides for a multi-day event, keyed by
  /// UTC-normalized day (matching `BarangayEvent.dayKey`) — a day missing
  /// from this map uses the default [_startTime]/[_endTime] uniformly,
  /// same as an event that's never had any overrides set.
  final Map<DateTime, ({TimeOfDay start, TimeOfDay end})> _perDayOverrides = {};

  bool get _isEditing => widget.existingEvent != null;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Public is superadmin-only; Group needs an lgu_member/superadmin role;
  /// Personal is open to everyone signed in. A null [AddEventPage.creatorProfile]
  /// (no session) gets the least-privilege default — Personal only — though
  /// in practice nothing would save without a session anyway, since the
  /// server-side RLS check requires auth.uid() regardless of event_type.
  bool get _canCreatePublic => widget.creatorProfile?.canCreatePublicEvents ?? false;
  bool get _canCreateGroupEvent => widget.creatorProfile?.canCreateGroupEvents ?? false;

  /// The existing event's own type is always included even if the editor
  /// (e.g. a group admin editing someone else's event) couldn't
  /// independently create that type — editing shouldn't force a type
  /// change nobody asked for.
  List<String> get _allowedEventTypes => {
        if (_canCreatePublic) EventType.public,
        if (_canCreateGroupEvent) EventType.shared,
        EventType.personal,
        if (widget.existingEvent != null) widget.existingEvent!.eventType,
      }.toList();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEvent;
    if (existing != null) {
      _titleController.text = existing.title;
      _locationController.text = existing.location;
      _descriptionController.text = existing.description;
      _startDate = DateTime(existing.startTime.year, existing.startTime.month, existing.startTime.day);
      _endDate = DateTime(existing.endTime.year, existing.endTime.month, existing.endTime.day);
      _startTime = TimeOfDay.fromDateTime(existing.startTime);
      _endTime = TimeOfDay.fromDateTime(existing.endTime);
      _eventType = existing.eventType;
      _isMultiDay = existing.isMultiDay;
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
    } else {
      _startDate = widget.initialDate;
      _endDate = widget.initialDate;
      _eventType = _allowedEventTypes.first;
      _selectedGroup = widget.myGroups.isNotEmpty ? widget.myGroups.first : null;
    }
    _recomputeConflicts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  String _formatClock(DateTime time) => formatDateTime12Hour(time);

  DateTime get _startDateTime => DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

  DateTime get _endDateTime => DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );

  /// This form's own time-of-day window for [day] — the per-day override
  /// in [_perDayOverrides] if that specific day has been customized,
  /// otherwise the default [_startTime]/[_endTime] applied uniformly.
  ({TimeOfDay start, TimeOfDay end}) _windowForFormDay(DateTime day) {
    final normalized = DateTime.utc(day.year, day.month, day.day);
    return _perDayOverrides[normalized] ?? (start: _startTime, end: _endTime);
  }

  /// Checks every day from [_startDate] to [_endDate] (just [_startDate]
  /// for a single-day event, since they're the same) against
  /// [AddEventPage.findOverlappingEvents], using that day's own window
  /// from [_windowForFormDay] — each existing event's time-of-day window
  /// applies on every day *it* spans too, so a 3-day event timed 7–8 AM
  /// only conflicts with something else scheduled 7–8 AM, leaving the
  /// rest of those days free. An event conflicting on more than one
  /// spanned day is only reported once (its first conflicting day). When
  /// editing, the event being edited never conflicts with itself.
  List<({BarangayEvent event, DateTime day})> _computeConflicts() {
    final seen = <String>{};
    final entries = <({BarangayEvent event, DateTime day})>[];
    for (var day = _startDate; !day.isAfter(_endDate); day = day.add(const Duration(days: 1))) {
      final window = _windowForFormDay(day);
      for (final event in widget.findOverlappingEvents(day, window.start, window.end)) {
        if (_isEditing && event.id == widget.existingEvent!.id) continue;
        if (seen.add(event.id)) {
          entries.add((event: event, day: day));
        }
      }
    }
    return entries;
  }

  void _recomputeConflicts() {
    _conflicts = _computeConflicts();
    // Suggesting a single replacement time slot only makes sense for a
    // single-day event — which day/time it'd apply to for a multi-day
    // range isn't well-defined, so it's left off there.
    _suggestedSlot = (!_isMultiDay && _conflicts.isNotEmpty)
        ? widget.suggestFreeSlot(_startDate, _startTime, _endTime)
        : null;
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

  String _typeHelperText() {
    final base = switch (_eventType) {
      EventType.shared => 'Only members of the group you pick can see this.',
      EventType.personal => 'Only you can see this.',
      _ => 'Everyone in the app can see this.',
    };
    if (_allowedEventTypes.length > 1) return base;
    return '$base Only verified LGU members can post Group events, and only '
        'the admin can post Public events.';
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and location are required.')),
      );
      return;
    }

    // Skipped when editing: an existing multi-day event may already be
    // underway (started in the past, still running today or later), and
    // that's exactly the "day 1 already happened, adjust day 2" scenario
    // editing exists for — it shouldn't be blocked by this check.
    if (!_isEditing && _startDate.isBefore(_today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Events can't be added on a past date.")),
      );
      return;
    }

    if (!_endDateTime.isAfter(_startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isMultiDay ? 'End must be after start.' : 'End time must be after start time.')),
      );
      return;
    }

    if (_eventType == EventType.shared && _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a group for this event — create or join one in the Groups tab.'),
        ),
      );
      return;
    }

    final finalConflicts = _computeConflicts();
    if (finalConflicts.isNotEmpty) {
      final first = finalConflicts.first;
      final dayNote = _isMultiDay ? ' on ${DateFormat('MMM d').format(first.day)}' : '';
      final hint = !_isMultiDay && _suggestedSlot != null
          ? ' Try the suggested free time.'
          : ' Pick a different time.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This still overlaps with "${first.event.title}"$dayNote.$hint')),
      );
      return;
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

    setState(() => _saving = true);
    try {
      final existing = widget.existingEvent;
      if (existing != null) {
        await widget.eventRepository.updateEvent(
          BarangayEvent(
            id: existing.id,
            title: title,
            location: location,
            startTime: _startDateTime,
            endTime: _endDateTime,
            description: description,
            hasAttachment: existing.hasAttachment,
            attachmentType: existing.attachmentType,
            createdAt: existing.createdAt,
            createdByName: existing.createdByName,
            createdByDepartment: existing.createdByDepartment,
            createdById: existing.createdById,
            eventType: _eventType,
            groupId: group?.id,
            groupName: group?.name,
            dailyOverrides: dailyOverrides,
          ),
        );
      } else {
        await widget.eventRepository.addEvent(
          BarangayEvent(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title,
            location: location,
            startTime: _startDateTime,
            endTime: _endDateTime,
            description: description,
            hasAttachment: false,
            createdAt: DateTime.now(),
            createdByName: widget.creatorProfile?.displayName,
            createdByDepartment: widget.creatorProfile?.department,
            createdById: widget.creatorProfile?.id,
            eventType: _eventType,
            groupId: group?.id,
            groupName: group?.name,
            dailyOverrides: dailyOverrides,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save the event: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop<AddEventResult>((
      date: DateTime.utc(_startDate.year, _startDate.month, _startDate.day),
      title: title,
      groupName: group?.name,
    ));
  }

  Widget _buildPickerRow({
    required FaIconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
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
          TextButton(onPressed: onTap, child: const Text('Change')),
        ],
      ),
    );
  }

  Widget _buildConflictWarning() {
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
                        ? 'Overlaps with an existing event:'
                        : 'Overlaps with ${_conflicts.length} existing events:',
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
                          '${_formatClock(entry.event.startTime)}–${_formatClock(entry.event.endTime)}'
                      : '${entry.event.title} • ${_formatClock(entry.event.startTime)}–'
                          '${_formatClock(entry.event.endTime)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_isMultiDay)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Adjust the time or date range to clear the overlap.',
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
                        'Free slot: ${formatTimeOfDay12Hour(_suggestedSlot!.start)} – '
                        '${formatTimeOfDay12Hour(_suggestedSlot!.end)} · Tap to use',
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
                  'No free slot left that day — try another date.',
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSubPage(
      title: _isEditing ? 'Edit Event' : 'Add Event',
      subtitle: _isEditing
          ? 'Update the details for this event.'
          : 'Share something happening in the barangay.',
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_allowedEventTypes.length > 1)
                SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                  showSelectedIcon: false,
                  segments: [
                    if (_canCreatePublic)
                      const ButtonSegment<String>(
                        value: EventType.public,
                        label: Text('Public'),
                        icon: FaIcon(FontAwesomeIcons.globe, size: 12),
                      ),
                    if (_canCreateGroupEvent)
                      const ButtonSegment<String>(
                        value: EventType.shared,
                        label: Text('Group'),
                        icon: FaIcon(FontAwesomeIcons.userGroup, size: 12),
                      ),
                    const ButtonSegment<String>(
                      value: EventType.personal,
                      label: Text('Personal'),
                      icon: FaIcon(FontAwesomeIcons.lock, size: 12),
                    ),
                  ],
                  selected: {_eventType},
                  onSelectionChanged: (selection) => setState(() => _eventType = selection.first),
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
                      'Personal event',
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
              if (_eventType == EventType.shared) ...[
                const SizedBox(height: 12),
                if (widget.myGroups.isEmpty)
                  Text(
                    'You have no groups yet — create one in the Groups tab first.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  )
                else
                  DropdownButtonFormField<BarangayGroup>(
                    initialValue: _selectedGroup,
                    decoration: InputDecoration(
                      labelText: 'Post to group',
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
                  labelText: 'Event title',
                  hintText: 'e.g. Barangay Assembly',
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.penToSquare, size: 14),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Barangay Hall',
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.locationDot, size: 14),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Add a short note for residents',
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multi-day event',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Spans more than one day, e.g. a 3-day fiesta.',
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
                  label: 'Start date',
                  value: DateFormat('EEEE, MMM d, yyyy').format(_startDate),
                  onTap: _pickStartDate,
                ),
                _buildPickerRow(
                  icon: FontAwesomeIcons.calendarCheck,
                  label: 'End date',
                  value: DateFormat('EEEE, MMM d, yyyy').format(_endDate),
                  onTap: _pickEndDate,
                ),
              ] else
                _buildPickerRow(
                  icon: FontAwesomeIcons.calendarDays,
                  label: 'Date',
                  value: DateFormat('EEEE, MMM d, yyyy').format(_startDate),
                  onTap: _pickDate,
                ),
              _buildPickerRow(
                icon: FontAwesomeIcons.clock,
                label: _isMultiDay ? 'Default start time' : 'Start time',
                value: formatTimeOfDay12Hour(_startTime),
                onTap: _pickStartTime,
              ),
              _buildPickerRow(
                icon: FontAwesomeIcons.hourglassStart,
                label: _isMultiDay ? 'Default end time' : 'End time',
                value: formatTimeOfDay12Hour(_endTime),
                onTap: _pickEndTime,
              ),
              if (_conflicts.isNotEmpty) _buildConflictWarning(),
            ],
          ),
        ),
        if (_isMultiDay) ...[
          const SizedBox(height: 16),
          _buildPerDaySchedule(),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: _saving ? null : () => unawaited(_save()),
          icon: FaIcon(_isEditing ? FontAwesomeIcons.check : FontAwesomeIcons.calendarPlus, size: 14),
          label: Text(_saving ? 'Saving...' : (_isEditing ? 'Save changes' : 'Save event')),
        ),
      ],
    );
  }

  /// Lists every day the event spans with its own time-of-day window —
  /// "Default" (using the shared start/end time above) unless customized,
  /// e.g. day 1 full day, day 2 just a half-day. Days list is capped
  /// implicitly by the date-range picker; a very long range just scrolls
  /// within the page like everything else here.
  Widget _buildPerDaySchedule() {
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
            'Per-day schedule',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Every day uses the default time above unless you customize it — '
            'e.g. a full day on day 1, just a few hours on day 2.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final day in days) _buildDayOverrideRow(day),
        ],
      ),
    );
  }

  Widget _buildDayOverrideRow(DateTime day) {
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
                      ? '${formatTimeOfDay12Hour(override.start)} – ${formatTimeOfDay12Hour(override.end)}'
                      : '${formatTimeOfDay12Hour(_startTime)} – ${formatTimeOfDay12Hour(_endTime)} (default)',
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
              child: const Text('Reset'),
            )
          else
            TextButton(
              onPressed: () => setState(() {
                _perDayOverrides[day] = (start: const TimeOfDay(hour: 0, minute: 0), end: const TimeOfDay(hour: 23, minute: 59));
                _recomputeConflicts();
              }),
              child: const Text('All day'),
            ),
          TextButton(
            onPressed: () => unawaited(_customizeDay(day)),
            child: Text(isCustom ? 'Edit' : 'Customize'),
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
