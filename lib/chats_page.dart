import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'event_chat_activity.dart';
import 'event_store.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';
import 'manila_clock.dart';

/// Messenger-style list of the user's event chats, newest message first,
/// opened from the Feed tab's Chats button — so a conversation can be found
/// without digging through events that have piled up or already passed.
///
/// "Your chats" are the ones [EventChatActivity.isMyChat] picks: chats you
/// posted in, chats on your own events, and your groups' chats. Searching
/// widens to every chat you can read, and also searches inside messages.
class ChatsPage extends StatefulWidget {
  const ChatsPage({
    super.key,
    required this.repository,
    required this.activity,
    required this.currentUserId,
    required this.events,
    required this.onOpenChat,
    required this.eventBadge,
  });

  final EventRepository repository;
  final EventChatActivity activity;
  final String currentUserId;

  /// The events this user can see. Read on every build: the list lives in
  /// the Calendar screen and changes live.
  final List<BarangayEvent> Function() events;

  /// Opens one event's chat page; completes when it closes.
  final Future<void> Function(BarangayEvent event) onOpenChat;

  /// The event's icon badge, the same one its cards use.
  final Widget Function(BarangayEvent event) eventBadge;

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

enum _ChatFilter { all, unread, groups, public }

class _ChatsPageState extends State<ChatsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _ChatFilter _filter = _ChatFilter.all;

  Map<String, EventComment> _latest = const {};
  bool _latestLoaded = false;
  bool _latestFailed = false;
  bool _loadingLatest = false;
  bool _reloadQueued = false;

  Timer? _searchDebounce;

  /// Message search results for [_searchedQuery]; null until a search for
  /// the current text has finished.
  List<EventComment>? _messageResults;
  String _searchedQuery = '';
  bool _searchFailed = false;

  @override
  void initState() {
    super.initState();
    widget.activity.addListener(_onActivity);
    unawaited(_loadLatest());
    unawaited(widget.activity.refresh());
  }

