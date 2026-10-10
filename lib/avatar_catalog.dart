/// The built-in profile pictures. Besides these, the superadmin can add more
/// to each category from the portal (stored on Hostinger — see
/// `AppAuthService.listAvatarPresets`), and users can upload their own photo. Files live at
/// `assets/avatars/<category>/<category>_NN.png` (declared in
/// pubspec.yaml's `flutter: assets:`), resized/compressed down from the
/// original 1080x1080 sources (~20MB total) to 200x200 (~1.9MB total).
enum AvatarCategory {
  anime('Anime'),
  animal('Animal'),
  person('Person');

  const AvatarCategory(this.label);
  final String label;

  /// The category for its database key ('anime' | 'animal' | 'person').
  static AvatarCategory? fromKey(String? key) {
    for (final category in values) {
      if (category.name == key) return category;
    }
    return null;
  }
}

class AvatarOption {
  const AvatarOption({required this.assetPath, required this.category});

  /// A built-in picture's asset path, or a superadmin preset's web link —
  /// either way, what gets saved as the profile's avatar_url.
  final String assetPath;
  final AvatarCategory category;
}

List<AvatarOption> _options(AvatarCategory category, int count) {
  return List.generate(count, (i) {
    final number = (i + 1).toString().padLeft(2, '0');
    return AvatarOption(
      assetPath: 'assets/avatars/${category.name}/${category.name}_$number.png',
      category: category,
    );
  });
}

/// All pickable avatars across every category.
final List<AvatarOption> avatarCatalog = [
  ..._options(AvatarCategory.anime, 14),
  ..._options(AvatarCategory.animal, 14),
  ..._options(AvatarCategory.person, 13),
];

List<AvatarOption> avatarsInCategory(AvatarCategory category) =>
    avatarCatalog.where((option) => option.category == category).toList();
