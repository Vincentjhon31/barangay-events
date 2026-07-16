// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eCalendar/main.dart';
import 'package:eCalendar/avatar_picker_page.dart';
import 'package:eCalendar/create_group_page.dart';
import 'package:eCalendar/day_detail_page.dart';
import 'package:eCalendar/event_store.dart';
import 'package:eCalendar/auth_service.dart';
import 'package:eCalendar/liquid_glass_components.dart';

/// Taps today's cell on the Month grid, which navigates to that day's
/// full-page view. Safe to find by plain day number: the grid hides
/// outside-month days (`outsideDaysVisible: false`), so there's no
/// ambiguous duplicate. Deliberately does NOT call `tester.ensureVisible`
/// first — the cell is already laid out and tappable without it (this is
/// an eager `ListView(children: ...)`, not a lazy builder), and
/// `ensureVisible`'s scroll-then-settle was found to make TableCalendar's
/// own internal PageView page forward to next month once it settles,
/// silently tapping e.g. next month's "16" instead of today's.
Future<void> openTodayDetail(WidgetTester tester) async {
  final todayCell = find.text(DateTime.now().day.toString());
  await tester.tap(todayCell);
  await tester.pumpAndSettle();
}

/// Opens today's day page, then its own Add Event button.
Future<void> openAddEventForToday(WidgetTester tester) async {
  await openTodayDetail(tester);
  await tester.tap(find.byKey(const Key('day-detail-add-event-fab')));
  await tester.pumpAndSettle();
}

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

    expect(find.text('eBongabong Calendar'), findsOneWidget);
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

    await openAddEventForToday(tester);

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

    // Save pops back to today's day page (not the main Calendar page), so
    // its own card is the only place this renders.
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

  testWidgets('can add a new calendar event from the main page\'s Add event button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    // The main Calendar page has its own "Add event" button — no need to
    // go through a day page first.
    expect(find.byKey(const Key('calendar-add-event-fab')), findsOneWidget);
    expect(find.text('Add event'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));
    await tester.enterText(textFields.at(0), 'Tree Planting');
    await tester.enterText(textFields.at(1), 'Barangay Nursery');

    await tester.scrollUntilVisible(
      find.text('Save event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();

    // Save pops straight back to the main Calendar page (not a day page).
    expect(find.byType(CalendarScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tree Planting'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tree Planting'), findsOneWidget);
  });

  testWidgets('can filter events by type and delete own event', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    // Add a (default: public) event for today, via its day page.
    await openAddEventForToday(tester);

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

    // Back on today's day page — its own card is the only place this shows.
    expect(find.text('Cleanup Drive'), findsOneWidget);

    // Back to the main Calendar page, where the filter chips live (the day
    // page has no filters of its own — it always shows every event). Popped
    // directly via the Navigator rather than tapping the glass back button:
    // `FaIcon` doesn't populate `Icon.icon` the way `find.byIcon` expects,
    // since it stores its icon data in a separate private field.
    Navigator.of(tester.element(find.byType(DayDetailPage))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Cleanup Drive'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Cleanup Drive'), findsWidgets);

    // Scroll back up to the filter chips (the lazy ListView unmounts them
    // once they're scrolled far off-screen). Keyed finders, not
    // find.text('Personal')/find.text('Public') — the Feed tab now has
    // identical chip labels and stays mounted alongside Calendar in the
    // shared IndexedStack.
    await tester.scrollUntilVisible(
      find.byKey(const Key('calendar-filter-personal')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // The Personal filter hides the public event.
    await tester.tap(find.byKey(const Key('calendar-filter-personal')));
    await tester.pumpAndSettle();
    expect(find.text('Cleanup Drive'), findsNothing);

    // The Public filter shows it again.
    await tester.ensureVisible(find.byKey(const Key('calendar-filter-public')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-filter-public')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cleanup Drive'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cleanup Drive'), findsWidgets);

    // Delete it via the card menu (creator-only option).
    final card = find.ancestor(
      of: find.text('Cleanup Drive').last,
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

    // Add an event for today (via its day page) so the current month has one.
    await openAddEventForToday(tester);
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

    // Back to the main Calendar page (List view lives there, not on the day page).
    Navigator.of(tester.element(find.byType(DayDetailPage))).pop();
    await tester.pumpAndSettle();

    // Switch to the List view. scrollUntilVisible (not ensureVisible): the
    // page's scroll position is still wherever it was left scrolled down to
    // reveal today's cell before navigating away, and "List" — being off
    // near the top now — may not even be mounted yet at that scroll
    // offset, which ensureVisible can't recover from since it needs the
    // target findable first.
    await tester.scrollUntilVisible(
      find.text('List'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
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
    expect(find.text('Fun Run'), findsWidgets);

    // Next month: the event disappears from the agenda — "No events in ..."
    // is the agenda-scoped signal that month navigation actually worked.
    await tester.ensureVisible(find.byKey(const Key('list-next-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('list-next-month')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No events in'), findsOneWidget);

    // Back to the current month: it reappears.
    await tester.tap(find.byKey(const Key('list-prev-month')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Fun Run'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fun Run'), findsWidgets);
  });

  testWidgets('event details no longer show a Going/Maybe/Not Going status section',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await openTodayDetail(tester);
    await tester.tap(find.text('Mayor Staff Meeting'));
    await tester.pumpAndSettle();

    expect(find.text('Your Status'), findsNothing);
    expect(find.text('Going'), findsNothing);
    expect(find.text('Maybe'), findsNothing);
    expect(find.text('Not Going'), findsNothing);
  });

  testWidgets('calendar search filters the List view\'s Upcoming feed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Upcoming'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();

    // Only "Mayor Staff Meeting" (today) is upcoming among the seeded
    // events — the rest are all hardcoded to dates in the past.
    await tester.scrollUntilVisible(
      find.text('Mayor Staff Meeting'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mayor Staff Meeting'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const Key('calendar-search-field')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar-search-field')),
      'zzz-no-such-event',
    );
    await tester.pumpAndSettle();

    expect(find.text('Mayor Staff Meeting'), findsNothing);
    expect(find.textContaining('No upcoming events match your search'), findsOneWidget);
  });

  testWidgets('Upcoming mode sorts by nearest-to-today with an asc/desc toggle',
      (WidgetTester tester) async {
    final repo = MemoryEventRepository.seeded();
    final now = DateTime.now();
    await repo.addEvent(BarangayEvent(
      id: 'test-far-future',
      title: 'Far Future Event',
      location: 'Somewhere',
      startTime: now.add(const Duration(days: 30)),
      endTime: now.add(const Duration(days: 30, hours: 1)),
      description: '',
      hasAttachment: false,
      createdAt: now,
      createdByName: 'Tester',
      createdById: 'mock-user-id',
      eventType: EventType.personal,
    ));

    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Upcoming'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();

    // Ascending (default): today's event comes before the far-future one.
    await tester.scrollUntilVisible(
      find.text('Far Future Event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final mayorPos = tester.getTopLeft(find.text('Mayor Staff Meeting')).dy;
    final farPos = tester.getTopLeft(find.text('Far Future Event')).dy;
    expect(mayorPos, lessThan(farPos));

    // Toggle to descending — order flips.
    await tester.scrollUntilVisible(
      find.byKey(const Key('upcoming-sort-toggle')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upcoming-sort-toggle')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Far Future Event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final mayorPos2 = tester.getTopLeft(find.text('Mayor Staff Meeting')).dy;
    final farPos2 = tester.getTopLeft(find.text('Far Future Event')).dy;
    expect(farPos2, lessThan(mayorPos2));
  });

  testWidgets('tapping a day opens its own event list page', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await openTodayDetail(tester);

    expect(find.byType(DayDetailPage), findsOneWidget);
    // Seeded for today — see MemoryEventRepository.seeded()/_seedEvents().
    expect(find.text('Mayor Staff Meeting'), findsOneWidget);
    expect(find.byKey(const Key('day-detail-add-event-fab')), findsOneWidget);
  });

  testWidgets('day detail page shows a scroll hint when the event list overflows',
      (WidgetTester tester) async {
    final repo = MemoryEventRepository.seeded();
    final today = DateTime.now();
    for (var i = 0; i < 15; i++) {
      await repo.addEvent(BarangayEvent(
        id: 'overflow-$i',
        title: 'Overflow Event $i',
        location: 'Barangay Hall',
        startTime: DateTime(today.year, today.month, today.day, 6 + i, 0),
        endTime: DateTime(today.year, today.month, today.day, 6 + i, 30),
        description: '',
        hasAttachment: false,
        createdAt: DateTime.now(),
      ));
    }

    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => repo,
      ),
    );
    await tester.pumpAndSettle();

    await openTodayDetail(tester);

    expect(find.byKey(const Key('day-detail-more-hint')), findsOneWidget);

    // Scrolling to the very bottom clears the hint (nothing more below).
    await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('day-detail-more-hint')), findsNothing);
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
    // Timeline day-group header, based on the seeded events' createdAt —
    // scrolled past the new search field/filter chips above the timeline.
    // Exact text, not textContaining('Jun 1'): each card's own "Posted by
    // ... " line also renders a "Jun 1"-shaped relative-time suffix for
    // anything that old, so a substring match hits multiple widgets.
    await tester.scrollUntilVisible(
      find.text('Monday, Jun 1'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Monday, Jun 1'), findsOneWidget);
    expect(find.textContaining('Posted by'), findsWidgets);
  });

  testWidgets('feed search filters posts by title', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    expect(find.text('Basketball Tournament'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Health Check-up'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Health Check-up'), findsOneWidget);

    // Scroll back up — the search field is above the timeline, and it's
    // now off the (virtualized) top after scrolling down to check
    // Health Check-up above.
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Search the feed'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Search the feed'), 'basketball');
    await tester.pumpAndSettle();

    expect(find.text('Basketball Tournament'), findsOneWidget);
    expect(find.text('Health Check-up'), findsNothing);

    // Clearing the search brings everything back.
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Health Check-up'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Health Check-up'), findsOneWidget);
  });

  testWidgets('feed type filter chips narrow the timeline', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    // "Health Check-up" is seeded as Personal; "Basketball Tournament" as
    // Public (no explicit eventType — defaults to public). Keyed finders,
    // not find.text('Personal') — the Calendar tab has identical chip
    // labels and stays mounted alongside Feed in the shared IndexedStack.
    await tester.tap(find.byKey(const Key('feed-filter-personal')));
    await tester.pumpAndSettle();

    expect(find.text('Health Check-up'), findsOneWidget);
    expect(find.text('Basketball Tournament'), findsNothing);

    // Back to "All" clears the filter.
    await tester.tap(find.byKey(const Key('feed-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Basketball Tournament'), findsOneWidget);
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

    expect(find.text('eBongabong Calendar'), findsWidgets);
    expect(find.textContaining('Version'), findsWidgets);
    // No updateService passed to BarangayCalendarApp in this test — the
    // page should degrade gracefully rather than crash.
    expect(find.textContaining("isn't available on this build"), findsOneWidget);
  });

  testWidgets('picking an avatar saves it and shows on the profile', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-avatar-button')));
    await tester.pumpAndSettle();

    expect(find.text('Profile Picture'), findsOneWidget);

    // Switch to the Animal category and pick the first one.
    await tester.tap(find.text('Animal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('avatar-option-assets/avatars/animal/animal_01.png')));
    await tester.pumpAndSettle();

    // Popped back to Profile, now showing the picked image instead of
    // initials on the profile tab's own avatar button.
    expect(find.byType(AvatarPickerPage), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-avatar-button')),
        matching: find.byWidgetPredicate((w) => w is CircleAvatar && w.backgroundImage != null),
      ),
      findsOneWidget,
    );
  });

  testWidgets('profile page shows the account role badge on the avatar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(role: 'lgu_member'),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('LGU MEMBER'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-avatar-button')),
        matching: find.byType(RoleAvatarFrame),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Calendar and Feed tabs support pull-to-refresh', (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    // IndexedStack builds every tab but only paints the selected one, and
    // find.byType's default skipOffstage excludes unpainted siblings — so
    // this checks each tab in turn rather than expecting both at once.
    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();
    expect(find.byType(RefreshIndicator), findsOneWidget);
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

    await openAddEventForToday(tester);

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

    // Create a group via the "Create" module tile, on its own page.
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Group name'),
      'Purok 3',
    );
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

    // Expand search (top-right icon), then search and join.
    await tester.scrollUntilVisible(
      find.byTooltip('Search groups'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search groups'));
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
    await openAddEventForToday(tester);
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
    await tester.tap(find.byKey(const Key('day-detail-add-event-fab')));
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

  group('group member management', () {
    test('creator is seeded as an admin member of their own group', () async {
      final repo = MemoryEventRepository.seeded();
      final group = await repo.createGroup('Test Group');

      final members = await repo.listGroupMembers(group.id);
      expect(members, hasLength(1));
      expect(members.single.role, 'admin');

      final myGroups = await repo.listMyGroups();
      expect(myGroups.single.isAdmin, isTrue);
    });

    test('promoting a member changes their role in the roster', () async {
      final repo = MemoryEventRepository.seeded();

      final before = await repo.listGroupMembers('grp-mayor');
      expect(before.firstWhere((member) => member.userId == 'staff-1').role, 'member');

      await repo.promoteMember('grp-mayor', 'staff-1');

      final after = await repo.listGroupMembers('grp-mayor');
      expect(after.firstWhere((member) => member.userId == 'staff-1').role, 'admin');
    });

    test('removing a member drops them from the roster and the member count',
        () async {
      final repo = MemoryEventRepository.seeded();
      final countBefore = await repo.fetchGroupMemberCount('grp-mayor');

      await repo.removeMember('grp-mayor', 'staff-1');

      final members = await repo.listGroupMembers('grp-mayor');
      expect(members.any((member) => member.userId == 'staff-1'), isFalse);
      expect(await repo.fetchGroupMemberCount('grp-mayor'), countBefore - 1);
    });

    test('members carry their account-wide role alongside their group role',
        () async {
      final repo = MemoryEventRepository.seeded();
      final members = await repo.listGroupMembers('grp-mayor');

      expect(members.firstWhere((m) => m.userId == 'mayor-1').accountRole, 'lgu_member');
      expect(members.firstWhere((m) => m.userId == 'staff-1').accountRole, 'citizen');
    });
  });

  group('role-based permissions', () {
    testWidgets('citizens can only create personal events', (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(role: 'citizen'),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
      await tester.pumpAndSettle();

      // No Public/Group choice at all for a citizen — just a locked label.
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(find.text('Personal event'), findsOneWidget);

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'My Personal Errand');
      await tester.enterText(textFields.at(1), 'Market');
      await tester.scrollUntilVisible(
        find.text('Save event'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('My Personal Errand'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('My Personal Errand'), findsOneWidget);
    });

    testWidgets('citizens cannot create a group, only join one', (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(role: 'citizen'),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      expect(find.text('LGU members only'), findsOneWidget);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Blocked — no navigation happened, just an explanatory SnackBar.
      expect(find.byType(CreateGroupPage), findsNothing);
      expect(
        find.textContaining('Only verified LGU members can create a group'),
        findsOneWidget,
      );
    });

    testWidgets('lgu members can post Group events but not Public ones',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(role: 'lgu_member'),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
      await tester.pumpAndSettle();

      expect(find.text('Group'), findsOneWidget);
      expect(find.text('Public'), findsNothing);
    });
  });
}
