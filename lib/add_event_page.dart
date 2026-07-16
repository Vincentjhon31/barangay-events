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
/// regular single-day event and a multi-day date range.
class AddEventPage extends StatefulWidget {
  const AddEventPage({
    super.key,
    required this.eventRepository,
    required this.myGroups,
    required this.initialDate,
    required this.creatorProfile,
    required this.findOverlappingEvents,
    required this.suggestFreeSlot,
  });

  final EventRepository eventRepository;
  final List<BarangayGroup> myGroups;

  /// Pre-clamped by the caller so it's never in the past.
  final DateTime initialDate;
  final AppUserProfile? creatorProfile;

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

  List<String> get _allowedEventTypes => [
        if (_canCreatePublic) EventType.public,
        if (_canCreateGroupEvent) EventType.shared,
        EventType.personal,
      ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate;
    _endDate = widget.initialDate;
    _eventType = _allowedEventTypes.first;
    _selectedGroup = widget.myGroups.isNotEmpty ? widget.myGroups.first : null;
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

  /// Checks every day from [_startDate] to [_endDate] (just [_startDate]
  /// for a single-day event, since they're the same) against
  /// [AddEventPage.findOverlappingEvents] — each existing event's
  /// time-of-day window applies on every day *it* spans too, so a 3-day
  /// event timed 7–8 AM only conflicts with something else scheduled
  /// 7–8 AM, leaving the rest of those days free. An event conflicting on
  /// more than one spanned day is only reported once (its first
  /// conflicting day).
  List<({BarangayEvent event, DateTime day})> _computeConflicts() {
    final seen = <String>{};
    final entries = <({BarangayEvent event, DateTime day})>[];
    for (var day = _startDate; !day.isAfter(_endDate); day = day.add(const Duration(days: 1))) {
      for (final event in widget.findOverlappingEvents(day, _startTime, _endTime)) {
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

    if (_startDate.isBefore(_today)) {
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
    final newEventId = DateTime.now().microsecondsSinceEpoch.toString();

    setState(() => _saving = true);
    try {
      await widget.eventRepository.addEvent(
        BarangayEvent(
          id: newEventId,
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
        ),
      );
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
      title: 'Add Event',
      subtitle: 'Share something happening in the barangay.',
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
                label: 'Start time',
                value: formatTimeOfDay12Hour(_startTime),
                onTap: _pickStartTime,
              ),
              _buildPickerRow(
                icon: FontAwesomeIcons.hourglassStart,
                label: 'End time',
                value: formatTimeOfDay12Hour(_endTime),
                onTap: _pickEndTime,
              ),
              if (_conflicts.isNotEmpty) _buildConflictWarning(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: _saving ? null : () => unawaited(_save()),
          icon: const FaIcon(FontAwesomeIcons.calendarPlus, size: 14),
          label: Text(_saving ? 'Saving...' : 'Save event'),
        ),
      ],
    );
  }
}
