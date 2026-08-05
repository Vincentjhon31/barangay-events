import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'attachment_image_viewer.dart';
import 'auth_service.dart' show AppUserProfile;
import 'event_colors.dart';
import 'event_store.dart';
import 'l10n/app_localizations.dart';
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
    this.lguLocations = const [],
  });

  final EventRepository eventRepository;
  final List<BarangayGroup> myGroups;

  /// Superadmin-curated quick picks for the Location field (see
  /// EventRepository.listLguLocations) — empty just means "no admin
  /// locations set up yet", in which case Location falls back to a plain
  /// text field exactly as before this existed.
  final List<LguLocation> lguLocations;

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
  bool _saving = false;

  List<({BarangayEvent event, DateTime day})> _conflicts = const [];
  ({TimeOfDay start, TimeOfDay end})? _suggestedSlot;

  /// Per-day time-of-day overrides for a multi-day event, keyed by
  /// UTC-normalized day (matching `BarangayEvent.dayKey`) — a day missing
  /// from this map uses the default [_startTime]/[_endTime] uniformly,
  /// same as an event that's never had any overrides set.
  final Map<DateTime, ({TimeOfDay start, TimeOfDay end})> _perDayOverrides = {};

  static const _maxAttachments = 5;
  static const _maxAttachmentBytes = 20 * 1024 * 1024;

  /// Already-uploaded attachments — only ever non-empty when editing
  /// (fetched in [initState]), since a brand-new event has no id yet for
  /// [EventRepository.listEventAttachments] to look up.
  List<EventAttachment> _existingAttachments = const [];

  /// Picked-but-not-yet-uploaded files for a brand-new event, held here
  /// until [_save] gets a real event id back — an existing event uploads
  /// immediately on pick instead (see [_pickAttachments]), since it
  /// already has one.
  final List<PlatformFile> _pendingAttachments = [];

  bool _pickingAttachments = false;
  final Set<String> _busyAttachmentIds = {};

  /// Thumbnails for [_existingAttachments], fetched in the background as
  /// soon as each one's metadata loads (see [_loadExistingAttachments]) —
  /// a pending file needs no equivalent map, since [PlatformFile.bytes]
  /// is already available locally the moment it's picked.
  final Map<String, Uint8List> _existingAttachmentThumbnails = {};

  int get _attachmentCount => _existingAttachments.length + _pendingAttachments.length;

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
      _selectedLocationOption = widget.lguLocations.any((loc) => loc.name == existing.location)
          ? existing.location
          : _customLocationOption;
      _descriptionController.text = existing.description;
      _startDate = DateTime(existing.startTime.year, existing.startTime.month, existing.startTime.day);
      _endDate = DateTime(existing.endTime.year, existing.endTime.month, existing.endTime.day);
      _startTime = TimeOfDay.fromDateTime(existing.startTime);
      _endTime = TimeOfDay.fromDateTime(existing.endTime);
      _eventType = existing.eventType;
      _colorKey = existing.colorKey;
      _contactNumberController.text = existing.contactNumber ?? '';
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
      unawaited(_loadExistingAttachments(existing.id));
    } else {
      _startDate = widget.initialDate;
      _endDate = widget.initialDate;
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
    final l10n = AppLocalizations.of(context)!;
    final base = switch (_eventType) {
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
                    _isMultiDay
                        ? '• ${entry.event.title} • ${DateFormat('MMM d').format(entry.day)}, '
                            '${_formatClock(entry.event.startTime)}–${_formatClock(entry.event.endTime)}'
                        : '• ${entry.event.title} • ${_formatClock(entry.event.startTime)}–'
                            '${_formatClock(entry.event.endTime)}',
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
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();
    final contactNumber = _contactNumberController.text.trim();

    if (title.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.titleLocationRequired)),
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

    setState(() => _saving = true);
    final existing = widget.existingEvent;
    final eventId = existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    try {
      if (existing != null) {
        await widget.eventRepository.updateEvent(
          BarangayEvent(
            id: eventId,
            title: title,
            location: location,
            startTime: _startDateTime,
            endTime: _endDateTime,
            description: description,
            createdAt: existing.createdAt,
            createdByName: existing.createdByName,
            createdByDepartment: existing.createdByDepartment,
            createdById: existing.createdById,
            eventType: _eventType,
            colorKey: _colorKey,
            contactNumber: contactNumber.isEmpty ? null : contactNumber,
            groupId: group?.id,
            groupName: group?.name,
            dailyOverrides: dailyOverrides,
          ),
        );
      } else {
        await widget.eventRepository.addEvent(
          BarangayEvent(
            id: eventId,
            title: title,
            location: location,
            startTime: _startDateTime,
            endTime: _endDateTime,
            description: description,
            createdAt: DateTime.now(),
            createdByName: widget.creatorProfile?.displayName,
            createdByDepartment: widget.creatorProfile?.department,
            createdById: widget.creatorProfile?.id,
            eventType: _eventType,
            colorKey: _colorKey,
            contactNumber: contactNumber.isEmpty ? null : contactNumber,
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
          content: Text(l10n.saveEventError(error.toString())),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    // Uploaded now that the event has a real id — a brand-new event's id
    // was only ever a locally-generated placeholder until addEvent above
    // actually succeeded. A failed upload here doesn't undo the
    // already-saved event; the user can just re-add the file via Edit.
    for (final file in _pendingAttachments) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      try {
        await widget.eventRepository.uploadEventAttachment(
          eventId,
          file.name,
          bytes,
          mimeType: _mimeTypeForExtension(file.extension),
        );
      } catch (_) {
        // See comment above — non-fatal.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop<AddEventResult>((
      date: DateTime.utc(_startDate.year, _startDate.month, _startDate.day),
      title: title,
      groupName: group?.name,
    ));
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
      final existing = widget.existingEvent;

      for (final file in picked) {
        if (_attachmentCount >= _maxAttachments) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.attachmentLimitReached(_maxAttachments))),
            );
          }
          break;
        }
        if (file.size > _maxAttachmentBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.attachmentTooLarge(file.name))),
            );
          }
          continue;
        }
        final bytes = file.bytes;
        if (bytes == null) continue;

        if (existing != null) {
          // Already has a real id — upload right away instead of holding
          // it in _pendingAttachments, which only exists to bridge the
          // "no id yet" gap for a brand-new event.
          try {
            await widget.eventRepository.uploadEventAttachment(
              existing.id,
              file.name,
              bytes,
              mimeType: _mimeTypeForExtension(file.extension),
            );
            await _loadExistingAttachments(existing.id);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.attachmentUploadError(file.name))),
              );
            }
          }
        } else {
          setState(() => _pendingAttachments.add(file));
        }
      }
    } catch (_) {
      // Covers the file picker call itself failing (e.g. the browser
      // blocked/cancelled it) — everything past that point already has
      // its own narrower catch, but nothing previously guarded this, so
      // a picker-level failure surfaced as an uncaught error instead of
      // this snackbar.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.attachmentPickError)),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingAttachments = false);
    }
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

  void _removePendingAttachment(PlatformFile file) {
    setState(() => _pendingAttachments.remove(file));
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
                SegmentedButton<String>(
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
                    _ColorSwatch(
                      colorKey: key,
                      selected: _colorKey == key,
                      onTap: () => setState(() => _colorKey = _colorKey == key ? null : key),
                    ),
                ],
              ),
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
                    if (_selectedLocationOption != _customLocationOption) {
                      _locationController.text = _selectedLocationOption;
                    }
                  }),
                ),
                if (_selectedLocationOption == _customLocationOption) const SizedBox(height: 12),
              ],
              if (widget.lguLocations.isEmpty || _selectedLocationOption == _customLocationOption)
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: widget.lguLocations.isEmpty ? l10n.detailLocation : l10n.locationCustomLabel,
                    hintText: l10n.locationHint,
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
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
                    thumbnailBytes:
                        _mimeTypeForExtension(file.extension)?.startsWith('image/') == true
                            ? file.bytes
                            : null,
                    onTap: (_mimeTypeForExtension(file.extension)?.startsWith('image/') == true &&
                            file.bytes != null)
                        ? () => unawaited(_viewImage(file.bytes!, file.name))
                        : null,
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
          label: Text(_saving ? l10n.savingButton : (_isEditing ? l10n.saveChangesButton : l10n.saveEventButton)),
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
                _perDayOverrides[day] = (start: const TimeOfDay(hour: 0, minute: 0), end: const TimeOfDay(hour: 23, minute: 59));
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
/// Tapping the already-selected swatch clears it back to "no color chosen".
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
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

/// One file in the attachments picker — already-uploaded (real
/// [EventAttachment]) or still-pending (a locally-held [PlatformFile]),
/// both rendered identically since the only difference is what removing
/// it actually does (see [AddEventPage]'s _removeExistingAttachment vs.
/// _removePendingAttachment).
/// One file in the attachments picker — already-uploaded (real
/// [EventAttachment]) or still-pending (a locally-held [PlatformFile]),
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
  /// [AddEventPage]'s _existingAttachmentThumbnails/PlatformFile.bytes.
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
