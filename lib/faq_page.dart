import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// A single FAQ entry, keyed to its own topic icon rather than a screenshot
/// (this is a coded app, not a design mock — the icon is the "visual").
typedef _FaqEntry = ({FaIconData icon, Color tint, String question, String answer});

/// Frequently Asked Questions — reached from the About page. Each entry is
/// its own collapsible accordion item so a long list of answers doesn't
/// have to be read top to bottom.
class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = <_FaqEntry>[
      (
        icon: FontAwesomeIcons.layerGroup,
        tint: const Color(0xFF2B7FFF),
        question: l10n.faqQ1,
        answer: l10n.faqA1,
      ),
      (
        icon: FontAwesomeIcons.doorOpen,
        tint: const Color(0xFF1F9D65),
        question: l10n.faqQ2,
        answer: l10n.faqA2,
      ),
      (
        icon: FontAwesomeIcons.peopleGroup,
        tint: const Color(0xFF1F9D65),
        question: l10n.faqQ3,
        answer: l10n.faqA3,
      ),
      (
        icon: FontAwesomeIcons.globe,
        tint: const Color(0xFF2B7FFF),
        question: l10n.faqQ4,
        answer: l10n.faqA4,
      ),
      (
        icon: FontAwesomeIcons.bell,
        tint: const Color(0xFFFFA726),
        question: l10n.faqQ5,
        answer: l10n.faqA5,
      ),
      (
        icon: FontAwesomeIcons.language,
        tint: const Color(0xFF7C4DFF),
        question: l10n.faqQ6,
        answer: l10n.faqA6,
      ),
      (
        icon: FontAwesomeIcons.tv,
        tint: const Color(0xFF7C4DFF),
        question: l10n.faqQ7,
        answer: l10n.faqA7,
      ),
      (
        icon: FontAwesomeIcons.idCard,
        tint: const Color(0xFF1F9D65),
        question: l10n.faqQ8,
        answer: l10n.faqA8,
      ),
      (
        icon: FontAwesomeIcons.shieldHalved,
        tint: const Color(0xFFE53935),
        question: l10n.faqQ9,
        answer: l10n.faqA9,
      ),
    ];

    return GlassSubPage(
      title: l10n.faqPageTitle,
      subtitle: l10n.faqPageSubtitle,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _FaqTile(entry: entries[i]),
          if (i != entries.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.entry});

  final _FaqEntry entry;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entry = widget.entry;

    return GlassPanel(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconBadge(icon: entry.icon, tint: entry.tint, size: 38, iconSize: 15),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.question,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _expanded ? 0.5 : 0,
                    child: FaIcon(
                      FontAwesomeIcons.chevronDown,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(width: 50),
                        Expanded(
                          child: Text(
                            entry.answer,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
