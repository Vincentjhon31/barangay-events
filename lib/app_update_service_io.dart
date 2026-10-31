import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_service.dart';

/// Checks the app's download page on the LGU's own site
/// (https://calendar.bongabong.gov.ph/download/) for a newer version. The
/// release workflow keeps `latest.json` there up to date — see
/// scripts/publish_release.py and hostinger/public_html/api/releases.php.
/// (Before 1.18 the app asked GitHub, which stops answering once the code
/// repository is private.)
class DownloadPageUpdateService implements AppUpdateService {
  DownloadPageUpdateService({Uri? latestUri}) : latestUri = latestUri ?? defaultLatestUri;

  static final Uri defaultLatestUri = Uri.https('calendar.bongabong.gov.ph', '/download/latest.json');

  final Uri latestUri;

  @override
  Future<AppUpdateInfo?> checkForUpdate() async {
    final release = await fetchLatestRelease();
    if (!release.isNewerThanInstalled) return null;

    return AppUpdateInfo(
      latestVersion: release.version,
      releaseUrl: release.releaseUrl,
      downloadUrl: release.downloadUrl,
      whatsNew: release.whatsNew,
    );
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
      isNewerThanInstalled: _isNewerVersion(
        version,
        '${packageInfo.version}+${packageInfo.buildNumber}',
      ),
    );
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
