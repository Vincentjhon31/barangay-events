import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eCalendar/auth_service.dart';
import 'package:eCalendar/event_store.dart';
import 'package:eCalendar/main.dart';
import 'package:eCalendar/push_notifications.dart';

/// Every row of the in-memory repo titled [title], earliest first.
Future<List<BarangayEvent>> rowsTitled(MemoryEventRepository repo, String title) async {
  final all = await repo.watchAllEvents().first;
  return all.where((e) => e.title == title).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
}

/// A Saturday–Sunday-style event on three weekends, posted by the signed-in
/// mock user: "wk-1" (the home date), "wk-2", "wk-3", a week apart.
Future<MemoryEventRepository> weekendSeries() async {
  final repo = MemoryEventRepository.seeded();
  final now = DateTime.now();
  for (var i = 0; i < 3; i++) {
    final day = DateTime(now.year, now.month, now.day + 7 + 7 * i);
    await repo.addEvent(BarangayEvent(
      id: 'wk-${i + 1}',
      title: 'Weekend Clinic',
      location: 'Covered Court',
      startTime: DateTime(day.year, day.month, day.day, 8),
      endTime: DateTime(day.year, day.month, day.day + 1, 12),
      description: '',
      createdAt: now,
      createdById: 'mock-user-id',
      createdByName: 'Maria Santos',
      eventType: EventType.public,
      seriesId: 'wk-1',
    ));
  }
  await repo.addEventCommentAs('wk-1', 'Bring your ID', userId: 'mayor-1', authorName: 'Juan Dela Cruz');
  return repo;
}

