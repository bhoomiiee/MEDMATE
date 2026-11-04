import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/alarm_sound_service.dart';
import '../services/emergency_contact_service.dart';
import '../services/supabase_service.dart';
import '../../features/reminders/screens/medicine_swipe_screen.dart';

/// Checks which reminders are due right now (at scheduled time, up to +15 min window)
/// and shows the swipe screen as a full-screen overlay.
class ReminderOverlayService {
  static bool _showing = false;
  static final Set<String> _locallyActionedKeys = <String>{};
  static bool _prefsLoaded = false;

  /// Ensure actioned keys for today are loaded from local cache
  static Future<void> _ensurePrefsLoaded() async {
    if (_prefsLoaded) return;
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('actioned_reminders_$todayStr') ?? [];
      _locallyActionedKeys.addAll(cached);
      _prefsLoaded = true;
    } catch (e) {
      debugPrint('ReminderOverlayService: Error loading prefs: $e');
    }
  }

  /// Call this whenever you want to check for pending reminders.
  /// Pass the root [BuildContext] (e.g. from a Navigator key).
  static Future<void> checkAndShow(BuildContext context) async {
    if (_showing) return;

    // No user logged in — skip
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _ensurePrefsLoaded();

    final pending = await _fetchPendingReminders(userId);
    if (pending.isEmpty) return;
    if (!context.mounted) return;

    _showing = true;
    AlarmSoundService.play();
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) => MedicineSwipeScreen(
        pendingReminders: pending,
        onAction: (id, status) async {
          AlarmSoundService.stop();
          await _handleAction(id, status);
        },
        onDone: () {
          AlarmSoundService.stop();
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
    AlarmSoundService.stop();
    _showing = false;
  }

  /// Fetch schedules whose times fall within the due window (scheduled time to +15 min)
  /// and haven't been logged as taken/skipped yet today.
  static Future<List<Map<String, dynamic>>> _fetchPendingReminders(
      String userId) async {
    try {
      await _ensurePrefsLoaded();

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final todayStart = DateTime(now.year, now.month, now.day).toUtc();
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Get all active schedules with medicine info
      final schedules = await SupabaseService.getAllActiveSchedules();

      // Get today's existing logs to avoid re-showing
      final logs = await SupabaseService.getReminderLogs(
        from: todayStart,
        to: todayEnd,
      );
      final loggedScheduleTimePairs = <String>{};
      for (final log in logs) {
        if (log['status'] == 'taken' || log['status'] == 'skipped') {
          final scheduledAt = log['scheduled_at'] as String?;
          if (scheduledAt != null) {
            // Parse UTC timestamp and convert to local time
            final dt = DateTime.parse(scheduledAt).toLocal();
            final timeStr =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            final key = '${log['schedule_id']}_$timeStr';
            loggedScheduleTimePairs.add(key);

            // Also keep in local set
            _locallyActionedKeys.add('${log['schedule_id']}_${todayStr}_$timeStr');
          }
        }
      }

      final pending = <Map<String, dynamic>>[];

      for (final schedule in schedules) {
        final times = List<String>.from(schedule['times'] ?? []);
        final startDate = schedule['start_date'] as String?;
        final endDate = schedule['end_date'] as String?;
        if (startDate == null) continue;
        if (DateTime.parse(startDate).isAfter(now)) continue;
        if (endDate != null &&
            DateTime.parse(endDate)
                .isBefore(now.subtract(const Duration(days: 1)))) {
          continue;
        }

        for (final time in times) {
          final parts = time.split(':');
          if (parts.length < 2) continue;
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final timeFormatted =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

          // Check if already taken or skipped locally today
          final actionedKey =
              '${schedule['id']}_${todayStr}_$timeFormatted';
          if (_locallyActionedKeys.contains(actionedKey)) {
            continue;
          }

          // Check if already logged in Supabase today
          final logKey = '${schedule['id']}_$timeFormatted';
          if (loggedScheduleTimePairs.contains(logKey)) {
            continue;
          }

          final scheduled = DateTime(
            now.year, now.month, now.day,
            hour, minute,
          );

          // Only trigger at or after the scheduled time, up to a 15-minute window
          if (now.isBefore(scheduled)) continue;
          final diff = now.difference(scheduled).inMinutes;
          if (diff > 15) continue;

          final medicine =
              schedule['user_medicines'] as Map<String, dynamic>?;

          pending.add({
            'id': '${schedule['id']}_$timeFormatted', // unique per schedule+time
            'schedule_id': schedule['id'],
            'medicine_name': medicine?['name'] ?? 'Medicine',
            'dosage':
                '${medicine?['dosage'] ?? ''} ${medicine?['unit'] ?? ''}'
                    .trim(),
            'form': medicine?['form'] ?? '',
            'color': medicine?['color'],
            'with_food': schedule['with_food'] ?? false,
            'instructions': schedule['instructions'],
            'scheduled_time': scheduled,
          });
        }
      }

      return pending;
    } catch (e) {
      debugPrint('ReminderOverlayService error: $e');
      return [];
    }
  }

  static Future<void> _handleAction(
      String compositeId, String status) async {
    try {
      // compositeId is "scheduleId_HH:mm"
      final parts = compositeId.split('_');
      if (parts.length < 2) return;
      final scheduleId = parts[0];
      final timePart = parts[1];
      final timeParts = timePart.split(':');
      if (timeParts.length < 2) return;

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final timeFormatted =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      // 1. Immediately mark locally so it NEVER pops up again today on this device
      final actionedKey = '${scheduleId}_${todayStr}_$timeFormatted';
      _locallyActionedKeys.add(actionedKey);

      try {
        final prefs = await SharedPreferences.getInstance();
        final cached =
            prefs.getStringList('actioned_reminders_$todayStr') ?? [];
        if (!cached.contains(actionedKey)) {
          cached.add(actionedKey);
          await prefs.setStringList('actioned_reminders_$todayStr', cached);
        }
      } catch (e) {
        debugPrint('ReminderOverlayService: Error persisting to SharedPreferences: $e');
      }

      // 2. Save to Supabase database (store in UTC for standard timestamptz)
      final scheduled = DateTime(
        now.year, now.month, now.day,
        hour, minute,
      );

      await SupabaseService.upsertReminderLog({
        'schedule_id': scheduleId,
        'user_id': Supabase.instance.client.auth.currentUser?.id,
        'scheduled_at': scheduled.toUtc().toIso8601String(),
        'status': status,
        if (status == 'taken')
          'taken_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 3. If taken, update remaining stock
      if (status == 'taken') {
        try {
          final schedule = await SupabaseService.client
              .from('schedules')
              .select('user_medicine_id')
              .eq('id', scheduleId)
              .maybeSingle();
          final medicineId = schedule?['user_medicine_id'] as String?;
          if (medicineId != null) {
            final med = await SupabaseService.getMedicine(medicineId);
            final currentStock = med?['current_stock'] as int?;
            if (currentStock != null && currentStock > 0) {
              await SupabaseService.updateStock(medicineId, currentStock - 1);
            }
          }
        } catch (e) {
          debugPrint('ReminderOverlayService: Stock update note: $e');
        }
      }

      // 4. If skipped, notify emergency contact & caregivers
      if (status == 'skipped') {
        SupabaseService.notifyCaregiversOfMissedDose(
          medicineName: 'scheduled dose',
          scheduledTime: timeFormatted,
        );
        EmergencyContactService.notifyMissedDoseDirectly(
          medicineName: 'scheduled medication',
          scheduledTime: timeFormatted,
        );
      }
    } catch (e) {
      debugPrint('ReminderOverlayService _handleAction error: $e');
    }
  }
}
