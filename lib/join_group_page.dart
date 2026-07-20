import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'event_store.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// Full page for joining a group by its 6-character code — pops with the
/// [GroupJoinResult], or null if the user backs out.
class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key, required this.eventRepository});

  final EventRepository eventRepository;

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final _codeController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterCodeError)),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      final result = await widget.eventRepository.requestOrJoinGroupByCode(code);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.joinGroupError)),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSubPage(
      title: l10n.joinWithCodeTitle,
      subtitle: l10n.joinWithCodeSubtitle,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: FontAwesomeIcons.circleInfo,
                    tint: colorScheme.primary,
                    size: 36,
                    iconSize: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.howJoiningWorksTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.howJoiningWorksBody,
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
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.groupCodeLabel,
                  hintText: l10n.groupCodeHint,
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.key, size: 14),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _joining ? null : () => unawaited(_join()),
                icon: const FaIcon(FontAwesomeIcons.userGroup, size: 14),
                label: Text(_joining ? l10n.joiningButton : l10n.joinGroupButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
