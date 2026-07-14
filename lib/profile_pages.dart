import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'about_page.dart';
import 'app_update_service.dart';
import 'auth_service.dart';
import 'event_store.dart';
import 'liquid_glass_components.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentProfile = widget.authService.currentUser;
    final profile = _profile ?? currentProfile;
    final displayName = profile?.displayName?.trim().isNotEmpty == true
        ? profile!.displayName!
        : 'Barangay Member';
    final email = profile?.email.isNotEmpty == true
        ? profile!.email
        : 'No email available';
    final department = profile?.department?.trim();
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
      children: [
        const SizedBox(height: 8),
        Center(
          child: CircleAvatar(
            radius: 38,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              profile?.initials ?? 'B',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
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
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.buildingUser, size: 12, color: colorScheme.primary),
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
          'Account',
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
                title: 'Profile Information',
                subtitle: 'Name, department, contact and address',
                onTap: () => unawaited(_openProfileInformation()),
              ),
              Divider(
                height: 8,
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              QuickActionTile(
                icon: FontAwesomeIcons.gear,
                title: 'Settings',
                subtitle: 'Appearance and app preferences',
                onTap: _openSettings,
              ),
              Divider(
                height: 8,
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              QuickActionTile(
                icon: FontAwesomeIcons.circleInfo,
                title: 'About',
                subtitle: 'Version, updates, and what\'s new',
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
                    'Sign out',
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
    _displayNameController = TextEditingController(text: profile?.displayName ?? '');
    _departmentController = TextEditingController(text: profile?.department ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _streetAddressController = TextEditingController(text: profile?.streetAddress ?? '');
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
      department: valueOrNull(_departmentController),
      phoneNumber: valueOrNull(_phoneController),
      streetAddress: valueOrNull(_streetAddressController),
      barangay: valueOrNull(_barangayController),
      city: valueOrNull(_cityController),
      bio: valueOrNull(_bioController),
      avatarUrl: widget.initialProfile?.avatarUrl,
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
        const SnackBar(content: Text('Could not save your profile. Please try again.')),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
    this.onGroupsChanged,
  });

  final EventRepository eventRepository;
  final VoidCallback? onGroupsChanged;

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

enum _GroupAddMode { create, search, code }

class _GroupsTabState extends State<GroupsTab> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _codeController = TextEditingController();

  List<BarangayGroup> _myGroups = const [];
  List<BarangayGroup> _searchResults = const [];
  List<GroupJoinRequest> _pendingRequests = const [];
  final Set<String> _busyIds = {};
  final Set<String> _respondingIds = {};
  bool _searched = false;
  bool _searching = false;
  bool _creating = false;
  bool _isPrivate = false;
  bool _joiningByCode = false;
  bool _loadingGroups = true;
  _GroupAddMode _addMode = _GroupAddMode.create;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _codeController.dispose();
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

  Future<void> _respondToRequest(GroupJoinRequest request, {required bool accept}) async {
    setState(() => _respondingIds.add(request.id));
    try {
      await widget.eventRepository.respondToJoinRequest(request.id, accept: accept);
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
        const SnackBar(content: Text('Could not respond to the request. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _respondingIds.remove(request.id));
    }
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name first.')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final group = await widget.eventRepository.createGroup(name, isPrivate: _isPrivate);
      if (!mounted) return;
      _nameController.clear();
      final wasPrivate = _isPrivate;
      setState(() => _isPrivate = false);
      await _loadMyGroups();
      widget.onGroupsChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasPrivate
                ? 'Created private group "${group.name}". Code ${group.code} lets people '
                    'request to join — you approve who gets in.'
                : 'Created "${group.name}". Share code ${group.code} so others can join.',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the group. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

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
        const SnackBar(content: Text('Could not join the group. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(group.id));
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group code first.')),
      );
      return;
    }

    setState(() => _joiningByCode = true);
    try {
      final result = await widget.eventRepository.requestOrJoinGroupByCode(code);
      if (!mounted) return;
      _codeController.clear();

      switch (result.status) {
        case GroupJoinStatus.joined:
          await _loadMyGroups();
          widget.onGroupsChanged?.call();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You joined "${result.group.name}".')),
          );
        case GroupJoinStatus.pending:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Request sent — waiting for "${result.group.name}" to approve you.',
              ),
            ),
          );
        case GroupJoinStatus.alreadyMember:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You\'re already in "${result.group.name}".')),
          );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not join. Check the code and try again.')),
      );
    } finally {
      if (mounted) setState(() => _joiningByCode = false);
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
        const SnackBar(content: Text('Could not leave the group. Please try again.')),
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
          FaIcon(icon, size: 18, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
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
                  'wants to join "${request.groupName}"',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed:
                          busy ? null : () => unawaited(_respondToRequest(request, accept: false)),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          busy ? null : () => unawaited(_respondToRequest(request, accept: true)),
                      child: const Text('Accept'),
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
    final busy = _busyIds.contains(group.id);

    return Padding(
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
                  '${group.memberCount} member${group.memberCount == 1 ? '' : 's'} • code ${group.code}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy group code',
            onPressed: () => unawaited(_copyCode(group)),
            icon: const FaIcon(FontAwesomeIcons.copy, size: 15),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => unawaited(_leave(group)),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultRow(BarangayGroup group) {
    final colorScheme = Theme.of(context).colorScheme;
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
                  '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (member)
            const OutlinedButton(onPressed: null, child: Text('Joined'))
          else
            FilledButton(
              onPressed: busy ? null : () => unawaited(_join(group)),
              child: const Text('Join'),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateModeContent(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Group name',
            hintText: "e.g. Mayor's Office Updates",
            prefixIcon: glassFieldIcon(FontAwesomeIcons.penToSquare, size: 14),
            prefixIconConstraints: glassFieldIconConstraints,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private group',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Hidden from search — people need your code, and '
                    'you approve who joins.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: _creating ? null : () => unawaited(_createGroup()),
          icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
          label: Text(_creating ? 'Creating...' : 'Create group'),
        ),
        const SizedBox(height: 10),
        Text(
          _isPrivate
              ? 'You approve each person who requests to join with your code.'
              : 'You get a code to share; anyone who joins sees every Group '
                  'event you post there.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildSearchModeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => unawaited(_search()),
          decoration: InputDecoration(
            labelText: 'Search by name',
            hintText: 'e.g. Mayor',
            prefixIcon: glassFieldIcon(FontAwesomeIcons.magnifyingGlass, size: 14),
            prefixIconConstraints: glassFieldIconConstraints,
            suffixIcon: TextButton(
              key: const Key('groups-search-button'),
              onPressed: _searching ? null : () => unawaited(_search()),
              child: Text(_searching ? '...' : 'Search'),
            ),
          ),
        ),
        if (_searched) ...[
          const SizedBox(height: 4),
          if (_searchResults.isEmpty)
            _buildEmptyState(
              FontAwesomeIcons.magnifyingGlass,
              'No groups found. Try another name, or ask for the code.',
            )
          else
            for (final group in _searchResults) _buildSearchResultRow(group),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Private groups won\'t show up here — you\'ll need their code.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildCodeModeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Group code',
            hintText: 'e.g. QXK2P9',
            prefixIcon: glassFieldIcon(FontAwesomeIcons.key, size: 14),
            prefixIconConstraints: glassFieldIconConstraints,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: _joiningByCode ? null : () => unawaited(_joinByCode()),
          icon: const FaIcon(FontAwesomeIcons.userGroup, size: 14),
          label: Text(_joiningByCode ? 'Joining...' : 'Join group'),
        ),
        const SizedBox(height: 10),
        Text(
          'Ask whoever created the group for their 6-character code. Works '
          'for private groups too — it just sends a request instead of '
          'joining instantly.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildAddGroupPanel(ColorScheme colorScheme) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelHeader(
            FontAwesomeIcons.userGroup,
            const Color(0xFFFFA726),
            'Add a group',
          ),
          const SizedBox(height: 14),
          SegmentedButton<_GroupAddMode>(
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
              foregroundColor: colorScheme.onSurfaceVariant,
              selectedForegroundColor: colorScheme.onPrimary,
              selectedBackgroundColor: colorScheme.primary.withValues(alpha: 0.4),
              side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.12)),
            ),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<_GroupAddMode>(
                value: _GroupAddMode.create,
                label: Text('Create'),
                icon: FaIcon(FontAwesomeIcons.plus, size: 13),
              ),
              ButtonSegment<_GroupAddMode>(
                value: _GroupAddMode.search,
                label: Text('Find'),
                icon: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 13),
              ),
              ButtonSegment<_GroupAddMode>(
                value: _GroupAddMode.code,
                label: Text('Code'),
                icon: FaIcon(FontAwesomeIcons.key, size: 13),
              ),
            ],
            selected: {_addMode},
            onSelectionChanged: (selection) =>
                setState(() => _addMode = selection.first),
          ),
          const SizedBox(height: 16),
          switch (_addMode) {
            _GroupAddMode.create => _buildCreateModeContent(colorScheme),
            _GroupAddMode.search => _buildSearchModeContent(),
            _GroupAddMode.code => _buildCodeModeContent(),
          },
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          Text(
            'Groups',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Like group chats, but for events everyone should see.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPanelHeader(
                  FontAwesomeIcons.peopleGroup,
                  colorScheme.primary,
                  'My Groups (${_myGroups.length})',
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
                    'You are not in any group yet. Use "Add a group" below to '
                    'create one, search, or enter a code.',
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
                    'Join requests (${_pendingRequests.length})',
                  ),
                  const SizedBox(height: 8),
                  for (final request in _pendingRequests) _buildRequestRow(request),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildAddGroupPanel(colorScheme),
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

    return GlassSubPage(
      title: 'Settings',
      subtitle: 'Personalize how the app looks.',
      children: [
        Text(
          'Appearance',
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
                  label: 'System default',
                  selected: mode == ThemeMode.system,
                  onTap: () => themeController.setThemeMode(ThemeMode.system),
                ),
                const SizedBox(height: 10),
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.sun,
                  label: 'Light',
                  selected: mode == ThemeMode.light,
                  onTap: () => themeController.setThemeMode(ThemeMode.light),
                ),
                const SizedBox(height: 10),
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.moon,
                  label: 'Dark',
                  selected: mode == ThemeMode.dark,
                  onTap: () => themeController.setThemeMode(ThemeMode.dark),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          'App style',
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
                  label: 'Liquid Glass',
                  subtitle: 'Translucent panels and glowing colors',
                  selected: style == UiStyle.liquid,
                  onTap: () => themeController.setUiStyle(UiStyle.liquid),
                ),
                const SizedBox(height: 10),
                _ThemeOptionTile(
                  icon: FontAwesomeIcons.bolt,
                  label: 'Solid',
                  subtitle: 'Plain colors — faster on most phones',
                  selected: style == UiStyle.solid,
                  onTap: () => themeController.setUiStyle(UiStyle.solid),
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
            IconBadge(icon: icon, tint: colorScheme.primary, size: 40, iconSize: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
              FaIcon(FontAwesomeIcons.circleCheck, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
