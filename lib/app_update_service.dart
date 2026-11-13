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

  /// Downloads [update] inside the app and hands it to the system installer.
  /// Emits download progress from 0 to 1 (null while the size is unknown) and
  /// completes once the installer has opened. On Windows the app then closes so
  /// the installer can replace it. Cancelling the subscription stops the
  /// download and removes the partial file.
  Stream<double?> downloadAndInstall(AppUpdateInfo update);
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    required this.downloadUrl,
    this.whatsNew = const [],
    this.sha256,
    this.size,
  });

  final String latestVersion;
  final String releaseUrl;
  final String downloadUrl;

  /// The file's checksum and byte size from the download page, used to check
  /// an in-app download before installing it.
  final String? sha256;
  final int? size;

  /// The user-facing "What's new" bullets for [latestVersion] — see
  /// AppReleaseInfo.whatsNew.
  final List<String> whatsNew;
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
    this.whatsNew = const [],
    this.sha256,
    this.size,
  });

  final String version;
  final String releaseUrl;
  final String downloadUrl;
  final String? sha256;
  final int? size;

  /// The release's full body as GitHub has it. Generated from commit titles,
  /// so it can mention internal details — NEVER show it to users; show
  /// [whatsNew] instead.
  final String releaseNotes;
  final bool isNewerThanInstalled;

  /// Only the hand-written, user-facing bullets from the release (the
  /// what's-new section the release workflow copies from
  /// assets/whats_new.md — see lib/whats_new.dart). Empty for releases made
  /// before this existed.
  final List<String> whatsNew;

  AppUpdateInfo get asUpdate => AppUpdateInfo(
        latestVersion: version,
        releaseUrl: releaseUrl,
        downloadUrl: downloadUrl,
        whatsNew: whatsNew,
        sha256: sha256,
        size: size,
      );
}
