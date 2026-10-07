import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../../features/reminders/screens/medicine_swipe_screen.dart';

/// Checks which reminders are due right now (±15 min window)
/// and shows the swipe screen as a full-screen overlay.
class ReminderOverlayService {
  static bool _showing = false;

  /// Call this whenever you want to check for pending reminders.
  /// Pass the root [BuildContext] (e.g. from a Navigator key).
  static Future<void> checkAndShow(BuildContext context) async {
    if (_showing) return;

    // No user logged in — skip
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final pending = await _fetchPendingReminders(userId);
    if (pending.isEmpty) return;
    if (!context.mounted) return;

    _showing = true;
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
        onAction: _handleAction,
        onDone: () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
    _showing = false;
  }

  /// Fetch schedules whose times fall within ±15 minutes of now
  /// and haven't been logged as taken/skipped yet today.
  static Future<List<Map<String, dynamic>>> _fetchPendingReminders(
      String userId) async {
    try {
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day);
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
            // Key: scheduleId_HH:mm
            final dt = DateTime.parse(scheduledAt).toLocal();
            final key =
                '${log['schedule_id']}_${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            loggedScheduleTimePairs.add(key);
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
          final scheduled = DateTime(
            now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]),
          );

          // Within ±15 minute window
          final diff = now.difference(scheduled).inMinutes;
          if (diff < -2 || diff > 15) continue;

          // Already actioned?
          final key =
              '${schedule['id']}_${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
          if (loggedScheduleTimePairs.contains(key)) continue;

          final medicine =
              schedule['user_medicines'] as Map<String, dynamic>?;

          pending.add({
            'id': '${schedule['id']}_$time', // unique per schedule+time
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
      final scheduled = DateTime(
        now.year, now.month, now.day,
        int.parse(timeParts[0]), int.parse(timeParts[1]),
      );

      await SupabaseService.upsertReminderLog({
        'schedule_id': scheduleId,
        'user_id': Supabase.instance.client.auth.currentUser?.id,
        'scheduled_at': scheduled.toIso8601String(),
        'status': status,
        if (status == 'taken')
          'taken_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('ReminderOverlayService _handleAction error: $e');
    }
  }
}
