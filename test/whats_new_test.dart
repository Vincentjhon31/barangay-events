import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eCalendar/about_page.dart';
import 'package:eCalendar/app_update_service.dart';
import 'package:eCalendar/auth_service.dart';
import 'package:eCalendar/event_store.dart';
import 'package:eCalendar/l10n/app_localizations.dart';
import 'package:eCalendar/main.dart';
import 'package:eCalendar/whats_new.dart';

/// A newer release whose GitHub body has user-facing notes between the
/// markers AND a developer changelog that must never reach the app.
const String _releaseBody = '''
## What's new
<!-- whats-new -->
- Chat with others on any event.
- Notifications now play the app's own sound.
<!-- /whats-new -->

## Features
- feat: attachments stored on internal-host via files API (#12)
- fix(rls): tighten policy on event_comments
''';

class _FakeUpdateService implements AppUpdateService {
  @override
  Future<AppUpdateInfo?> checkForUpdate() async => AppUpdateInfo(
        latestVersion: '9.9.0',
        releaseUrl: 'https://example.com/release',
        downloadUrl: 'https://example.com/app.apk',
        whatsNew: publicNotesFromReleaseBody(_releaseBody),
      );

  @override
  Future<AppReleaseInfo> fetchLatestRelease() async => AppReleaseInfo(
        version: '9.9.0',
        releaseUrl: 'https://example.com/release',
        downloadUrl: 'https://example.com/app.apk',
        releaseNotes: _releaseBody,
        isNewerThanInstalled: true,
        whatsNew: publicNotesFromReleaseBody(_releaseBody),
      );
}

/// Asset reads are real I/O, which never finishes inside a widget test's
/// fake clock — read the real notes once outside it, then serve that text.
Future<void> _cacheBundledNotes(WidgetTester tester) async {
  final markdown = await tester.runAsync(() => rootBundle.loadString(whatsNewAsset));
  final original = loadWhatsNewMarkdown;
  loadWhatsNewMarkdown = () async => markdown!;
  addTearDown(() => loadWhatsNewMarkdown = original);
}

Widget _localizedApp(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2340);
    view.devicePixelRatio = 3.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  group('parsing', () {
    test('parseWhatsNew reads versions and bullets, skipping comments', () {
      final entries = parseWhatsNew('''
# What's new
<!--
## 0.0.1
- hidden in a comment
-->
## 1.2.0
- First **thing**.
- See [the guide](https://example.com).

Some stray paragraph.
## v1.1.0
- Older thing.
## 1.0.0
''');
      expect(entries.map((e) => e.version), ['1.2.0', '1.1.0']);
      expect(entries.first.items, ['First thing.', 'See the guide.']);
      expect(entries[1].items, ['Older thing.']);
    });

    test('release body: only the bullets between the markers, never the rest', () {
      expect(publicNotesFromReleaseBody(_releaseBody), [
        'Chat with others on any event.',
        "Notifications now play the app's own sound.",
      ]);
    });

    test('release body without markers (older releases) gives nothing', () {
      expect(publicNotesFromReleaseBody('## Features\n- feat: something internal'), isEmpty);
      expect(publicNotesFromReleaseBody('<!-- whats-new -->\n- unterminated'), isEmpty);
    });

    test('plainText strips markup and links', () {
      expect(plainText('<b>Bold</b> `code` _it_ [link](http://x) ![img](y.png)'), 'Bold code it link img');
    });

    test('the bundled notes parse and cover the current version', () async {
      final entry = await bundledWhatsNewFor('1.17.0+29');
      expect(entry, isNotNull);
      expect(entry!.items, isNotEmpty);
      expect(await bundledWhatsNewFor('0.0.1'), isNull);
    });
  });

  group('after an update', () {
    Future<void> pumpHost(WidgetTester tester, String version, {bool updatedSinceInstall = false}) async {
      await _cacheBundledNotes(tester);
      await tester.pumpWidget(_localizedApp(Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () =>
                showWhatsNewAfterUpdateIfNeeded(context, version, updatedSinceInstall: updatedSinceInstall),
            child: const Text('go'),
          ),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('a fresh install shows nothing', (tester) async {
      await pumpHost(tester, '1.17.0+29');
      expect(find.byKey(const Key('whats-new-sheet')), findsNothing);
    });

    testWidgets('updating from a version that never saved one still shows the notes', (tester) async {
      await pumpHost(tester, '1.17.0+29', updatedSinceInstall: true);
      expect(find.byKey(const Key('whats-new-sheet')), findsOneWidget);
    });

    testWidgets('the first open after updating shows the notes once', (tester) async {
      SharedPreferences.setMockInitialValues({'whats_new_seen_version': '1.16.1'});
      await pumpHost(tester, '1.17.0+29');
      expect(find.byKey(const Key('whats-new-sheet')), findsOneWidget);
      expect(find.text("What's new in 1.17.0"), findsOneWidget);

      await tester.ensureVisible(find.text('Got it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whats-new-sheet')), findsNothing);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whats-new-sheet')), findsNothing);
    });
  });

  testWidgets('update prompt and banner show only the user-facing notes', (tester) async {
    await tester.pumpWidget(BarangayCalendarApp(
      authServiceFactory: () async => MemoryAuthService.signedIn(),
      eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      updateService: _FakeUpdateService(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.byKey(const Key('update-dialog-whats-new')), findsOneWidget);
    expect(find.text('Chat with others on any event.'), findsOneWidget);
    expect(find.textContaining('internal-host'), findsNothing);
    expect(find.textContaining('policy'), findsNothing);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('update-banner-whats-new')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('whats-new-sheet')), findsOneWidget);
    expect(find.text('Chat with others on any event.'), findsOneWidget);
    expect(find.textContaining('internal-host'), findsNothing);
  });

  testWidgets('About page shows the curated notes, never the raw release body', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'eCalendar',
      packageName: 'ph.gov.bongabong.ecalendar',
      version: '1.17.0',
      buildNumber: '29',
      buildSignature: '',
    );
    await _cacheBundledNotes(tester);
    await tester.pumpWidget(_localizedApp(AboutPage(updateService: _FakeUpdateService())));
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text("What's new in 9.9.0"), 300, scrollable: list);
    expect(find.text('Chat with others on any event.'), findsOneWidget);
    expect(find.textContaining('internal-host'), findsNothing);
    expect(find.textContaining('policy'), findsNothing);
    await tester.scrollUntilVisible(find.text("What's new in this version"), 300, scrollable: list);
    expect(find.text("What's new in this version"), findsOneWidget);
  });
}
