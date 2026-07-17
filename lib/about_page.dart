import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_service.dart';
import 'liquid_glass_components.dart';

/// About page: installed version, a manual "check for updates" action, and
/// the latest release's notes ("What's New") — reached from Profile.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.updateService});

  /// Null when the host build has no update checking wired up (e.g. widget
  /// tests) — the page still shows static version info in that case.
  final AppUpdateService? updateService;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  // Permanent URL printed on the QR code below — always forwards to the
  // newest release's APK (see docs/index.html), so it never goes stale.
  static const String _downloadUrl = 'https://vincentjhon31.github.io/barangay-events/';

  String? _installedVersion;
  AppReleaseInfo? _latestRelease;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInstalledVersion());
    unawaited(_checkForUpdates());
  }

  Future<void> _loadInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _installedVersion = '${info.version} (${info.buildNumber})');
  }

  Future<void> _checkForUpdates() async {
    final updateService = widget.updateService;
    if (updateService == null) return;

    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final release = await updateService.fetchLatestRelease();
      if (!mounted) return;
      setState(() => _latestRelease = release);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not check for updates right now.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openDownload(String url) async {
    final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the update link.')),
      );
    }
  }

  Future<void> _shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Download eBongabong Calendar: $_downloadUrl',
        subject: 'eBongabong Calendar',
      ),
    );
  }

  Widget _sectionHeader(FaIconData icon, Color tint, String title) {
    return Row(
      children: [
        IconBadge(icon: icon, tint: tint, size: 40, iconSize: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildShareAppPanel() {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(FontAwesomeIcons.shareNodes, const Color(0xFF2B7FFF), 'Share app'),
          const SizedBox(height: 12),
          Text(
            'Scan the QR code or share the link so others can install eBongabong Calendar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'docs/download-qr.png',
                width: 180,
                height: 180,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => unawaited(_shareApp()),
            icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 14),
            label: const Text('Share download link'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final release = _latestRelease;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(FontAwesomeIcons.arrowsRotate, const Color(0xFF1F9D65), 'Updates'),
          const SizedBox(height: 12),
          if (widget.updateService == null)
            Text(
              "Update checking isn't available on this build.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
          else if (_checking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            if (_error != null)
              Text(_error!, style: TextStyle(color: colorScheme.error))
            else if (release != null && release.isNewerThanInstalled) ...[
              Text(
                'Version ${release.version} is available.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => unawaited(_openDownload(release.downloadUrl)),
                icon: const FaIcon(FontAwesomeIcons.download, size: 14),
                label: const Text('Update now'),
              ),
              const SizedBox(height: 12),
            ] else if (release != null) ...[
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.circleCheck, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text("You're up to date.", style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _checking ? null : () => unawaited(_checkForUpdates()),
              icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 13),
              label: const Text('Check for updates'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final release = _latestRelease;

    return GlassSubPage(
      title: 'About',
      subtitle: "Version info and what's new.",
      children: [
        GlassPanel(
          child: Row(
            children: [
              IconBadge(
                icon: FontAwesomeIcons.calendarDays,
                tint: colorScheme.primary,
                size: 52,
                iconSize: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'eBongabong Calendar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _installedVersion == null ? 'Loading version…' : 'Version $_installedVersion',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildShareAppPanel(),
        const SizedBox(height: 16),
        _buildUpdatesPanel(),
        if (release != null && release.releaseNotes.isNotEmpty) ...[
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeader(
                  FontAwesomeIcons.listCheck,
                  const Color(0xFF7C4DFF),
                  "What's new in ${release.version}",
                ),
                const SizedBox(height: 12),
                Text(
                  release.releaseNotes,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
