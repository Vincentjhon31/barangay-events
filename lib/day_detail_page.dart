import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'add_event_page.dart';
import 'auth_service.dart' show AppUserProfile;
import 'event_conflicts.dart';
import 'event_store.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// Full-page view of a single day's events, reached by tapping a day on the
/// Month/Week calendar grid or a day header in the List view. Owns its own
/// live subscription to [EventRepository.watchAllEvents] (independent of
/// whatever page pushed it) so it stays correct if events change — e.g.
/// after using its own Add button below.
class DayDetailPage extends StatefulWidget {
  const DayDetailPage({
    super.key,
    required this.date,
    required this.eventRepository,
    required this.creatorProfile,
    required this.buildEventCard,
  });

  final DateTime date;
  final EventRepository eventRepository;
  final AppUserProfile? creatorProfile;

  /// Renders a single event's card — reused from the calendar screen
  /// (`_CalendarScreenState._buildEventCard`) rather than duplicated here,
  /// so icon/tint heuristics, the delete menu, and the details sheet all
  /// stay in one place.
  final Widget Function(BarangayEvent event) buildEventCard;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  final ScrollController _scrollController = ScrollController();
  late StreamSubscription<List<BarangayEvent>> _subscription;
  List<BarangayEvent> _allEvents = const [];
  bool _loaded = false;
  bool _hasMoreBelow = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.eventRepository.watchAllEvents().listen((events) {
      if (!mounted) return;
      setState(() {
        _allEvents = events;
        _loaded = true;
      });
    });
    // Catches the user actually scrolling.
    _scrollController.addListener(_checkScrollIndicator);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  List<BarangayEvent> get _dayEvents {
    final events = _allEvents.where((event) => event.occursOnDay(widget.date)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return events;
  }

  /// Whether there's more content below the fold — checked after every
  /// build (scheduled from [build] below) so it also catches "the list is
  /// already taller than the viewport, before any scrolling happened",
  /// not just live scroll events from [_scrollController]'s listener.
  void _checkScrollIndicator() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final hasMore = position.maxScrollExtent - position.pixels > 24;
    if (hasMore != _hasMoreBelow) setState(() => _hasMoreBelow = hasMore);
  }

  Future<void> _openAddEvent() async {
    List<BarangayGroup> myGroups = const [];
    try {
      myGroups = await widget.eventRepository.listMyGroups();
    } catch (_) {
      // Groups unavailable (e.g. migration not run) — Add Event still works
      // for public/personal events.
    }
    if (!mounted) return;

    final result = await Navigator.of(context).push<AddEventResult>(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          eventRepository: widget.eventRepository,
          myGroups: myGroups,
          initialDate: widget.date,
          creatorProfile: widget.creatorProfile,
          findOverlappingEvents: (date, start, end) =>
              findOverlappingEvents(_allEvents, date, start, end),
          suggestFreeSlot: (date, start, end) =>
              suggestFreeSlot(_allEvents, date, start, end),
        ),
      ),
    );
    // No manual merge needed for the list itself on return — the live
    // watchAllEvents() subscription above already picks up the newly saved
    // event. Just the confirmation message is our job here.
    if (result != null && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.groupName != null
                ? l10n.addedEventToGroup(result.title, result.groupName!)
                : l10n.addedEventToCalendar(result.title),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final events = _dayEvents;

    // Scheduled after every build (not just specific state changes) so it
    // also catches "the list is already taller than the viewport, before
    // any scrolling happened" — not just live scroll events, which
    // _scrollController's own listener (attached in initState) handles.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollIndicator());

    return GlassSubPage(
      title: DateFormat('EEEE').format(widget.date),
      subtitle: DateFormat('MMMM d, yyyy').format(widget.date),
      scrollController: _scrollController,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('day-detail-add-event-fab'),
        onPressed: () => unawaited(_openAddEvent()),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: FaIcon(FontAwesomeIcons.plus, size: 16, color: colorScheme.onPrimary),
        label: Text(l10n.addEventButton, style: TextStyle(color: colorScheme.onPrimary)),
      ),
      bottomOverlay: _hasMoreBelow ? _buildMoreBelowHint(colorScheme) : null,
      children: [
        if (!_loaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (events.isEmpty)
          GlassPanel(
            child: Text(
              l10n.noEventsForDate(DateFormat('MMMM d').format(widget.date)),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final event in events) ...[
            widget.buildEventCard(event),
            const SizedBox(height: 12),
          ],
        // Breathing room so the last card can clear the floating "more
        // below" hint / FAB instead of sitting flush behind them.
        const SizedBox(height: 64),
      ],
    );
  }

  Widget _buildMoreBelowHint(ColorScheme colorScheme) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      key: const Key('day-detail-more-hint'),
      child: Container(
        height: 56,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [background.withValues(alpha: 0), background.withValues(alpha: 0.92)],
          ),
        ),
        child: FaIcon(
          FontAwesomeIcons.chevronDown,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
