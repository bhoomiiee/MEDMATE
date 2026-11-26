import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/web_notification.dart';

class MaternalWebMonitor {
  MaternalWebMonitor._();

  static Timer? _timer;
  static bool _checking = false;
  static String? _activeUserId;

  static final Map<String, DateTime> _delivered = {};

  static SupabaseClient get _client => Supabase.instance.client;

  static void initialize() {
    if (!kIsWeb) return;

    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(checkReminders()),
    );

    unawaited(checkReminders());
  }

  static Future<void> checkReminders() async {
    if (!kIsWeb || _checking) return;

    final userId = _client.auth.currentUser?.id;

    if (_activeUserId != userId) {
      _delivered.clear();
      _activeUserId = userId;
    }

    if (userId == null) return;

    _checking = true;

    try {
      final now = DateTime.now().toUtc();

      _delivered.removeWhere(
        (_, deliveredAt) =>
            now.difference(deliveredAt) > const Duration(minutes: 10),
      );

      final windowStart = now.subtract(
        const Duration(minutes: 2),
      );

      final supplements = await _client
          .from('maternal_health_reminders')
          .select('id, remind_at')
          .eq('user_id', userId)
          .eq('category', 'Supplement')
          .gte('remind_at', windowStart.toIso8601String())
          .lte('remind_at', now.toIso8601String());

      final wellness = await _client
          .from('womens_wellness_reminders')
          .select('id, remind_at')
          .eq('user_id', userId)
          .gte('remind_at', windowStart.toIso8601String())
          .lte('remind_at', now.toIso8601String());

      if (_client.auth.currentUser?.id != userId) {
        return;
      }

      for (final item in supplements) {
        _notify(userId, 'supplement', item);
      }

      for (final item in wellness) {
        _notify(userId, 'wellness', item);
      }
    } catch (_) {
      debugPrint('Maternal browser reminder check failed.');
    } finally {
      _checking = false;
    }
  }

  static void _notify(
    String userId,
    String category,
    Map<String, dynamic> reminder,
  ) {
    if (_client.auth.currentUser?.id != userId) return;

    final key = '$userId:$category:${reminder['id']}:${reminder['remind_at']}';

    if (_delivered.containsKey(key)) return;

    _delivered[key] = DateTime.now().toUtc();

    showWebNotification(
      'MedMate Reminder',
      'You have a scheduled health reminder. '
          'Open MedMate for details.',
    );
  }

  static void dispose() {
    _timer?.cancel();
    _timer = null;
    _delivered.clear();
    _activeUserId = null;
  }
}
