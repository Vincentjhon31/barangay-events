import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eCalendar/auth_service.dart';
import 'package:eCalendar/event_chat_activity.dart';
import 'package:eCalendar/event_chat_page.dart';
import 'package:eCalendar/event_store.dart';
import 'package:eCalendar/l10n/app_localizations.dart';
import 'package:eCalendar/main.dart';
import 'package:eCalendar/manila_clock.dart';
import 'package:eCalendar/push_notifications.dart';

/// Today's seeded "Mayor Staff Meeting" (a group event created by someone
/// else, with one seeded chat message from its creator) — opened from
/// today's day page, like a user would.
Future<void> openMayorMeetingDetails(WidgetTester tester) async {
  await tester.tap(find.text(DateTime.now().day.toString()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mayor Staff Meeting'));
  await tester.pumpAndSettle();
}

Future<void> pumpSignedIn(
  WidgetTester tester, {
  String role = 'admin',
  MemoryEventRepository? repository,
}) async {
  final repo = repository ?? MemoryEventRepository.seeded();
  await tester.pumpWidget(
    BarangayCalendarApp(
      authServiceFactory: () async => MemoryAuthService.signedIn(role: role),
      eventRepositoryFactory: () async => repo,
    ),
  );
  await tester.pumpAndSettle();
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

  group('Manila time', () {
    test('toManila shifts any instant to UTC+8 wall-clock time', () {
      // 4:30 PM UTC is already 12:30 AM the next day in Manila.
      final manila = toManila(DateTime.utc(2026, 10, 8, 16, 30));
      expect(manila.year, 2026);
      expect(manila.month, 10);
      expect(manila.day, 9);
      expect(manila.hour, 0);
      expect(manila.minute, 30);
    });

    test('toManila gives the same result for a local and a UTC DateTime of one instant', () {
      final instant = DateTime.now();
      expect(toManila(instant), toManila(instant.toUtc()));
    });

    test('manilaNow is 8 hours ahead of UTC', () {
      final utcFields = DateTime.now().toUtc();
      final manila = manilaNow();
      final asIfUtc = DateTime.utc(manila.year, manila.month, manila.day, manila.hour, manila.minute);
      final expected = DateTime.utc(utcFields.year, utcFields.month, utcFields.day, utcFields.hour, utcFields.minute)
          .add(const Duration(hours: 8));
      expect(asIfUtc.difference(expected).inMinutes.abs(), lessThanOrEqualTo(1));
    });

    testWidgets('the Calendar header shows a live Philippine clock beside the avatar', (tester) async {
      await pumpSignedIn(tester);

      expect(find.byKey(const Key('manila-clock')), findsOneWidget);
      final timeText = tester.widget<Text>(find.byKey(const Key('manila-clock-time')));
      expect(timeText.data, matches(RegExp('^[0-9]{1,2}:[0-9]{2}:[0-9]{2} (AM|PM)[.]?')));
      expect(find.textContaining('PHT'), findsOneWidget);

      // The clock keeps ticking without errors or layout overflow.
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('isEmojiOnlyMessage', () {
    test('is true for one to three emoji, including flags, skin tones, and ZWJ sequences', () {
      expect(isEmojiOnlyMessage('😀'), isTrue);
      expect(isEmojiOnlyMessage('👍🏽'), isTrue);
      expect(isEmojiOnlyMessage('🇵🇭'), isTrue);
      expect(isEmojiOnlyMessage('❤️ 🎉'), isTrue);
      expect(isEmojiOnlyMessage('👨‍👩‍👧'), isTrue);
      expect(isEmojiOnlyMessage('😀😀😀'), isTrue);
    });

    test('is false for text, digits, and more than three emoji', () {
      expect(isEmojiOnlyMessage(''), isFalse);
      expect(isEmojiOnlyMessage('hi'), isFalse);
      expect(isEmojiOnlyMessage('123'), isFalse);
      expect(isEmojiOnlyMessage('ok 👍'), isFalse);
      expect(isEmojiOnlyMessage(':)'), isFalse);
      expect(isEmojiOnlyMessage('😀😀😀😀'), isFalse);
    });

    test('every emoji in the built-in picker counts as an emoji', () {
      for (final category in emojiCategories) {
        for (final emoji in category.emojis) {
          expect(isEmojiOnlyMessage(emoji), isTrue, reason: emoji);
        }
      }
    });
  });

  group('event chat', () {
    testWidgets('the details sheet has a chat button showing the message count', (tester) async {
      await pumpSignedIn(tester);
      await openMayorMeetingDetails(tester);

      expect(find.byKey(const Key('event-chat-button')), findsOneWidget);
      expect(find.byKey(const Key('event-chat-count')), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('can read the chat and send a message and a thumbs up', (tester) async {
      await pumpSignedIn(tester);
      await openMayorMeetingDetails(tester);
      await tester.tap(find.byKey(const Key('event-chat-button')));
      await tester.pumpAndSettle();

      expect(find.text('Event chat'), findsOneWidget);
      expect(find.text('Please be on time, everyone!'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);

      // With nothing typed the send slot is a thumbs up; typing swaps in Send.
      expect(find.byKey(const Key('event-chat-like')), findsOneWidget);
      expect(find.byKey(const Key('event-chat-send')), findsNothing);
      await tester.enterText(find.byKey(const Key('event-chat-input')), '  Hello team  ');
      await tester.pump();
      expect(find.byKey(const Key('event-chat-send')), findsOneWidget);

      await tester.tap(find.byKey(const Key('event-chat-send')));
      await tester.pumpAndSettle();
      expect(find.text('Hello team'), findsOneWidget);
      expect(find.byKey(const Key('event-chat-message-comment-local-1')), findsOneWidget);
      // The field clears after sending, bringing the thumbs up back.
      expect(find.byKey(const Key('event-chat-like')), findsOneWidget);

      await tester.tap(find.byKey(const Key('event-chat-like')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('event-chat-message-comment-local-2')),
          matching: find.text('👍'),
        ),
        findsOneWidget,
      );

      // Back on the details sheet, the badge counts the new messages.
      await tester.tap(find.byKey(const Key('event-chat-back')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('event-chat-count'))).data,
        '3',
      );
    });

    testWidgets('the emoji panel inserts emoji into the message', (tester) async {
      await pumpSignedIn(tester);
      await openMayorMeetingDetails(tester);
      await tester.tap(find.byKey(const Key('event-chat-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('event-chat-input')), 'Great job');
      await tester.pump();
      await tester.tap(find.byKey(const Key('event-chat-emoji-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-chat-emoji-panel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('event-chat-emoji-category-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-chat-emoji-🔥')));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byKey(const Key('event-chat-input'))).controller!.text,
        'Great job🔥',
      );

      await tester.tap(find.byKey(const Key('event-chat-send')));
      await tester.pumpAndSettle();
      expect(find.text('Great job🔥'), findsOneWidget);

      // Toggling back to the keyboard closes the panel.
      await tester.tap(find.byKey(const Key('event-chat-emoji-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-chat-emoji-panel')), findsNothing);
    });

    testWidgets('deleting your own message leaves a "You deleted a message" trace', (tester) async {
      // lgu_member, not the event's creator: no moderation rights here.
      await pumpSignedIn(tester, role: 'lgu_member');
      await openMayorMeetingDetails(tester);
      await tester.tap(find.byKey(const Key('event-chat-button')));
      await tester.pumpAndSettle();

      // Someone else's message: copy only — no edit, no delete.
      await tester.longPress(find.text('Please be on time, everyone!'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-chat-copy')), findsOneWidget);
      expect(find.byKey(const Key('event-chat-edit')), findsNothing);
      expect(find.byKey(const Key('event-chat-delete')), findsNothing);
      await tester.tapAt(const Offset(180, 100));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('event-chat-input')), 'Typo mesage');
      await tester.pump();
      await tester.tap(find.byKey(const Key('event-chat-send')));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Typo mesage'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-chat-delete')));
      await tester.pumpAndSettle();

      // Asks first; Cancel keeps the message.
      expect(find.text('Delete this message?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Typo mesage'), findsOneWidget);

      await tester.longPress(find.text('Typo mesage'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-chat-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-chat-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Typo mesage'), findsNothing);
      expect(find.text('You deleted a message'), findsOneWidget);
      expect(find.byKey(const Key('event-chat-deleted-comment-local-1')), findsOneWidget);
      expect(find.text('Message deleted.'), findsOneWidget);

      // The trace itself has no actions.
      await tester.longPress(find.text('You deleted a message'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-chat-copy')), findsNothing);

      // Deleted messages don't count toward the chat button's badge.
      await tester.tap(find.byKey(const Key('event-chat-back')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('event-chat-count'))).data, '1');
    });

    testWidgets('other people see who deleted a message, or that a moderator removed it', (tester) async {
      final now = DateTime.now().toUtc();
      final event = (await MemoryEventRepository.seeded().getEventById('seed-mayor-meeting'))!;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EventChatPage(
            event: event,
            repository: _FakeChatRepository([
              // Newest first, like watchEventComments.
              EventComment(
                id: 'by-moderator',
                eventId: event.id,
                userId: 'liza-1',
                body: '',
                createdAt: now,
                authorName: 'Liza Santos',
                deletedAt: now,
                deletedBy: 'mayor-1',
              ),
              EventComment(
                id: 'by-author',
                eventId: event.id,
                userId: 'mayor-1',
                body: '',
                createdAt: now.subtract(const Duration(minutes: 10)),
                authorName: 'Juan Dela Cruz',
                deletedAt: now,
                deletedBy: 'mayor-1',
              ),
            ]),
            currentUserId: 'viewer-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Juan Dela Cruz deleted a message'), findsOneWidget);
      expect(find.text('This message was removed by a moderator'), findsOneWidget);
    });

    testWidgets('a superadmin can remove anyone\'s message, leaving a trace', (tester) async {
      await pumpSignedIn(tester, role: 'superadmin');
      await openMayorMeetingDetails(tester);
      await tester.tap(find.byKey(const Key('event-chat-button')));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Please be on time, everyone!'));
      await tester.pumpAndSettle();
      // A moderator can remove it but never edit someone else's words.
      expect(find.byKey(const Key('event-chat-edit')), findsNothing);
      await tester.tap(find.byKey(const Key('event-chat-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-chat-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Please be on time, everyone!'), findsNothing);
      expect(find.text('You removed this message'), findsOneWidget);
      expect(find.byKey(const Key('event-chat-empty')), findsNothing);
    });

    testWidgets('you can edit your own message, and it shows as Edited', (tester) async {
      await pumpSignedIn(tester, role: 'lgu_member');
      await openMayorMeetingDetails(tester);
      await tester.tap(find.byKey(const Key('event-chat-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('event-chat-input')), 'See you at 9');
      await tester.pump();
      await tester.tap(find.byKey(const Key('event-chat-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Edited'), findsNothing);

      await tester.longPress(find.text('See you at 9'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-chat-edit')));
      await tester.pumpAndSettle();

      // Edit mode: banner, the text loaded in the field, a save button
      // instead of send/thumbs up.
      expect(find.byKey(const Key('event-chat-editing-banner')), findsOneWidget);
      expect(find.text('Editing message'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('event-chat-input'))).controller!.text,
        'See you at 9',
      );
      expect(find.byKey(const Key('event-chat-save-edit')), findsOneWidget);
      expect(find.byKey(const Key('event-chat-like')), findsNothing);

      await tester.enterText(find.byKey(const Key('event-chat-input')), 'See you at 10 instead');
      await tester.pump();
      await tester.tap(find.byKey(const Key('event-chat-save-edit')));
      await tester.pumpAndSettle();

      expect(find.text('See you at 9'), findsNothing);
      expect(find.text('See you at 10 instead'), findsOneWidget);
      expect(find.textContaining('Edited · '), findsOneWidget);
      // Back to normal: no banner, empty field, thumbs up again — and the
      // edit didn't post a second message.
      expect(find.byKey(const Key('event-chat-editing-banner')), findsNothing);
      expect(find.byKey(const Key('event-chat-like')), findsOneWidget);
      expect(find.byKey(const Key('event-chat-message-comment-local-2')), findsNothing);
    });

    testWidgets('cancelling an edit leaves the message unchanged', (tester) async {
      await pumpSignedIn(tester, role: 'lgu_member');
      await openMayorMeetingDetails(tester);
      await tester.tap(find.byKey(const Key('event-chat-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('event-chat-input')), 'Original text');
      await tester.pump();
      await tester.tap(find.byKey(const Key('event-chat-send')));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Original text'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-chat-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('event-chat-input')), 'Changed my mind');
      await tester.pump();

      await tester.tap(find.byKey(const Key('event-chat-cancel-edit')));
      await tester.pumpAndSettle();

      expect(find.text('Original text'), findsOneWidget);
      expect(find.text('Changed my mind'), findsNothing);
      expect(find.textContaining('Edited'), findsNothing);
      expect(find.byKey(const Key('event-chat-editing-banner')), findsNothing);
    });

    testWidgets('an emptied edit cannot be saved', (tester) async {
      await pumpSignedIn(tester, role: 'lgu_member');
      await openMayorMeetingDetails(tester);
      await tester.tap(find.byKey(const Key('event-chat-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('event-chat-input')), 'Keep me');
      await tester.pump();
      await tester.tap(find.byKey(const Key('event-chat-send')));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Keep me'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-chat-edit')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('event-chat-input')), '   ');
      await tester.pump();
      final save = tester.widget<IconButton>(find.byKey(const Key('event-chat-save-edit')));
      expect(save.onPressed, isNull);
    });

    testWidgets('personal events have no chat button', (tester) async {
      final repo = MemoryEventRepository.seeded();
      final now = DateTime.now();
      await repo.addEvent(BarangayEvent(
        id: 'personal-today',
        title: 'My Dentist Visit',
        location: 'Clinic',
        startTime: DateTime(now.year, now.month, now.day, 14),
        endTime: DateTime(now.year, now.month, now.day, 15),
        description: '',
        createdAt: now,
        createdById: 'mock-user-id',
        eventType: EventType.personal,
      ));
      await pumpSignedIn(tester, repository: repo);

      await tester.tap(find.text(now.day.toString()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Dentist Visit'));
      await tester.pumpAndSettle();

      expect(find.text('Event Details'), findsOneWidget);
      expect(find.byKey(const Key('event-chat-button')), findsNothing);
    });
  });
  group('chat button shape', () {
    testWidgets('the chat button is a circle with a round speech bubble', (tester) async {
      await pumpSignedIn(tester);
      await openMayorMeetingDetails(tester);

      final button = tester.widget<FloatingActionButton>(find.byKey(const Key('event-chat-button')));
      expect(button.shape, isA<CircleBorder>());
      expect(
        find.descendant(
          of: find.byKey(const Key('event-chat-button')),
          matching: find.byWidgetPredicate((w) => w is FaIcon && w.icon == FontAwesomeIcons.solidComment.data),
        ),
        findsOneWidget,
      );
    });
  });

  group('chat indicator on event cards', () {
    testWidgets('shows the message count, highlighted while unread, and opens the chat', (tester) async {
      await pumpSignedIn(tester, role: 'lgu_member');

      // Today's seeded meeting has one message from someone else. Checked
      // on today's day page — the main tab's floating tab bar would cover
      // the card at this small test screen size.
      const indicator = Key('event-chat-indicator-seed-mayor-meeting');
      const unreadDot = Key('event-chat-indicator-unread-seed-mayor-meeting');
      await tester.tap(find.text(DateTime.now().day.toString()));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(indicator), matching: find.text('1')), findsOneWidget);
      expect(find.byKey(unreadDot), findsOneWidget);

      // Tapping the pill goes straight to that event's chat.
      await tester.tap(find.byKey(indicator));
      await tester.pumpAndSettle();
      expect(find.text('Event chat'), findsOneWidget);
      expect(find.text('Please be on time, everyone!'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('event-chat-input')), 'On my way');
      await tester.pump();
      await tester.tap(find.byKey(const Key('event-chat-send')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('event-chat-back')));
      await tester.pumpAndSettle();

      // Read now, and counting the new message.
      expect(find.byKey(unreadDot), findsNothing);
      expect(find.descendant(of: find.byKey(indicator), matching: find.text('2')), findsOneWidget);
    });

    testWidgets('events without messages, and personal events, show no indicator', (tester) async {
      final repo = MemoryEventRepository.seeded();
      final now = DateTime.now();
      await repo.addEvent(BarangayEvent(
        id: 'personal-today',
        title: 'My Dentist Visit',
        location: 'Clinic',
        startTime: DateTime(now.year, now.month, now.day, 14),
        endTime: DateTime(now.year, now.month, now.day, 15),
        description: '',
        createdAt: now,
        createdById: 'mock-user-id',
        eventType: EventType.personal,
      ));
      // Even a personal event that somehow has a message gets no pill.
      await repo.addEventComment('personal-today', 'note to self');
      await pumpSignedIn(tester, repository: repo);

      await tester.tap(find.text(now.day.toString()));
      await tester.pumpAndSettle();
      expect(find.text('My Dentist Visit'), findsOneWidget);
      expect(find.byKey(const Key('event-chat-indicator-personal-today')), findsNothing);
      expect(find.byKey(const Key('event-chat-indicator-seed-mayor-meeting')), findsOneWidget);
    });

    testWidgets('a message from someone else lights the indicator up live', (tester) async {
      final repo = MemoryEventRepository.seeded();
      await pumpSignedIn(tester, role: 'lgu_member', repository: repo);
      const unreadDot = Key('event-chat-indicator-unread-seed-mayor-meeting');

      // Read the chat first, so nothing is unread.
      await openMayorMeetingDetails(tester);
      await tester.tap(find.byKey(const Key('event-chat-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-chat-back')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 60));
      await tester.pumpAndSettle();
      expect(find.byKey(unreadDot), findsNothing);

      // Some time later (a fresh timestamp after the read mark), a new
      // message arrives through the realtime activity stream.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await repo.addEventCommentAs('seed-mayor-meeting', 'Agenda attached', userId: 'mayor-1');
      await tester.pumpAndSettle();
      expect(find.byKey(unreadDot), findsOneWidget);
    });
  });

  group('chat notifications', () {
    testWidgets('a chat push in the foreground shows an in-app toast that opens the chat', (tester) async {
      final push = _CapturingPushService();
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(role: 'lgu_member'),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
          pushNotificationServiceFactory: () async => push,
        ),
      );
      await tester.pumpAndSettle();

      push.onChatMessage!(const ChatPushMessage(
        eventId: 'seed-mayor-meeting',
        authorName: 'Juan Dela Cruz',
        preview: 'Agenda attached',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('new-event-notice-chat')), findsOneWidget);
      expect(find.text('New message · Mayor Staff Meeting'), findsOneWidget);
      expect(find.text('Juan Dela Cruz: Agenda attached'), findsOneWidget);

      await tester.tap(find.byKey(const Key('new-event-notice-chat')));
      await tester.pumpAndSettle();
      expect(find.text('Event chat'), findsOneWidget);
      expect(find.text('Please be on time, everyone!'), findsOneWidget);

      // While that chat is open, the app tells the push service to skip
      // pushes for it (no toast, no system notification) — but not others.
      expect(push.isChatOpen!('seed-mayor-meeting'), isTrue);
      expect(push.isChatOpen!('seed-assembly'), isFalse);

      await tester.tap(find.byKey(const Key('event-chat-back')));
      await tester.pumpAndSettle();
      expect(push.isChatOpen!('seed-mayor-meeting'), isFalse);
    });

    testWidgets('tapping a chat notification opens that event\'s chat', (tester) async {
      final push = _CapturingPushService(tappedChatEventId: 'seed-mayor-meeting');
      await tester.pumpWidget(
        BarangayCalendarApp(
          authServiceFactory: () async => MemoryAuthService.signedIn(role: 'lgu_member'),
          eventRepositoryFactory: () async => MemoryEventRepository.seeded(),
          pushNotificationServiceFactory: () async => push,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Event chat'), findsOneWidget);
      expect(find.text('Please be on time, everyone!'), findsOneWidget);
    });
  });

  group('EventChatActivity', () {
    test('your own latest message is never unread, and seen state survives a restart', () async {
      final repo = MemoryEventRepository.seeded();
      final activity = EventChatActivity(repository: repo, currentUserId: 'mock-user-id');
      await activity.start();
      expect(activity.countFor('seed-mayor-meeting'), 1);
      expect(activity.hasUnread('seed-mayor-meeting'), isTrue);

      // The mock user's own reply makes theirs the latest message.
      await repo.addEventComment('seed-mayor-meeting', 'Noted');
      await activity.refresh();
      expect(activity.countFor('seed-mayor-meeting'), 2);
      expect(activity.hasUnread('seed-mayor-meeting'), isFalse);

      await repo.addEventCommentAs('seed-mayor-meeting', 'Thanks!', userId: 'mayor-1');
      await activity.refresh();
      expect(activity.hasUnread('seed-mayor-meeting'), isTrue);
      activity.markSeen('seed-mayor-meeting');
      expect(activity.hasUnread('seed-mayor-meeting'), isFalse);
      await Future<void>.delayed(Duration.zero);
      activity.dispose();

      final reopened = EventChatActivity(repository: repo, currentUserId: 'mock-user-id');
      await reopened.start();
      expect(reopened.hasUnread('seed-mayor-meeting'), isFalse);
      reopened.dispose();
    });
  });

}

/// Serves a fixed chat for [EventChatPage] tests that need messages the
/// in-memory repo can't produce (e.g. one its author deleted themselves).
/// Anything else the page might call is unsupported.
class _FakeChatRepository implements EventRepository {
  _FakeChatRepository(this.comments);

  final List<EventComment> comments;

  @override
  Stream<List<EventComment>> watchEventComments(String eventId) => Stream.value(comments);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the chat callbacks the app registers, so a test can deliver a
/// chat push by hand — and optionally reports a tapped chat notification
/// right away, like a cold start from one.
class _CapturingPushService implements PushNotificationService {
  _CapturingPushService({this.tappedChatEventId});

  final String? tappedChatEventId;
  void Function(ChatPushMessage message)? onChatMessage;
  bool Function(String eventId)? isChatOpen;

  @override
  Future<void> initialize({
    void Function()? onAppUpdateAvailable,
    void Function(String eventId)? onEventReminder,
    void Function(String eventId)? onNotificationTapped,
    void Function(ChatPushMessage message)? onChatMessage,
    void Function(String eventId)? onChatNotificationTapped,
    bool Function(String eventId)? isChatOpen,
  }) async {
    this.onChatMessage = onChatMessage;
    this.isChatOpen = isChatOpen;
    final tapped = tappedChatEventId;
    if (tapped != null) onChatNotificationTapped?.call(tapped);
  }

  @override
  Future<void> syncTopics(List<String> groupIds) async {}

  @override
  Future<void> syncUserTopic(String? userId) async {}
}
