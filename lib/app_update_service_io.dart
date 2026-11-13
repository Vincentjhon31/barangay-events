import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app_update_service.dart';

/// Checks the app's download page on the LGU's own site
/// (https://calendar.bongabong.gov.ph/download/) for a newer version. The
/// release workflow keeps `latest.json` there up to date — see
/// scripts/publish_release.py and hostinger/public_html/api/releases.php.
/// (Before 1.18 the app asked GitHub, which stops answering once the code
/// repository is private.)
class DownloadPageUpdateService implements AppUpdateService {
  /// [downloadDirectory] and [install] are for tests; by default updates go
  /// to the app's cache and open in the system installer.
  DownloadPageUpdateService({
    Uri? latestUri,
    Directory? downloadDirectory,
    Future<void> Function(File file)? install,
  })  : latestUri = latestUri ?? defaultLatestUri,
        _downloadDirectory = downloadDirectory,
        _install = install ?? _openSystemInstaller;

  static final Uri defaultLatestUri = Uri.https('calendar.bongabong.gov.ph', '/download/latest.json');

  final Uri latestUri;
  final Directory? _downloadDirectory;
  final Future<void> Function(File file) _install;

  @override
  Future<AppUpdateInfo?> checkForUpdate() async {
    final release = await fetchLatestRelease();
    if (!release.isNewerThanInstalled) return null;

    return release.asUpdate;
  }

  @override
  Future<AppReleaseInfo> fetchLatestRelease() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final latest = await _fetchLatest();
    // Windows gets the installer; every other platform that checks (in
    // practice Android) gets the APK.
    final entry = latest[Platform.isWindows ? 'windows' : 'android'];
    if (entry is! Map<String, dynamic>) {
      throw HttpException('No download for this platform on the download page yet', uri: latestUri);
    }
    final pageUrl = latest['page'] as String? ?? latestUri.resolve('./').toString();
    final build = (entry['build'] as num?)?.toInt() ?? 0;
    final version = '${entry['version']}+$build';
    final whatsNew = (entry['whats_new'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();

    return AppReleaseInfo(
      version: version,
      releaseUrl: pageUrl,
      // Through the download counter when the page offers one.
      downloadUrl: entry['download'] as String? ?? entry['url'] as String? ?? pageUrl,
      releaseNotes: whatsNew.join('\n'),
      whatsNew: whatsNew,
      sha256: entry['sha256'] as String?,
      size: (entry['size'] as num?)?.toInt(),
      isNewerThanInstalled: _isNewerVersion(
        version,
        '${packageInfo.version}+${packageInfo.buildNumber}',
      ),
    );
  }

  @override
  Stream<double?> downloadAndInstall(AppUpdateInfo update) async* {
    final sep = Platform.pathSeparator;
    final dir = _downloadDirectory ?? Directory('${(await getTemporaryDirectory()).path}${sep}updates');
    final name = 'e-calendar-${update.latestVersion.replaceAll('+', '-')}${Platform.isWindows ? '-setup.exe' : '.apk'}';
    final file = File('${dir.path}$sep$name');

    // Already downloaded (e.g. the installer was closed without installing).
    if (!await _isIntact(file, update.sha256)) {
      await dir.create(recursive: true);
      // Earlier versions and broken downloads are no longer needed.
      await for (final old in dir.list()) {
        if (old.path != file.path) await old.delete(recursive: true);
      }
      yield* _download(Uri.parse(update.downloadUrl), file, update.size);
      if (!await _isIntact(file, update.sha256)) {
        await file.delete();
        throw const FileSystemException('The downloaded update is damaged');
      }
    }
    yield 1;
    await _install(file);
  }

  /// Saves [uri] to [target] through a `.part` file, so [target] only ever
  /// exists once the download finished.
  Stream<double?> _download(Uri uri, File target, int? expectedSize) async* {
    final part = File('${target.path}.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    var finished = false;
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'ebongabong-calendar-app');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed with status ${response.statusCode}', uri: uri);
      }
      final total = response.contentLength > 0 ? response.contentLength : expectedSize;
      sink = part.openWrite();
      var received = 0;
      var lastPercent = -1;
      // A stalled connection fails instead of freezing the progress bar.
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        if (total == null || total <= 0) continue;
        final percent = received * 100 ~/ total;
        if (percent != lastPercent) {
          lastPercent = percent;
          yield (received / total).clamp(0.0, 1.0);
        }
      }
      await sink.close();
      sink = null;
      await part.rename(target.path);
      finished = true;
    } finally {
      // Also runs when the user cancels: the file must be closed before it
      // can be deleted on Windows.
      try {
        await sink?.close();
      } catch (_) {}
      client.close(force: true);
      if (!finished && await part.exists()) await part.delete();
    }
  }

  static Future<bool> _isIntact(File file, String? expectedSha256) async {
    if (!await file.exists()) return false;
    if (expectedSha256 == null || expectedSha256.isEmpty) return true;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expectedSha256.toLowerCase();
  }

  static Future<void> _openSystemInstaller(File file) async {
    if (Platform.isAndroid) {
      // MainActivity.kt opens Android's own "Update this app?" screen.
      await const MethodChannel('ebongabong/app_update').invokeMethod<void>('installApk', {'path': file.path});
    } else if (Platform.isWindows) {
      // Per-user Inno Setup installer: /SILENT shows only its progress window
      // and reopens the app when done (see windows/installer/*.iss).
      await Process.start(file.path, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART'], mode: ProcessStartMode.detached);
      // The installer can't replace the files of an app that is still running.
      exit(0);
    } else {
      throw UnsupportedError('In-app updates work on Android and Windows only');
    }
  }

  Future<Map<String, dynamic>> _fetchLatest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(latestUri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache')
        ..set(HttpHeaders.userAgentHeader, 'ebongabong-calendar-app');

      final response = await request.close();
      final body = await utf8.decodeStream(response);

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Update check failed with status ${response.statusCode}',
          uri: latestUri,
        );
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}

String _normalizeVersion(String version) {
  return version.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
}

bool _isNewerVersion(String latestVersion, String currentVersion) {
  final latest = _Version.parse(latestVersion);
  final current = _Version.parse(currentVersion);
  return latest.compareTo(current) > 0;
}

class _Version implements Comparable<_Version> {
  const _Version(this.major, this.minor, this.patch, this.build);

  factory _Version.parse(String input) {
    final normalized = _normalizeVersion(input);
    final parts = normalized.split('+');
    final versionParts = parts.first.split('.');

    int valueAt(int index) {
      if (index >= versionParts.length) return 0;
      return int.tryParse(
              versionParts[index].replaceAll(RegExp(r'\D.*$'), '')) ??
          0;
    }

    return _Version(
      valueAt(0),
      valueAt(1),
      valueAt(2),
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int build;

  @override
  int compareTo(_Version other) {
    final comparisons = [
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
      build.compareTo(other.build),
    ];

    return comparisons.firstWhere((value) => value != 0, orElse: () => 0);
  }
}
