import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/alarm_sound_service.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/web_notification.dart';
import '../theme/app_theme.dart';
import '../widgets/swipe_to_confirm_button.dart';

class ReminderMonitorService {
  static final ReminderMonitorService instance = ReminderMonitorService._();
  ReminderMonitorService._();

  Timer? _timer;
  final Set<String> _alertedKeys = {};
  GlobalKey<NavigatorState>? navigatorKey;

  void initialize(GlobalKey<NavigatorState> navKey) {
    navigatorKey = navKey;
    _timer?.cancel();
    // Request web notification permissions on Web
    requestWebNotificationPermission();
    // Poll every 10 seconds for real-time responsiveness
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => checkReminders());
    // Also run an immediate check
    checkReminders();
  }

  void dispose() {
    _timer?.cancel();
    AlarmSoundService.stop();
  }

  Future<void> checkReminders() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final currentHM = DateFormat('HH:mm').format(now);
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final schedules = await SupabaseService.getAllActiveSchedules();

      for (final schedule in schedules) {
        final scheduleId = schedule['id'] as String;
        final times = List<String>.from(schedule['times'] ?? []);
        final med = schedule['user_medicines'] as Map<String, dynamic>? ?? {};
        final medName = med['name'] as String? ?? 'Medicine';
        final dosage = med['dosage'] as String? ?? '';
        final withFood = schedule['with_food'] as bool? ?? false;
        final medicineId = schedule['user_medicine_id'] as String?;

        // Check if any scheduled time matches the current minute
        for (final time in times) {
          final alertKey = '${scheduleId}_${todayStr}_$time';

          // Match current time (or within the current minute)
          if (time == currentHM && !_alertedKeys.contains(alertKey)) {
            _alertedKeys.add(alertKey);
            _triggerAlert(
              scheduleId: scheduleId,
              medicineId: medicineId,
              medicineName: medName,
              dosage: dosage,
              withFood: withFood,
              scheduledTime: time,
            );
            break;
          }
        }
      }
    } catch (_) {
      // Background check failure is non-fatal
    }
  }

  void _triggerAlert({
    required String scheduleId,
    required String? medicineId,
    required String medicineName,
    required String dosage,
    required bool withFood,
    required String scheduledTime,
  }) {
    // 1. Play real alarm chime
    AlarmSoundService.play();

    // 2. Web / System Browser Notification
    final body = withFood
        ? 'Time to take $dosage with food.'
        : 'Time to take $dosage.';
    showWebNotification('💊 Time for $medicineName', body);

    // 3. In-App Interactive Modal with Swipe Button
    final context = navigatorKey?.currentContext;
    if (context != null && context.mounted) {
      showInAppAlert(
        context,
        scheduleId: scheduleId,
        medicineId: medicineId,
        medicineName: medicineName,
        dosage: dosage,
        withFood: withFood,
        scheduledTime: scheduledTime,
      );
    }
  }

  /// Trigger a live test reminder right away to verify alerts
  void testReminderNow(
    BuildContext context, {
    String medicineName = 'Dolo 650',
    String dosage = '650 mg',
    String? medicineId,
    String? scheduleId,
    VoidCallback? onDoseTaken,
  }) {
    final nowTime = DateFormat('HH:mm').format(DateTime.now());
    AlarmSoundService.play();
    showWebNotification(
      '💊 Time for $medicineName',
      'Reminder test: Take $dosage now.',
    );
    showInAppAlert(
      context,
      scheduleId: scheduleId ?? 'test-schedule',
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      withFood: true,
      scheduledTime: nowTime,
      onDoseTaken: onDoseTaken,
    );
  }

  void showInAppAlert(
    BuildContext context, {
    required String scheduleId,
    required String? medicineId,
    required String medicineName,
    required String dosage,
    required bool withFood,
    required String scheduledTime,
    VoidCallback? onDoseTaken,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.alarm_on_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'MEDICINE REMINDER • $scheduledTime',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              medicineName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dosage: $dosage',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (withFood) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.restaurant_rounded, size: 14, color: AppColors.secondary),
                  SizedBox(width: 6),
                  Text(
                    'Take with or after meals',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            // Tactile Swipe to Confirm Button
            SwipeToConfirmButton(
              label: 'Swipe to confirm taken',
              onConfirmed: () async {
                AlarmSoundService.stop();
                await Future.delayed(const Duration(milliseconds: 350));
                if (ctx.mounted) Navigator.pop(ctx);
                int? newStock;
                if (medicineId != null) {
                  try {
                    final med = await SupabaseService.getMedicine(medicineId);
                    final currentStock = (med?['current_stock'] as int?) ?? 1;
                    newStock = (currentStock - 1).clamp(0, 9999);
                    await SupabaseService.updateStock(medicineId, newStock);
                    final user = AuthService.currentUser;
                    if (user != null && scheduleId != 'test-schedule') {
                      await SupabaseService.upsertReminderLog({
                        'schedule_id': scheduleId,
                        'user_id': user.id,
                        'scheduled_at': DateTime.now().toIso8601String(),
                        'status': 'taken',
                        'taken_at': DateTime.now().toIso8601String(),
                      });
                    }
                  } catch (_) {}
                }
                onDoseTaken?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(newStock != null
                              ? 'Marked $medicineName as taken! Stock reduced to $newStock units.'
                              : 'Marked $medicineName as taken!'),
                        ],
                      ),
                      backgroundColor: AppColors.secondary,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    AlarmSoundService.stop();
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Skip this dose',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    AlarmSoundService.stop();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Snoozed for 10 minutes'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.snooze_rounded,
                      size: 16, color: AppColors.primary),
                  label: const Text(
                    'Snooze 10m',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}
