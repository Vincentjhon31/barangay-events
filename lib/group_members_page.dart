import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'event_store.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// A group's member roster: search, and — for admins — promote to admin or
/// remove a member. Also surfaces the invite code, since there's no live
/// user directory to "add" someone from directly.
class GroupMembersPage extends StatefulWidget {
  const GroupMembersPage({
    super.key,
    required this.group,
    required this.eventRepository,
    required this.currentUserId,
    this.isSuperadmin = false,
  });

  final BarangayGroup group;
  final EventRepository eventRepository;
  final String? currentUserId;

  /// Lets a superadmin toggle the verified/official badge, and use
  /// ownership transfer as a fallback for a group whose creator already
  /// left/was demoted.
  final bool isSuperadmin;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  final _searchController = TextEditingController();
  List<GroupMember> _members = const [];
  String _query = '';
  bool _loading = true;
  final Set<String> _busyIds = {};

  // Tracked locally (rather than read straight off widget.group) since
  // both can change while this page is open — a toggle or a completed
  // transfer needs to be reflected immediately, not just after re-opening.
  late bool _isVerified = widget.group.isVerified;
  late String? _createdBy = widget.group.createdBy;
  late bool _requiresApproval = widget.group.requiresApproval;
  bool _verifyBusy = false;
  bool _transferBusy = false;
  bool _joinPolicyBusy = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final members = await widget.eventRepository.listGroupMembers(widget.group.id);
      if (!mounted) return;
      setState(() => _members = members);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotLoadMembersError)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _myRole {
    for (final member in _members) {
      if (member.userId == widget.currentUserId) return member.role;
    }
    return '';
  }

  bool get _isAdmin => _myRole == 'admin';

  bool get _isCreator => _createdBy != null && _createdBy == widget.currentUserId;

  /// Ownership transfer is offered to the current creator, or to a
  /// superadmin as a fallback for a group whose creator already
  /// left/was demoted and can't do this themselves.
  bool get _canTransferOwnership => _isCreator || widget.isSuperadmin;

  List<GroupMember> get _filtered {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _members;
    return _members.where((member) => member.displayName.toLowerCase().contains(needle)).toList();
  }

  Future<void> _promote(GroupMember member) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busyIds.add(member.userId));
    try {
      await widget.eventRepository.promoteMember(widget.group.id, member.userId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.promotedToAdminMessage(member.displayName))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotPromoteError)),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(member.userId));
    }
  }

  Future<void> _remove(GroupMember member) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.removeMemberTitle(member.displayName)),
        content: Text(l10n.removeMemberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.removeButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(member.userId));
    try {
      await widget.eventRepository.removeMember(widget.group.id, member.userId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.removedMemberMessage(member.displayName))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotRemoveError)),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(member.userId));
    }
  }

  Future<void> _toggleVerified() async {
    final l10n = AppLocalizations.of(context)!;
    final next = !_isVerified;
    setState(() => _verifyBusy = true);
    try {
      await widget.eventRepository.setGroupVerified(widget.group.id, next);
      if (!mounted) return;
      setState(() => _isVerified = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next ? l10n.verifiedGroupMarked : l10n.verifiedGroupUnmarked)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotUpdateGroupError)),
      );
    } finally {
      if (mounted) setState(() => _verifyBusy = false);
    }
  }

  Future<void> _toggleRequiresApproval() async {
    final l10n = AppLocalizations.of(context)!;
    final next = !_requiresApproval;
    setState(() => _joinPolicyBusy = true);
    try {
      await widget.eventRepository.setGroupRequiresApproval(widget.group.id, next);
      if (!mounted) return;
      setState(() => _requiresApproval = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next ? l10n.requireApprovalEnabledMessage : l10n.requireApprovalDisabledMessage),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotUpdateJoinSettingError)),
      );
    } finally {
      if (mounted) setState(() => _joinPolicyBusy = false);
    }
  }

  Future<void> _transferOwnership() async {
    final l10n = AppLocalizations.of(context)!;
    final candidates = _members.where((member) => member.userId != _createdBy).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noOtherMembersError)),
      );
      return;
    }

    final chosen = await showDialog<GroupMember>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.transferOwnershipToTitle),
        children: [
          for (final member in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(member),
              child: Text(member.displayName),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.makeOwnerTitle(chosen.displayName)),
        content: Text(l10n.makeOwnerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.transferButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _transferBusy = true);
    try {
      await widget.eventRepository.transferGroupOwnership(widget.group.id, chosen.userId);
      await _load();
      if (!mounted) return;
      setState(() => _createdBy = chosen.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ownershipTransferredMessage(chosen.displayName))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotTransferError)),
      );
    } finally {
      if (mounted) setState(() => _transferBusy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteGroupConfirmTitle(widget.group.name)),
        content: Text(l10n.deleteGroupConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteGroupButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.eventRepository.deleteGroup(widget.group.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotDeleteGroupError)),
      );
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.group.code));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.codeCopiedMessage(widget.group.code))),
    );
  }

  /// Verified badge + its superadmin toggle, and the ownership-transfer
  /// entry point — only rendered when at least one of those is relevant
  /// to the viewer, so a regular member sees nothing extra here.
  Widget? _buildOwnerPanel() {
    if (!_isVerified && !widget.isSuperadmin && !_canTransferOwnership && !_isCreator) return null;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isVerified || widget.isSuperadmin)
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.certificate,
                      size: 16, color: _isVerified ? const Color(0xFF1F9D65) : colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isVerified ? l10n.verifiedOfficialGroup : l10n.notVerified,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _isVerified ? const Color(0xFF1F9D65) : colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  if (widget.isSuperadmin)
                    _verifyBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => unawaited(_toggleVerified()),
                            child: Text(_isVerified ? l10n.removeMarkButton : l10n.markAsOfficialButton),
                          ),
                ],
              ),
            if (_canTransferOwnership) ...[
              if (_isVerified || widget.isSuperadmin) const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.staffTurnoverHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _transferBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => unawaited(_transferOwnership()),
                          child: Text(l10n.transferOwnershipButton),
                        ),
                ],
              ),
            ],
            if (_isCreator) ...[
              if (_isVerified || widget.isSuperadmin || _canTransferOwnership) const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.deleteGroupHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                          onPressed: () => unawaited(_delete()),
                          child: Text(l10n.deleteGroupButton),
                        ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Join-policy toggle (open vs. requires approval) — visible to any
  /// admin of the group, independent of the owner-only settings above,
  /// since this is an ordinary group setting rather than a trust signal.
  Widget? _buildJoinSettingsPanel() {
    if (!_isAdmin) return null;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassPanel(
        child: Row(
          children: [
            FaIcon(
              _requiresApproval ? FontAwesomeIcons.userClock : FontAwesomeIcons.doorOpen,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _requiresApproval ? l10n.joinPolicyApprovalRequired : l10n.joinPolicyOpen,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    l10n.requiresApprovalHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _joinPolicyBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () => unawaited(_toggleRequiresApproval()),
                    child: Text(_requiresApproval ? l10n.allowInstantJoinButton : l10n.requireApprovalButton),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(GroupMember member) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarUrl = member.avatarUrl;
    return RoleAvatarFrame(
      role: member.accountRole,
      size: 40,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? Image.asset(avatarUrl, fit: BoxFit.cover)
          : IconBadge(
              icon: FontAwesomeIcons.circleUser,
              tint: colorScheme.primary,
              size: 40,
              iconSize: 16,
            ),
    );
  }

  Widget _buildMemberRow(GroupMember member) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final busy = _busyIds.contains(member.userId);
    final isSelf = member.userId == widget.currentUserId;
    final canRemove = _isAdmin && !isSelf && (!member.isAdmin || _isCreator);
    final canPromote = _isAdmin && !member.isAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildAvatar(member),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isSelf ? l10n.memberYouSuffix(member.displayName) : member.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (member.isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.adminBadge,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  l10n.joinedDatePrefix(DateFormat.yMMMd().format(member.joinedAt)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (canPromote || canRemove)
            PopupMenuButton<String>(
              icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16, color: colorScheme.onSurfaceVariant),
              onSelected: (value) {
                if (value == 'promote') unawaited(_promote(member));
                if (value == 'remove') unawaited(_remove(member));
              },
              itemBuilder: (context) => [
                if (canPromote)
                  PopupMenuItem(value: 'promote', child: Text(l10n.promoteToAdminMenuItem)),
                if (canRemove)
                  PopupMenuItem(value: 'remove', child: Text(l10n.removeFromGroupMenuItem)),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final ownerPanel = _buildOwnerPanel();
    final joinSettingsPanel = _buildJoinSettingsPanel();

    return GlassSubPage(
      title: widget.group.name,
      subtitle: '${_members.length} member${_members.length == 1 ? '' : 's'}'
          '${widget.group.isPrivate ? ' • Private' : ''}',
      children: [
        if (ownerPanel != null) ownerPanel,
        if (joinSettingsPanel != null) joinSettingsPanel,
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconBadge(
                    icon: FontAwesomeIcons.key,
                    tint: Color(0xFFFFA726),
                    size: 36,
                    iconSize: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.invitePeopleTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.invitePeopleBody(
                  widget.group.isPrivate ? l10n.sendsJoinRequestAction : l10n.joinsInstantlyAction,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: colorScheme.onSurface.withValues(alpha: 0.06),
                      ),
                      child: Text(
                        widget.group.code,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.copyCodeTooltip,
                    onPressed: () => unawaited(_copyCode()),
                    icon: const FaIcon(FontAwesomeIcons.copy, size: 15),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            labelText: l10n.searchMembersLabel,
            hintText: l10n.searchMembersHint,
            prefixIcon: glassFieldIcon(FontAwesomeIcons.magnifyingGlass, size: 14),
            prefixIconConstraints: glassFieldIconConstraints,
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: FontAwesomeIcons.peopleGroup,
                    tint: colorScheme.primary,
                    size: 40,
                    iconSize: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.membersHeader,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _query.isEmpty ? l10n.noMembersYet : l10n.noMembersMatch(_query),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                for (final member in _filtered) _buildMemberRow(member),
            ],
          ),
        ),
      ],
    );
  }
}
