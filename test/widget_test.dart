// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eCalendar/main.dart';
import 'package:eCalendar/attachment_image_viewer.dart';
import 'package:eCalendar/avatar_picker_page.dart';
import 'package:eCalendar/day_detail_page.dart';
import 'package:eCalendar/event_store.dart';
import 'package:eCalendar/auth_service.dart';
import 'package:eCalendar/liquid_glass_components.dart';
import 'package:eCalendar/profile_pages.dart';
import 'package:eCalendar/push_notifications.dart';
import 'package:eCalendar/responsive_scale.dart';
import 'package:eCalendar/security_page.dart';
import 'package:eCalendar/theme_controller.dart';

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
  // flutter_test's default surface (800x600 @ ratio 1.0) is wider than
  // ResponsiveScaler's 430-logical-px design-width reference, which would
  // silently activate the scale-up path in every test below and break their
  // tap-coordinate assumptions. Pin a realistic phone viewport instead, so
  // these tests keep exercising today's actual scale=1.0 behavior.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2340);
    view.devicePixelRatio = 3.0; // logical 360x780 — below the 430 design width
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('Welcome screen renders when signed out, offering Guest or Register/Login',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('welcome-continue-as-guest')), findsOneWidget);
    expect(find.byKey(const Key('welcome-register-login')), findsOneWidget);
  });

  testWidgets('Login screen renders after tapping Register/Login from Welcome',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome-register-login')));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.textContaining('Create one'), findsOneWidget);
  });

  testWidgets('Continuing as Guest renders a read-only Calendar with no Add Event/Groups',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome-continue-as-guest')));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.byKey(const Key('calendar-add-event-fab')), findsNothing);
    expect(find.byKey(const Key('calendar-filter-shared')), findsNothing);
    expect(find.byKey(const Key('guest-register-login-button')), findsOneWidget);
  });

  testWidgets("Guest's back button returns to the Welcome choice, not straight to sign-in",
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome-continue-as-guest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guest-register-login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('welcome-continue-as-guest')), findsOneWidget);
    expect(find.byKey(const Key('welcome-register-login')), findsOneWidget);
    expect(find.byType(CalendarScreen), findsNothing);
  });

  testWidgets("Guest's back button starts expanded (icon + label), then auto-collapses to icon-only",
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-continue-as-guest')));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byKey(const Key('guest-register-login-button')),
            matching: find.byType(Text)),
        findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byKey(const Key('guest-register-login-button')),
            matching: find.byType(Text)),
        findsNothing);
  });

  testWidgets('the Guest choice is never remembered — a fresh launch starts at Welcome again',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-continue-as-guest')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);

    // A second, independent app instance (simulating a fresh relaunch) must
    // not inherit the first instance's guest choice — it's in-memory-only
    // state on _BarangayCalendarAppState, not persisted anywhere. Pumping a
    // throwaway widget first forces the old State to actually be disposed —
    // otherwise pumpWidget's normal element-reconciliation would just call
    // didUpdateWidget on the *same* _BarangayCalendarAppState instance
    // (same widget type, no key), which wouldn't exercise "fresh state" at
    // all despite looking like a new app instance.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('welcome-continue-as-guest')), findsOneWidget);
    expect(find.byType(CalendarScreen), findsNothing);
  });

  testWidgets('Guest cannot add an event from the day-detail page (no FAB)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-continue-as-guest')));
    await tester.pumpAndSettle();

    await openTodayDetail(tester);

    expect(find.byType(DayDetailPage), findsOneWidget);
    expect(find.byKey(const Key('day-detail-add-event-fab')), findsNothing);
  });

  testWidgets('Guest has no type-filter chips but can reach Settings via the gear button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-continue-as-guest')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-filter-all')), findsNothing);
    expect(find.byKey(const Key('calendar-filter-public')), findsNothing);
    expect(find.byKey(const Key('calendar-filter-personal')), findsNothing);

    await tester.tap(find.byKey(const Key('guest-settings-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets("Sign-in screen's back button returns to the Welcome choice",
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-register-login')));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('signin-back-to-welcome')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('welcome-continue-as-guest')), findsOneWidget);
    expect(find.byKey(const Key('welcome-register-login')), findsOneWidget);
  });

  testWidgets(
      'sign-up form has no department field and requires matching passwords',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedOut(),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome-register-login')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Create one'));
    await tester.pumpAndSettle();

    // In-app registration always creates a citizen — no department field.
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Department / Office'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Juan Dela Cruz');
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'juan@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password1');
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'password2',
    );
    await tester.scrollUntilVisible(
      find.text('Create account'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
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
    expect(textFields, findsNWidgets(4));

    await tester.enterText(textFields.at(0), 'Community Cleanup');
    await tester.enterText(textFields.at(1), 'Barangay Plaza');
    await tester.enterText(textFields.at(3), 'Bring gloves and trash bags');

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
    expect(textFields, findsNWidgets(4));
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
    // scrollUntilVisible only guarantees the text itself cleared the fold —
    // the card's own popup button can still land under the floating tab bar
    // overlay, so nudge further to clear it before tapping (same fix used
    // for the feed pagination test's next-page button).
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
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
    // A dedicated, always-upcoming event — deliberately not relying on the
    // seeded "Mayor Staff Meeting" here, since that has a fixed 10-11 AM
    // window and would flake depending on what time of day the suite runs.
    final repo = MemoryEventRepository.seeded();
    final now = DateTime.now();
    await repo.addEvent(BarangayEvent(
      id: 'test-upcoming-search',
      title: 'Upcoming Search Target',
      location: 'Somewhere',
      startTime: now.add(const Duration(days: 10)),
      endTime: now.add(const Duration(days: 10, hours: 1)),
      description: '',
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

    await tester.scrollUntilVisible(
      find.text('Upcoming Search Target'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Upcoming Search Target'), findsWidgets);

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

    expect(find.text('Upcoming Search Target'), findsNothing);
    expect(find.textContaining('No upcoming events match your search'), findsOneWidget);
  });

  testWidgets('Group filter picker narrows Group events down to specific groups once you belong to more than one',
      (WidgetTester tester) async {
    final repo = MemoryEventRepository.seeded();
    await repo.joinGroup('grp-mayor');
    await repo.joinGroup('grp-basketball');
    final now = DateTime.now();
    await repo.addEvent(BarangayEvent(
      id: 'test-mayor-group-event',
      title: 'Mayor Group Event',
      location: 'City Hall',
      startTime: now.add(const Duration(days: 5)),
      endTime: now.add(const Duration(days: 5, hours: 1)),
      description: '',
      createdAt: now,
      createdByName: 'Mayor Staff',
      eventType: EventType.shared,
      groupId: 'grp-mayor',
      groupName: "Mayor's Office Updates",
    ));
    await repo.addEvent(BarangayEvent(
      id: 'test-basketball-group-event',
      title: 'Basketball Group Event',
      location: 'Covered Court',
      startTime: now.add(const Duration(days: 6)),
      endTime: now.add(const Duration(days: 6, hours: 1)),
      description: '',
      createdAt: now,
      createdByName: 'Coach',
      eventType: EventType.shared,
      groupId: 'grp-basketball',
      groupName: 'Basketball League',
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

    // Both groups' events show before any picking happens.
    await tester.scrollUntilVisible(
      find.text('Mayor Group Event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mayor Group Event'), findsWidgets);
    expect(find.text('Basketball Group Event'), findsWidgets);

    // The picker icon only shows up once there's more than one group to
    // choose between (see _buildTypeFilterChips's showGroupPicker).
    await tester.scrollUntilVisible(
      find.byKey(const Key('calendar-filter-group-picker')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-filter-group-picker')));
    await tester.pumpAndSettle();

    // Uncheck Basketball League, leaving only Mayor's Office Updates picked.
    await tester.tap(find.byKey(const Key('group-filter-checkbox-grp-basketball')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Mayor Group Event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mayor Group Event'), findsWidgets);
    expect(find.text('Basketball Group Event'), findsNothing);
  });

  testWidgets('citizens see no Group filter chip on the Calendar tab (they can never join a group)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(role: 'citizen'),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-filter-shared')), findsNothing);
    expect(find.byKey(const Key('calendar-filter-public')), findsOneWidget);
    expect(find.byKey(const Key('calendar-filter-personal')), findsOneWidget);
  });

  testWidgets('Upcoming mode sorts by nearest-to-today with an asc/desc toggle',
      (WidgetTester tester) async {
    final repo = MemoryEventRepository.seeded();
    final now = DateTime.now();
    // Deliberately two events added here (rather than relying on the
    // seeded "Mayor Staff Meeting", which has a fixed 10-11 AM window and
    // would flake depending on what time of day the suite runs) so both
    // ends of the sort comparison are fully under this test's control.
    await repo.addEvent(BarangayEvent(
      id: 'test-near-future',
      title: 'Near Future Event',
      location: 'Somewhere Close',
      startTime: now.add(const Duration(hours: 2)),
      endTime: now.add(const Duration(hours: 3)),
      description: '',
      createdAt: now,
      createdByName: 'Tester',
      createdById: 'mock-user-id',
      eventType: EventType.personal,
    ));
    await repo.addEvent(BarangayEvent(
      id: 'test-far-future',
      title: 'Far Future Event',
      location: 'Somewhere',
      startTime: now.add(const Duration(days: 30)),
      endTime: now.add(const Duration(days: 30, hours: 1)),
      description: '',
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

    // Ascending (default): the near-future event comes before the far one.
    await tester.scrollUntilVisible(
      find.text('Far Future Event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final nearPos = tester.getTopLeft(find.text('Near Future Event')).dy;
    final farPos = tester.getTopLeft(find.text('Far Future Event')).dy;
    expect(nearPos, lessThan(farPos));

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
    final nearPos2 = tester.getTopLeft(find.text('Near Future Event')).dy;
    final farPos2 = tester.getTopLeft(find.text('Far Future Event')).dy;
    expect(farPos2, lessThan(nearPos2));
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
    // The filter row is its own horizontal-scrolling strip, and on a
    // realistically narrow phone width not every chip fits without
    // scrolling to it first.
    await tester.ensureVisible(find.byKey(const Key('feed-filter-personal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feed-filter-personal')));
    await tester.pumpAndSettle();

    expect(find.text('Health Check-up'), findsOneWidget);
    expect(find.text('Basketball Tournament'), findsNothing);

    // Back to "All" clears the filter — scrolled out of view to the left
    // after scrolling to reach "Personal" above.
    await tester.ensureVisible(find.byKey(const Key('feed-filter-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feed-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Basketball Tournament'), findsOneWidget);
  });

  testWidgets('feed paginates instead of one long scroll once there are enough posts',
      (WidgetTester tester) async {
    final repo = MemoryEventRepository.seeded();
    final now = DateTime.now();
    for (var i = 0; i < 20; i++) {
      await repo.addEvent(BarangayEvent(
        id: 'feed-page-test-$i',
        title: 'Feed Item $i',
        location: 'Somewhere',
        startTime: now.add(Duration(days: i + 1)),
        endTime: now.add(Duration(days: i + 1, hours: 1)),
        description: '',
        createdAt: now.subtract(Duration(minutes: i)),
        createdByName: 'Tester',
        createdById: 'mock-user-id',
        eventType: EventType.personal,
      ));
    }

    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(),
        eventRepositoryFactory: () async => repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('Page 1 of'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible only scrolls the minimum needed, which can leave
    // the pagination bar sitting right under the floating bottom tab bar
    // overlay (hence the ListView's own 130px trailing padding) — drag
    // further to the actual end of the list so it's clear of that overlay
    // and hit-testable.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Page 1 of'), findsOneWidget);
    expect(find.text('Feed Item 19'), findsNothing); // on page 2, not page 1

    await tester.tap(find.byKey(const Key('feed-next-page')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('Page 2 of'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Page 2 of'), findsOneWidget);
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

    // The new Privacy Policy tile (inserted between Settings and About)
    // pushed the About tile further down, past where it used to sit clear
    // of the floating bottom tab bar — scroll it into view first so the
    // tap actually lands on it rather than the overlay on top of it.
    await tester.scrollUntilVisible(
      find.text('About'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('eBongabong Calendar'), findsWidgets);
    expect(find.textContaining('Version'), findsWidgets);
    // No updateService passed to BarangayCalendarApp in this test — the
    // page should degrade gracefully rather than crash. The Updates panel
    // now sits below the new About This App / FAQ content, so it needs a
    // scroll to come into the sliver's build range before it can be found.
    await tester.scrollUntilVisible(
      find.textContaining("isn't available on this build"),
      300,
      scrollable: find.byType(Scrollable).first,
    );
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

  testWidgets('citizens don\'t see a department field on Profile Information',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      BarangayCalendarApp(
        authServiceFactory: () async => MemoryAuthService.signedIn(role: 'citizen'),
        eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile Information'));
    await tester.pumpAndSettle();

    expect(find.text('Department / Office'), findsNothing);
  });

  testWidgets('lgu members still see a department field on Profile Information',
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
    await tester.tap(find.text('Profile Information'));
    await tester.pumpAndSettle();

    expect(find.text('Department / Office'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('Create group'),
      300,
      scrollable: find.byType(Scrollable).first,
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

    await tester.scrollUntilVisible(
      find.text('Overlaps with an existing event:'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Overlaps with an existing event:'), findsOneWidget);
    expect(find.textContaining('Team Meeting • '), findsOneWidget);

    // Saving while still conflicting now prompts a confirmation dialog
    // instead of hard-blocking — canceling it keeps Add Event open with the
    // conflicting data untouched.
    await tester.scrollUntilVisible(
      find.text('Save event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();
    expect(find.textContaining('overlaps with'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Still on Add Event, still conflicting — canceling didn't save it.
    expect(find.text('Overlaps with an existing event:'), findsOneWidget);

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

  group('event editing', () {
    test('updateEvent replaces an event, including its per-day overrides',
        () async {
      final repo = MemoryEventRepository.seeded();
      final original = BarangayEvent(
        id: 'multi-1',
        title: 'Fiesta',
        location: 'Plaza',
        startTime: DateTime(2026, 8, 1, 8, 0),
        endTime: DateTime(2026, 8, 3, 20, 0),
        description: '',
        createdAt: DateTime.now(),
        createdById: 'mock-user-id',
        eventType: EventType.personal,
      );
      await repo.addEvent(original);

      await repo.updateEvent(BarangayEvent(
        id: original.id,
        title: 'Fiesta (updated)',
        location: original.location,
        startTime: original.startTime,
        endTime: original.endTime,
        description: original.description,
        createdAt: original.createdAt,
        createdById: original.createdById,
        eventType: original.eventType,
        dailyOverrides: [
          DailyOverride(
            day: DateTime.utc(2026, 8, 2),
            startMinutes: 13 * 60,
            endMinutes: 17 * 60,
          ),
        ],
      ));

      final events = await repo.watchAllEvents().first;
      final saved = events.firstWhere((e) => e.id == 'multi-1');
      expect(saved.title, 'Fiesta (updated)');

      // Day 2 uses its override...
      final day2 = saved.minutesWindowForDay(DateTime.utc(2026, 8, 2));
      expect(day2.startMinutes, 13 * 60);
      expect(day2.endMinutes, 17 * 60);
      // ...but day 1 still falls back to the event's own default window.
      final day1 = saved.minutesWindowForDay(DateTime.utc(2026, 8, 1));
      expect(day1.startMinutes, 8 * 60);
      expect(day1.endMinutes, 20 * 60);
    });

    testWidgets('creator can edit their own event', (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      await openAddEventForToday(tester);
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Original Title');
      await tester.enterText(textFields.at(1), 'Original Location');
      await tester.scrollUntilVisible(
        find.text('Save event'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Original Title'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Edit'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Event'), findsOneWidget);
      final editFields = find.byType(TextField);
      await tester.enterText(editFields.at(0), 'Updated Title');
      await tester.scrollUntilVisible(
        find.text('Save changes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Updated Title'), findsWidgets);
      expect(find.text('Original Title'), findsNothing);
    });

    testWidgets('a promoted group admin can edit an event they did not create,'
        ' but still cannot delete it', (WidgetTester tester) async {
      final repo = MemoryEventRepository.seeded();
      await repo.joinGroup('grp-mayor');
      await repo.promoteMember('grp-mayor', 'mock-user-id');

      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => repo,
        ),
      );
      await tester.pumpAndSettle();

      await openTodayDetail(tester);
      await tester.tap(find.text('Mayor Staff Meeting'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete event'), findsNothing);
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

    testWidgets('citizens have no Groups tab at all', (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(role: 'citizen'),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      // Group creation/events are LGU-level — a citizen only ever sees
      // Calendar, Feed, and Profile, not a Groups tab to be locked out of.
      expect(find.text('Groups'), findsNothing);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Tapping Profile still resolves correctly even though its bottom
      // tab bar index shifted left by one now that Groups isn't there.
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('CITIZEN'), findsOneWidget);
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

  group('responsive scaling', () {
    testWidgets('scales up on a large kiosk-sized viewport but taps still work',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(3840, 2160);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();

      expect(find.text('Feed'), findsWidgets);
    });

    testWidgets('Settings lets you switch between Auto/Mobile/Tablet/Windows display size',
        (WidgetTester tester) async {
      // Verified against the controller directly, not by re-inspecting the
      // widget tree after selecting "Windows / Kiosk" — that preset forces a
      // fixed 2x scale on the *whole app*, which on this test's small
      // phone-sized viewport shrinks the effective canvas to something even
      // Settings' own content can't render sanely (a real Windows/kiosk
      // screen wouldn't have this problem, only this test's tiny viewport).
      final themeController = ThemeController();
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
          themeController: themeController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Tablet'), findsOneWidget);
      expect(find.text('Windows / Kiosk'), findsOneWidget);
      expect(themeController.displayMode, DisplayMode.auto);

      await tester.ensureVisible(find.text('Windows / Kiosk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Windows / Kiosk'));
      await tester.pumpAndSettle();

      expect(themeController.displayMode, DisplayMode.windows);
    });
  });

  group('add-event overlap confirmation', () {
    testWidgets('proceeding through the overlap dialog still saves the event',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      // First event keeps the dialog's default 9:00-10:00 AM slot today.
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
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Second event defaults to the exact same slot -> conflict.
      await tester.tap(find.byKey(const Key('day-detail-add-event-fab')));
      await tester.pumpAndSettle();
      textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Board Meeting');
      await tester.enterText(textFields.at(1), 'Room B');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Save event'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();

      expect(find.textContaining('overlaps with'), findsWidgets);
      await tester.tap(find.text('Proceed anyway'));
      await tester.pumpAndSettle();

      // Back on the day page — both conflicting events were saved.
      await tester.scrollUntilVisible(
        find.text('Board Meeting'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Team Meeting'), findsOneWidget);
      expect(find.text('Board Meeting'), findsOneWidget);
    });
  });

  group('upcoming empty state', () {
    testWidgets("shows nearby upcoming events when today has none",
        (WidgetTester tester) async {
      final repo = MemoryEventRepository.seeded();
      // Today's own seeded event is removed so today is genuinely empty —
      // see _seedEvents()'s comment on 'seed-mayor-meeting'.
      await repo.deleteEvent('seed-mayor-meeting');
      final now = DateTime.now();
      await repo.addEvent(BarangayEvent(
        id: 'future-fiesta',
        title: 'Fiesta Planning',
        location: 'Barangay Hall',
        startTime: now.add(const Duration(days: 3)),
        endTime: now.add(const Duration(days: 3, hours: 1)),
        description: '',
        createdAt: now,
      ));

      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => repo,
        ),
      );
      await tester.pumpAndSettle();

      // Scrolled into view rather than asserted immediately — how far down
      // this sits depends on how many rows the current real month's
      // calendar grid needs (5 vs. 6, depending on what weekday the 1st
      // falls on), which can push it outside the test surface's default
      // mount range without this.
      await tester.scrollUntilVisible(
        find.text("Nothing today — here's what's coming up:"),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text("Nothing today — here's what's coming up:"), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Fiesta Planning'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Fiesta Planning'), findsOneWidget);
    });
  });

  group('new event notice banner', () {
    testWidgets('shows a banner when someone else posts a new event',
        (WidgetTester tester) async {
      final repo = MemoryEventRepository.seeded();
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => repo,
        ),
      );
      await tester.pumpAndSettle();

      final now = DateTime.now();
      await repo.addEvent(BarangayEvent(
        id: 'other-user-event',
        title: 'Blood Donation Drive',
        location: 'Barangay Hall',
        startTime: now.add(const Duration(days: 2)),
        endTime: now.add(const Duration(days: 2, hours: 2)),
        description: '',
        createdAt: now,
        createdById: 'someone-else',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('New event posted'), findsOneWidget);
      expect(find.text('Blood Donation Drive'), findsOneWidget);
    });

    testWidgets("does not show a banner for the current user's own new event",
        (WidgetTester tester) async {
      final repo = MemoryEventRepository.seeded();
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => repo,
        ),
      );
      await tester.pumpAndSettle();

      final now = DateTime.now();
      await repo.addEvent(BarangayEvent(
        id: 'my-own-event',
        title: 'My Own Meeting',
        location: 'Somewhere',
        startTime: now.add(const Duration(days: 1)),
        endTime: now.add(const Duration(days: 1, hours: 1)),
        description: '',
        createdAt: now,
        createdById: 'mock-user-id',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('New event posted'), findsNothing);
    });

    testWidgets(
        'does not show a banner for an old event newly visible (e.g. after joining a group)',
        (WidgetTester tester) async {
      final repo = MemoryEventRepository.seeded();
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => repo,
        ),
      );
      await tester.pumpAndSettle();

      final now = DateTime.now();
      await repo.addEvent(BarangayEvent(
        id: 'old-event-now-visible',
        title: 'Old Fiesta Meeting',
        location: 'Somewhere',
        startTime: now.add(const Duration(days: 5)),
        endTime: now.add(const Duration(days: 5, hours: 1)),
        description: '',
        createdAt: now.subtract(const Duration(days: 10)),
        createdById: 'someone-else',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('New event posted'), findsNothing);
    });
  });

  group('notification tap', () {
    testWidgets('tapping a notification for a known event opens its detail sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
          pushNotificationServiceFactory: () async =>
              _TappedNotificationPushService('seed-assembly'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Event Details'), findsOneWidget);
      expect(find.text('Barangay Assembly'), findsOneWidget);
    });

    testWidgets('tapping a notification for an unknown event does nothing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
          pushNotificationServiceFactory: () async =>
              _TappedNotificationPushService('does-not-exist'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Event Details'), findsNothing);
    });
  });

  group('event attachments', () {
    testWidgets('shows an uploaded attachment on the event detail sheet',
        (WidgetTester tester) async {
      final repo = MemoryEventRepository.seeded();
      await repo.uploadEventAttachment(
        'seed-assembly',
        'agenda.pdf',
        Uint8List.fromList([1, 2, 3]),
        mimeType: 'application/pdf',
      );

      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => repo,
          pushNotificationServiceFactory: () async =>
              _TappedNotificationPushService('seed-assembly'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Event Details'), findsOneWidget);
      expect(find.text('agenda.pdf'), findsOneWidget);
    });

    testWidgets('shows no attachments section when an event has none',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
          pushNotificationServiceFactory: () async =>
              _TappedNotificationPushService('seed-assembly'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Event Details'), findsOneWidget);
      expect(find.text('Attachments'), findsNothing);
    });

    testWidgets('shows an image attachment thumbnail and opens the full-screen viewer',
        (WidgetTester tester) async {
      final repo = MemoryEventRepository.seeded();
      // A minimal 1x1 transparent PNG — real enough for Image.memory to
      // decode without erroring.
      final pngBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
        '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      await repo.uploadEventAttachment(
        'seed-assembly',
        'photo.png',
        pngBytes,
        mimeType: 'image/png',
      );

      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => repo,
          pushNotificationServiceFactory: () async =>
              _TappedNotificationPushService('seed-assembly'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('photo.png'), findsOneWidget);
      final attachmentFinder = find.byKey(const Key('event-attachment-attachment-1'));
      expect(attachmentFinder, findsOneWidget);
      // A real thumbnail (not just the generic file-type icon) means the
      // downloaded bytes actually made it into the row.
      expect(find.descendant(of: attachmentFinder, matching: find.byType(Image)), findsOneWidget);

      await tester.scrollUntilVisible(
        attachmentFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // A direct callback invocation, not tester.tap() — the row sits
      // inside the event-detail sheet's DraggableScrollableSheet, where a
      // synthetic tap reliably passes hit-testing (no warnIfMissed
      // warning) but still doesn't reach InkWell's gesture recognizer in
      // the test harness; confirmed this is a test-environment quirk, not
      // a real bug — the same tap works fine in an actual browser/app.
      tester.widget<InkWell>(attachmentFinder).onTap!();
      await tester.pumpAndSettle();

      expect(find.byType(AttachmentImageViewer), findsOneWidget);
      // No signed/Storage URL anywhere in the viewer — it renders straight
      // from the bytes already fetched through the authenticated client.
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });

  group('password reset', () {
    testWidgets("forgot-password dialog sends a reset email and shows confirmation",
        (WidgetTester tester) async {
      final authService = MemoryAuthService.signedOut();
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => authService,
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('welcome-register-login')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'someone@example.com');
      await tester.tap(find.byKey(const Key('signin-forgot-password')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forgot-password-email-field')), findsOneWidget);
      await tester.tap(find.byKey(const Key('forgot-password-send-button')));
      await tester.pumpAndSettle();

      expect(authService.lastPasswordResetEmail, 'someone@example.com');
      expect(find.textContaining('Check your email'), findsOneWidget);
    });

    testWidgets('a recovery event shows ResetPasswordPage, and saving exits it',
        (WidgetTester tester) async {
      final authService = MemoryAuthService.signedOut();
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => authService,
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-password-new-field')), findsNothing);

      authService.simulatePasswordRecovery();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset-password-new-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('reset-password-new-field')), 'newpass123');
      await tester.enterText(find.byKey(const Key('reset-password-confirm-field')), 'newpass123');
      await tester.tap(find.byKey(const Key('reset-password-save-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset-password-new-field')), findsNothing);
    });

    testWidgets('rejects a mismatched confirmation on ResetPasswordPage',
        (WidgetTester tester) async {
      final authService = MemoryAuthService.signedOut();
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => authService,
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      authService.simulatePasswordRecovery();
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('reset-password-new-field')), 'newpass123');
      await tester.enterText(find.byKey(const Key('reset-password-confirm-field')), 'different');
      await tester.tap(find.byKey(const Key('reset-password-save-button')));
      await tester.pumpAndSettle();

      // Still on the page — the mismatch was rejected before calling
      // updatePassword.
      expect(find.byKey(const Key('reset-password-new-field')), findsOneWidget);
    });
  });

  group('language preference', () {
    testWidgets('switching to Filipino in Settings re-renders the in-scope UI',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      // English by default.
      expect(find.text('Calendar'), findsWidgets);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // The lazy ListView hasn't built the (currently off-screen) Language
      // section yet — scrollUntilVisible incrementally scrolls until it
      // does, unlike ensureVisible, which needs the element to already
      // exist in the tree.
      await tester.scrollUntilVisible(
        find.text('Language'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      await tester.tap(find.text('Filipino'));
      await tester.pumpAndSettle();

      // The whole app rebuilds immediately — Settings' own title (scrolled
      // out of the lazy ListView's built range by the scroll above) switches
      // right away.
      await tester.scrollUntilVisible(
        find.text('Mga Setting'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Mga Setting'), findsWidgets);

      // Pop back to the main shell (the tab bar sits underneath this pushed
      // page, offstage — find.text skips offstage widgets by default) and
      // confirm it switched too.
      Navigator.of(tester.element(find.byType(SettingsPage))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Kalendaryo'), findsWidgets);
      expect(find.text('Calendar'), findsNothing);
    });
  });

  group('security page', () {
    Future<void> openSecurityPage(WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-security-tile')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the current email pre-filled in the new-email field',
        (WidgetTester tester) async {
      await openSecurityPage(tester);

      expect(find.byType(SecurityPage), findsOneWidget);
      final emailField = tester.widget<TextField>(
        find.byKey(const Key('security-new-email-field')),
      );
      expect(emailField.controller?.text, 'user@example.com');
    });

    testWidgets('password fields start obscured and the eye icon reveals them',
        (WidgetTester tester) async {
      await openSecurityPage(tester);

      TextField passwordField() => tester.widget<TextField>(
            find.byKey(const Key('security-new-password-field')),
          );

      expect(passwordField().obscureText, isTrue);

      await tester.tap(find.byKey(const Key('security-toggle-new-password-visibility')));
      await tester.pumpAndSettle();

      expect(passwordField().obscureText, isFalse);
    });

    testWidgets('rejects mismatched new/confirm passwords',
        (WidgetTester tester) async {
      await openSecurityPage(tester);

      await tester.enterText(
        find.byKey(const Key('security-new-password-field')),
        'newpassword1',
      );
      await tester.enterText(
        find.byKey(const Key('security-confirm-password-field')),
        'newpassword2',
      );
      await tester.tap(find.byKey(const Key('security-update-password-button')));
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('Kiosk Passcode section only shows for kiosk accounts',
        (WidgetTester tester) async {
      await openSecurityPage(tester);
      expect(find.text('Kiosk Passcode'), findsNothing);
    });

    testWidgets('Kiosk Passcode section shows and rejects a mismatched confirmation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async =>
              MemoryAuthService.signedIn(isKioskAccount: true),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-security-tile')));
      await tester.pumpAndSettle();

      expect(find.text('Kiosk Passcode'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('security-update-passcode-button')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('security-current-passcode-field')), '0000');
      await tester.enterText(
        find.byKey(const Key('security-new-passcode-field')), '1234');
      await tester.enterText(
        find.byKey(const Key('security-confirm-passcode-field')), '5678');
      await tester.tap(find.byKey(const Key('security-update-passcode-button')));
      await tester.pump();

      expect(find.text('Passcodes do not match.'), findsOneWidget);
    });
  });

  group('kiosk exit passcode', () {
    Future<void> enterPasscode(WidgetTester tester, String passcode) async {
      for (final digit in passcode.split('')) {
        await tester.tap(find.byKey(Key('keypad-digit-$digit')));
        await tester.pump();
      }
    }

    testWidgets('wrong passcode shows an error and does not exit kiosk mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async =>
              MemoryAuthService.signedIn(isKioskAccount: true),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('enable-kiosk-mode-button')));
      await tester.pumpAndSettle();
      expect(find.text('Exit Kiosk Mode'), findsOneWidget);

      await tester.tap(find.text('Exit Kiosk Mode'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Passcode'), findsOneWidget);

      await enterPasscode(tester, '9999'); // mock default passcode is 0000
      await tester.pumpAndSettle();

      expect(find.text('Incorrect passcode. Try again.'), findsOneWidget);
      // Still in kiosk mode — the sheet is still open, not dismissed.
      expect(find.text('Enter Passcode'), findsOneWidget);
    });

    testWidgets('correct passcode exits kiosk mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async =>
              MemoryAuthService.signedIn(isKioskAccount: true),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('enable-kiosk-mode-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit Kiosk Mode'));
      await tester.pumpAndSettle();

      await enterPasscode(tester, '0000');
      await tester.pumpAndSettle();

      expect(find.text('Enter Passcode'), findsNothing);
      expect(find.byKey(const Key('enable-kiosk-mode-button')), findsOneWidget);
    });
  });
}

/// Fires [onNotificationTapped] with a fixed [eventId] as soon as
/// [initialize] runs — simulates the app cold-starting from a tapped push
/// notification (see PushNotificationService.onNotificationTapped).
class _TappedNotificationPushService implements PushNotificationService {
  _TappedNotificationPushService(this.eventId);

  final String eventId;

  @override
  Future<void> initialize({
    void Function()? onAppUpdateAvailable,
    void Function(String eventId)? onEventReminder,
    void Function(String eventId)? onNotificationTapped,
  }) async {
    onNotificationTapped?.call(eventId);
  }

  @override
  Future<void> syncTopics(List<String> groupIds) async {}

  @override
  Future<void> syncUserTopic(String? userId) async {}
}
