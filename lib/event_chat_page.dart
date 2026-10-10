import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'avatar_image.dart';
import 'event_chat_activity.dart';
import 'event_store.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';
import 'manila_clock.dart';

/// The round chat button pinned to the bottom-right of an event's details
/// sheet. Shows how many messages the event's chat has, and refreshes that
/// count when the chat page closes.
class EventChatButton extends StatefulWidget {
  const EventChatButton({
    super.key,
    required this.event,
    required this.repository,
    required this.currentUserId,
    required this.canModerate,
    this.activity,
  });

  final BarangayEvent event;
  final EventRepository repository;
  final String currentUserId;

  /// Whether the viewer may delete other people's messages — the event's
  /// creator, an admin, or the superadmin (mirrors the server's delete policy).
  final bool canModerate;

  /// Shared chat activity (unread tracking, which chat is open) — see
  /// [EventChatActivity]. Optional so the button also works standalone.
  final EventChatActivity? activity;

  @override
  State<EventChatButton> createState() => _EventChatButtonState();
}

class _EventChatButtonState extends State<EventChatButton> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCount());
  }

  Future<void> _loadCount() async {
    try {
      final count = await widget.repository.countEventComments(widget.event.id);
      if (mounted) setState(() => _count = count);
    } catch (_) {
      // Just the badge — the button still works without it.
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventChatPage(
          event: widget.event,
          repository: widget.repository,
          currentUserId: widget.currentUserId,
          canModerate: widget.canModerate,
          activity: widget.activity,
        ),
      ),
    );
    await _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Badge(
      isLabelVisible: _count > 0,
      label: Text(_count > 99 ? '99+' : '$_count', key: const Key('event-chat-count')),
      offset: const Offset(-2, 2),
      child: FloatingActionButton(
        key: const Key('event-chat-button'),
        // Several FABs can be alive at once under the details sheet (day
        // page, main screen) — no hero animation between them.
        heroTag: null,
        tooltip: l10n.eventChatButtonTooltip,
        // A perfect circle (Material 3's default FAB is a rounded square)
        // around a round speech bubble.
        shape: const CircleBorder(),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        onPressed: _open,
        child: const FaIcon(FontAwesomeIcons.solidComment, size: 22),
      ),
    );
  }
}

/// One event's live chat: everyone who can see the event can read it and
/// post (text and emoji). Messages stream in realtime, newest at the
/// bottom; times are shown in Philippine (Asia/Manila) time.
class EventChatPage extends StatefulWidget {
  const EventChatPage({
    super.key,
    required this.event,
    required this.repository,
    required this.currentUserId,
    this.canModerate = false,
    this.activity,
  });

  final BarangayEvent event;
  final EventRepository repository;
  final String currentUserId;

  /// See [EventChatButton.canModerate].
  final bool canModerate;

  /// See [EventChatButton.activity]. While this page is open it's marked
  /// as the open chat (so pushes for it are skipped) and kept "seen".
  final EventChatActivity? activity;

  @override
  State<EventChatPage> createState() => _EventChatPageState();
}

