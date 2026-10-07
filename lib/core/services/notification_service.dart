import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../constants/app_constants.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create Android notification channels
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.medicineReminderChannelId,
          'Medicine Reminders',
          description: 'Reminders to take your medicines on time',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.refillReminderChannelId,
          'Refill Reminders',
          description: 'Reminders to refill low medicine stock',
          importance: Importance.defaultImportance,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.caregiverAlertChannelId,
          'Caregiver Alerts',
          description: 'Alerts for caregivers about patient medicines',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.vaccinationReminderChannelId,
          'Vaccination Reminders',
          description: 'Reminders for upcoming vaccinations',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  static void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap / action button press
    debugPrint(
        'Notification response: id=${response.id} payload=${response.payload} '
        'action=${response.actionId}');
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
          alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static AndroidNotificationDetails _androidDetails(
    String channelId, {
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    List<AndroidNotificationAction> actions = const [],
  }) =>
      AndroidNotificationDetails(
        channelId,
        channelId,
        importance: importance,
        priority: priority,
        actions: actions,
      );

  static const DarwinNotificationDetails _iosDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // ── Schedule a one-time medicine reminder ─────────────────────────────────

  static Future<void> scheduleMedicineReminder({
    required int id,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
    required bool withFood,
    String? instructions,
  }) async {
    final body = withFood ? 'Take $dosage with food' : 'Take $dosage';
    final fullBody =
        instructions != null ? '$body\n$instructions' : body;

    final tzScheduled =
        tz.TZDateTime.from(scheduledTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      '💊 Time for $medicineName',
      fullBody,
      tzScheduled,
      NotificationDetails(
        android: _androidDetails(
          AppConstants.medicineReminderChannelId,
          actions: const [
            AndroidNotificationAction('TAKEN', 'Taken ✓',
                showsUserInterface: false),
            AndroidNotificationAction('SKIP', 'Skip',
                showsUserInterface: false),
          ],
        ),
        iOS: _iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'medicine:$id',
    );
  }

  // ── Schedule a daily repeating reminder ──────────────────────────────────

  static Future<void> scheduleDailyReminder({
    required int id,
    required String medicineName,
    required String dosage,
    required int hour,
    required int minute,
    bool withFood = false,
  }) async {
    final body = withFood ? 'Take $dosage with food' : 'Take $dosage';

    await _plugin.zonedSchedule(
      id,
      '💊 Time for $medicineName',
      body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: _androidDetails(
          AppConstants.medicineReminderChannelId,
          actions: const [
            AndroidNotificationAction('TAKEN', 'Taken ✓',
                showsUserInterface: false),
            AndroidNotificationAction('SKIP', 'Skip',
                showsUserInterface: false),
          ],
        ),
        iOS: _iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily:$id',
    );
  }

  // ── Refill reminder ───────────────────────────────────────────────────────

  static Future<void> showRefillReminder({
    required int id,
    required String medicineName,
    required int currentStock,
  }) async {
    await _plugin.show(
      id,
      '🔄 Low Stock: $medicineName',
      'Only $currentStock units remaining. Time to refill!',
      NotificationDetails(
        android: _androidDetails(
          AppConstants.refillReminderChannelId,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: _iosDetails,
      ),
    );
  }

  // ── Caregiver alert ───────────────────────────────────────────────────────

  static Future<void> showCaregiverAlert({
    required int id,
    required String patientName,
    required String message,
  }) async {
    await _plugin.show(
      id,
      '⚠️ Alert: $patientName',
      message,
      NotificationDetails(
        android: _androidDetails(AppConstants.caregiverAlertChannelId),
        iOS: _iosDetails,
      ),
    );
  }

  // ── Vaccination reminder ──────────────────────────────────────────────────

  static Future<void> showVaccinationReminder({
    required int id,
    required String vaccineName,
    required DateTime dueDate,
  }) async {
    await _plugin.show(
      id,
      '💉 Vaccination Due: $vaccineName',
      'Due on ${dueDate.day}/${dueDate.month}/${dueDate.year}',
      NotificationDetails(
        android: _androidDetails(
          AppConstants.vaccinationReminderChannelId,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: _iosDetails,
      ),
    );
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  static Future<void> cancelNotification(int id) =>
      _plugin.cancel(id);

  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Private helpers ───────────────────────────────────────────────────────

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
