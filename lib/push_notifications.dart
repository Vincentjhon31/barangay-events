import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// One FCM topic every device always listens to; public events are pushed
/// here regardless of who created them.
const String publicEventsTopic = 'public-events';

/// The FCM topic a given group's events are pushed to.
String groupTopic(String groupId) => 'group-$groupId';

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
  Future<void> initialize();

  /// Subscribes to [publicEventsTopic] plus one topic per id in [groupIds],
  /// unsubscribing from any group topics no longer present. Call at sign-in
  /// and whenever the user's group memberships change.
  Future<void> syncTopics(List<String> groupIds);
}

class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool _initialized = false;
  Set<String> _subscribedGroupIds = const {};

  @override
  Future<void> initialize() async {
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

    await _messaging.subscribeToTopic(publicEventsTopic);

    // Background/terminated delivery is handled natively by FCM once the
    // payload has a `notification` block — only the foreground case needs
    // app code, since Android doesn't surface FCM notifications while the
    // app is in front. The subscription is intentionally left unowned: it
    // should live for as long as the process does, same as this service.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'event_updates',
          'Event updates',
          channelDescription: 'New public and group events posted to the barangay calendar.',
          importance: Importance.high,
          priority: Priority.high,
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
}

class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> syncTopics(List<String> groupIds) async {}
}
