import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'event_store.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// Superadmin-only screen to manage the quick-pick venues offered in Add
/// Event's Location field (see EventRepository.listLguLocations). A thin
/// CRUD UI over the same lgu_locations table the LGU admin web portal's
/// own Locations section manages — either interface works; this one just
/// avoids having to leave the app.
class ManageLocationsPage extends StatefulWidget {
  const ManageLocationsPage({super.key, required this.eventRepository});

  final EventRepository eventRepository;

  @override
  State<ManageLocationsPage> createState() => _ManageLocationsPageState();
}

class _ManageLocationsPageState extends State<ManageLocationsPage> {
  final _nameController = TextEditingController();
  List<LguLocation> _locations = const [];
  bool _loading = true;
  bool _adding = false;
  final Set<String> _deletingIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final locations = await widget.eventRepository.listLguLocations();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    try {
      await widget.eventRepository.addLguLocation(name);
      _nameController.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _delete(LguLocation location) async {
    setState(() => _deletingIds.add(location.id));
    try {
      await widget.eventRepository.deleteLguLocation(location.id);
      if (!mounted) return;
      setState(() {
        _locations = _locations.where((l) => l.id != location.id).toList();
        _deletingIds.remove(location.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingIds.remove(location.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSubPage(
      title: l10n.manageLocationsTitle,
      subtitle: l10n.manageLocationsSubtitle,
      children: [
        GlassPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('manage-locations-name-field'),
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.locationNameLabel,
                    hintText: l10n.locationHint,
                    prefixIcon: glassFieldIcon(FontAwesomeIcons.locationDot, size: 14),
                    prefixIconConstraints: glassFieldIconConstraints,
                  ),
                  onSubmitted: (_) => unawaited(_add()),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                key: const Key('manage-locations-add-button'),
                onPressed: _adding ? null : () => unawaited(_add()),
                child: _adding
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.addButton),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_error != null)
          GlassPanel(child: Text(_error!, style: TextStyle(color: colorScheme.error)))
        else if (_locations.isEmpty)
          GlassPanel(
            child: Text(
              l10n.manageLocationsEmpty,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final location in _locations) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(location.name),
                        ),
                      ),
                      IconButton(
                        key: Key('delete-location-${location.id}'),
                        onPressed: _deletingIds.contains(location.id)
                            ? null
                            : () => unawaited(_delete(location)),
                        icon: _deletingIds.contains(location.id)
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : FaIcon(FontAwesomeIcons.trash, size: 15, color: colorScheme.error),
                      ),
                    ],
                  ),
                  if (location != _locations.last)
                    Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.08)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
