import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const List<_AnnouncementNotice> announcementCards = [
  _AnnouncementNotice(
    icon: FontAwesomeIcons.syringe,
    tint: Color(0xFF2B7FFF),
    title: 'Vaccination Drive',
    body: 'Free immunization and health screening at the barangay health center.',
    meta: 'Friday • 8:00 AM - 2:00 PM',
  ),
  _AnnouncementNotice(
    icon: FontAwesomeIcons.truckFast,
    tint: Color(0xFF1F9D65),
    title: 'Garbage Collection Schedule',
    body: 'Remember to place segregated waste outside before the collection window.',
    meta: 'Monday, Wednesday, Friday',
  ),
  _AnnouncementNotice(
    icon: FontAwesomeIcons.fireFlameCurved,
    tint: Color(0xFFFFA726),
    title: 'Fiesta Announcement',
    body: 'Save the date for the barangay fiesta parade and evening program.',
    meta: 'Next week • Parade starts at 4:00 PM',
  ),
  _AnnouncementNotice(
    icon: FontAwesomeIcons.peopleGroup,
    tint: Color(0xFF7C4DFF),
    title: 'Barangay Assembly',
    body: 'Residents are invited to discuss schedules, safety, and community updates.',
    meta: 'This Saturday • 5:00 PM',
  ),
];

class _AnnouncementNotice {
  const _AnnouncementNotice({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    required this.meta,
  });

  final FaIconData icon;
  final Color tint;
  final String title;
  final String body;
  final String meta;
}

class LiquidGlassBackdrop extends StatelessWidget {
  const LiquidGlassBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF8FCFF),
                Color(0xFFF0F6FB),
                Color(0xFFF7FBF6),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -20,
          child: BlurOrb(color: const Color(0xFF6EA8FF).withValues(alpha: 0.24), size: 180),
        ),
        Positioned(
          top: 180,
          left: -35,
          child: BlurOrb(color: const Color(0xFF7BE0B2).withValues(alpha: 0.22), size: 160),
        ),
        Positioned(
          bottom: 120,
          right: 10,
          child: BlurOrb(color: const Color(0xFFF7C873).withValues(alpha: 0.18), size: 140),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: const SizedBox.expand(),
        ),
      ],
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
            blurRadius: 50,
            spreadRadius: 18,
          ),
        ],
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 30,
    this.tint,
  });

  final Widget? child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? Colors.white).withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
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
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: FaIcon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
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
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.55) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
