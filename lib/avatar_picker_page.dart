import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'auth_service.dart';
import 'avatar_catalog.dart';
import 'avatar_image.dart';
import 'image_prep.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// Profile-picture selection: the user's own photo (picked from the gallery,
/// cropped square, stored on the Hostinger file server), or a picture from
/// the Anime / Animal / Person categories — the built-in ones plus any the
/// superadmin added from the portal. Picking saves immediately and pops back
/// with the updated profile.
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
  bool _uploading = false;
  List<AvatarOption> _presets = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadPresets());
  }

  Future<void> _loadPresets() async {
    try {
      final presets = await widget.authService.listAvatarPresets();
      if (mounted) setState(() => _presets = presets);
    } catch (_) {
      // No superadmin presets (or offline) — the built-in pictures remain.
    }
  }

  /// [widget.initialProfile] with a new picture — every other field carried
  /// over unchanged.
  AppUserProfile _profileWith(String avatar) {
    final p = widget.initialProfile;
    return AppUserProfile(
      id: p?.id ?? widget.authService.currentUser?.id ?? '',
      email: p?.email ?? widget.authService.currentUser?.email ?? '',
      displayName: p?.displayName,
      department: p?.department,
      phoneNumber: p?.phoneNumber,
      streetAddress: p?.streetAddress,
      barangay: p?.barangay,
      city: p?.city,
      bio: p?.bio,
      avatarUrl: avatar,
      role: p?.role ?? 'citizen',
      lguRequestStatus: p?.lguRequestStatus,
      isKioskAccount: p?.isKioskAccount ?? false,
      calendarGroupFilterIds: p?.calendarGroupFilterIds ?? const [],
      adminPermissions: p?.adminPermissions ?? const {},
    );
  }

  bool get _hasUploadedPhoto {
    final current = widget.initialProfile?.avatarUrl;
    return current != null && current.contains('/avatars/users/');
  }

  Future<void> _pick(AvatarOption option) async {
    if (_saving != null || _uploading) return;
    setState(() => _saving = option.assetPath);
    final hadUploadedPhoto = _hasUploadedPhoto;

    try {
      await widget.authService.updateAvatar(option.assetPath);
      // Their old photo file is no longer used anywhere.
      if (hadUploadedPhoto) unawaited(widget.authService.deleteUploadedPhoto().catchError((_) {}));
      if (!mounted) return;
      Navigator.of(context).pop(_profileWith(option.assetPath));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.couldNotSaveAvatarError)),
      );
    }
  }

  Future<void> _uploadPhoto() async {
    if (_saving != null || _uploading) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      final bytes = result?.files.single.bytes;
      if (bytes == null) return;
      setState(() => _uploading = true);
      final photo = await squareProfilePhoto(bytes);
      final url = await widget.authService.uploadProfilePhoto(photo);
      if (!mounted) return;
      Navigator.of(context).pop(_profileWith(url));
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.avatarNotAPicture)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.avatarUploadFailed} $error')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _categoryLabel(AppLocalizations l10n, AvatarCategory category) {
    return switch (category) {
      AvatarCategory.anime => l10n.avatarCategoryAnime,
      AvatarCategory.animal => l10n.avatarCategoryAnimal,
      AvatarCategory.person => l10n.avatarCategoryPerson,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currentAvatar = widget.initialProfile?.avatarUrl;
    final options = [
      // Superadmin-added pictures first, so new ones are easy to spot.
      ..._presets.where((p) => p.category == _category),
      ...avatarsInCategory(_category),
    ];

    return GlassSubPage(
      title: l10n.profilePictureTitle,
      subtitle: l10n.profilePictureSubtitle,
      children: [
        GlassPanel(
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _hasUploadedPhoto
                      ? avatarImage(currentAvatar!, width: 56, height: 56)
                      : ColoredBox(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          child: Center(child: FaIcon(FontAwesomeIcons.camera, size: 20, color: colorScheme.primary)),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.avatarOwnPhotoTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.avatarOwnPhotoHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      key: const Key('avatar-upload-photo'),
                      onPressed: _uploading || _saving != null ? null : () => unawaited(_uploadPhoto()),
                      icon: _uploading
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const FaIcon(FontAwesomeIcons.upload, size: 14),
                      label: Text(_hasUploadedPhoto ? l10n.avatarChangePhotoButton : l10n.avatarUploadPhotoButton),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                  label: Text(_categoryLabel(l10n, category)),
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
              for (final option in options)
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
              child: avatarImage(
                option.assetPath,
                width: 64,
                height: 64,
                fallback: ColoredBox(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                  child: const SizedBox(width: 64, height: 64),
                ),
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
