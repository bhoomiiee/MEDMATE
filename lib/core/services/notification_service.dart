import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../constants/app_constants.dart';
import 'supabase_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Initialize timezones and set to phone's actual local timezone
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String currentTimeZone = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
      debugPrint('NotificationService: Local timezone configured to $currentTimeZone');
    } catch (e) {
      debugPrint('NotificationService: Could not get local timezone, fallback: $e');
      try {
        final offset = DateTime.now().timeZoneOffset;
        final matching = tz.timeZoneDatabase.locations.values.where(
          (loc) => loc.currentTimeZone.offset == offset.inMilliseconds,
        );
        if (matching.isNotEmpty) {
          tz.setLocalLocation(matching.first);
        }
      } catch (_) {}
    }

    // 2. Initialize plugins for Android & iOS
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

    // 3. Create high-priority Android notification channels (especially Alarms)
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // Medicine reminders channel configured with MAX importance and ALARM audio
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          AppConstants.medicineReminderChannelId,
          'Medicine Reminders & Alarms',
          description: 'High-priority alarms and reminders to take your medicines on time',
          importance: Importance.max,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
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
    debugPrint(
        'Notification response: id=${response.id} payload=${response.payload} '
        'action=${response.actionId}');
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      // Also request exact alarms permission on Android 12+ / 13+ / 14+
      try {
        await android.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Exact alarms permission check: $e');
      }
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

  static Future<AndroidScheduleMode> _getScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      try {
        final canExact = await android.canScheduleExactNotifications();
        if (canExact == true) {
          return AndroidScheduleMode.exactAllowWhileIdle;
        }
      } catch (e) {
        debugPrint('canScheduleExactNotifications check: $e');
      }
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static AndroidNotificationDetails _medicineAlarmAndroidDetails({
    List<AndroidNotificationAction> actions = const [],
  }) {
    return AndroidNotificationDetails(
      AppConstants.medicineReminderChannelId,
      'Medicine Reminders & Alarms',
      channelDescription:
          'High-priority alarms and reminders to take your medicines on time',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      playSound: true,
      visibility: NotificationVisibility.public,
      ticker: 'Time for your medicine',
      actions: actions,
    );
  }

  static const DarwinNotificationDetails _iosAlarmDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

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
    final fullBody = instructions != null && instructions.isNotEmpty
        ? '$body\n$instructions'
        : body;

    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);
    final scheduleMode = await _getScheduleMode();
    final safeId = id.abs() & 0x7FFFFFFF;

    await _plugin.zonedSchedule(
      safeId,
      '💊 Time for $medicineName',
      fullBody,
      tzScheduled,
      NotificationDetails(
        android: _medicineAlarmAndroidDetails(
          actions: const [
            AndroidNotificationAction('TAKEN', 'Taken ✓',
                showsUserInterface: false),
            AndroidNotificationAction('SKIP', 'Skip',
                showsUserInterface: false),
          ],
        ),
        iOS: _iosAlarmDetails,
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'medicine:$safeId',
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
    String? instructions,
  }) async {
    final body = withFood ? 'Take $dosage with food' : 'Take $dosage';
    final fullBody = instructions != null && instructions.isNotEmpty
        ? '$body\n$instructions'
        : body;

    final scheduleMode = await _getScheduleMode();
    final safeId = id.abs() & 0x7FFFFFFF;
    final scheduledDate = _nextInstanceOfTime(hour, minute);

    await _plugin.zonedSchedule(
      safeId,
      '💊 Time for $medicineName',
      fullBody,
      scheduledDate,
      NotificationDetails(
        android: _medicineAlarmAndroidDetails(
          actions: const [
            AndroidNotificationAction('TAKEN', 'Taken ✓',
                showsUserInterface: false),
            AndroidNotificationAction('SKIP', 'Skip',
                showsUserInterface: false),
          ],
        ),
        iOS: _iosAlarmDetails,
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily:$safeId',
    );
  }

  // ── Schedule a weekly repeating reminder (Specific Days) ─────────────────

  static Future<void> scheduleWeeklyReminder({
    required int id,
    required String medicineName,
    required String dosage,
    required int dayOfWeek, // 1 (Mon) - 7 (Sun)
    required int hour,
    required int minute,
    bool withFood = false,
    String? instructions,
  }) async {
    final body = withFood ? 'Take $dosage with food' : 'Take $dosage';
    final fullBody = instructions != null && instructions.isNotEmpty
        ? '$body\n$instructions'
        : body;

    final scheduleMode = await _getScheduleMode();
    final safeId = id.abs() & 0x7FFFFFFF;
    final scheduledDate = _nextInstanceOfDayAndTime(dayOfWeek, hour, minute);

    await _plugin.zonedSchedule(
      safeId,
      '💊 Time for $medicineName',
      fullBody,
      scheduledDate,
      NotificationDetails(
        android: _medicineAlarmAndroidDetails(
          actions: const [
            AndroidNotificationAction('TAKEN', 'Taken ✓',
                showsUserInterface: false),
            AndroidNotificationAction('SKIP', 'Skip',
                showsUserInterface: false),
          ],
        ),
        iOS: _iosAlarmDetails,
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly:$safeId',
    );
  }

  // ── Immediate Test Alarm (For verifying sound/vibration on phone) ─────────

  static Future<void> testAlarmNow() async {
    await _plugin.show(
      999999,
      '💊 MEDMATE Alarm Test',
      'If you hear sound and feel vibration, your phone alarms are working perfectly!',
      NotificationDetails(
        android: _medicineAlarmAndroidDetails(),
        iOS: _iosAlarmDetails,
      ),
    );
  }

  // ── Refill reminder ───────────────────────────────────────────────────────

  static Future<void> showRefillReminder({
    required int id,
    required String medicineName,
    required int currentStock,
  }) async {
    final safeId = id.abs() & 0x7FFFFFFF;
    await _plugin.show(
      safeId,
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
    final safeId = id.abs() & 0x7FFFFFFF;
    await _plugin.show(
      safeId,
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
    final safeId = id.abs() & 0x7FFFFFFF;
    await _plugin.show(
      safeId,
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

  static Future<void> scheduleVaccinationReminder({
    required int id,
    required String vaccineName,
    required DateTime dueDate,
    String? patientName,
  }) async {
    final safeId = id.abs() & 0x7FFFFFFF;
    final scheduledDate = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9, // 9:00 AM on the due date
      0,
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final scheduleMode = await _getScheduleMode();
    final message = patientName != null && patientName.isNotEmpty
        ? '$vaccineName is due today for $patientName'
        : 'Time for your $vaccineName vaccination today!';

    await _plugin.zonedSchedule(
      safeId,
      '💉 Vaccination Due: $vaccineName',
      message,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.vaccinationReminderChannelId,
          'Vaccination Reminders',
          channelDescription: 'Reminders for upcoming vaccinations',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Vaccination Due',
        ),
        iOS: _iosAlarmDetails,
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'vaccination:$safeId',
    );
  }

  static Future<void> cancelVaccinationReminder(String vaccinationId) async {
    await cancelNotification((vaccinationId.hashCode ^ 8888) & 0x7FFFFFFF);
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  static Future<void> cancelNotification(int id) =>
      _plugin.cancel(id.abs() & 0x7FFFFFFF);

  static Future<void> cancelAll() => _plugin.cancelAll();

  static Future<void> cancelScheduleNotifications(String scheduleId, [int maxTimes = 10]) async {
    for (int i = 0; i < maxTimes; i++) {
      await cancelNotification((scheduleId.hashCode ^ (i * 1000)) & 0x7FFFFFFF);
      for (int d = 1; d <= 7; d++) {
        await cancelNotification((scheduleId.hashCode ^ (d * 100) ^ (i * 1000)) & 0x7FFFFFFF);
      }
    }
  }

  // ── Sync All Active Schedules from Database into AlarmManager ─────────────

  static Future<void> syncSchedulesFromDatabase() async {
    try {
      final schedules = await SupabaseService.getAllActiveSchedules();
      final dayMap = {
        'Mon': DateTime.monday,
        'Tue': DateTime.tuesday,
        'Wed': DateTime.wednesday,
        'Thu': DateTime.thursday,
        'Fri': DateTime.friday,
        'Sat': DateTime.saturday,
        'Sun': DateTime.sunday,
      };

      for (final schedule in schedules) {
        final med = schedule['user_medicines'] as Map<String, dynamic>? ?? {};
        final medName = med['name'] as String? ?? 'Medicine';
        final dosage = med['dosage'] as String? ?? '';
        final withFood = schedule['with_food'] as bool? ?? false;
        final instructions = schedule['instructions'] as String?;
        final frequency = schedule['frequency'] as String? ?? 'daily';
        final times = List<String>.from(schedule['times'] ?? []);
        final selectedDays = List<String>.from(schedule['days_of_week'] ?? []);
        final scheduleId = schedule['id'] as String;

        for (int i = 0; i < times.length; i++) {
          final parts = times[i].split(':');
          if (parts.length < 2) continue;
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);

          if (frequency == 'daily' ||
              frequency == 'twice_daily' ||
              frequency == 'thrice_daily') {
            final notifId = (scheduleId.hashCode ^ (i * 1000)) & 0x7FFFFFFF;
            await scheduleDailyReminder(
              id: notifId,
              medicineName: medName,
              dosage: dosage,
              hour: hour,
              minute: minute,
              withFood: withFood,
              instructions: instructions,
            );
          } else if (frequency == 'specific_days' && selectedDays.isNotEmpty) {
            for (final dayItem in selectedDays) {
              final parsed = int.tryParse(dayItem.toString());
              final weekday = parsed != null ? (parsed + 1) : (dayMap[dayItem.toString()] ?? DateTime.monday);
              final notifId = (scheduleId.hashCode ^ (weekday * 100) ^ (i * 1000)) & 0x7FFFFFFF;
              await scheduleWeeklyReminder(
                id: notifId,
                medicineName: medName,
                dosage: dosage,
                dayOfWeek: weekday,
                hour: hour,
                minute: minute,
                withFood: withFood,
                instructions: instructions,
              );
            }
          }
        }
      }
      debugPrint('NotificationService: Synced ${schedules.length} active schedules.');
    } catch (e) {
      debugPrint('NotificationService: Error syncing schedules: $e');
    }
  }

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

  static tz.TZDateTime _nextInstanceOfDayAndTime(
      int dayOfWeek, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
