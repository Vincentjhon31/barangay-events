// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:barangay_events/main.dart';
import 'package:barangay_events/event_store.dart';
import 'package:barangay_events/auth_service.dart';

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

    expect(find.text('Barangay Events Calendar'), findsOneWidget);
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

    expect(find.text('Community Cleanup'), findsOneWidget);
    expect(find.textContaining('Barangay Plaza'), findsOneWidget);
    expect(find.textContaining('Bring gloves and trash bags'), findsOneWidget);
  });
}
