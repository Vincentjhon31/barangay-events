import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'auth_service.dart';
import 'liquid_glass_components.dart';
import 'theme_controller.dart';

/// The Profile tab: a hub that shows the user's identity and links out to
/// dedicated pages for Profile Information and Settings.
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.authService,
    required this.themeController,
    this.onProfileSaved,
    this.onCalendarJoined,
  });

  final AppAuthService authService;
  final ThemeController themeController;
  final VoidCallback? onProfileSaved;

  /// Called after the user joins another calendar so the event list can
  /// refresh with the newly visible shared events.
  final VoidCallback? onCalendarJoined;

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

  void _openCalendarSharing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalendarSharingPage(
          authService: widget.authService,
          onCalendarJoined: widget.onCalendarJoined,
        ),
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
                icon: FontAwesomeIcons.userGroup,
                title: 'Calendar Sharing',
                subtitle: 'Your share code and joined calendars',
                onTap: _openCalendarSharing,
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

/// Shared scaffold for pages pushed from the Profile tab: liquid glass
/// backdrop, a glass back button and a page title.
class _GlassSubPage extends StatelessWidget {
  const _GlassSubPage({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(child: LiquidGlassBackdrop()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: IconBadge(
                        icon: FontAwesomeIcons.chevronLeft,
                        tint: colorScheme.primary,
                        size: 44,
                        iconSize: 16,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ...children,
              ],
            ),
          ),
        ],
      ),
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
    return _GlassSubPage(
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
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: FaIcon(FontAwesomeIcons.userPen),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department / Office',
                  hintText: "e.g. Mayor's Office, HRMO",
                  prefixIcon: FaIcon(FontAwesomeIcons.buildingUser),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: FaIcon(FontAwesomeIcons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio / About you',
                  prefixIcon: FaIcon(FontAwesomeIcons.alignLeft),
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
                decoration: const InputDecoration(
                  labelText: 'Street address',
                  prefixIcon: FaIcon(FontAwesomeIcons.houseChimney),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _barangayController,
                decoration: const InputDecoration(
                  labelText: 'Barangay',
                  prefixIcon: FaIcon(FontAwesomeIcons.mapPin),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: FaIcon(FontAwesomeIcons.buildingFlag),
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

/// Full page for calendar sharing: shows the user's own share code and
/// lets them join someone else's calendar with a code.
class CalendarSharingPage extends StatefulWidget {
  const CalendarSharingPage({
    super.key,
    required this.authService,
    this.onCalendarJoined,
  });

  final AppAuthService authService;
  final VoidCallback? onCalendarJoined;

  @override
  State<CalendarSharingPage> createState() => _CalendarSharingPageState();
}

class _CalendarSharingPageState extends State<CalendarSharingPage> {
  final _joinCodeController = TextEditingController();
  String? _shareCode;
  bool _loadingCode = true;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadShareCode());
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadShareCode() async {
    String? code;
    try {
      code = await widget.authService.fetchShareCode();
    } catch (_) {
      code = null;
    }
    if (!mounted) return;
    setState(() {
      _shareCode = code;
      _loadingCode = false;
    });
  }

  Future<void> _copyShareCode() async {
    final code = _shareCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share code copied.')),
    );
  }

  Future<void> _joinCalendar() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a share code first.')),
      );
      return;
    }

    setState(() => _joining = true);

    try {
      final ownerLabel = await widget.authService.joinSharedCalendar(code);
      if (!mounted) return;

      _joinCodeController.clear();
      widget.onCalendarJoined?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You now follow $ownerLabel.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join. Check the code and try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _GlassSubPage(
      title: 'Calendar Sharing',
      subtitle: 'Follow an office, or let others follow yours.',
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: FontAwesomeIcons.qrcode,
                    tint: colorScheme.primary,
                    size: 40,
                    iconSize: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your share code',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_loadingCode)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_shareCode == null)
                Text(
                  'No share code available yet. Save your profile first, then come back here.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          _shareCode!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                                fontFamily: 'monospace',
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Copy code',
                      onPressed: () => unawaited(_copyShareCode()),
                      icon: const FaIcon(FontAwesomeIcons.copy, size: 16),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                'Give this code to people who should see your Shared events. '
                'Public events are visible to everyone, and Personal events stay private.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
                children: [
                  const IconBadge(
                    icon: FontAwesomeIcons.userPlus,
                    tint: Color(0xFF1F9D65),
                    size: 40,
                    iconSize: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Join a calendar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Share code',
                  hintText: 'e.g. A1B2C3',
                  prefixIcon: FaIcon(FontAwesomeIcons.key),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _joining ? null : () => unawaited(_joinCalendar()),
                icon: const FaIcon(FontAwesomeIcons.userGroup, size: 16),
                label: Text(_joining ? 'Joining...' : 'Join'),
              ),
              const SizedBox(height: 10),
              Text(
                "Enter an office's or a person's code once and their Shared "
                'events will always show up in your calendar.',
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
}

/// Full page for app settings (appearance / theme).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _GlassSubPage(
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
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

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
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
