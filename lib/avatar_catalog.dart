/// The fixed set of pickable profile-picture avatars — no upload/capture,
/// users choose one of these bundled images. Files live at
/// `assets/avatars/<category>/<category>_NN.png` (declared in
/// pubspec.yaml's `flutter: assets:`), resized/compressed down from the
/// original 1080x1080 sources (~20MB total) to 200x200 (~1.9MB total).
enum AvatarCategory {
  anime('Anime'),
  animal('Animal'),
  person('Person');

  const AvatarCategory(this.label);
  final String label;
}

class AvatarOption {
  const AvatarOption({required this.assetPath, required this.category});
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