class _EventChatPageState extends State<EventChatPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late Stream<List<EventComment>> _comments;
  bool _showEmojiPanel = false;
  bool _sending = false;
  int _emojiCategory = 0;

  /// The message being edited, while the composer is in edit mode (its
  /// text loaded into the field, Send saving the change instead).
  EventComment? _editing;

  @override
  void initState() {
    super.initState();
    _comments = widget.repository.watchEventComments(widget.event.id);
    final activity = widget.activity;
    if (activity != null) {
      activity.openChatEventId = widget.event.id;
      // After this frame — marking seen notifies the indicators, and
      // initState runs mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) => activity.markSeen(widget.event.id));
    }
    _controller.addListener(_onTextChanged);
    // Typing again closes the emoji panel, like every messaging app.
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPanel) {
        setState(() => _showEmojiPanel = false);
      }
    });
  }

  @override
  void dispose() {
    final activity = widget.activity;
    if (activity != null) {
      if (activity.openChatEventId == widget.event.id) activity.openChatEventId = null;
      // Deferred: dispose runs while the widget tree is locked, and
      // marking seen notifies listeners that rebuild.
      final eventId = widget.event.id;
      scheduleMicrotask(() => activity.markSeen(eventId));
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Rebuilds only to swap the send button between "send" and "thumbs up".
  bool _hadText = false;
  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hadText) setState(() => _hadText = hasText);
  }

  void _retryLoad() {
    setState(() => _comments = widget.repository.watchEventComments(widget.event.id));
  }

  Future<void> _send({String? override}) async {
    if (_sending) return;
    if (_editing != null && override == null) return _saveEdit();
    final body = (override ?? _controller.text).trim();
    if (body.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final draft = _controller.text;
    setState(() => _sending = true);
    if (override == null) _controller.clear();
    try {
      await widget.repository.addEventComment(widget.event.id, body);
    } catch (_) {
      if (!mounted) return;
      // Give the unsent text back rather than losing it.
      if (override == null && _controller.text.isEmpty) _controller.text = draft;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventChatSendFailed)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEdit(EventComment comment) {
    setState(() => _editing = comment);
    _controller.value = TextEditingValue(
      text: comment.body,
      selection: TextSelection.collapsed(offset: comment.body.length),
    );
    if (!_showEmojiPanel) _focusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editing = null);
    _controller.clear();
  }

  Future<void> _saveEdit() async {
    final editing = _editing;
    if (editing == null) return;
    final body = _controller.text.trim();
    // An emptied message isn't saved — deleting is its own action.
    if (body.isEmpty) return;
    if (body == editing.body) {
      _cancelEdit();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _sending = true);
    try {
      await widget.repository.editEventComment(editing.id, body);
      if (mounted && _editing?.id == editing.id) _cancelEdit();
    } catch (_) {
      // Stay in edit mode with the text intact so nothing typed is lost.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventChatEditFailed)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.eventChatDeleteConfirmTitle),
        content: Text(l10n.eventChatDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('event-chat-delete-confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.eventChatDeleteConfirmButton),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _toggleEmojiPanel() {
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPanel = true);
    }
  }

  /// Inserts [emoji] at the cursor (or replaces the selection), the way a
  /// keyboard would.
  void _insertEmoji(String emoji) {
    final value = _controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final updated = text.replaceRange(start, end, emoji);
    if (updated.length > maxEventCommentLength) return;
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _showMessageActions(EventComment comment) async {
    // A deleted message is just its trace — nothing left to copy or change.
    if (comment.isDeleted) return;
    final l10n = AppLocalizations.of(context)!;
    final isMine = comment.userId == widget.currentUserId;
    final canDelete = isMine || widget.canModerate;
    final colorScheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('event-chat-copy'),
              leading: const FaIcon(FontAwesomeIcons.copy, size: 18),
              title: Text(l10n.eventChatCopyMessage),
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
            // Only the author can edit — a moderator can remove a message
            // but never put words in someone else's mouth.
            if (isMine)
              ListTile(
                key: const Key('event-chat-edit'),
                leading: const FaIcon(FontAwesomeIcons.penToSquare, size: 18),
                title: Text(l10n.eventChatEditMessage),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
            if (canDelete)
              ListTile(
                key: const Key('event-chat-delete'),
                leading: FaIcon(FontAwesomeIcons.trashCan, size: 18, color: colorScheme.error),
                title: Text(
                  l10n.eventChatDeleteMessage,
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: comment.body));
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventChatCopied)));
    } else if (action == 'edit') {
      _startEdit(comment);
    } else if (action == 'delete') {
      if (!await _confirmDelete() || !mounted) return;
      try {
        await widget.repository.deleteEventComment(comment.id);
        // Deleting the message you were in the middle of editing ends
        // the edit too.
        if (mounted && _editing?.id == comment.id) _cancelEdit();
        messenger.showSnackBar(SnackBar(content: Text(l10n.eventChatMessageDeleted)));
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.eventChatDeleteFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back closes the emoji panel first (like the keyboard would), then
      // cancels an edit in progress, and only then leaves the chat.
      canPop: !_showEmojiPanel && _editing == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showEmojiPanel) {
          setState(() => _showEmojiPanel = false);
        } else if (_editing != null) {
          _cancelEdit();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            const Positioned.fill(child: LiquidGlassBackdrop()),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: _buildHeader(),
                  ),
                  Expanded(child: _buildMessages()),
                  _buildComposer(),
                  if (_showEmojiPanel) _buildEmojiPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Tooltip(
          message: MaterialLocalizations.of(context).backButtonTooltip,
          child: InkWell(
            key: const Key('event-chat-back'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).maybePop(),
            child: IconBadge(
              icon: FontAwesomeIcons.chevronLeft,
              tint: colorScheme.primary,
              size: 44,
              iconSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.eventChatTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessages() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<EventComment>>(
      stream: _comments,
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.eventChatLoadFailed, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retryLoad,
                      icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 14),
                      label: Text(l10n.eventChatRetry),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // Newest first — the list is reversed, so index 0 sits at the
        // bottom and new messages appear there without any scrolling.
        final comments = snapshot.data!;
        // Everything on screen counts as read. After this frame: marking
        // seen notifies the indicators, which mustn't happen mid-build.
        final activity = widget.activity;
        if (activity != null && comments.isNotEmpty) {
          final newest = comments.first.createdAt;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            activity.markSeen(widget.event.id, upTo: newest);
          });
        }
        if (comments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconBadge(
                    icon: FontAwesomeIcons.comments,
                    tint: colorScheme.primary,
                    size: 64,
                    iconSize: 26,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.eventChatEmpty,
                    key: const Key('event-chat-empty'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.eventChatSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          key: const Key('event-chat-list'),
          reverse: true,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            final older = index + 1 < comments.length ? comments[index + 1] : null;
            final localTime = toManila(comment.createdAt);
            final startsNewDay =
                older == null || !_sameDay(toManila(older.createdAt), localTime);
            // A run of messages from one person within a few minutes shows
            // their name/avatar only once, at the top of the run.
            final startsRun = startsNewDay ||
                older.userId != comment.userId ||
                comment.createdAt.difference(older.createdAt) > const Duration(minutes: 5);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (startsNewDay) _buildDaySeparator(localTime),
                _MessageBubble(
                  key: Key('event-chat-message-${comment.id}'),
                  comment: comment,
                  isMine: comment.userId == widget.currentUserId,
                  currentUserId: widget.currentUserId,
                  isBeingEdited: _editing?.id == comment.id,
                  showAuthor: startsRun,
                  onLongPress: () => unawaited(_showMessageActions(comment)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDaySeparator(DateTime manilaTime) {
    final l10n = AppLocalizations.of(context)!;
    final today = manilaNow();
    final yesterday = today.subtract(const Duration(days: 1));
    final label = _sameDay(manilaTime, today)
        ? l10n.eventChatToday
        : _sameDay(manilaTime, yesterday)
            ? l10n.eventChatYesterday
            : DateFormat('EEEE, MMM d, y').format(manilaTime);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: GlassPanel(
          borderRadius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = _controller.text.trim().isNotEmpty;
    final editing = _editing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: GlassPanel(
        borderRadius: 26,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (editing != null)
              Padding(
                key: const Key('event-chat-editing-banner'),
                padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
                child: Row(
                  children: [
                    FaIcon(FontAwesomeIcons.pen, size: 12, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.eventChatEditing,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.primary,
                                ),
                          ),
                          Text(
                            editing.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('event-chat-cancel-edit'),
                      tooltip: l10n.eventChatCancelEdit,
                      visualDensity: VisualDensity.compact,
                      onPressed: _cancelEdit,
                      icon: FaIcon(FontAwesomeIcons.xmark, size: 16, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            _buildComposerRow(hasText: hasText, editing: editing),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerRow({required bool hasText, required EventComment? editing}) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final Widget action;
    if (editing != null) {
      // Saving an edit; disabled while the field is empty (an emptied
      // message isn't saved — deleting is its own action).
      action = IconButton(
        key: const Key('event-chat-save-edit'),
        tooltip: l10n.eventChatSaveEdit,
        onPressed: _sending || !hasText ? null : () => unawaited(_saveEdit()),
        icon: FaIcon(
          FontAwesomeIcons.solidCircleCheck,
          size: 22,
          color: hasText ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      );
    } else if (hasText) {
      action = IconButton(
        key: const Key('event-chat-send'),
        tooltip: l10n.eventChatSendTooltip,
        onPressed: _sending ? null : () => unawaited(_send()),
        icon: FaIcon(FontAwesomeIcons.solidPaperPlane, size: 20, color: colorScheme.primary),
      );
    } else {
      // Messenger-style: with nothing typed, the send slot sends a quick
      // thumbs up instead.
      action = IconButton(
        key: const Key('event-chat-like'),
        tooltip: l10n.eventChatLikeTooltip,
        onPressed: _sending ? null : () => unawaited(_send(override: '👍')),
        icon: const Text('👍', style: TextStyle(fontSize: 22)),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          key: const Key('event-chat-emoji-toggle'),
          tooltip: _showEmojiPanel ? l10n.eventChatKeyboardTooltip : l10n.eventChatEmojiTooltip,
          onPressed: _toggleEmojiPanel,
          icon: FaIcon(
            _showEmojiPanel ? FontAwesomeIcons.keyboard : FontAwesomeIcons.faceSmile,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
        Expanded(
          child: TextField(
            key: const Key('event-chat-input'),
            controller: _controller,
            focusNode: _focusNode,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            // Enter sends (or saves an edit), on a hardware keyboard too;
            // the phone keyboard's own emoji key still works alongside the
            // panel.
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => unawaited(_send()),
            inputFormatters: [
              LengthLimitingTextInputFormatter(maxEventCommentLength),
            ],
            decoration: InputDecoration(
              hintText: l10n.eventChatInputHint,
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
          ),
        ),
        action,
      ],
    );
  }

  Widget _buildEmojiPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final category = emojiCategories[_emojiCategory];
    return SizedBox(
      key: const Key('event-chat-emoji-panel'),
      height: 260,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: GlassPanel(
          borderRadius: 22,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    for (var i = 0; i < emojiCategories.length; i++)
                      Expanded(
                        child: InkWell(
                          key: Key('event-chat-emoji-category-$i'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _emojiCategory = i),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: i == _emojiCategory
                                  ? colorScheme.primary.withValues(alpha: 0.16)
                                  : null,
                            ),
                            child: Text(
                              emojiCategories[i].icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: GridView.builder(
                  key: Key('event-chat-emoji-grid-$_emojiCategory'),
                  padding: const EdgeInsets.only(bottom: 8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 46,
                  ),
                  itemCount: category.emojis.length,
                  itemBuilder: (context, index) {
                    final emoji = category.emojis[index];
                    return InkWell(
                      key: Key('event-chat-emoji-$emoji'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _insertEmoji(emoji),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.comment,
    required this.isMine,
    required this.currentUserId,
    required this.showAuthor,
    required this.onLongPress,
    this.isBeingEdited = false,
  });

  final EventComment comment;
  final bool isMine;
  final String currentUserId;
  final bool showAuthor;
  final VoidCallback onLongPress;

  /// Highlights the message while its text is loaded in the composer.
  final bool isBeingEdited;

  /// The trace a deleted message leaves, from the viewer's point of view.
  String _deletedLabel(AppLocalizations l10n, String authorName) {
    if (comment.wasRemovedByModerator) {
      return comment.deletedBy == currentUserId
          ? l10n.eventChatRemovedByYou
          : l10n.eventChatRemovedByModerator;
    }
    return isMine ? l10n.eventChatYouDeleted : l10n.eventChatUserDeleted(authorName);
  }

  static const double _avatarSize = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final time = DateFormat('h:mm a').format(toManila(comment.createdAt));
    final bigEmoji = !comment.isDeleted && isEmojiOnlyMessage(comment.body);
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;
    final authorName = (comment.authorName?.trim().isNotEmpty ?? false)
        ? comment.authorName!.trim()
        : l10n.eventChatSomeone;

    final Widget content;
    if (comment.isDeleted) {
      // Messenger-style trace: an empty outlined pill where the message was.
      content = Container(
        key: Key('event-chat-deleted-${comment.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.ban, size: 12, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _deletedLabel(l10n, authorName),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (bigEmoji) {
      // A message that's just an emoji or three is shown big and without
      // a bubble, like in Messenger.
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(comment.body, style: const TextStyle(fontSize: 40, height: 1.15)),
      );
    } else if (isMine) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          comment.body,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary),
        ),
      );
    } else {
      content = GlassPanel(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(comment.body, style: theme.textTheme.bodyMedium),
      );
    }

    final bubbleColumn = Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showAuthor && !isMine)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 3),
            child: Text(
              authorName,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        GestureDetector(
          // A deleted message is only a trace — nothing to act on.
          onLongPress: comment.isDeleted ? null : onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isBeingEdited ? 0.55 : 1,
              child: content,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
          child: Text(
            comment.isEdited ? '${l10n.eventChatEdited} · $time' : time,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: showAuthor ? 10 : 4),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            // Keeps the column aligned across a run even where the avatar
            // itself is only shown on the run's first message.
            SizedBox(
              width: _avatarSize,
              child: showAuthor
                  ? Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: RoleAvatarFrame(
                        role: comment.authorRole,
                        size: _avatarSize,
                        child: _AuthorAvatar(
                          avatarUrl: comment.authorAvatarUrl,
                          name: authorName,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubbleColumn),
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.avatarUrl, required this.name});

  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = Container(
      alignment: Alignment.center,
      color: colorScheme.primary.withValues(alpha: 0.16),
      child: Text(
        name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: colorScheme.primary,
        ),
      ),
    );
    final url = avatarUrl;
    if (url == null || url.isEmpty) return initial;
    return avatarImage(url, fallback: initial);
  }
}

/// Whether [body] is nothing but one to three emoji (ignoring spaces) —
/// such a message is shown large, without a bubble.
bool isEmojiOnlyMessage(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return false;
  final graphemes = trimmed.characters.where((c) => c.trim().isNotEmpty).toList();
  if (graphemes.length > 3) return false;
  return graphemes.every(_emojiGrapheme.hasMatch);
}

// One emoji "character": a pictograph (optionally with a skin tone,
// variation selector, or joined to more pictographs, e.g. a family), a
// flag, or a keycap. Plain digits, letters and punctuation never match.
// Explicit code-point ranges rather than \p{Extended_Pictographic}: Dart's
// RegExp doesn't support Unicode property escapes.
const String _pictograph = r'[\u{00A9}\u{00AE}\u{203C}\u{2049}\u{2122}\u{2139}\u{2194}-\u{21AA}\u{231A}-\u{23FF}'
    r'\u{24C2}\u{25AA}-\u{25FE}\u{2600}-\u{27BF}\u{2934}\u{2935}\u{2B05}-\u{2B55}'
    r'\u{3030}\u{303D}\u{3297}\u{3299}\u{1F000}-\u{1FAFF}]';
const String _skinTone = r'[\u{1F3FB}-\u{1F3FF}]?';
const String _variation = r'[\u{FE0E}\u{FE0F}]?';
final RegExp _emojiGrapheme = RegExp(
  '^(?:'
  r'[\u{1F1E6}-\u{1F1FF}]{2}'
  r'|[#*0-9]\u{FE0F}?\u{20E3}'
  '|$_pictograph$_variation$_skinTone'
  '(?:\u{200D}$_pictograph$_variation$_skinTone)*'
  r')$',
  unicode: true,
);

class EmojiCategory {
  const EmojiCategory(this.icon, this.emojis);

  /// Shown as the category's tab.
  final String icon;
  final List<String> emojis;
}

/// The chat's built-in emoji picker. A curated set rather than a package:
/// the phone keyboard's own emoji key covers the long tail, and this keeps
/// a new native plugin (and its Android build constraints) out of the app.
const List<EmojiCategory> emojiCategories = [
  EmojiCategory('😀', [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '😉', '😊', '😇',
    '🥰', '😍', '🤩', '😘', '😋', '😛', '😜', '🤪', '🤗', '🤭', '🤔', '🤐',
    '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '😌', '😔', '😪', '😴', '😷',
    '🤒', '🥵', '🥶', '😵', '🤯', '🥳', '😎', '🤓', '😕', '😟', '🙁', '😮',
    '😲', '😳', '🥺', '😢', '😭', '😱', '😤', '😡', '😠', '🤬', '😈', '💀',
  ]),
  EmojiCategory('👍', [
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇',
    '☝️', '✋', '🤚', '👋', '🖐️', '👏', '🙌', '👐', '🤲', '🙏', '🤝', '💪',
    '✍️', '🫡', '🫶', '🙋', '🙆', '🙅', '🤷', '🤦', '🙇', '💁', '🏃', '🚶',
  ]),
  EmojiCategory('❤️', [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕',
    '💞', '💓', '💗', '💖', '💘', '💝', '💯', '✨', '⭐', '🌟', '🔥', '💥',
    '✅', '❌', '⚠️', '❗', '❓', '💬', '👀', '🆗', '🆕', '🔔', '📣', '📢',
  ]),
  EmojiCategory('🎉', [
    '🎉', '🎊', '🎈', '🎂', '🍰', '🎁', '🏆', '🥇', '🏅', '🎖️', '🎗️', '🎟️',
    '🎤', '🎶', '🎵', '🥁', '💃', '🕺', '🏀', '🏐', '⚽', '🏸', '🎯', '🎲',
    '🍚', '🍗', '🍖', '🍜', '🥘', '🍢', '🍌', '🥭', '🍍', '🥥', '☕', '🥤',
  ]),
  EmojiCategory('📅', [
    '📅', '📆', '🗓️', '⏰', '⌛', '📍', '🗺️', '🏛️', '🏫', '🏥', '⛪', '🏠',
    '🚌', '🚗', '🛺', '🏍️', '🚲', '⛵', '☀️', '🌤️', '⛅', '🌧️', '⛈️', '🌀',
    '🌈', '🌊', '🌴', '🌺', '🌻', '🐓', '🐶', '🐱', '📝', '📌', '📎', '📞',
    '💉', '💊', '🩺', '🧹', '♻️', '🗑️', '🚑', '🚒', '🚓', '🇵🇭',
  ]),
];
