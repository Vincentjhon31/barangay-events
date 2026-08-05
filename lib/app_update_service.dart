// Platform-agnostic contract and data classes only.
//
// The GitHub-release implementation lives in app_update_service_io.dart
// because it needs dart:io (HttpClient, Platform), which has no web compile
// target. Keeping THIS file free of dart:io is what lets main.dart, about_page
// and profile_pages import it on every platform including web. Choose an
// implementation through app_update_service_factory.dart, which conditionally
// exports the io or web variant.
abstract class AppUpdateService {
  /// Null when the installed version is already current — used for the
  /// launch-time popup, which should stay silent unless there's actually
  /// something newer.
  Future<AppUpdateInfo?> checkForUpdate();

  /// Always returns the latest release's info (version, notes, whether it's
  /// newer than what's installed) regardless of update status — used by the
  /// About page's "What's New", which is useful whether you're current or not.
  Future<AppReleaseInfo> fetchLatestRelease();
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    required this.downloadUrl,
  });

  final String latestVersion;
  final String releaseUrl;
  final String downloadUrl;
}

/// Full info about the latest GitHub release, independent of whether it's
/// newer than what's installed — see [AppUpdateService.fetchLatestRelease].
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isNewerThanInstalled,
  });

  final String version;
  final String releaseUrl;
  final String downloadUrl;
  final String releaseNotes;
  final bool isNewerThanInstalled;
}
