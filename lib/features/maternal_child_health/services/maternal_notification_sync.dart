import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'maternal_notification_service.dart';

class MaternalNotificationSync {
  MaternalNotificationSync._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> _queue = Future<void>.value();

  static Future<void> synchronize() {
    _queue = _queue.then((_) async {
      try {
        await _synchronizeInternal();
      } catch (e) {
        debugPrint(
          'Maternal notification synchronization failed.',
        );
      }
    });

    return _queue;
  }

  static Future<void> _synchronizeInternal() async {
    if (!MaternalNotificationService.isSupported) return;

    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      await MaternalNotificationService.cancelMaternalNotifications();
      return;
    }

    // Remove notifications belonging to previous accounts.
    final pending =
        await MaternalNotificationService.getPendingMaternalNotifications();

    final accountPrefix =
        '${MaternalNotificationService.payloadPrefix}$userId:';

    final hasPreviousAccount = pending.any(
      (item) => !(item.payload?.startsWith(accountPrefix) ?? false),
    );

    if (hasPreviousAccount) {
      await MaternalNotificationService.cancelMaternalNotifications();
    }

    if (_client.auth.currentUser?.id != userId) {
      await MaternalNotificationService.cancelMaternalNotifications();
      return;
    }

    final now = DateTime.now().toUtc();

    final supplements = await _client
        .from('maternal_health_reminders')
        .select('id, remind_at')
        .eq('user_id', userId)
        .eq('category', 'Supplement')
        .gt('remind_at', now.toIso8601String());

    final wellness = await _client
        .from('womens_wellness_reminders')
        .select('id, remind_at')
        .eq('user_id', userId)
        .gt('remind_at', now.toIso8601String());

    if (_client.auth.currentUser?.id != userId) {
      await MaternalNotificationService.cancelMaternalNotifications();
      return;
    }

    final reminders = <String, DateTime>{};

    for (final item in supplements) {
      final date = DateTime.tryParse(
        item['remind_at'].toString(),
      );

      if (date != null && date.isAfter(now)) {
        reminders['supplement:${item['id']}'] = date;
      }
    }

    for (final item in wellness) {
      final date = DateTime.tryParse(
        item['remind_at'].toString(),
      );

      if (date != null && date.isAfter(now)) {
        reminders['wellness:${item['id']}'] = date;
      }
    }

    final entries = reminders.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final desiredPayloads = reminders.keys
        .map(
          (key) => '${MaternalNotificationService.payloadPrefix}$userId:$key',
        )
        .toSet();

    final existing =
        await MaternalNotificationService.getPendingMaternalNotifications();

    final existingIds = <String, int>{};
    final usedIds = <int>{};

    for (final item in existing) {
      if (_client.auth.currentUser?.id != userId) {
        await MaternalNotificationService.cancelMaternalNotifications();
        return;
      }

      final payload = item.payload;

      if (payload == null ||
          !desiredPayloads.contains(payload) ||
          existingIds.containsKey(payload)) {
        await MaternalNotificationService.cancelMaternalNotification(item.id);
      } else {
        existingIds[payload] = item.id;
        usedIds.add(item.id);
      }
    }

    var failed = 0;

    for (final entry in entries) {
      if (_client.auth.currentUser?.id != userId) {
        await MaternalNotificationService.cancelMaternalNotifications();
        return;
      }

      final key = '$userId:${entry.key}';
      final payload = '${MaternalNotificationService.payloadPrefix}$key';

      var notificationId = existingIds[payload] ?? _generateId(key);

      if (!existingIds.containsKey(payload)) {
        while (usedIds.contains(notificationId)) {
          notificationId =
              notificationId == -2147483647 ? -1 : notificationId - 1;
        }
      }

      usedIds.add(notificationId);

      try {
        await MaternalNotificationService.schedule(
          notificationId: notificationId,
          reminderKey: key,
          remindAt: entry.value,
        );
      } catch (_) {
        failed++;
        debugPrint('A maternal reminder could not be scheduled.');
      }

      if (_client.auth.currentUser?.id != userId) {
        await MaternalNotificationService.cancelMaternalNotifications();
        return;
      }
    }

    if (failed > 0) {
      debugPrint('Maternal scheduling completed with failures: $failed');
      return;
    }

    debugPrint(
      'Maternal notification synchronization completed.',
    );
  }

  static int _generateId(String key) {
    int hash = 0;

    for (final unit in key.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7FFFFFFF;
    }

    return hash == 0 ? -1 : -hash;
  }
}
