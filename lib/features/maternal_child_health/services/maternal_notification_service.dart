import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class MaternalNotificationService {
  MaternalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'maternal_health_reminders';

  static const String payloadPrefix = 'medmate_maternal:';

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize() async {
    if (!isSupported) return;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        'Health Reminders',
        description: 'Personal health and wellness reminders',
        importance: Importance.defaultImportance,
      ),
    );
  }

  static Future<List<PendingNotificationRequest>>
      getPendingMaternalNotifications() async {
    if (!isSupported) return [];

    final pending = await _plugin.pendingNotificationRequests();

    return pending
        .where(
          (item) => item.payload?.startsWith(payloadPrefix) ?? false,
        )
        .toList();
  }

  static Future<void> schedule({
    required int notificationId,
    required String reminderKey,
    required DateTime remindAt,
  }) async {
    if (!isSupported) return;

    if (!remindAt.isAfter(DateTime.now())) return;

    if (notificationId >= 0 || notificationId < -2147483648) {
      throw ArgumentError('Invalid maternal notification ID.');
    }

    final pending = await _plugin.pendingNotificationRequests();

    for (final item in pending) {
      if (item.id == notificationId &&
          item.payload != '$payloadPrefix$reminderKey') {
        throw StateError('Notification ID already in use.');
      }
    }

    await _plugin.zonedSchedule(
      notificationId,
      'MedMate Reminder',
      'You have a scheduled health reminder. Open MedMate for details.',
      tz.TZDateTime.from(remindAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Health Reminders',
          channelDescription: 'Personal health and wellness reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '$payloadPrefix$reminderKey',
    );
  }

  static Future<void> cancelMaternalNotification(int id) async {
    if (!isSupported) return;

    final pending = await getPendingMaternalNotifications();

    if (pending.any((item) => item.id == id)) {
      await _plugin.cancel(id);
    }
  }

  static Future<void> cancelMaternalNotifications() async {
    if (!isSupported) return;

    final pending = await getPendingMaternalNotifications();

    for (final item in pending) {
      await _plugin.cancel(item.id);
    }
  }
}
