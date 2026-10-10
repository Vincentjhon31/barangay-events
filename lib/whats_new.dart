import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// "What's new" for users: a short, hand-written list per version, kept in
/// `assets/whats_new.md`. It's the ONLY release text the app shows —
/// GitHub's own release notes are generated from commit titles and can
/// mention internal details (server functions, database rules, hosting),
/// so the app never displays them. The release workflow copies the
/// matching version's section into the GitHub release between
/// [whatsNewStartMarker] and [whatsNewEndMarker], which is how the update
/// prompt can show what's in a version before it's installed.

const String whatsNewAsset = 'assets/whats_new.md';
const String whatsNewStartMarker = '<!-- whats-new -->';
const String whatsNewEndMarker = '<!-- /whats-new -->';

class WhatsNewEntry {
  const WhatsNewEntry({required this.version, required this.items});

  /// e.g. "1.17.0" (no build number).
  final String version;
  final List<String> items;
}

/// Parses `assets/whats_new.md`: a `## <version>` heading per version, then
/// `- ` bullet lines. Everything else (title, comments, blank lines) is
/// ignored.
List<WhatsNewEntry> parseWhatsNew(String markdown) {
  final withoutComments = markdown.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  final entries = <WhatsNewEntry>[];
  String? version;
  var items = <String>[];
  void flush() {
    if (version != null && items.isNotEmpty) {
      entries.add(WhatsNewEntry(version: version, items: items));
    }
  }

  for (final rawLine in withoutComments.split('\n')) {
    final line = rawLine.trim();
    final heading = RegExp(r'^##\s+v?(\d+\.\d+\.\d+)').firstMatch(line);
    if (heading != null) {
      flush();
      version = heading.group(1);
      items = <String>[];
    } else if (version != null && line.startsWith('- ')) {
      final item = plainText(line.substring(2));
      if (item.isNotEmpty) items.add(item);
    }
  }
  flush();
  return entries;
}

/// The user-facing bullets from a GitHub release body: only the lines
/// between the what's-new markers. A release without the markers (older
/// releases) gives an empty list — never the rest of the body.
List<String> publicNotesFromReleaseBody(String body) {
  final start = body.indexOf(whatsNewStartMarker);
  if (start < 0) return const [];
  final end = body.indexOf(whatsNewEndMarker, start);
  if (end < 0) return const [];
  return body
      .substring(start + whatsNewStartMarker.length, end)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('- '))
      .map((line) => plainText(line.substring(2)))
      .where((line) => line.isNotEmpty)
      .toList();
}

/// Markdown/HTML reduced to plain text — the notes are shown as plain
/// text, and links or markup in them are never rendered or followed.
String plainText(String text) {
  return text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '')
      .replaceAll(RegExp(r'[*_`]'), '')
      .trim();
}

/// Reads the bundled notes file. Replaceable in widget tests, whose fake
/// clock never finishes a real asset read.
@visibleForTesting
Future<String> Function() loadWhatsNewMarkdown = () => rootBundle.loadString(whatsNewAsset);

/// The bundled notes for [version] (build number ignored), or null.
Future<WhatsNewEntry?> bundledWhatsNewFor(String version) async {
  final wanted = version.split('+').first;
  try {
    final entries = parseWhatsNew(await loadWhatsNewMarkdown());
    for (final entry in entries) {
      if (entry.version == wanted) return entry;
    }
  } catch (_) {
    // No notes bundled — nothing to show.
  }
  return null;
}

const String _seenVersionKey = 'whats_new_seen_version';

/// Shows "What's new in version X" once, the first time the app opens after
/// an update — not on a fresh install (there's nothing "new" to someone who
/// just installed it), and not again after it's been seen.
///
/// Versions before this feature never saved a seen version, so with none
/// saved, [updatedSinceInstall] (the system's install vs. last-update time)
/// tells someone who updated from one of those apart from a fresh install.
Future<void> showWhatsNewAfterUpdateIfNeeded(
  BuildContext context,
  String installedVersion, {
  bool updatedSinceInstall = false,
}) async {
  final version = installedVersion.split('+').first;
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getString(_seenVersionKey);
  await prefs.setString(_seenVersionKey, version);
  if (seen == version || (seen == null && !updatedSinceInstall)) return;
  final entry = await bundledWhatsNewFor(version);
  if (entry == null || !context.mounted) return;
  await showWhatsNewSheet(context, entry.version, entry.items);
}

/// A bottom sheet listing what's new in [version].
Future<void> showWhatsNewSheet(BuildContext context, String version, List<String> items) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
          child: SingleChildScrollView(
            key: const Key('whats-new-sheet'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const IconBadge(icon: FontAwesomeIcons.wandMagicSparkles, tint: Color(0xFF7C4DFF), size: 44, iconSize: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.whatsNewInVersion(version),
                        style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                WhatsNewList(items: items),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(l10n.whatsNewGotIt),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The notes as a bulleted list.
class WhatsNewList extends StatelessWidget {
  const WhatsNewList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FaIcon(FontAwesomeIcons.solidCircleCheck, size: 13, color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
