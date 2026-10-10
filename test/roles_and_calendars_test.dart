import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eCalendar/auth_service.dart';
import 'package:eCalendar/event_calendars.dart';
import 'package:eCalendar/event_store.dart';
import 'package:eCalendar/liquid_glass_components.dart';
import 'package:eCalendar/main.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  String role = 'admin',
  Map<String, bool> adminPermissions = const {},
  MemoryEventRepository? repository,
}) async {
  final repo = repository ?? MemoryEventRepository.seeded();
  await tester.pumpWidget(
    BarangayCalendarApp(
      authServiceFactory: () async =>
          MemoryAuthService.signedIn(role: role, adminPermissions: adminPermissions),
      eventRepositoryFactory: () async => repo,
    ),
  );
  await tester.pumpAndSettle();
}

/// The chip row scrolls sideways; at the 360px test width a calendar chip
/// (after All/Public/Group/Personal) starts off-screen.
Future<void> tapTypeChip(WidgetTester tester, String key) async {
  await tester.drag(find.byKey(const Key('calendar-filter-all')), const Offset(-400, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Today's day page — it applies the Calendar tab's active filter to its
/// own event list, and has no floating tab bar covering the cards.
Future<void> openToday(WidgetTester tester) async {
  await tester.tap(find.text(DateTime.now().day.toString()));
  await tester.pumpAndSettle();
}

BarangayEvent todayEvent(String id, String title, {String? calendarId}) {
  final now = DateTime.now();
  return BarangayEvent(
    id: id,
    title: title,
    location: 'Covered Court',
    startTime: DateTime(now.year, now.month, now.day, 14),
    endTime: DateTime(now.year, now.month, now.day, 15),
    description: '',
    createdAt: DateTime(2026, 1, 1),
    createdById: 'someone-else',
    createdByName: 'Sports Office',
    eventType: calendarId != null ? EventType.calendar : EventType.public,
    calendarId: calendarId,
    calendarName: calendarId != null ? 'Sports' : null,
  );
}

void main() {
  // Same pinned 360x780 phone viewport and fresh preferences as
  // widget_test.dart — see the comment on its setUp.
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

  group('account roles and admin permissions', () {
    AppUserProfile profile(String role, [Map<String, bool> permissions = const {}]) =>
        AppUserProfile(id: 'u', email: 'u@example.com', role: role, adminPermissions: permissions);

    test('an admin has every permission until the superadmin switches one off', () {
      final admin = profile('admin');
      expect(admin.isAdmin, isTrue);
      expect(admin.isStaffAdmin, isTrue);
      expect(admin.isSuperadmin, isFalse);
      expect(admin.canCreatePublicEvents, isTrue);
      expect(admin.canCreateGroups, isTrue);
      expect(admin.canManageGroups, isTrue);
      expect(admin.canManageLocations, isTrue);
      expect(admin.canCreateGroupEvents, isTrue);

      final limited = profile('admin', {
        AdminPermission.publicEvents: false,
        AdminPermission.manageGroups: false,
        AdminPermission.locations: true,
      });
      expect(limited.canCreatePublicEvents, isFalse);
      expect(limited.canCreateGroups, isFalse);
      expect(limited.canManageGroups, isFalse);
      expect(limited.canManageLocations, isTrue);
      // Group events and chat moderation aren't toggles.
      expect(limited.canCreateGroupEvents, isTrue);
      expect(limited.isStaffAdmin, isTrue);
    });

    test('the superadmin always has every admin power, whatever the toggles say', () {
      final owner = profile('superadmin', {AdminPermission.publicEvents: false});
      expect(owner.canCreatePublicEvents, isTrue);
      expect(owner.canManageGroups, isTrue);
      expect(owner.canManageLocations, isTrue);
      expect(owner.isStaffAdmin, isTrue);
    });

    test('LGU members and citizens hold no admin permissions', () {
      final lgu = profile('lgu_member', {AdminPermission.publicEvents: true});
      expect(lgu.canCreatePublicEvents, isFalse);
      expect(lgu.canCreateGroups, isTrue);
      expect(lgu.canCreateGroupEvents, isTrue);
      expect(lgu.canManageGroups, isFalse);
      expect(lgu.isStaffAdmin, isFalse);

      final citizen = profile('citizen');
      expect(citizen.canCreatePublicEvents, isFalse);
      expect(citizen.canCreateGroups, isFalse);
      expect(citizen.canCreateGroupEvents, isFalse);
      expect(citizen.canManageLocations, isFalse);
    });

    test('admin_permissions is read from the server but never sent back on a self-save', () {
      final parsed = AppUserProfile.fromJson({
        'id': 'u',
        'email': 'u@example.com',
        'role': 'admin',
        'admin_permissions': {'public_events': false, 'locations': true},
      });
      expect(parsed.adminPermissions, {'public_events': false, 'locations': true});
      expect(parsed.canCreatePublicEvents, isFalse);
      expect(parsed.toJson().containsKey('admin_permissions'), isFalse);
      expect(parsed.toJson().containsKey('role'), isFalse);
    });

    test('admins and the superadmin get distinct labels and frame colors', () {
      final scheme = ThemeData.light().colorScheme;
      expect(roleLabel('admin'), 'Admin');
      expect(roleLabel('superadmin'), 'Superadmin');
      expect(roleAccentColor('admin', scheme), isNot(roleAccentColor('superadmin', scheme)));
      expect(roleAccentColor('admin', scheme), isNot(roleAccentColor('citizen', scheme)));
    });

    testWidgets('an admin without the Public events permission can\'t pick Public', (tester) async {
      await pumpApp(tester, adminPermissions: {AdminPermission.publicEvents: false});
      await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
      await tester.pumpAndSettle();

      expect(find.text('Group'), findsOneWidget);
      expect(find.text('Public'), findsNothing);
    });

    testWidgets('a default admin can still pick Public', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
      await tester.pumpAndSettle();

      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget);
    });

    testWidgets('Manage Locations follows the Event locations permission', (tester) async {
      await pumpApp(tester, adminPermissions: {AdminPermission.locations: false});
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-privacy-policy-tile')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // It would sit right after Privacy Policy — well inside the built area.
      expect(find.byKey(const Key('profile-manage-locations-tile')), findsNothing);
      expect(find.text('ADMIN'), findsOneWidget);
    });

    testWidgets('a superadmin in the app keeps the admin tools', (tester) async {
      await pumpApp(tester, role: 'superadmin');
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-manage-locations-tile')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(const Key('profile-manage-locations-tile')), findsOneWidget);
      expect(find.text('SUPERADMIN'), findsOneWidget);
    });
  });

  group('custom calendars', () {
    const sports = EventCalendar(id: 'sports', name: 'Sports', icon: 'basketball', colorKey: 'tangerine', sortOrder: 1);

    MemoryEventRepository repoWithSports({bool handledByMe = false}) {
      final repo = MemoryEventRepository.seeded();
      repo.addEventCalendar(sports, handledByMe: handledByMe);
      return repo;
    }

    testWidgets('a calendar shows up as an extra tab on the Calendar and Feed', (tester) async {
      await pumpApp(tester, repository: repoWithSports());

      expect(find.byKey(const Key('calendar-filter-cal-sports')), findsOneWidget);
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feed-filter-cal-sports')), findsOneWidget);
    });

    testWidgets('its tab shows only its events, and they don\'t count as Public', (tester) async {
      final repo = repoWithSports();
      await repo.addEvent(todayEvent('ev-finals', 'Basketball Finals', calendarId: 'sports'));
      await pumpApp(tester, repository: repo);

      await tapTypeChip(tester, 'calendar-filter-cal-sports');
      await openToday(tester);
      expect(find.text('Basketball Finals'), findsOneWidget);
      // Today's seeded meeting isn't in the Sports calendar.
      expect(find.text('Mayor Staff Meeting'), findsNothing);
      // The card's type pill names the calendar.
      expect(find.byKey(const Key('event-calendar-pill-ev-finals')), findsOneWidget);
      expect(find.text('Sports'), findsWidgets);

      // Back from the day page (it has its own back chevron, not an AppBar).
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      // The chip row is still scrolled to the calendar tab; scroll back.
      await tester.drag(find.byKey(const Key('calendar-filter-cal-sports')), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendar-filter-public')));
      await tester.pumpAndSettle();
      await openToday(tester);
      expect(find.text('Basketball Finals'), findsNothing);
    });

    testWidgets('archiving a calendar removes its tab and falls back to All', (tester) async {
      final repo = repoWithSports();
      await pumpApp(tester, repository: repo);
      await tapTypeChip(tester, 'calendar-filter-cal-sports');

      repo.archiveEventCalendar('sports');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar-filter-cal-sports')), findsNothing);
      await openToday(tester);
      // No leftover invisible filter: today's other event shows.
      expect(find.text('Mayor Staff Meeting'), findsOneWidget);
    });

    testWidgets('a handler can post to the calendar from Add Event', (tester) async {
      final repo = repoWithSports(handledByMe: true);
      await pumpApp(tester, repository: repo);
      await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Volleyball Clinic');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Public / Group / Personal / Sports — scrolls sideways when crowded.
      await tester.ensureVisible(find.byKey(const Key('add-event-type-sports')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-event-type-sports')));
      await tester.pumpAndSettle();
      expect(find.textContaining('under the Sports tab'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Save event'), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();

      final saved = (await repo.watchAllEvents().first).firstWhere((e) => e.title == 'Volleyball Clinic');
      expect(saved.eventType, EventType.calendar);
      expect(saved.calendarId, 'sports');
      expect(saved.calendarName, 'Sports');
    });

    testWidgets('someone who doesn\'t handle the calendar can\'t post to it', (tester) async {
      await pumpApp(tester, repository: repoWithSports());
      await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-event-type-sports')), findsNothing);
    });

    testWidgets('a citizen assigned as handler gets Personal + the calendar', (tester) async {
      await pumpApp(tester, role: 'citizen', repository: repoWithSports(handledByMe: true));
      await tester.tap(find.byKey(const Key('calendar-add-event-fab')));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.byKey(const Key('add-event-type-sports')), findsOneWidget);
      expect(find.text('Public'), findsNothing);
    });

    testWidgets('handlers can edit anyone\'s event in their calendar', (tester) async {
      final repo = repoWithSports(handledByMe: true);
      await repo.addEvent(todayEvent('ev-finals', 'Basketball Finals', calendarId: 'sports'));
      await pumpApp(tester, role: 'citizen', repository: repo);

      await openToday(tester);
      await tester.tap(find.text('Basketball Finals'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      // Deleting stays with the event's creator.
      expect(find.text('Delete event'), findsNothing);
    });

    test('calendar events round-trip through Supabase rows', () {
      final event = BarangayEvent.fromSupabase({
        'id': 'e1',
        'title': 'Fun Run',
        'location': 'Plaza',
        'start_time': '2026-10-20T06:00:00+00:00',
        'end_time': '2026-10-20T08:00:00+00:00',
        'description': '',
        'created_at': '2026-10-01T00:00:00+00:00',
        'event_type': 'calendar',
        'calendar_id': 'sports',
        'calendar_name': 'Sports',
      });
      expect(event.eventType, EventType.calendar);
      expect(event.calendarId, 'sports');
      expect(event.calendarName, 'Sports');
      final json = event.toSupabaseJson();
      expect(json['calendar_id'], 'sports');
      // Filled server-side, never written by the app.
      expect(json.containsKey('calendar_name'), isFalse);
      expect(BarangayEvent.fromJson(event.toJson()).calendarId, 'sports');
    });

    test('calendar values and icons', () {
      expect(calendarIdFromValue(calendarValue('sports')), 'sports');
      expect(calendarIdFromValue('public'), isNull);
      expect(calendarIcon('does-not-exist'), calendarIcon('tag'));
    });
  });
}