Future<void> pumpApp(WidgetTester tester, MemoryEventRepository repo, {PushNotificationService? push}) async {
  await tester.pumpWidget(
    BarangayCalendarApp(
      authServiceFactory: () async => MemoryAuthService.signedIn(),
      eventRepositoryFactory: () async => repo,
      pushNotificationServiceFactory: push == null ? null : () async => push,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openFromFeed(WidgetTester tester, String title) async {
  await tester.tap(find.text('Feed'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

/// Scrolls [finder] fully into view, then taps it. (The form is a lazily
/// built list: its lower parts don't exist until scrolled to.)
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapInSheet(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Opens one date's details directly, the way a tapped notification does.
class _OpenDetailsPush implements PushNotificationService {
  _OpenDetailsPush(this.eventId);

  final String eventId;

  @override
  Future<void> initialize({
    void Function()? onAppUpdateAvailable,
    void Function(String eventId)? onEventReminder,
    void Function(String eventId)? onNotificationTapped,
    void Function(ChatPushMessage message)? onChatMessage,
    void Function(String eventId)? onChatNotificationTapped,
    bool Function(String eventId)? isChatOpen,
  }) async {
    onNotificationTapped?.call(eventId);
  }

  @override
  Future<void> syncTopics(List<String> groupIds) async {}

  @override
  Future<void> syncUserTopic(String? userId) async {}
}

void main() {
  // Same pinned 360x780 phone viewport and fresh preferences as
  // widget_test.dart.
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

  testWidgets('"Repeat every week" saves one linked event per week', (tester) async {
    final repo = MemoryEventRepository.seeded();
    await pumpApp(tester, repo);
    await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Saturday Market');
    await tester.enterText(fields.at(1), 'Public Market');

    await scrollAndTap(tester, find.byKey(const Key('add-event-repeat-weekly')));
    // The "until" picker opens about a month ahead: keep it.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Added 4 dates.'), findsOneWidget);
    expect(find.text('5 dates'), findsOneWidget);

    await scrollAndTap(tester, find.text('Save event'));

    final rows = await rowsTitled(repo, 'Saturday Market');
    expect(rows, hasLength(5));
    final home = rows.first;
    expect(home.seriesId, home.id);
    expect(rows.every((e) => e.seriesId == home.id), isTrue);
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].startTime.difference(rows[i - 1].startTime).inDays, 7);
      expect(rows[i].startTime.hour, home.startTime.hour);
      expect(rows[i].location, 'Public Market');
    }
  });

  testWidgets('"Add a date" ticks several dates on one calendar, then Done adds them all', (tester) async {
    final repo = MemoryEventRepository.seeded();
    await pumpApp(tester, repo);
    await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Zumba Night');
    await tester.enterText(fields.at(1), 'Plaza');

    await scrollAndTap(tester, find.byKey(const Key('add-event-add-date')));
    final calendar = find.byKey(const Key('add-event-more-dates-calendar'));
    // Next month: every day there is in the future, whatever today is.
    await tester.tap(find.descendant(of: calendar, matching: find.byIcon(Icons.chevron_right)));
    await tester.pumpAndSettle();
    Future<void> tapDay(int day) async {
      await tester.tap(find.descendant(of: calendar, matching: find.text('$day')));
      await tester.pumpAndSettle();
    }

    await tapDay(10);
    await tapDay(17);
    await tapDay(24);
    await tapDay(17); // untick
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('3 dates')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-event-more-dates-done')));
    await tester.pumpAndSettle();
    expect(find.text('3 dates'), findsOneWidget);

    await scrollAndTap(tester, find.text('Save event'));
    final rows = await rowsTitled(repo, 'Zumba Night');
    final now = DateTime.now();
    expect(rows, hasLength(3));
    expect(rows.skip(1).map((e) => DateTime(e.startTime.year, e.startTime.month, e.startTime.day)),
        [DateTime(now.year, now.month + 1, 10), DateTime(now.year, now.month + 1, 24)]);
    expect(rows.every((e) => e.seriesId == rows.first.id), isTrue);
  });

  testWidgets('dates that overlap ones already on the list are skipped, and one can be removed', (tester) async {
    final repo = MemoryEventRepository.seeded();
    await pumpApp(tester, repo);
    await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.byKey(const Key('add-event-repeat-weekly')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('5 dates'), findsOneWidget);

    // The same weeks again: all already there.
    await scrollAndTap(tester, find.byKey(const Key('add-event-repeat-weekly')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('No dates added: those weeks overlap dates already on the list.'), findsOneWidget);
    expect(find.text('5 dates'), findsOneWidget);

    final now = DateTime.now();
    final nextWeek = DateTime(now.year, now.month, now.day + 7);
    final remove = find.byKey(Key('add-event-remove-date-${nextWeek.year}-'
        '${nextWeek.month.toString().padLeft(2, '0')}-${nextWeek.day.toString().padLeft(2, '0')}'));
    await scrollAndTap(tester, remove);
    expect(find.text('4 dates'), findsOneWidget);
  });

  testWidgets('the Feed shows an event on several dates once, and its details list every date', (tester) async {
    await pumpApp(tester, await weekendSeries());
    await openFromFeed(tester, 'Weekend Clinic');

    expect(find.byKey(const Key('event-details-dates')), findsOneWidget);
    Navigator.of(tester.element(find.text('Event Details'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Weekend Clinic'), findsOneWidget);
    expect(find.text('+2 more dates'), findsOneWidget);
  });

  testWidgets('every date opens the same shared chat', (tester) async {
    await pumpApp(tester, await weekendSeries(), push: _OpenDetailsPush('wk-3'));
    expect(find.text('Event Details'), findsOneWidget);

    await tester.tap(find.byKey(const Key('event-chat-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bring your ID'), findsOneWidget);
  });

  testWidgets('deleting only one date keeps the others, and the chat moves with them', (tester) async {
    final repo = await weekendSeries();
    await pumpApp(tester, repo, push: _OpenDetailsPush('wk-1'));

    await tapInSheet(tester, 'Delete event');
    expect(find.text('"Weekend Clinic" is on 3 dates.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('series-scope-this-date')));
    await tester.pumpAndSettle();

    final rows = await rowsTitled(repo, 'Weekend Clinic');
    expect(rows.map((e) => e.id), ['wk-2', 'wk-3']);
    // wk-2 is the new home date: the chat moved to it.
    expect(rows.every((e) => e.seriesId == 'wk-2'), isTrue);
    final chat = await repo.watchEventComments('wk-2').first;
    expect(chat.map((c) => c.body), contains('Bring your ID'));
  });

  testWidgets('deleting all dates removes every one', (tester) async {
    final repo = await weekendSeries();
    await pumpApp(tester, repo, push: _OpenDetailsPush('wk-2'));

    await tapInSheet(tester, 'Delete event');
    await tester.tap(find.byKey(const Key('series-scope-all-dates')));
    await tester.pumpAndSettle();

    expect(await rowsTitled(repo, 'Weekend Clinic'), isEmpty);
    expect(find.textContaining('all 3 dates'), findsOneWidget);
  });

  testWidgets('editing all dates changes every date', (tester) async {
    final repo = await weekendSeries();
    await pumpApp(tester, repo, push: _OpenDetailsPush('wk-2'));

    await tapInSheet(tester, 'Edit');
    await tester.tap(find.byKey(const Key('series-scope-all-dates')));
    await tester.pumpAndSettle();
    // Typed first: the form is lazily built, so scrolling down drops its top.
    await tester.enterText(find.byType(TextField).first, 'Weekend Health Clinic');
    await scrollTo(tester, find.byKey(const Key('add-event-more-dates')));
    expect(find.text('Your changes apply to all 3 dates of this event.'), findsOneWidget);
    await scrollAndTap(tester, find.text('Save changes'));

    final rows = await rowsTitled(repo, 'Weekend Health Clinic');
    expect(rows.map((e) => e.id), ['wk-1', 'wk-2', 'wk-3']);
    expect(rows.every((e) => e.seriesId == 'wk-1'), isTrue);
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].startTime.difference(rows[i - 1].startTime).inDays, 7);
    }
  });

  testWidgets('editing one date leaves the other dates alone', (tester) async {
    final repo = await weekendSeries();
    await pumpApp(tester, repo, push: _OpenDetailsPush('wk-2'));

    await tapInSheet(tester, 'Edit');
    await tester.tap(find.byKey(const Key('series-scope-this-date')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Weekend Clinic (moved)');
    await scrollTo(tester, find.byKey(const Key('add-event-one-date-note')));
    expect(find.byKey(const Key('add-event-more-dates')), findsNothing);
    await scrollAndTap(tester, find.text('Save changes'));

    expect((await rowsTitled(repo, 'Weekend Clinic')).map((e) => e.id), ['wk-1', 'wk-3']);
    final moved = (await rowsTitled(repo, 'Weekend Clinic (moved)')).single;
    expect(moved.id, 'wk-2');
    // Still one of the event's dates.
    expect(moved.seriesId, 'wk-1');
  });

  test('deleting the home date hands its chat and files to the next date', () async {
    final repo = await weekendSeries();
    await repo.uploadEventAttachment('wk-1', 'program.pdf', Uint8List.fromList([37, 80, 68, 70]), mimeType: 'application/pdf');

    await repo.deleteEvent('wk-1');
    expect((await repo.listEventAttachments('wk-2')).map((a) => a.fileName), ['program.pdf']);
    expect((await repo.watchEventComments('wk-2').first).single.body, 'Bring your ID');

    // Down to one date: an ordinary event again.
    await repo.deleteEvent('wk-3');
    await repo.deleteEvent('wk-2');
    expect(await rowsTitled(repo, 'Weekend Clinic'), isEmpty);
  });

  test('a series left with one date becomes an ordinary event', () async {
    final repo = await weekendSeries();
    await repo.deleteEvent('wk-3');
    await repo.deleteEvent('wk-1');
    final rows = await rowsTitled(repo, 'Weekend Clinic');
    expect(rows.single.id, 'wk-2');
    expect(rows.single.seriesId, isNull);
    expect(rows.single.homeId, 'wk-2');
  });
}
