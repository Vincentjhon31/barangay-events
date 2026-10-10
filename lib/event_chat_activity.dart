import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'event_store.dart';
import 'l10n/app_localizations.dart';

/// App-wide view of event chat activity: how many messages each event's
/// chat has, which ones have messages this user hasn't seen yet, and which
/// chat (if any) is open on screen right now.
///
/// One instance lives in the Calendar screen's state and is shared with
/// every chat indicator, chat button and chat page, so they all update
/// together — including on pages pushed on top (e.g. the day page), which
/// listen to this directly rather than waiting to be rebuilt.
///
/// "Seen" is remembered per device (SharedPreferences), the same way the
/// Feed tab's NEW badges are.
class EventChatActivity extends ChangeNotifier {
  EventChatActivity({required this.repository, this.currentUserId});

  final EventRepository repository;

  /// Messages this user posted never count as unread.
  String? currentUserId;

  static const String _lastSeenPrefKey = 'event_chat_last_seen_v1';

  Map<String, EventChatSummary> _summaries = const {};
  final Map<String, int> _lastSeenMillis = {};
  StreamSubscription<void>? _activitySubscription;
  bool _refreshing = false;
  bool _refreshQueued = false;
  bool _disposed = false;

  /// The event whose chat page is open right now, if any — a push for
  /// that chat is skipped, since the message is already on screen.
  String? openChatEventId;

  /// Loads what this device has already seen, then follows chat activity
  /// live.
  Future<void> start() async {
    await _loadLastSeen();
    _activitySubscription ??= repository.watchEventChatActivity().listen((_) => unawaited(refresh()));
    await refresh();
  }

  /// Re-fetches every chat's summary. Calls that arrive mid-fetch are
  /// coalesced into one follow-up fetch rather than piling up.
  Future<void> refresh() async {
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final summaries = await repository.fetchEventChatSummaries();
      if (_disposed) return;
      _summaries = summaries;
      notifyListeners();
    } catch (_) {
      // Just the indicators — keep the last known counts.
    } finally {
      _refreshing = false;
      if (_refreshQueued && !_disposed) {
        _refreshQueued = false;
        unawaited(refresh());
      }
    }
  }

  int countFor(String eventId) => _summaries[eventId]?.messageCount ?? 0;

  /// Whether [eventId]'s chat has a message from someone else that arrived
  /// after this user last looked at that chat.
  bool hasUnread(String eventId) {
    final summary = _summaries[eventId];
    if (summary == null || summary.messageCount == 0) return false;
    if (summary.lastAuthorId != null && summary.lastAuthorId == currentUserId) return false;
    final seen = _lastSeenMillis[eventId];
    return seen == null || summary.lastMessageAt.millisecondsSinceEpoch > seen;
  }

  /// Marks [eventId]'s chat as read up to now (or up to [upTo], the newest
  /// message on screen, if that's later — guards against a phone clock
  /// that runs behind the server's).
  void markSeen(String eventId, {DateTime? upTo}) {
    var millis = DateTime.now().millisecondsSinceEpoch;
    final candidates = [upTo, _summaries[eventId]?.lastMessageAt];
    for (final candidate in candidates) {
      if (candidate != null && candidate.millisecondsSinceEpoch > millis) {
        millis = candidate.millisecondsSinceEpoch;
      }
    }
    if ((_lastSeenMillis[eventId] ?? 0) >= millis) return;
    final wasUnread = hasUnread(eventId);
    _lastSeenMillis[eventId] = millis;
    if (wasUnread && !_disposed) notifyListeners();
    unawaited(_saveLastSeen());
  }

  Future<void> _loadLastSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastSeenPrefKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final existing = _lastSeenMillis[entry.key] ?? 0;
        final loaded = (entry.value as num).toInt();
        if (loaded > existing) _lastSeenMillis[entry.key] = loaded;
      }
    } catch (_) {
      // Unreadable prefs — everything just starts out unread.
    }
  }

  Future<void> _saveLastSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSeenPrefKey, jsonEncode(_lastSeenMillis));
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_activitySubscription?.cancel());
    super.dispose();
  }
}

/// The small chat pill on an event card: a speech bubble and the message
/// count, filled in the accent color (with a dot) when there's something
/// unread. Shows nothing for an event with no messages yet.
class EventChatIndicator extends StatelessWidget {
  const EventChatIndicator({
    super.key,
    required this.eventId,
    required this.activity,
    this.onTap,
  });

  final String eventId;
  final EventChatActivity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: activity,
      builder: (context, _) {
        final count = activity.countFor(eventId);
        if (count == 0) return const SizedBox.shrink();
        final unread = activity.hasUnread(eventId);
        final l10n = AppLocalizations.of(context)!;
        final colorScheme = Theme.of(context).colorScheme;
        final foreground = unread ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
        final label = count > 99 ? '99+' : '$count';

        return Tooltip(
          message: unread ? l10n.eventChatIndicatorUnreadTooltip(count) : l10n.eventChatIndicatorTooltip(count),
          child: InkWell(
            key: Key('event-chat-indicator-$eventId'),
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: unread ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.solidComment, size: 11, color: foreground),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: foreground,
                            ),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Positioned(
                    key: Key('event-chat-indicator-unread-$eventId'),
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
