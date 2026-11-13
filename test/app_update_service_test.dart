import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:eCalendar/app_update_service.dart';
import 'package:eCalendar/app_update_service_io.dart';

/// Serves [body] as the download page's latest.json on a local port.
Future<HttpServer> serveLatest(Object body, {int status = 200}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    unawaited(request.response.close());
  });
  return server;
}

Map<String, Object?> entry(String version, int build, String file) => {
      'version': version,
      'build': build,
      'date': '2026-11-05',
      'whats_new': ['Chat history', 'Fewer double notifications'],
      'name': file,
      'size': 123,
      'sha256': 'a' * 64,
      'url': 'https://calendar.bongabong.gov.ph/download/files/$file',
      'download': 'https://calendar.bongabong.gov.ph/api/download.php?file=$file',
    };

void main() {
  late HttpServer server;
  // The device's own platform decides which entry the app reads.
  final platformFile = Platform.isWindows ? 'e-calendar-1.18.0-setup.exe' : 'e-calendar-1.18.0.apk';

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'eBongabong Calendar',
      packageName: 'com.zynt31.barangay_events',
      version: '1.17.0',
      buildNumber: '29',
      buildSignature: '',
    );
  });

  tearDown(() => server.close(force: true));

  DownloadPageUpdateService service() =>
      DownloadPageUpdateService(latestUri: Uri.parse('http://127.0.0.1:${server.port}/download/latest.json'));

  test('offers a newer version from the download page, with its notes and counted link', () async {
    server = await serveLatest({
      'page': 'https://calendar.bongabong.gov.ph/download/',
      'android': entry('1.18.0', 30, 'e-calendar-1.18.0.apk'),
      'windows': entry('1.18.0', 30, 'e-calendar-1.18.0-setup.exe'),
    });

    final update = await service().checkForUpdate();

    expect(update, isNotNull);
    expect(update!.latestVersion, '1.18.0+30');
    expect(update.downloadUrl, 'https://calendar.bongabong.gov.ph/api/download.php?file=$platformFile');
    expect(update.releaseUrl, 'https://calendar.bongabong.gov.ph/download/');
    expect(update.whatsNew, ['Chat history', 'Fewer double notifications']);
  });

  test('stays quiet when the installed version is the newest', () async {
    server = await serveLatest({
      'page': 'https://calendar.bongabong.gov.ph/download/',
      'android': entry('1.17.0', 29, 'e-calendar-1.17.0.apk'),
      'windows': entry('1.17.0', 29, 'e-calendar-1.17.0-setup.exe'),
    });

    expect(await service().checkForUpdate(), isNull);
    final release = await service().fetchLatestRelease();
    expect(release.isNewerThanInstalled, isFalse);
    expect(release.whatsNew, isNotEmpty);
  });

  test('a newer build of the same version counts as an update', () async {
    server = await serveLatest({
      'android': entry('1.17.0', 30, 'e-calendar-1.17.0.apk'),
      'windows': entry('1.17.0', 30, 'e-calendar-1.17.0-setup.exe'),
    });

    expect((await service().checkForUpdate())?.latestVersion, '1.17.0+30');
  });

  test('no file for this platform yet, or a server error, fails the check', () async {
    server = await serveLatest({'android': null, 'windows': null});
    await expectLater(service().checkForUpdate(), throwsA(isA<HttpException>()));
    await server.close(force: true);

    server = await serveLatest({'error': 'down'}, status: 503);
    await expectLater(service().checkForUpdate(), throwsA(isA<HttpException>()));
  });

  group('in-app download', () {
    late Directory dir;
    late List<int> apk;
    late int requests;
    late List<File> installed;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('update_test');
      apk = List.generate(300 * 1024, (i) => i % 251);
      requests = 0;
      installed = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        requests++;
        request.response
          ..contentLength = apk.length
          ..add(apk);
        unawaited(request.response.close());
      });
    });

    tearDown(() => dir.delete(recursive: true));

    DownloadPageUpdateService downloader() => DownloadPageUpdateService(
          downloadDirectory: dir,
          install: (file) async => installed.add(file),
        );

    AppUpdateInfo update(String sha) => AppUpdateInfo(
          latestVersion: '1.19.0+31',
          releaseUrl: 'https://calendar.bongabong.gov.ph/download/',
          downloadUrl: 'http://127.0.0.1:${server.port}/e-calendar.bin',
          sha256: sha,
          size: apk.length,
        );

    test('shows progress, checks the file, opens the installer, and reuses a finished download', () async {
      final good = update(sha256.convert(apk).toString());

      final progress = await downloader().downloadAndInstall(good).toList();

      expect(progress, isNotEmpty);
      expect(progress.last, 1);
      expect(progress.whereType<double>(), orderedEquals([...progress.whereType<double>()]..sort()));
      expect(installed, hasLength(1));
      expect(await installed.single.readAsBytes(), apk);
      expect(dir.listSync().map((f) => f.path).where((p) => p.endsWith('.part')), isEmpty);

      // Closing the installer and tapping Update again doesn't download twice.
      await downloader().downloadAndInstall(good).toList();
      expect(requests, 1);
      expect(installed, hasLength(2));
    });

    test('a damaged download is deleted and never installed', () async {
      await expectLater(
        downloader().downloadAndInstall(update('0' * 64)).toList(),
        throwsA(isA<FileSystemException>()),
      );
      expect(installed, isEmpty);
      expect(dir.listSync(), isEmpty);
    });
  });
}
