import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One FCM topic every device always listens to; public events are pushed
/// here regardless of who created them.
const String publicEventsTopic = 'public-events';

/// The FCM topic a given group's events are pushed to.
String groupTopic(String groupId) => 'group-$groupId';

/// The FCM topic targeted notifications for one specific account go to —
/// used for event reminders (see supabase/functions/send-event-reminders),
/// since those are per-user opt-in and can't ride the broadcast
/// public-events/group topics without notifying people who turned
/// reminders off.
String userTopic(String userId) => 'user-$userId';

/// One FCM topic every device always listens to; a new app release is
/// announced here (sent by the release GitHub Action, not by the app).
const String appUpdatesTopic = 'app-updates';

const AndroidNotificationChannel _eventUpdatesChannel = AndroidNotificationChannel(
  'event_updates',
  'Event updates',
  description: 'New public and group events posted to the barangay calendar.',
  importance: Importance.high,
);

/// Keeps this device's push subscriptions in sync with what the signed-in
/// user can see, and displays incoming notifications.
///
/// [FirebasePushNotificationService] is the real implementation; every other
/// call site (including every existing widget test) gets
/// [NoopPushNotificationService] by default — see `BarangayCalendarApp` in
/// `lib/main.dart` for why the default deliberately points at the no-op
/// rather than the real service.
abstract class PushNotificationService {
  /// Requests notification permission and starts showing incoming pushes.
  /// Safe to call once, after the user is signed in.
  ///
  /// [onAppUpdateAvailable] fires when a push announcing a new app release
  /// arrives while the app is in the foreground, in addition to the system
  /// notification being shown — the caller uses it to refresh its own
  /// in-app "update available" state immediately, rather than only on the
  /// next cold launch.
  ///
  /// [onEventReminder] fires the same way for a `user-<uid>` reminder push
  /// (see send-event-reminders), passing the reminded-about event's id —
  /// the caller uses it to show an in-app toast on top of the system
  /// notification, matching the existing "new event posted" toast.
  ///
  /// [onNotificationTapped] fires with the tapped notification's event id
  /// when the user actually taps a system notification — whether the app
  /// was backgrounded (`onMessageOpenedApp`) or fully cold-started from it
  /// (`getInitialMessage`), unlike [onEventReminder]/[onAppUpdateAvailable]
  /// which only fire for a push arriving while already in the foreground.
  /// The caller uses it to open that event's detail sheet directly.
  Future<void> initialize({
    void Function()? onAppUpdateAvailable,
    void Function(String eventId)? onEventReminder,
    void Function(String eventId)? onNotificationTapped,
  });

  /// Subscribes to [publicEventsTopic] plus one topic per id in [groupIds],
  /// unsubscribing from any group topics no longer present. Call at sign-in
  /// and whenever the user's group memberships change.
  Future<void> syncTopics(List<String> groupIds);

  /// Subscribes this device to [userId]'s personal topic (see [userTopic]),
  /// unsubscribing from any previously-subscribed account's topic first —
  /// matters for a shared/kiosk device where one account signs out and
  /// another signs in, so reminders never leak to the wrong account. Pass
  /// null on sign-out with nobody signed in.
  Future<void> syncUserTopic(String? userId);
}

