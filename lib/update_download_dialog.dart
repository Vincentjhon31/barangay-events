import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_service.dart';
import 'l10n/app_localizations.dart';

/// Downloads [update] inside the app with a progress bar, then opens the
/// system installer — no browser trip. If the download fails, the person can
/// try again or fall back to downloading in the browser.
Future<void> showUpdateDownloadDialog(
  BuildContext context,
  AppUpdateService service,
  AppUpdateInfo update,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDownloadDialog(service: service, update: update),
  );
}

class UpdateDownloadDialog extends StatefulWidget {
  const UpdateDownloadDialog({super.key, required this.service, required this.update});

  final AppUpdateService service;
  final AppUpdateInfo update;

  @override
  State<UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<UpdateDownloadDialog> {
  StreamSubscription<double?>? _download;
  double? _progress;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    // Closing the dialog mid-download stops it and removes the partial file.
    unawaited(_download?.cancel());
    super.dispose();
  }

  void _start() {
    setState(() {
      _failed = false;
      _progress = null;
    });
    _download = widget.service.downloadAndInstall(widget.update).listen(
      (progress) => setState(() => _progress = progress),
      onError: (Object error) {
        debugPrint('In-app update failed: $error');
        if (mounted) setState(() => _failed = true);
      },
      // The installer is open now (on Windows the app has already closed).
      onDone: () {
        if (mounted) Navigator.pop(context);
      },
      cancelOnError: true,
    );
  }

  Future<void> _openInBrowser() async {
    Navigator.pop(context);
    await launchUrl(Uri.parse(widget.update.downloadUrl), mode: LaunchMode.externalApplication);
  }

  String _megabytes(num bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final progress = _progress;
    final size = widget.update.size;
    final installing = progress == 1;

    final String status;
    if (installing) {
      status = l10n.updateOpeningInstaller;
    } else if (progress != null && size != null) {
      status = l10n.updateDownloadProgress(_megabytes(progress * size), _megabytes(size));
    } else {
      status = l10n.updateDownloadStarting;
    }

    return AlertDialog(
      title: Text(l10n.updateDownloadTitle(widget.update.latestVersion)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _failed
            ? [Text(l10n.updateDownloadFailed)]
            : [
                LinearProgressIndicator(
                  key: const Key('update-download-progress'),
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  semanticsLabel: status,
                  semanticsValue: progress == null ? null : '${(progress * 100).round()}%',
                ),
                const SizedBox(height: 12),
                Text(status, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  defaultTargetPlatform == TargetPlatform.windows
                      ? l10n.updateWindowsInstallHint
                      : l10n.updateAndroidInstallHint,
                  style: textTheme.bodySmall,
                ),
              ],
      ),
      actions: [
        if (_failed) TextButton(onPressed: () => unawaited(_openInBrowser()), child: Text(l10n.updateOpenDownloadPage)),
        if (!installing || _failed) TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        if (_failed) FilledButton(onPressed: _start, child: Text(l10n.updateRetryButton)),
      ],
    );
  }
}
