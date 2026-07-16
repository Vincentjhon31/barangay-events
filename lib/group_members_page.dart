import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'event_store.dart';
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
  });

  final BarangayGroup group;
  final EventRepository eventRepository;
  final String? currentUserId;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  final _searchController = TextEditingController();
  List<GroupMember> _members = const [];
  String _query = '';
  bool _loading = true;
  final Set<String> _busyIds = {};

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load members. Please try again.')),
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

  bool get _isCreator =>
      widget.group.createdBy != null && widget.group.createdBy == widget.currentUserId;

  List<GroupMember> get _filtered {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _members;
    return _members.where((member) => member.displayName.toLowerCase().contains(needle)).toList();
  }

  Future<void> _promote(GroupMember member) async {
    setState(() => _busyIds.add(member.userId));
    try {
      await widget.eventRepository.promoteMember(widget.group.id, member.userId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.displayName} is now an admin.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not promote this member. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(member.userId));
    }
  }

  Future<void> _remove(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${member.displayName}?'),
        content: const Text(
          'They will lose access to this group\'s events until they rejoin with the code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
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
        SnackBar(content: Text('Removed ${member.displayName}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove this member. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(member.userId));
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.group.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code ${widget.group.code} copied.')),
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
                        isSelf ? '${member.displayName} (You)' : member.displayName,
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
                          'Admin',
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
                  'Joined ${DateFormat.yMMMd().format(member.joinedAt)}',
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
                  const PopupMenuItem(value: 'promote', child: Text('Promote to admin')),
                if (canRemove)
                  const PopupMenuItem(value: 'remove', child: Text('Remove from group')),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSubPage(
      title: widget.group.name,
      subtitle: '${_members.length} member${_members.length == 1 ? '' : 's'}'
          '${widget.group.isPrivate ? ' • Private' : ''}',
      children: [
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
                      'Invite people',
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
                'There\'s no user directory to add people from directly — share this '
                'code instead. Anyone who enters it '
                '${widget.group.isPrivate ? 'sends a request you approve' : 'joins instantly'}.',
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
                    tooltip: 'Copy code',
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
            labelText: 'Search members',
            hintText: 'Type a name',
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
                      'Members',
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
                    _query.isEmpty ? 'No members yet.' : 'No members match "$_query".',
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