class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _providedMessaging = messaging,
        _providedLocalNotifications = localNotifications;

  // Deliberately NOT resolved as constructor-parameter defaults: those run
  // the instant this object is constructed, and `main()` constructs this
  // unconditionally on every platform. `FirebaseMessaging.instance` throws
  // immediately if Firebase never initialized (e.g. web/Windows/macOS/Linux,
  // where only Android has a google-services.json), so touching it at
  // construction time crashed the app on start on those platforms even
  // though nothing had called initialize() yet. Resolving lazily here means
  // merely creating this object is always safe.
  final FirebaseMessaging? _providedMessaging;
  final FlutterLocalNotificationsPlugin? _providedLocalNotifications;
  FirebaseMessaging get _messaging => _providedMessaging ?? FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin get _localNotifications =>
      _providedLocalNotifications ?? (_localNotificationsInstance ??= FlutterLocalNotificationsPlugin());
  FlutterLocalNotificationsPlugin? _localNotificationsInstance;

  // Process-wide, not per instance. Firebase's onMessage/onMessageOpenedApp
  // are global streams that outlive any one service object, and the app
  // used to build a new service on every sign-in — each one added another
  // listener, so after a few sign-out/sign-in cycles every incoming push was
  // shown once per listener (reported as the same notification ~7 times).
  // Holding the subscriptions statically, and replacing them on each
  // initialize(), guarantees exactly one listener however many instances
  // exist. main() also shares a single instance now.
  static bool _initialized = false;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;

  static const _topicsResetPrefKey = 'push_topics_reset_v1';
  static const _subscribedUserPrefKey = 'push_subscribed_user_id';

  Set<String> _subscribedGroupIds = const {};
  String? _subscribedUserId;
  void Function()? _onAppUpdateAvailable;
  void Function(String eventId)? _onEventReminder;
  void Function(String eventId)? _onNotificationTapped;

  @override
  Future<void> initialize({
    void Function()? onAppUpdateAvailable,
    void Function(String eventId)? onEventReminder,
    void Function(String eventId)? onNotificationTapped,
  }) async {
    _onAppUpdateAvailable = onAppUpdateAvailable;
    _onEventReminder = onEventReminder;
    _onNotificationTapped = onNotificationTapped;

    // Always (re)attach, replacing whatever listener was there before —
    // see the static fields above. Background/terminated delivery is
    // handled natively by FCM once the payload has a `notification` block;
    // only the foreground case needs app code, since Android doesn't
    // surface FCM notifications while the app is in front.
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    // Tapping a notification while the app is backgrounded (not fully
    // killed) fires this — the payload's `data` survives the tap same as
    // it does in the foreground.
    await _openedAppSubscription?.cancel();
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(settings: initSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_eventUpdatesChannel);

    await _resetStaleTopicsOnce(await SharedPreferences.getInstance());
    await _messaging.subscribeToTopic(publicEventsTopic);
    await _messaging.subscribeToTopic(appUpdatesTopic);

    // A tap that cold-starts the app (process wasn't running at all)
    // doesn't go through onMessageOpenedApp — this is the one-shot way to
    // recover that same tap after initialize() runs.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);
  }

  /// One-time cleanup (per install). Before the fix above, each sign-in's
  /// fresh service never knew the previous account, so a phone that had
  /// been signed into several accounts stayed subscribed to all of their
  /// `user-<uid>` topics — receiving every one of those accounts' reminders:
  /// duplicates at best, someone else's personal reminders at worst. FCM
  /// can't list a device's topics, but deleting the token drops all of
  /// them; the current ones are re-subscribed right after this.
  Future<void> _resetStaleTopicsOnce(SharedPreferences prefs) async {
    if (prefs.getBool(_topicsResetPrefKey) ?? false) return;
    try {
      await _messaging.deleteToken();
      await prefs.remove(_subscribedUserPrefKey);
      await prefs.setBool(_topicsResetPrefKey, true);
    } catch (_) {
      // Offline or similar — try again next launch.
    }
  }

  /// The same logical notification always gets the same id — one event's
  /// reminder, one event's new/updated/cancelled push, one app release —
  /// so a duplicate delivery replaces the notification already showing
  /// instead of stacking a second copy.
  int _notificationIdFor(RemoteMessage message) {
    final data = message.data;
    final eventId = data['eventId'] as String?;
    final key = switch (data['type']) {
      'event_reminder' => 'reminder:$eventId:${data['window']}',
      'app_update' => 'app_update:${data['version']}',
      _ => eventId != null
          ? 'event:$eventId:${data['changeType']}'
          : (message.messageId ?? '${message.hashCode}'),
    };
    return key.hashCode & 0x7fffffff;
  }

  void _handleNotificationTap(RemoteMessage message) {
    final eventId = message.data['eventId'] as String?;
    if (eventId != null) _onNotificationTapped?.call(eventId);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (message.data['type'] == 'app_update') {
      _onAppUpdateAvailable?.call();
    } else if (message.data['type'] == 'event_reminder') {
      final eventId = message.data['eventId'] as String?;
      if (eventId != null) _onEventReminder?.call(eventId);
    }

    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: _notificationIdFor(message),
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'event_updates',
          'Event updates',
          channelDescription: 'New public and group events posted to the barangay calendar.',
          importance: Importance.high,
          priority: Priority.high,
          // A duplicate that replaces an already-showing notification
          // (same id, see _notificationIdFor) updates it silently.
          onlyAlertOnce: true,
        ),
      ),
    );
  }

  @override
  Future<void> syncTopics(List<String> groupIds) async {
    final nextGroupIds = groupIds.toSet();
    final toSubscribe = nextGroupIds.difference(_subscribedGroupIds);
    final toUnsubscribe = _subscribedGroupIds.difference(nextGroupIds);

    await Future.wait([
      for (final groupId in toSubscribe) _messaging.subscribeToTopic(groupTopic(groupId)),
      for (final groupId in toUnsubscribe) _messaging.unsubscribeFromTopic(groupTopic(groupId)),
    ]);

    _subscribedGroupIds = nextGroupIds;
  }

  @override
  Future<void> syncUserTopic(String? userId) async {
    // The previously-subscribed account is remembered across restarts, so
    // switching accounts (or signing out) always drops the old account's
    // topic — not just when it happens within one app session.
    final prefs = await SharedPreferences.getInstance();
    final previous = _subscribedUserId ?? prefs.getString(_subscribedUserPrefKey);
    if (previous != null && previous != userId) {
      await _messaging.unsubscribeFromTopic(userTopic(previous));
    }
    // Subscribed once per process, not skipped just because it was
    // subscribed in an earlier run: re-subscribing is idempotent, and it
    // repairs a subscription lost to a token reset.
    if (userId != null && _subscribedUserId != userId) {
      await _messaging.subscribeToTopic(userTopic(userId));
    }
    _subscribedUserId = userId;
    if (userId == null) {
      await prefs.remove(_subscribedUserPrefKey);
    } else {
      await prefs.setString(_subscribedUserPrefKey, userId);
    }
  }
}

class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Future<void> initialize({
    void Function()? onAppUpdateAvailable,
    void Function(String eventId)? onEventReminder,
    void Function(String eventId)? onNotificationTapped,
  }) async {}

  @override
  Future<void> syncTopics(List<String> groupIds) async {}

  @override
  Future<void> syncUserTopic(String? userId) async {}
}
