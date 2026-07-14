// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:barangay_events/main.dart';
import 'package:barangay_events/event_store.dart';
import 'package:barangay_events/auth_service.dart';
import 'package:barangay_events/liquid_glass_components.dart';

void main() {
  testWidgets('Login screen renders when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.textContaining('Create one'), findsOneWidget);
  });

  testWidgets('Calendar screen renders when signed in', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Community Calendar'), findsOneWidget);
    expect(find.byType(CalendarScreen), findsOneWidget);
  });

  testWidgets('can add a new calendar event', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    await tester.enterText(textFields.at(0), 'Community Cleanup');
    await tester.enterText(textFields.at(1), 'Barangay Plaza');
    await tester.enterText(textFields.at(2), 'Bring gloves and trash bags');

    await tester.scrollUntilVisible(
      find.text('Save event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Community Cleanup'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Community Cleanup'), findsOneWidget);
    expect(find.textContaining('Barangay Plaza'), findsOneWidget);
    expect(find.textContaining('Bring gloves and trash bags'), findsOneWidget);
  });

  testWidgets('can filter events by type and delete own event', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    // Add a (default: public) event for today.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Cleanup Drive');
    await tester.enterText(textFields.at(1), 'Barangay Plaza');

    await tester.scrollUntilVisible(
      find.text('Save event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Cleanup Drive'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Cleanup Drive'), findsOneWidget);

    // Scroll back up to the filter chips (the lazy ListView unmounts them
    // once they're scrolled far off-screen).
    await tester.scrollUntilVisible(
      find.text('Personal'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // The Personal filter hides the public event.
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(find.text('Cleanup Drive'), findsNothing);

    // The Public filter shows it again.
    await tester.tap(find.text('Public'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cleanup Drive'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cleanup Drive'), findsOneWidget);

    // Delete it via the card menu (creator-only option).
    final card = find.ancestor(
      of: find.text('Cleanup Drive'),
      matching: find.byType(GlassPanel),
    );
    await tester.tap(
      find.descendant(of: card.first, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete event'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Cleanup Drive'), findsNothing);
  });

  testWidgets('list view shows events grouped per month with month navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    // Add an event for today so the current month has one.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Fun Run');
    await tester.enterText(textFields.at(1), 'Barangay Plaza');
    await tester.scrollUntilVisible(
      find.text('Save event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();

    // Switch to the List view.
    await tester.ensureVisible(find.text('List'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    final monthTitle = DateFormat('MMMM yyyy').format(DateTime.now());
    expect(find.text(monthTitle), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Fun Run'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fun Run'), findsOneWidget);

    // Next month: the event disappears.
    await tester.ensureVisible(find.byKey(const Key('list-next-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('list-next-month')));
    await tester.pumpAndSettle();
    expect(find.text('Fun Run'), findsNothing);
    expect(find.textContaining('No events in'), findsOneWidget);

    // Back to the current month: it reappears.
    await tester.tap(find.byKey(const Key('list-prev-month')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Fun Run'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fun Run'), findsOneWidget);
  });

  testWidgets('feed tab lists events with posted-by info', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    expect(find.textContaining('New events from people you follow'), findsOneWidget);
    expect(find.textContaining('Posted by'), findsWidgets);
  });

  testWidgets('About page shows version info, with update-checking disabled when no service is wired up',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('Barangay Calendar'), findsOneWidget);
    expect(find.textContaining('Version'), findsWidgets);
    // No updateService passed to BarangayCalendarApp in this test — the
    // page should degrade gracefully rather than crash.
    expect(find.textContaining("isn't available on this build"), findsOneWidget);
  });

  testWidgets('group event details show group name and member count',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Mayor Staff Meeting'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mayor Staff Meeting'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('24 members'));
    expect(find.textContaining("Mayor's Office Updates"), findsOneWidget);
    expect(find.textContaining('24 members'), findsOneWidget);
  });

  testWidgets('group events need a group picked in the add dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Not a member of any group yet: picking the Group type shows a hint
    // instead of the group dropdown.
    expect(find.textContaining('no groups yet'), findsNothing);

    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no groups yet'), findsOneWidget);
  });

  testWidgets('can create, search, and join groups', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();

    // Create a group.
    await tester.scrollUntilVisible(
      find.text('Create group'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Group name'),
      'Purok 3',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('My Groups (1)'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Purok 3'), findsOneWidget);
    expect(find.text('My Groups (1)'), findsOneWidget);

    // Switch the "Add a group" panel to Find mode, then search and join.
    await tester.scrollUntilVisible(
      find.text('Find'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Search by name'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search by name'),
      'Mayor',
    );
    await tester.pumpAndSettle();
    // Submit via the field's search action rather than tapping the tiny
    // suffixIcon button directly — Flutter's InputDecorator computes
    // suffix/prefix icon hit-test geometry in a way that can be unreliable
    // to tap precisely in widget tests, even though it renders correctly.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.textContaining("Mayor's Office Updates"), findsWidgets);

    await tester.ensureVisible(find.text('Join'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('My Groups (2)'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('My Groups (2)'), findsOneWidget);
  });

  testWidgets('warns about overlapping events and offers a free slot',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    // Add the first event, keeping the dialog's default time (9:00-10:00 AM
    // today) — matches "can add a new calendar event" and avoids depending
    // on real-world "now" vs. any fixed seed date.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    var textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Team Meeting');
    await tester.enterText(textFields.at(1), 'Room A');
    await tester.scrollUntilVisible(
      find.text('Save event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();
    // Let the "Added..." SnackBar's display timer actually elapse — it's a
    // plain Timer, not an animation, so pumpAndSettle() doesn't wait it out
    // and it would otherwise sit queued in front of the next SnackBar below.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Second event defaults to the exact same 9:00-10:00 slot -> conflict.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Board Meeting');
    await tester.enterText(textFields.at(1), 'Room B');
    await tester.pumpAndSettle();

    expect(find.text('Overlaps with an existing event:'), findsOneWidget);
    expect(find.textContaining('Team Meeting • '), findsOneWidget);

    // Saving while still conflicting is blocked; the dialog stays open.
    // A single pump (not pumpAndSettle, which would fast-forward past the
    // SnackBar's whole show-and-auto-dismiss cycle) catches it on screen.
    await tester.scrollUntilVisible(
      find.text('Save event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pump();
    // The blocking SnackBar only renders if the page is still mounted (a
    // popped page's ScaffoldMessenger wouldn't show it) — proof enough
    // that the save was blocked and Add Event stayed open, without relying
    // on the page title still being within the ListView's cache extent
    // after scrolling down to reach the Save button.
    expect(find.textContaining('overlaps with'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Tapping the suggested free slot clears the conflict...
    await tester.ensureVisible(find.textContaining('Free slot:'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Free slot:'));
    await tester.pumpAndSettle();
    expect(find.text('Overlaps with an existing event:'), findsNothing);

    // ...and the event now saves successfully.
    await tester.scrollUntilVisible(
      find.text('Save event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // warnIfMissed: false — a lingering Scaffold/Overlay render object from
    // the just-cleared conflict panel's collapse animation sits in the hit
    // chain at this exact offset even after pumpAndSettle, but the tap
    // still reaches the button (confirmed below: the event does save).
    await tester.tap(find.text('Save event'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Board Meeting'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Board Meeting'), findsOneWidget);
  });

  group('multi-day events', () {
    test('occursOnDay covers every day in the range, not just the start day', () {
      final event = BarangayEvent(
        id: 'multi-1',
        title: 'Barangay Fiesta',
        location: 'Plaza',
        startTime: DateTime.utc(2026, 12, 20, 9, 0),
        endTime: DateTime.utc(2026, 12, 22, 17, 0),
        description: '',
        hasAttachment: false,
        createdAt: DateTime.utc(2026, 12, 1),
      );

      expect(event.isMultiDay, isTrue);
      expect(event.occursOnDay(DateTime.utc(2026, 12, 19)), isFalse);
      expect(event.occursOnDay(DateTime.utc(2026, 12, 20)), isTrue);
      expect(event.occursOnDay(DateTime.utc(2026, 12, 21)), isTrue);
      expect(event.occursOnDay(DateTime.utc(2026, 12, 22)), isTrue);
      expect(event.occursOnDay(DateTime.utc(2026, 12, 23)), isFalse);
    });

    test('a single-day event is not multi-day and only occurs on its own day', () {
      final event = BarangayEvent(
        id: 'single-1',
        title: 'Quick Meeting',
        location: 'Hall',
        startTime: DateTime.utc(2026, 12, 20, 9, 0),
        endTime: DateTime.utc(2026, 12, 20, 10, 0),
        description: '',
        hasAttachment: false,
        createdAt: DateTime.utc(2026, 12, 1),
      );

      expect(event.isMultiDay, isFalse);
      expect(event.occursOnDay(DateTime.utc(2026, 12, 20)), isTrue);
      expect(event.occursOnDay(DateTime.utc(2026, 12, 21)), isFalse);
    });

    test('a multi-day event only blocks its own daily time window on days it spans',
        () {
      // Barangay Fiesta: Dec 20 7:00 AM through Dec 22 8:00 AM — the app's
      // conflict check (main.dart's _findOverlappingEvents) applies this
      // event's clock-time window (7–8 AM) on every day occursOnDay says it
      // spans, so it only blocks 7–8 AM each of those days, not the whole
      // day. This mirrors that check's half-open interval overlap math
      // without needing to drive the full Add Event UI, since
      // _findOverlappingEvents is a private method on _CalendarScreenState.
      final fiesta = BarangayEvent(
        id: 'fiesta-1',
        title: 'Barangay Fiesta',
        location: 'Plaza',
        startTime: DateTime.utc(2026, 12, 20, 7, 0),
        endTime: DateTime.utc(2026, 12, 22, 8, 0),
        description: '',
        hasAttachment: false,
        createdAt: DateTime.utc(2026, 12, 1),
      );

      int minutes(TimeOfDay t) => t.hour * 60 + t.minute;
      bool overlapsFiestaOn(DateTime day, TimeOfDay start, TimeOfDay end) {
        if (!fiesta.occursOnDay(day)) return false;
        final fiestaStart = minutes(TimeOfDay.fromDateTime(fiesta.startTime));
        final fiestaEnd = minutes(TimeOfDay.fromDateTime(fiesta.endTime));
        return minutes(start) < fiestaEnd && fiestaStart < minutes(end);
      }

      // Middle day (Dec 21), same 7–8 AM window: conflicts.
      expect(
        overlapsFiestaOn(
          DateTime.utc(2026, 12, 21),
          const TimeOfDay(hour: 7, minute: 30),
          const TimeOfDay(hour: 8, minute: 30),
        ),
        isTrue,
      );
      // Middle day, later in the morning: no conflict — still available.
      expect(
        overlapsFiestaOn(
          DateTime.utc(2026, 12, 21),
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 10, minute: 0),
        ),
        isFalse,
      );
      // Outside the date range entirely: no conflict regardless of time.
      expect(
        overlapsFiestaOn(
          DateTime.utc(2026, 12, 23),
          const TimeOfDay(hour: 7, minute: 30),
          const TimeOfDay(hour: 8, minute: 30),
        ),
        isFalse,
      );
    });
  });

  // MemoryEventRepository only ever acts as one identity (the mock user),
  // so these exercise the private-group workflow directly against the
  // repository rather than through the UI — the seeded "Barangay Council"
  // (private, owned by someone else) covers the requester's side, and
  // "Trusted Circle" (private, owned by the mock user, with one seeded
  // pending request) covers the approver's side.
  group('private groups', () {
    test('entering a private group\'s code sends a request, not membership',
        () async {
      final repo = MemoryEventRepository.seeded();

      final result = await repo.requestOrJoinGroupByCode('COUNCIL');
      expect(result.status, GroupJoinStatus.pending);
      expect(result.group.name, 'Barangay Council');

      // Not this group's creator, so requesting it doesn't add anything to
      // the mock user's own approval inbox — only the pre-seeded request
      // for their own "Trusted Circle" group is there.
      final inbox = await repo.listPendingJoinRequests();
      expect(inbox, hasLength(1));
      expect(inbox.single.groupName, 'Trusted Circle');

      // Requesting again while already pending stays pending (no duplicate).
      final second = await repo.requestOrJoinGroupByCode('COUNCIL');
      expect(second.status, GroupJoinStatus.pending);
    });

    test('private groups are hidden from search but public ones still show',
        () async {
      final repo = MemoryEventRepository.seeded();

      expect(await repo.searchGroups('Council'), isEmpty);
      expect(await repo.searchGroups('Mayor'), isNotEmpty);
    });

    test('creator can accept a pending request, adding the requester', () async {
      final repo = MemoryEventRepository.seeded();

      final pending = await repo.listPendingJoinRequests();
      expect(pending, hasLength(1));
      expect(pending.first.groupName, 'Trusted Circle');
      expect(pending.first.requesterLabel, contains('Pedro Reyes'));

      await repo.respondToJoinRequest(pending.first.id, accept: true);

      expect(await repo.listPendingJoinRequests(), isEmpty);
      expect(await repo.fetchGroupMemberCount('grp-private-mock'), 2);
    });

    test('creator can decline a pending request without adding a member',
        () async {
      final repo = MemoryEventRepository.seeded();

      final pending = await repo.listPendingJoinRequests();
      await repo.respondToJoinRequest(pending.first.id, accept: false);

      expect(await repo.listPendingJoinRequests(), isEmpty);
      expect(await repo.fetchGroupMemberCount('grp-private-mock'), 1);
    });
  });
}
