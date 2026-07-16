import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'auth_service.dart';
import 'avatar_catalog.dart';
import 'liquid_glass_components.dart';

/// Profile-picture selection — a fixed catalog of bundled images grouped by
/// category (Anime / Animal / Person), no upload or camera capture. Tapping
/// an image saves it immediately and pops back with the updated profile.
class AvatarPickerPage extends StatefulWidget {
  const AvatarPickerPage({
    super.key,
    required this.authService,
    required this.initialProfile,
  });

  final AppAuthService authService;
  final AppUserProfile? initialProfile;

  @override
  State<AvatarPickerPage> createState() => _AvatarPickerPageState();
}

class _AvatarPickerPageState extends State<AvatarPickerPage> {
  AvatarCategory _category = AvatarCategory.anime;
  String? _saving;

  Future<void> _pick(AvatarOption option) async {
    if (_saving != null) return;
    setState(() => _saving = option.assetPath);

    try {
      await widget.authService.updateAvatar(option.assetPath);
      if (!mounted) return;

      final updated = AppUserProfile(
        id: widget.initialProfile?.id ?? widget.authService.currentUser?.id ?? '',
        email: widget.initialProfile?.email ?? widget.authService.currentUser?.email ?? '',
        displayName: widget.initialProfile?.displayName,
        department: widget.initialProfile?.department,
        phoneNumber: widget.initialProfile?.phoneNumber,
        streetAddress: widget.initialProfile?.streetAddress,
        barangay: widget.initialProfile?.barangay,
        city: widget.initialProfile?.city,
        bio: widget.initialProfile?.bio,
        avatarUrl: option.assetPath,
        role: widget.initialProfile?.role ?? 'citizen',
        lguRequestStatus: widget.initialProfile?.lguRequestStatus,
      );
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your profile picture. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentAvatar = widget.initialProfile?.avatarUrl;

    return GlassSubPage(
      title: 'Profile Picture',
      subtitle: 'Pick one — it saves right away.',
      children: [
        GlassPanel(
          child: SegmentedButton<AvatarCategory>(
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
              foregroundColor: colorScheme.onSurfaceVariant,
              selectedForegroundColor: colorScheme.onPrimary,
              selectedBackgroundColor: colorScheme.primary.withValues(alpha: 0.4),
              side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.12)),
            ),
            showSelectedIcon: false,
            segments: [
              for (final category in AvatarCategory.values)
                ButtonSegment<AvatarCategory>(
                  value: category,
                  label: Text(category.label),
                ),
            ],
            selected: {_category},
            onSelectionChanged: (selection) => setState(() => _category = selection.first),
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              for (final option in avatarsInCategory(_category))
                _buildTile(option, colorScheme, isSelected: option.assetPath == currentAvatar),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile(AvatarOption option, ColorScheme colorScheme, {required bool isSelected}) {
    final isSaving = _saving == option.assetPath;

    return InkWell(
      key: Key('avatar-option-${option.assetPath}'),
      borderRadius: BorderRadius.circular(999),
      onTap: () => unawaited(_pick(option)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: Image.asset(
                option.assetPath,
                fit: BoxFit.cover,
                width: 64,
                height: 64,
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: IconBadge(
                icon: FontAwesomeIcons.check,
                tint: colorScheme.primary,
                size: 20,
                iconSize: 10,
              ),
            ),
          if (isSaving)
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
