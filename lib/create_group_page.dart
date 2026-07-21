import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'event_store.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// Full page for creating a group — pops with the created [BarangayGroup],
/// or null if the user backs out.
class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key, required this.eventRepository});

  final EventRepository eventRepository;

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameController = TextEditingController();
  bool _isPrivate = false;
  bool _requiresApproval = false;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterGroupNameError)),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final group = await widget.eventRepository.createGroup(
        name,
        isPrivate: _isPrivate,
        requiresApproval: _requiresApproval,
      );
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createGroupError)),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSubPage(
      title: l10n.createGroupTitle,
      subtitle: l10n.createGroupSubtitle,
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
                      l10n.howGroupsWorkTitle,
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
                l10n.howGroupsWorkBody,
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
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.groupNameLabel,
                  hintText: l10n.groupNameHint,
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.penToSquare, size: 14),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.privateGroupLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          l10n.privateGroupHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPrivate,
                    onChanged: (value) => setState(() {
                      _isPrivate = value;
                      // Nudge toward the old default (private == needs
                      // approval) without forcing it — still independently
                      // toggleable right below.
                      if (value) _requiresApproval = true;
                    }),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.requiresApprovalLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          l10n.requiresApprovalHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _requiresApproval,
                    onChanged: (value) => setState(() => _requiresApproval = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _creating ? null : () => unawaited(_create()),
                icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                label: Text(_creating ? l10n.creatingButton : l10n.createGroupButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
