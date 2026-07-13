import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

bool isDarkContext(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// A `TextField`/`DropdownButtonFormField` prefix icon, centered inside a
/// fixed-size box. A bare `FaIcon` passed straight to `InputDecoration
/// .prefixIcon` looks inconsistently positioned field-to-field: Font
/// Awesome glyphs don't share Material icons' internal metrics, so each
/// icon's visible shape sits slightly differently within Flutter's default
/// 48x48 prefix box depending on the icon (e.g. `key` vs `envelope`). Pin
/// every field's icon to the same box with [glassFieldIconConstraints] so
/// a stacked form lines up cleanly regardless of which icons it uses.
Widget glassFieldIcon(FaIconData icon, {double size = 16}) {
  return Center(child: FaIcon(icon, size: size));
}

// Fixed (not just minimum) size: a min-only BoxConstraints leaves the max
// unbounded, and Center() inside the prefix-icon slot happily expands to
// fill whatever space that leaves it — which swallowed most of the actual
// text field, blocking taps and typing. Tight constraints keep this an
// icon-sized box, nothing more.
const BoxConstraints glassFieldIconConstraints = BoxConstraints.tightFor(width: 44, height: 44);

/// The app's visual style: the fancy translucent "Liquid Glass" look, or a
/// plain solid palette that renders much faster on low-end phones.
enum UiStyle { liquid, solid }

/// Makes the chosen [UiStyle] available to every glass component without
/// threading it through constructors. Defaults to [UiStyle.liquid] when no
/// scope is present (e.g. in isolated widget tests).
class AppStyleScope extends InheritedWidget {
  const AppStyleScope({super.key, required this.style, required super.child});

  final UiStyle style;

  static UiStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStyleScope>()?.style ??
      UiStyle.liquid;

  @override
  bool updateShouldNotify(AppStyleScope oldWidget) => oldWidget.style != style;
}

bool isSolidStyle(BuildContext context) => AppStyleScope.of(context) == UiStyle.solid;

/// A frosted backdrop with soft color blobs — the base layer for the
/// iOS 26 "Liquid Glass" look. Adapts its palette to light/dark mode.
class LiquidGlassBackdrop extends StatelessWidget {
  const LiquidGlassBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = isDarkContext(context);

    if (isSolidStyle(context)) {
      // Solid palette: a flat background, no orbs, no blur — the cheapest
      // thing a GPU can draw.
      return ColoredBox(
        color: dark ? const Color(0xFF05070C) : const Color(0xFFF8FCFF),
      );
    }

    // The whole backdrop is static, so it renders once into a cached layer
    // instead of re-blurring the screen every frame.
    return RepaintBoundary(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? const [
                        Color(0xFF05070C),
                        Color(0xFF0A0D14),
                        Color(0xFF06080D),
                      ]
                    : const [
                        Color(0xFFF8FCFF),
                        Color(0xFFF0F6FB),
                        Color(0xFFF7FBF6),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -60,
                    right: -30,
                    child: BlurOrb(color: const Color(0xFF2B7FFF).withValues(alpha: dark ? 0.28 : 0.20), size: 220),
                  ),
                  Positioned(
                    top: 220,
                    left: -50,
                    child: BlurOrb(color: const Color(0xFF1F9D65).withValues(alpha: dark ? 0.22 : 0.18), size: 200),
                  ),
                  Positioned(
                    bottom: 160,
                    right: 0,
                    child: BlurOrb(color: const Color(0xFFFFA726).withValues(alpha: dark ? 0.14 : 0.14), size: 160),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BlurOrb extends StatelessWidget {
  const BlurOrb({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 60,
            spreadRadius: 24,
          ),
        ],
      ),
    );
  }
}

/// A frosted glass panel with soft refraction. Adapts contrast to
/// light/dark mode so it reads correctly on either backdrop.
///
/// By default the panel is plain translucency: a real `BackdropFilter` blur
/// on every card forces the GPU to re-blur that region every frame, which
/// makes scrolling lists visibly laggy on phones. Because the backdrop
/// behind panels is a static gradient, translucency looks nearly identical.
/// Set [frosted] only on surfaces that content actually scrolls underneath
/// (the floating tab bar), where one live blur is affordable.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 28,
    this.tint,
    this.tintAlpha,
    this.frosted = false,
  });

  final Widget? child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? tint;
  final double? tintAlpha;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkContext(context);

    if (isSolidStyle(context)) {
      // Solid palette: opaque cards, light borders, small shadows. Accent
      // tints (selected states, warnings) are blended into the card color
      // so they still read clearly.
      final cardColor = dark ? const Color(0xFF121826) : Colors.white;
      final color = tint == null
          ? cardColor
          : Color.alphaBlend(tint!.withValues(alpha: tintAlpha ?? 0.16), cardColor);

      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.25 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
    }

    final baseTint = tint ?? Colors.white;
    final alpha = tintAlpha ?? (dark ? 0.12 : 0.55);

    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseTint.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
            blurRadius: dark ? 28 : 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );

    if (!frosted) {
      return panel;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: panel,
      ),
    );
  }
}

/// A rounded, tinted icon badge used on announcement and event cards.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 46,
    this.iconSize = 19,
  });

  final FaIconData icon;
  final Color tint;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Center(
        child: FaIcon(icon, size: iconSize, color: tint),
      ),
    );
  }
}

class MiniStatChip extends StatelessWidget {
  const MiniStatChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 22,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final FaIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            IconBadge(icon: icon, tint: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class TabButton extends StatelessWidget {
  const TabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDot = false,
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Shows a small notification dot on the icon (e.g. unseen feed items).
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkContext(context);
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : (dark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.45));

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        // Selection is already shown by the pill background below; the
        // default tap ripple/highlight on top of it could linger and read
        // as a second "active" button, so it's turned off here.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? (dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.9))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FaIcon(icon, color: color, size: 20),
                  if (showDot)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: dark ? const Color(0xFF05070C) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The floating, semi-transparent bottom tab bar that hovers above the
/// screen edge rather than sitting flush against it.
class LiquidTabBar extends StatelessWidget {
  const LiquidTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.dotIndices = const {},
  });

  final List<({FaIconData icon, String label})> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Tab indices that should show a notification dot.
  final Set<int> dotIndices;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkContext(context);
    return GlassPanel(
      borderRadius: 30,
      tint: dark ? Colors.black : Colors.white,
      tintAlpha: dark ? 0.32 : 0.55,
      frosted: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: TabButton(
                icon: items[i].icon,
                label: items[i].label,
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
                showDot: dotIndices.contains(i),
              ),
            ),
        ],
      ),
    );
  }
}
