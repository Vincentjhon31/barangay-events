import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'event_store.dart';
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
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group code first.')),
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
        const SnackBar(content: Text('Could not join. Check the code and try again.')),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSubPage(
      title: 'Join with a code',
      subtitle: 'Have an invite code? Use it to join that group.',
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
                      'How joining works',
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
                'Ask whoever created the group for their 6-character code — it\'s '
                'shown right on the group\'s member page. Entering it here works for '
                'private groups too: instead of joining instantly, it sends a request '
                'the group\'s admin approves.',
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
                  labelText: 'Group code',
                  hintText: 'e.g. QXK2P9',
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
                label: Text(_joining ? 'Joining...' : 'Join group'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
