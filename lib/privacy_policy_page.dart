import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// Privacy Policy — reached from Settings. Static content; nothing here
/// reads or writes any user data.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = <({FaIconData icon, Color tint, String heading, String body})>[
      (
        icon: FontAwesomeIcons.database,
        tint: const Color(0xFF2B7FFF),
        heading: l10n.privacyCollectHeading,
        body: l10n.privacyCollectBody,
      ),
      (
        icon: FontAwesomeIcons.gears,
        tint: const Color(0xFF1F9D65),
        heading: l10n.privacyUseHeading,
        body: l10n.privacyUseBody,
      ),
      (
        icon: FontAwesomeIcons.eye,
        tint: const Color(0xFFFFA726),
        heading: l10n.privacyVisibilityHeading,
        body: l10n.privacyVisibilityBody,
      ),
      (
        icon: FontAwesomeIcons.cloud,
        tint: const Color(0xFF7C4DFF),
        heading: l10n.privacyThirdPartyHeading,
        body: l10n.privacyThirdPartyBody,
      ),
      (
        icon: FontAwesomeIcons.userCheck,
        tint: const Color(0xFF1F9D65),
        heading: l10n.privacyRetentionHeading,
        body: l10n.privacyRetentionBody,
      ),
      (
        icon: FontAwesomeIcons.childReaching,
        tint: const Color(0xFF2B7FFF),
        heading: l10n.privacyChildrenHeading,
        body: l10n.privacyChildrenBody,
      ),
      (
        icon: FontAwesomeIcons.clockRotateLeft,
        tint: const Color(0xFFFFA726),
        heading: l10n.privacyChangesHeading,
        body: l10n.privacyChangesBody,
      ),
      (
        icon: FontAwesomeIcons.landmark,
        tint: const Color(0xFFE53935),
        heading: l10n.privacyLegalHeading,
        body: l10n.privacyLegalBody,
      ),
    ];

    return GlassSubPage(
      title: l10n.privacyPolicyTitle,
      subtitle: l10n.privacyPolicySubtitle,
      children: [
        GlassPanel(
          child: Text(
            l10n.privacyIntro,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
        for (final section in sections) ...[
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconBadge(icon: section.icon, tint: section.tint, size: 38, iconSize: 15),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        section.heading,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  section.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
