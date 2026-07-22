import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_service.dart';
import 'faq_page.dart';
import 'l10n/app_localizations.dart';
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
      setState(() => _error = AppLocalizations.of(context)!.checkUpdateError);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openDownload(String url) async {
    final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.openUpdateLinkError)),
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

  void _openFaq() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FaqPage()),
    );
  }

  Widget _buildFeatureLine(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: FaIcon(FontAwesomeIcons.circleCheck, size: 12, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutThisAppPanel() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(FontAwesomeIcons.landmark, const Color(0xFF1F9D65), l10n.aboutThisAppSection),
          const SizedBox(height: 12),
          Text(
            l10n.aboutThisAppBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.aboutThisAppFeaturesIntro,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          _buildFeatureLine(l10n.aboutFeaturePublicEvents),
          _buildFeatureLine(l10n.aboutFeatureGroups),
          _buildFeatureLine(l10n.aboutFeaturePersonal),
          _buildFeatureLine(l10n.aboutFeatureNotifications),
          _buildFeatureLine(l10n.aboutFeatureLanguage),
          _buildFeatureLine(l10n.aboutFeatureDisplay),
          const SizedBox(height: 16),
          GlassPanel(
            tint: colorScheme.primary,
            tintAlpha: 0.08,
            padding: const EdgeInsets.all(4),
            child: QuickActionTile(
              key: const Key('about-faq-tile'),
              icon: FontAwesomeIcons.circleQuestion,
              title: l10n.faqTile,
              subtitle: l10n.faqTileCaption,
              onTap: _openFaq,
            ),
          ),
        ],
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
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(FontAwesomeIcons.shareNodes, const Color(0xFF2B7FFF), l10n.shareAppSection),
          const SizedBox(height: 12),
          Text(
            l10n.shareAppHint,
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
            label: Text(l10n.shareDownloadLinkButton),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesPanel() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final release = _latestRelease;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(FontAwesomeIcons.arrowsRotate, const Color(0xFF1F9D65), l10n.updatesSection),
          const SizedBox(height: 12),
          if (widget.updateService == null)
            Text(
              l10n.updateCheckingUnavailable,
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
                l10n.versionAvailable(release.version),
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
                label: Text(l10n.updateNowButton),
              ),
              const SizedBox(height: 12),
            ] else if (release != null) ...[
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.circleCheck, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(l10n.upToDateMessage, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _checking ? null : () => unawaited(_checkForUpdates()),
              icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 13),
              label: Text(l10n.checkForUpdatesButton),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final release = _latestRelease;

    return GlassSubPage(
      title: l10n.aboutTile,
      subtitle: l10n.aboutSubtitle,
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
                      _installedVersion == null ? l10n.loadingVersion : l10n.versionLabel(_installedVersion!),
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
        _buildAboutThisAppPanel(),
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
                  l10n.whatsNewInVersion(release.version),
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
