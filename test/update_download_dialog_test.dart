import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eCalendar/app_update_service.dart';
import 'package:eCalendar/l10n/app_localizations.dart';
import 'package:eCalendar/update_download_dialog.dart';

class _ControlledUpdateService implements AppUpdateService {
  final downloads = <StreamController<double?>>[];

  @override
  Stream<double?> downloadAndInstall(AppUpdateInfo update) {
    final controller = StreamController<double?>();
    downloads.add(controller);
    return controller.stream;
  }

  @override
  Future<AppUpdateInfo?> checkForUpdate() => throw UnimplementedError();

  @override
  Future<AppReleaseInfo> fetchLatestRelease() => throw UnimplementedError();
}

void main() {
  testWidgets('shows download progress, offers a retry when it fails, and closes once the installer opens',
      (tester) async {
    final service = _ControlledUpdateService();
    const update = AppUpdateInfo(
      latestVersion: '1.19.0+31',
      releaseUrl: 'https://calendar.bongabong.gov.ph/download/',
      downloadUrl: 'https://calendar.bongabong.gov.ph/api/download.php?file=e-calendar-1.19.0.apk',
      size: 10 * 1024 * 1024,
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showUpdateDownloadDialog(context, service, update),
          child: const Text('Update'),
        ),
      ),
    ));
    await tester.tap(find.text('Update'));
    await tester.pump();

    service.downloads.single.add(0.5);
    await tester.pump();
    expect(find.text('Downloading… 5.0 of 10.0 MB'), findsOneWidget);

    service.downloads.single.addError(Exception('offline'));
    await tester.pump();
    expect(find.textContaining('could not be downloaded'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(service.downloads, hasLength(2));

    service.downloads.last.add(1);
    await tester.pump();
    expect(find.text('Opening the installer…'), findsOneWidget);
    await service.downloads.last.close();
    await tester.pumpAndSettle();
    expect(find.byType(UpdateDownloadDialog), findsNothing);
  });
}
