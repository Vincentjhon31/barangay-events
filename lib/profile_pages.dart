import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'about_page.dart';
import 'app_update_service.dart';
import 'auth_service.dart';
import 'avatar_picker_page.dart';
import 'create_group_page.dart';
import 'event_store.dart';
import 'group_members_page.dart';
import 'join_group_page.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';
import 'responsive_scale.dart';
import 'security_page.dart';
import 'theme_controller.dart';

/// The Profile tab: a hub that shows the user's identity and links out to
/// dedicated pages for Profile Information, Settings, and About.
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.authService,
    required this.themeController,
    this.onProfileSaved,
    this.updateService,
  });

  final AppAuthService authService;
  final ThemeController themeController;
  final VoidCallback? onProfileSaved;

  /// Null when the host build has no update checking wired up (e.g. widget
  /// tests) — passed straight through to [AboutPage].
  final AppUpdateService? updateService;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  AppUserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final authService = widget.authService;
    AppUserProfile? profile;
    if (authService is SupabaseAuthService) {
      profile = await authService.fetchUserProfile();
    } else {
      profile = authService.currentUser;
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _openProfileInformation() async {
    final updated = await Navigator.of(context).push<AppUserProfile>(
      MaterialPageRoute(
        builder: (_) => ProfileInformationPage(
          authService: widget.authService,
          initialProfile: _profile,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _profile = updated);
      widget.onProfileSaved?.call();
    }
  }

  void _openSecurity() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SecurityPage(authService: widget.authService),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(themeController: widget.themeController),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AboutPage(updateService: widget.updateService),
      ),
    );
  }

  Future<void> _openAvatarPicker() async {
    final updated = await Navigator.of(context).push<AppUserProfile>(
      MaterialPageRoute(
        builder: (_) => AvatarPickerPage(
          authService: widget.authService,
          initialProfile: _profile,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _profile = updated);
      widget.onProfileSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final l10n = AppLocalizations.of(context)!;
    final currentProfile = widget.authService.currentUser;
    final profile = _profile ?? currentProfile;
    final displayName = profile?.displayName?.trim().isNotEmpty == true
        ? profile!.displayName!
        : l10n.defaultMemberName;
    final email = profile?.email.isNotEmpty == true
        ? profile!.email
        : l10n.noEmailAvailable;
    final department = profile?.department?.trim();
    final colorScheme = Theme.of(context).colorScheme;
    final accountRole = profile?.role ?? 'citizen';
    final roleAccent = roleAccentColor(accountRole, colorScheme);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
      children: [
        const SizedBox(height: 8),
        Center(
          child: InkWell(
            key: const Key('profile-avatar-button'),
            borderRadius: BorderRadius.circular(999),
            onTap: () => unawaited(_openAvatarPicker()),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                RoleAvatarFrame(
                  role: accountRole,
                  size: 76,
                  badgeOnLeft: true,
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: profile?.avatarUrl != null
                        ? AssetImage(profile!.avatarUrl!)
                        : null,
                    child: profile?.avatarUrl == null
                        ? Text(
                            profile?.initials ?? 'B',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: IconBadge(
                    icon: FontAwesomeIcons.pen,
                    tint: colorScheme.primary,
                    size: 30,
                    iconSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: roleAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: roleAccent.withValues(alpha: 0.5)),
            ),
            child: Text(
              roleLabel(accountRole).toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: roleAccent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
            ),
          ),
        ),
        if (department != null && department.isNotEmpty) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.buildingUser,
                      size: 12, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    department,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 26),
        Text(
          l10n.accountSectionHeader,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              QuickActionTile(
                icon: FontAwesomeIcons.idCard,
                title: l10n.profileInformationTile,
                subtitle: l10n.profileInformationCaption,
                onTap: () => unawaited(_openProfileInformation()),
              ),
              Divider(
                height: 8,
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              QuickActionTile(
                key: const Key('profile-security-tile'),
                icon: FontAwesomeIcons.shieldHalved,
                title: l10n.securityTile,
                subtitle: l10n.securityTileCaption,
                onTap: _openSecurity,
              ),
              Divider(
                height: 8,
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              QuickActionTile(
                icon: FontAwesomeIcons.gear,
                title: l10n.settingsTile,
                subtitle: l10n.settingsTileCaption,
                onTap: _openSettings,
              ),
              Divider(
                height: 8,
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              QuickActionTile(
                icon: FontAwesomeIcons.circleInfo,
                title: l10n.aboutTile,
                subtitle: l10n.aboutTileCaption,
                onTap: _openAbout,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => unawaited(widget.authService.signOut()),
          child: GlassPanel(
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            tint: colorScheme.error,
            tintAlpha: 0.10,
            child: Row(
              children: [
                IconBadge(
                  icon: FontAwesomeIcons.arrowRightFromBracket,
                  tint: colorScheme.error,
                  size: 40,
                  iconSize: 16,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.signOut,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.error,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full page for editing the user's profile details.
class ProfileInformationPage extends StatefulWidget {
  const ProfileInformationPage({
    super.key,
    required this.authService,
    this.initialProfile,
  });

  final AppAuthService authService;
  final AppUserProfile? initialProfile;

  @override
  State<ProfileInformationPage> createState() => _ProfileInformationPageState();
}

class _ProfileInformationPageState extends State<ProfileInformationPage> {
  /// Citizens don't have a department/office — that's an LGU-role concept
  /// (see [[project-event-sharing-model]]) — so the field is hidden for
  /// them entirely rather than shown-but-irrelevant.
  bool get _isCitizen => (widget.initialProfile?.role ?? 'citizen') == 'citizen';

  late final TextEditingController _displayNameController;
  late final TextEditingController _departmentController;
  late final TextEditingController _phoneController;
  late final TextEditingController _streetAddressController;
  late final TextEditingController _barangayController;
  late final TextEditingController _cityController;
  late final TextEditingController _bioController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _displayNameController =
        TextEditingController(text: profile?.displayName ?? '');
    _departmentController =
        TextEditingController(text: profile?.department ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _streetAddressController =
        TextEditingController(text: profile?.streetAddress ?? '');
    _barangayController = TextEditingController(text: profile?.barangay ?? '');
    _cityController = TextEditingController(text: profile?.city ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _streetAddressController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final authService = widget.authService;
    final currentProfile = authService.currentUser;
    final nextName = _displayNameController.text.trim();
    if (nextName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty.')),
      );
      return;
    }

    String? valueOrNull(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    final updatedProfile = AppUserProfile(
      id: widget.initialProfile?.id ?? currentProfile?.id ?? '',
      email: widget.initialProfile?.email ?? currentProfile?.email ?? '',
      displayName: nextName,
      department: _isCitizen ? null : valueOrNull(_departmentController),
      phoneNumber: valueOrNull(_phoneController),
      streetAddress: valueOrNull(_streetAddressController),
      barangay: valueOrNull(_barangayController),
      city: valueOrNull(_cityController),
      bio: valueOrNull(_bioController),
      avatarUrl: widget.initialProfile?.avatarUrl,
      role: widget.initialProfile?.role ?? 'citizen',
      lguRequestStatus: widget.initialProfile?.lguRequestStatus,
    );

    setState(() => _saving = true);

    try {
      if (authService is SupabaseAuthService) {
        await authService.createOrUpdateProfile(updatedProfile);
      } else {
        await authService.updateDisplayName(nextName);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.of(context).pop(updatedProfile);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save your profile. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassSubPage(
      title: 'Profile Information',
      subtitle: 'Tell your community who you are.',
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Personal Information',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.userPen),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              if (!_isCitizen) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _departmentController,
                  decoration: InputDecoration(
                    labelText: 'Department / Office',
                    hintText: "e.g. Mayor's Office, HRMO",
                    prefixIcon: glassFieldIcon(FontAwesomeIcons.buildingUser),
                    prefixIconConstraints: glassFieldIconConstraints,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.phone),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio / About you',
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.alignLeft),
                  prefixIconConstraints: glassFieldIconConstraints,
                  alignLabelWithHint: true,
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
                'Address',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _streetAddressController,
                decoration: InputDecoration(
                  labelText: 'Street address',
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.houseChimney),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _barangayController,
                decoration: InputDecoration(
                  labelText: 'Barangay',
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.mapPin),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: 'City',
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.buildingFlag),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: _saving ? null : () => unawaited(_saveProfile()),
          icon: const FaIcon(FontAwesomeIcons.floppyDisk),
          label: Text(_saving ? 'Saving...' : 'Save profile'),
        ),
      ],
    );
  }
}

/// The Groups tab (group-chat model): my groups with shareable codes,
/// create a group, find groups by name, or join with a code.
class GroupsTab extends StatefulWidget {
  const GroupsTab({
    super.key,
    required this.eventRepository,
    required this.currentUserId,
    required this.canCreateGroups,
    this.isSuperadmin = false,
    this.onGroupsChanged,
  });

  final EventRepository eventRepository;

  /// Used to gate member-management actions (promote/remove) in
  /// [GroupMembersPage] — null in build configurations without auth.
  final String? currentUserId;

  /// Group creation ("create a gc") is an LGU-member/superadmin
  /// privilege — citizens can still join existing groups by search or
  /// code, just not create new ones.
  final bool canCreateGroups;

  /// Lets [GroupMembersPage] surface the verified/official badge toggle,
  /// and lets ownership transfer fall back to a superadmin for a group
  /// whose creator already left/was demoted.
  final bool isSuperadmin;
  final VoidCallback? onGroupsChanged;

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  final _searchController = TextEditingController();

  List<BarangayGroup> _myGroups = const [];
  List<BarangayGroup> _searchResults = const [];
  List<GroupJoinRequest> _pendingRequests = const [];
  final Set<String> _busyIds = {};
  final Set<String> _respondingIds = {};
  bool _searched = false;
  bool _searching = false;
  bool _searchExpanded = false;
  bool _loadingGroups = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isMember(String groupId) =>
      _myGroups.any((group) => group.id == groupId);

  Future<void> _loadAll() async {
    setState(() => _loadingGroups = true);
    await Future.wait([_loadMyGroups(), _loadPendingRequests()]);
    if (mounted) setState(() => _loadingGroups = false);
  }

  Future<void> _loadMyGroups() async {
    try {
      final groups = await widget.eventRepository.listMyGroups();
      if (!mounted) return;
      setState(() => _myGroups = groups);
    } catch (_) {
      // Groups unavailable (e.g. migration not run yet) — leave empty.
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final requests = await widget.eventRepository.listPendingJoinRequests();
      if (!mounted) return;
      setState(() => _pendingRequests = requests);
    } catch (_) {
      // Feature unavailable (e.g. migration not run yet) — leave empty.
    }
  }

  Future<void> _respondToRequest(GroupJoinRequest request,
      {required bool accept}) async {
    setState(() => _respondingIds.add(request.id));
    try {
      await widget.eventRepository
          .respondToJoinRequest(request.id, accept: accept);
      if (!mounted) return;
      await Future.wait([_loadPendingRequests(), _loadMyGroups()]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? '${request.requesterLabel} joined "${request.groupName}".'
                : 'Declined ${request.requesterLabel}\'s request.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Could not respond to the request. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _respondingIds.remove(request.id));
    }
  }

  Future<void> _openCreateGroup() async {
    if (!widget.canCreateGroups) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only verified LGU members can create a group. You can still '
            'join one by searching its name or entering a code.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final created = await Navigator.of(context).push<BarangayGroup>(
      MaterialPageRoute(
        builder: (_) =>
            CreateGroupPage(eventRepository: widget.eventRepository),
      ),
    );
    if (created == null || !mounted) return;
    await _loadMyGroups();
    widget.onGroupsChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created.isPrivate
              ? 'Created private group "${created.name}". Code ${created.code} lets '
                  'people request to join — you approve who gets in.'
              : 'Created "${created.name}". Share code ${created.code} so others can join.',
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _openJoinByCode() async {
    final result = await Navigator.of(context).push<GroupJoinResult>(
      MaterialPageRoute(
        builder: (_) => JoinGroupPage(eventRepository: widget.eventRepository),
      ),
    );
    if (result == null || !mounted) return;

    if (result.status == GroupJoinStatus.joined) {
      await _loadMyGroups();
      widget.onGroupsChanged?.call();
    }
    if (!mounted) return;
    final message = switch (result.status) {
      GroupJoinStatus.joined => 'You joined "${result.group.name}".',
      GroupJoinStatus.pending =>
        'Request sent — waiting for "${result.group.name}" to approve you.',
      GroupJoinStatus.alreadyMember =>
        'You\'re already in "${result.group.name}".',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openGroupMembers(BarangayGroup group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupMembersPage(
          group: group,
          eventRepository: widget.eventRepository,
          currentUserId: widget.currentUserId,
          isSuperadmin: widget.isSuperadmin,
        ),
      ),
    );
    // Membership/role may have changed while the member page was open
    // (self-promotion state, someone else removed us, etc.) — this also
    // needs to reach the calendar screen, since its admin-gated Edit
    // button relies on a cache that's otherwise only refreshed on
    // app start, pull-to-refresh, or join/leave/create.
    if (!mounted) return;
    await _loadMyGroups();
    widget.onGroupsChanged?.call();
  }

  // A blank [_searchController] deliberately still runs the search — the
  // repository treats an empty query as "browse all public groups" rather
  // than requiring a name to be typed first.
  Future<void> _search() async {
    final query = _searchController.text.trim();

    setState(() => _searching = true);
    try {
      final results = await widget.eventRepository.searchGroups(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _join(BarangayGroup group) async {
    setState(() => _busyIds.add(group.id));
    try {
      await widget.eventRepository.joinGroup(group.id);
      if (!mounted) return;
      await _loadMyGroups();
      widget.onGroupsChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You joined "${group.name}".')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not join the group. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(group.id));
    }
  }

  Future<void> _leave(BarangayGroup group) async {
    setState(() => _busyIds.add(group.id));
    try {
      await widget.eventRepository.leaveGroup(group.id);
      if (!mounted) return;
      await _loadMyGroups();
      widget.onGroupsChanged?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not leave the group. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(group.id));
    }
  }

  Future<void> _copyCode(BarangayGroup group) async {
    await Clipboard.setData(ClipboardData(text: group.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code ${group.code} copied.')),
    );
  }

  Widget _buildPanelHeader(FaIconData icon, Color tint, String title) {
    return Row(
      children: [
        IconBadge(icon: icon, tint: tint, size: 40, iconSize: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(FaIconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          FaIcon(icon,
              size: 18,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestRow(GroupJoinRequest request) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final busy = _respondingIds.contains(request.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: FontAwesomeIcons.circleUser,
            tint: Color(0xFFE53935),
            size: 38,
            iconSize: 15,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.requesterLabel,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  l10n.wantsToJoinGroup(request.groupName),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                _respondToRequest(request, accept: false)),
                        child: Text(l10n.declineButton),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                _respondToRequest(request, accept: true)),
                        child: Text(l10n.acceptButton),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyGroupRow(BarangayGroup group) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final busy = _busyIds.contains(group.id);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => unawaited(_openGroupMembers(group)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconBadge(
              icon: FontAwesomeIcons.peopleGroup,
              tint: colorScheme.primary,
              size: 38,
              iconSize: 15,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (group.isAdmin) ...[
                        const SizedBox(width: 6),
                        FaIcon(
                          FontAwesomeIcons.solidStar,
                          size: 11,
                          color: colorScheme.primary,
                        ),
                      ],
                      if (group.isPrivate) ...[
                        const SizedBox(width: 6),
                        FaIcon(
                          FontAwesomeIcons.lock,
                          size: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    l10n.memberCountWithCode(group.memberCount, group.code),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.copyGroupCode,
              onPressed: () => unawaited(_copyCode(group)),
              icon: const FaIcon(FontAwesomeIcons.copy, size: 15),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => unawaited(_leave(group)),
              child: Text(l10n.leaveButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultRow(BarangayGroup group) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final busy = _busyIds.contains(group.id);
    final member = _isMember(group.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const IconBadge(
            icon: FontAwesomeIcons.peopleGroup,
            tint: Color(0xFF1F9D65),
            size: 38,
            iconSize: 15,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  l10n.memberCount(group.memberCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (member)
            OutlinedButton(onPressed: null, child: Text(l10n.joinedButton))
          else
            FilledButton(
              onPressed: busy ? null : () => unawaited(_join(group)),
              child: Text(l10n.joinButton),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelHeader(
            FontAwesomeIcons.magnifyingGlass,
            const Color(0xFF1F9D65),
            l10n.searchGroups,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => unawaited(_search()),
            decoration: InputDecoration(
              labelText: l10n.searchByName,
              hintText: l10n.searchHintExample,
              prefixIcon:
                  glassFieldIcon(FontAwesomeIcons.magnifyingGlass, size: 14),
              prefixIconConstraints: glassFieldIconConstraints,
              suffixIcon: TextButton(
                key: const Key('groups-search-button'),
                onPressed: _searching ? null : () => unawaited(_search()),
                child: Text(_searching ? '...' : l10n.searchButton),
              ),
            ),
          ),
          if (_searched) ...[
            const SizedBox(height: 4),
            if (_searchResults.isEmpty)
              _buildEmptyState(
                FontAwesomeIcons.magnifyingGlass,
                l10n.noGroupsFound,
              )
            else
              for (final group in _searchResults) _buildSearchResultRow(group),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              l10n.privateGroupsHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModuleTile({
    required FaIconData icon,
    required Color tint,
    required String label,
    required String caption,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, tint: tint, size: 42, iconSize: 17),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.groupsTitle,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.groupsSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _searchExpanded ? l10n.closeSearch : l10n.searchGroups,
                onPressed: () {
                  final opening = !_searchExpanded;
                  setState(() {
                    _searchExpanded = opening;
                    if (!opening) {
                      _searched = false;
                      _searchResults = const [];
                      _searchController.clear();
                    }
                  });
                  // Browse all public groups immediately on open, rather
                  // than requiring a name to be typed first.
                  if (opening) unawaited(_search());
                },
                icon: FaIcon(
                  _searchExpanded
                      ? FontAwesomeIcons.xmark
                      : FontAwesomeIcons.magnifyingGlass,
                  size: 18,
                ),
              ),
            ],
          ),
          if (_searchExpanded) ...[
            const SizedBox(height: 12),
            _buildSearchPanel(),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildModuleTile(
                  icon: widget.canCreateGroups
                      ? FontAwesomeIcons.plus
                      : FontAwesomeIcons.lock,
                  tint: widget.canCreateGroups
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  label: l10n.groupsCreateTile,
                  caption: widget.canCreateGroups
                      ? l10n.groupsCreateCaption
                      : l10n.groupsCreateLguOnly,
                  onTap: () => unawaited(_openCreateGroup()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModuleTile(
                  icon: FontAwesomeIcons.key,
                  tint: const Color(0xFFFFA726),
                  label: l10n.groupsJoinTile,
                  caption: l10n.groupsJoinCaption,
                  onTap: () => unawaited(_openJoinByCode()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPanelHeader(
                  FontAwesomeIcons.peopleGroup,
                  colorScheme.primary,
                  l10n.myGroupsHeader(_myGroups.length),
                ),
                const SizedBox(height: 8),
                if (_loadingGroups)
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
                else if (_myGroups.isEmpty)
                  _buildEmptyState(
                    FontAwesomeIcons.peopleGroup,
                    l10n.myGroupsEmpty,
                  )
                else
                  for (final group in _myGroups) _buildMyGroupRow(group),
              ],
            ),
          ),
          if (_pendingRequests.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPanelHeader(
                    FontAwesomeIcons.userClock,
                    const Color(0xFFE53935),
                    l10n.joinRequestsHeader(_pendingRequests.length),
                  ),
                  const SizedBox(height: 8),
                  for (final request in _pendingRequests)
                    _buildRequestRow(request),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full page for app settings (appearance / theme).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return GlassSubPage(
      title: l10n.settingsTitle,
      subtitle: l10n.settingsSubtitle,
      children: [
        Text(
          l10n.settingsAppearance,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            final mode = themeController.themeMode;
            return Column(
              children: [
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.circleHalfStroke,
                  label: l10n.settingsSystemDefault,
                  selected: mode == ThemeMode.system,
                  onTap: () => themeController.setThemeMode(ThemeMode.system),
                ),
                const SizedBox(height: 10),
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.sun,
                  label: l10n.settingsLight,
                  selected: mode == ThemeMode.light,
                  onTap: () => themeController.setThemeMode(ThemeMode.light),
                ),
                const SizedBox(height: 10),
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.moon,
                  label: l10n.settingsDark,
                  selected: mode == ThemeMode.dark,
                  onTap: () => themeController.setThemeMode(ThemeMode.dark),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          l10n.settingsAppStyle,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            final style = themeController.uiStyle;
            return Column(
              children: [
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.wandMagicSparkles,
                  label: l10n.settingsLiquidGlass,
                  subtitle: l10n.settingsLiquidGlassSubtitle,
                  selected: style == UiStyle.liquid,
                  onTap: () => themeController.setUiStyle(UiStyle.liquid),
                ),
                const SizedBox(height: 10),
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.bolt,
                  label: l10n.settingsSolid,
                  subtitle: l10n.settingsSolidSubtitle,
                  selected: style == UiStyle.solid,
                  onTap: () => themeController.setUiStyle(UiStyle.solid),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          l10n.settingsDisplaySize,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.settingsDisplaySizeHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            final displayMode = themeController.displayMode;
            final options = <(DisplayMode, FaIconData, String)>[
              (DisplayMode.auto, FontAwesomeIcons.wandMagicSparkles, l10n.settingsDisplayAuto),
              (DisplayMode.mobile, FontAwesomeIcons.mobileScreen, l10n.settingsDisplayMobile),
              (DisplayMode.tablet, FontAwesomeIcons.tabletScreenButton, l10n.settingsDisplayTablet),
              (DisplayMode.windows, FontAwesomeIcons.desktop, l10n.settingsDisplayWindows),
            ];
            return Column(
              children: [
                for (final (mode, icon, subtitle) in options) ...[
                  _ThemeOptionTile(
                    icon: icon,
                    label: mode.label,
                    subtitle: subtitle,
                    selected: displayMode == mode,
                    onTap: () => themeController.setDisplayMode(mode),
                  ),
                  if (mode != options.last.$1) const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          l10n.settingsLanguage,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.settingsLanguageHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            final language = themeController.locale.languageCode;
            return Column(
              children: [
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.language,
                  label: l10n.settingsLanguageEnglish,
                  selected: language == 'en',
                  onTap: () => themeController.setLanguage('en'),
                ),
                const SizedBox(height: 10),
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.language,
                  label: l10n.settingsLanguageFilipino,
                  selected: language == 'fil',
                  onTap: () => themeController.setLanguage('fil'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: GlassPanel(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        tint: selected ? colorScheme.primary : null,
        tintAlpha: selected ? 0.18 : null,
        child: Row(
          children: [
            IconBadge(
                icon: icon, tint: colorScheme.primary, size: 40, iconSize: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (selected)
              FaIcon(FontAwesomeIcons.circleCheck,
                  size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