  @override
  void dispose() {
    widget.activity.removeListener(_onActivity);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// A message was posted, edited or deleted somewhere, or a chat was read:
  /// redraw, and fetch fresh previews.
  void _onActivity() {
    if (!mounted) return;
    setState(() {});
    unawaited(_loadLatest());
  }

  /// Calls that arrive mid-fetch are coalesced into one follow-up fetch.
  Future<void> _loadLatest() async {
    if (_loadingLatest) {
      _reloadQueued = true;
      return;
    }
    _loadingLatest = true;
    try {
      final latest = await widget.repository.fetchLatestEventComments();
      if (mounted) {
        setState(() {
          _latest = latest;
          _latestLoaded = true;
          _latestFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _latestLoaded = true;
          _latestFailed = true;
        });
      }
    } finally {
      _loadingLatest = false;
      if (_reloadQueued && mounted) {
        _reloadQueued = false;
        unawaited(_loadLatest());
      }
    }
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    setState(() {
      _query = value;
      if (trimmed != _searchedQuery) _messageResults = null;
    });
    if (trimmed.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () => _searchMessages(trimmed));
  }

  Future<void> _searchMessages(String query) async {
    List<EventComment> results = const [];
    var failed = false;
    try {
      results = await widget.repository.searchEventComments(query);
    } catch (_) {
      failed = true;
    }
    // Typing moved on while this was in flight — its own search follows.
    if (!mounted || _query.trim() != query) return;
    setState(() {
      _messageResults = results;
      _searchedQuery = query;
      _searchFailed = failed;
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _messageResults = null;
      _searchedQuery = '';
    });
  }

  Future<void> _open(BarangayEvent event) async {
    await widget.onOpenChat(event);
    if (mounted) unawaited(_loadLatest());
  }

  /// Chats with at least one message, newest message first — only this
  /// user's own chats, or every readable chat when [everyChat]. An event on
  /// several dates has one chat, so it's listed once, by its home date.
  List<BarangayEvent> _chats({required bool everyChat}) {
    final activity = widget.activity;
    final epoch = DateTime.utc(1970);
    final byChat = <String, BarangayEvent>{};
    for (final event in widget.events()) {
      if (event.eventType == EventType.personal) continue;
      if (!(everyChat ? activity.countFor(event.homeId) > 0 : activity.isMyChat(event))) continue;
      if (!byChat.containsKey(event.homeId) || event.id == event.homeId) byChat[event.homeId] = event;
    }
    return byChat.values.toList()
      ..sort((a, b) =>
          (activity.lastMessageAt(b.homeId) ?? epoch).compareTo(activity.lastMessageAt(a.homeId) ?? epoch));
  }

  bool _passesFilter(BarangayEvent event) {
    return switch (_filter) {
      _ChatFilter.all => true,
      _ChatFilter.unread => widget.activity.hasUnread(event.homeId),
      _ChatFilter.groups => event.eventType == EventType.shared,
      _ChatFilter.public => event.eventType != EventType.shared,
    };
  }

  static bool _nameMatches(BarangayEvent event, String needle) {
    return [event.title, event.groupName, event.calendarName, event.location]
        .whereType<String>()
        .any((text) => text.toLowerCase().contains(needle));
  }

  /// Today: "3:45 PM"; this week: "Mon"; this year: "Oct 12"; older:
  /// "Oct 12, 2025" — Philippine time, like the chat page.
  static String _timeLabel(DateTime instant) {
    final at = toManila(instant);
    final now = manilaNow();
    final days = DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(at.year, at.month, at.day))
        .inDays;
    if (days == 0) return DateFormat.jm().format(at);
    if (days < 7) return DateFormat.E().format(at);
    if (at.year == now.year) return DateFormat.MMMd().format(at);
    return DateFormat.yMMMd().format(at);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final needle = _query.trim().toLowerCase();
    final searching = needle.isNotEmpty;
    final chats = _chats(everyChat: searching)
        .where(_passesFilter)
        .where((event) => !searching || _nameMatches(event, needle))
        .toList();

    return GlassSubPage(
      title: l10n.chatsTitle,
      subtitle: l10n.chatsSubtitle,
      children: [
        TextField(
          key: const Key('chats-search'),
          controller: _searchController,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            labelText: l10n.chatsSearchLabel,
            hintText: l10n.chatsSearchHint,
            prefixIcon: glassFieldIcon(FontAwesomeIcons.magnifyingGlass, size: 14),
            prefixIconConstraints: glassFieldIconConstraints,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.clearSearch,
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                    onPressed: _clearSearch,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFilterChips(l10n),
        const SizedBox(height: 18),
        if (searching) ...[
          _sectionLabel(l10n.chatsSectionChats),
          if (chats.isEmpty) _note(l10n.chatsSearchNoChats) else ...chats.map(_buildChatRow),
          const SizedBox(height: 14),
          _sectionLabel(l10n.chatsSectionMessages),
          ..._buildMessageResults(l10n),
        ] else if (!_latestLoaded)
          _loadingPanel()
        else if (chats.isEmpty)
          _note(_filter == _ChatFilter.all ? l10n.chatsEmpty : l10n.chatsEmptyFiltered)
        else ...[
          if (_latestFailed) _failedNote(l10n),
          ...chats.map(_buildChatRow),
        ],
      ],
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = [
      (filter: _ChatFilter.all, label: l10n.chatsFilterAll, icon: FontAwesomeIcons.solidComments),
      (filter: _ChatFilter.unread, label: l10n.chatsFilterUnread, icon: FontAwesomeIcons.circleDot),
      (filter: _ChatFilter.groups, label: l10n.chatsFilterGroups, icon: FontAwesomeIcons.peopleGroup),
      (filter: _ChatFilter.public, label: l10n.chatsFilterPublic, icon: FontAwesomeIcons.bullhorn),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            InkWell(
              key: Key('chats-filter-${option.filter.name}'),
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _filter = option.filter),
              child: GlassPanel(
                borderRadius: 999,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                tint: _filter == option.filter ? colorScheme.primary : null,
                tintAlpha: _filter == option.filter ? 0.22 : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      option.icon,
                      size: 12,
                      color: _filter == option.filter ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      option.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _filter == option.filter ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildChatRow(BarangayEvent event) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activity = widget.activity;
    final unread = activity.hasUnread(event.homeId);
    final latest = _latest[event.homeId];
    final at = latest?.createdAt ?? activity.lastMessageAt(event.homeId);
    final String preview;
    if (latest == null) {
      preview = l10n.chatsMessageCount(activity.countFor(event.homeId));
    } else {
      final body = latest.body.replaceAll('\n', ' ');
      preview = latest.userId == widget.currentUserId
          ? l10n.chatsPreviewYou(body)
          : l10n.chatsPreviewOther(latest.authorName ?? '?', body);
    }
    final where = switch (event.eventType) {
      EventType.shared => event.groupName ?? '',
      EventType.calendar => event.calendarName ?? '',
      _ => l10n.chatsTypePublic,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key('chats-row-${event.homeId}'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => _open(event),
        child: GlassPanel(
          borderRadius: 22,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              widget.eventBadge(event),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (at != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _timeLabel(at),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                              color: unread ? colorScheme.primary : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                              color: unread ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            key: Key('chats-unread-${event.homeId}'),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    if (where.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        where,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMessageResults(AppLocalizations l10n) {
    final query = _query.trim();
    if (query.length < 2) return [_note(l10n.chatsSearchTooShort)];
    final results = _messageResults;
    if (results == null || _searchedQuery != query) return [_loadingPanel()];
    if (_searchFailed) return [_note(l10n.chatsSearchFailed)];
    final eventsById = {for (final event in widget.events()) event.id: event};
    final rows = <Widget>[
      for (final comment in results)
        // A chat whose event this user can no longer see is skipped.
        if (eventsById[comment.eventId] case final event?)
          if (_passesFilter(event)) _buildMessageResult(comment, event, query.toLowerCase()),
    ];
    return rows.isEmpty ? [_note(l10n.chatsSearchNoMessages(query))] : rows;
  }

  Widget _buildMessageResult(EventComment comment, BarangayEvent event, String needle) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final author = comment.userId == widget.currentUserId ? null : (comment.authorName ?? '?');
    final body = comment.body.replaceAll('\n', ' ');
    final baseStyle = theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface);

    // The matched words in bold, accent-colored, like a search engine.
    final spans = <TextSpan>[];
    final lower = body.toLowerCase();
    var start = 0;
    while (true) {
      final index = lower.indexOf(needle, start);
      if (index < 0) {
        spans.add(TextSpan(text: body.substring(start)));
        break;
      }
      if (index > start) spans.add(TextSpan(text: body.substring(start, index)));
      spans.add(TextSpan(
        text: body.substring(index, index + needle.length),
        style: TextStyle(fontWeight: FontWeight.w800, color: colorScheme.primary),
      ));
      start = index + needle.length;
    }
    final prefix = author == null ? l10n.chatsPreviewYou('') : l10n.chatsPreviewOther(author, '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key('chats-message-${comment.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => _open(event),
        child: GlassPanel(
          borderRadius: 22,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _timeLabel(comment.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: [
                    TextSpan(text: prefix, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ...spans,
                  ],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }

  Widget _failedNote(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.chatsLoadFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(onPressed: _loadLatest, child: Text(l10n.eventChatRetry)),
          ],
        ),
      ),
    );
  }

  Widget _loadingPanel() {
    return const GlassPanel(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }
}
