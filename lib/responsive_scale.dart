import 'package:flutter/material.dart';

/// User-facing override for [ResponsiveScaler]'s scaling — set from the
/// Settings page. [auto] (the default) computes the scale from the actual
/// window size, same as if this didn't exist; the others lock to a fixed
/// zoom level regardless of the real screen size, for cases where auto
/// detection guesses wrong on specific hardware (e.g. an unusual kiosk
/// panel) or someone just wants a fixed size on purpose.
enum DisplayMode {
  auto,
  mobile,
  tablet,
  windows;

  /// Null for [auto] (falls back to the computed scale); a fixed multiplier
  /// otherwise.
  double? get fixedScale => switch (this) {
        DisplayMode.auto => null,
        DisplayMode.mobile => 1.0,
        DisplayMode.tablet => 1.5,
        DisplayMode.windows => 2.0,
      };

  String get label => switch (this) {
        DisplayMode.auto => 'Auto',
        DisplayMode.mobile => 'Mobile',
        DisplayMode.tablet => 'Tablet',
        DisplayMode.windows => 'Windows / Kiosk',
      };
}

/// Wraps the whole app (via MaterialApp.builder) so it renders sensibly on
/// screens far bigger than a phone — Android tablets, Windows desktop
/// windows, and kiosk panels up to ~55" — without touching any existing
/// page's layout code. Keeps rendering the exact same phone-tuned canvas,
/// just uniformly bigger the more room there is, rather than reflowing into
/// a different desktop layout.
class ResponsiveScaler extends StatelessWidget {
  const ResponsiveScaler({
    super.key,
    required this.child,
    this.displayMode = DisplayMode.auto,
  });

  final Widget child;

  /// Manual override from Settings — see [DisplayMode].
  final DisplayMode displayMode;

  /// Reference width the whole design was tuned against — matches typical
  /// phone widths, so real phones get scale 1.0 (no change at all).
  static const double _designWidth = 430;

  /// The effective canvas width never exceeds this, even on a wide
  /// landscape screen — otherwise a Windows window or widescreen kiosk
  /// panel would stretch the single-column phone layout into an oddly
  /// wide, thin page instead of "the same design, bigger." Roomier than a
  /// phone (bigger touch targets, more breathing room) without losing the
  /// phone-shaped proportions the design was built around.
  static const double _maxContentWidth = 640;

  /// Caps the magnification itself, so a huge kiosk panel doesn't blow
  /// spacing/icons up into caricature.
  static const double _maxScale = 2.2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return child;
        }

        final shortestSide = width < height ? width : height;
        final scale = displayMode.fixedScale ??
            (shortestSide / _designWidth).clamp(1.0, _maxScale);
        if (scale == 1.0) return child; // real phones: no-op, unchanged today

        final innerWidth = (width / scale).clamp(0.0, _maxContentWidth);
        final innerHeight = height / scale; // uncapped — scrollables just show more
        final mediaQuery = MediaQuery.of(context);

        final scaledChild = MediaQuery(
          data: mediaQuery.copyWith(
            size: Size(innerWidth, innerHeight),
            // These are still expressed in outer (full-scale) pixels —
            // rescale them too, or SafeArea/keyboard insets eat proportionally
            // too much of the shrunk canvas.
            padding: mediaQuery.padding / scale,
            viewInsets: mediaQuery.viewInsets / scale,
            viewPadding: mediaQuery.viewPadding / scale,
            systemGestureInsets: mediaQuery.systemGestureInsets / scale,
          ),
          child: child,
        );

        return ColoredBox(
          // Fills any pillarboxed margin (wide landscape screens) with the
          // app's own background instead of a blank/black gap.
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: scale * innerWidth,
              height: scale * innerHeight,
              child: OverflowBox(
                minWidth: innerWidth,
                maxWidth: innerWidth,
                minHeight: innerHeight,
                maxHeight: innerHeight,
                alignment: Alignment.topLeft,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: innerWidth,
                    height: innerHeight,
                    child: scaledChild,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
