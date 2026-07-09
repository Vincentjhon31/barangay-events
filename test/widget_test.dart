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

    await tester.tap(find.text('Save'));
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

    await tester.tap(find.text('Save'));
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
    await tester.tap(find.text('Save'));
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
}
