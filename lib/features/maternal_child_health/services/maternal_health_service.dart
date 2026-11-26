import 'package:supabase_flutter/supabase_flutter.dart';
import 'maternal_notification_sync.dart';

class MaternalHealthService {
  static SupabaseClient get client => Supabase.instance.client;

  static String get userId {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('Please sign in to your MedMate account.');
    }

    return user.id;
  }

  // ==========================================
  // PREGNANCY PROFILE
  // ==========================================

  static Future<void> savePregnancyProfile({
    required DateTime lastMenstrualPeriod,
    DateTime? expectedDeliveryDate,
    String? notes,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lmp = DateTime(
      lastMenstrualPeriod.year,
      lastMenstrualPeriod.month,
      lastMenstrualPeriod.day,
    );

    if (lmp.isAfter(today)) {
      throw ArgumentError('LMP cannot be a future date.');
    }

    final dueDate =
        expectedDeliveryDate ?? DateTime(lmp.year, lmp.month, lmp.day + 280);

    if (!dueDate.isAfter(lmp)) {
      throw ArgumentError('Invalid expected delivery date.');
    }

    await client.from('maternal_health_profiles').upsert({
      'user_id': userId,
      'last_menstrual_period': lmp.toIso8601String().split('T').first,
      'expected_delivery_date': dueDate.toIso8601String().split('T').first,
      'notes': notes?.trim(),
      'updated_at': now.toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  static Future<Map<String, dynamic>?> getPregnancyProfile() async {
    return await client
        .from('maternal_health_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  // ==========================================
  // MATERNAL HEALTH REMINDERS
  // ==========================================

  static Future<List<Map<String, dynamic>>> getMaternalReminders() async {
    return await client
        .from('maternal_health_reminders')
        .select()
        .eq('user_id', userId);
  }

  // ==========================================
  // SUPPLEMENT REMINDERS
  // ==========================================

  static const String supplementCategory = 'Supplement';

  static void validateSupplementReminder({
    required String title,
    required DateTime remindAt,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError(
        'Please enter a supplement name.',
      );
    }

    if (!remindAt.isAfter(DateTime.now())) {
      throw ArgumentError(
        'Please select a future reminder date and time.',
      );
    }
  }

  // Get saved supplement reminders
  static Future<List<Map<String, dynamic>>> getSupplementReminders() async {
    return await client
        .from('maternal_health_reminders')
        .select()
        .eq('user_id', userId)
        .eq('category', supplementCategory)
        .order('remind_at', ascending: true);
  }

  // Add a supplement reminder
  static Future<void> addSupplementReminder({
    required String title,
    required DateTime remindAt,
    String? notes,
  }) async {
    final currentUserId = userId;

    validateSupplementReminder(
      title: title,
      remindAt: remindAt,
    );

    await client.from('maternal_health_reminders').insert({
      'user_id': currentUserId,
      'title': title.trim(),
      'category': supplementCategory,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'notes': notes?.trim(),
    });
    await MaternalNotificationSync.synchronize();
  }

  // Update an existing supplement reminder
  static Future<void> updateSupplementReminder({
    required String id,
    required String title,
    required DateTime remindAt,
    String? notes,
  }) async {
    final currentUserId = userId;

    validateSupplementReminder(
      title: title,
      remindAt: remindAt,
    );

    final response = await client
        .from('maternal_health_reminders')
        .update({
          'title': title.trim(),
          'remind_at': remindAt.toUtc().toIso8601String(),
          'notes': notes?.trim(),
        })
        .eq('id', id)
        .eq('user_id', currentUserId)
        .eq('category', supplementCategory)
        .select('id');

    if (response.isEmpty) {
      throw Exception(
        'Supplement reminder not found or access denied.',
      );
    }
    await MaternalNotificationSync.synchronize();
  }

  // Delete a supplement reminder
  static Future<void> deleteSupplementReminder(
    String id,
  ) async {
    final currentUserId = userId;

    final response = await client
        .from('maternal_health_reminders')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId)
        .eq('category', supplementCategory)
        .select('id');

    if (response.isEmpty) {
      throw Exception(
        'Supplement reminder not found or access denied.',
      );
    }
    await MaternalNotificationSync.synchronize();
  }

  // ==========================================
  // WOMEN'S WELLNESS REMINDERS
  // ==========================================

  static void validateWellnessReminder({
    required String title,
    required DateTime remindAt,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError(
        'Please enter a reminder title.',
      );
    }

    if (!remindAt.isAfter(DateTime.now())) {
      throw ArgumentError(
        'Please select a future reminder date and time.',
      );
    }
  }

  // Get saved wellness reminders
  static Future<List<Map<String, dynamic>>> getWellnessReminders() async {
    return await client
        .from('womens_wellness_reminders')
        .select()
        .eq('user_id', userId)
        .order('remind_at', ascending: true);
  }

  // Add a wellness reminder
  static Future<void> addWellnessReminder({
    required String title,
    required DateTime remindAt,
    String? notes,
  }) async {
    final currentUserId = userId;

    validateWellnessReminder(
      title: title,
      remindAt: remindAt,
    );

    await client.from('womens_wellness_reminders').insert({
      'user_id': currentUserId,
      'title': title.trim(),
      'remind_at': remindAt.toUtc().toIso8601String(),
      'notes': notes?.trim(),
    });
    await MaternalNotificationSync.synchronize();
  }

  // Update an existing wellness reminder
  static Future<void> updateWellnessReminder({
    required String id,
    required String title,
    required DateTime remindAt,
    String? notes,
  }) async {
    final currentUserId = userId;

    validateWellnessReminder(
      title: title,
      remindAt: remindAt,
    );

    final response = await client
        .from('womens_wellness_reminders')
        .update({
          'title': title.trim(),
          'remind_at': remindAt.toUtc().toIso8601String(),
          'notes': notes?.trim(),
        })
        .eq('id', id)
        .eq('user_id', currentUserId)
        .select('id');

    if (response.isEmpty) {
      throw Exception(
        'Reminder not found or access denied.',
      );
    }
    await MaternalNotificationSync.synchronize();
  }

  // Delete a wellness reminder
  static Future<void> deleteWellnessReminder(
    String id,
  ) async {
    final currentUserId = userId;

    final response = await client
        .from('womens_wellness_reminders')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId)
        .select('id');

    if (response.isEmpty) {
      throw Exception(
        'Reminder not found or access denied.',
      );
    }
    await MaternalNotificationSync.synchronize();
  }

  // ==========================================
  // FAMILY MEMBERS
  // ==========================================

  static Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    return await client
        .from('family_members')
        .select()
        .eq('owner_id', userId)
        .order('full_name');
  }

  // ==========================================
  // CHILD GROWTH RECORDS
  // ==========================================

  static Future<List<Map<String, dynamic>>> getChildProfiles() async {
    return await client
        .from('family_members')
        .select('id, full_name, relation, date_of_birth')
        .eq('owner_id', userId)
        .inFilter('relation', ['Child', 'Grandchild']).order('full_name');
  }

  static Future<void> _verifyChildProfile(
    String childId,
    String currentUserId,
  ) async {
    final child = await client
        .from('family_members')
        .select('id')
        .eq('id', childId)
        .eq('owner_id', currentUserId)
        .inFilter('relation', ['Child', 'Grandchild']).maybeSingle();

    if (child == null) {
      throw Exception('Child profile not found or access denied.');
    }

    if (userId != currentUserId) {
      throw Exception('Your login session has changed.');
    }
  }

  static void validateChildGrowthRecord({
    required DateTime recordedOn,
    double? heightCm,
    double? weightKg,
  }) {
    if (heightCm == null && weightKg == null) {
      throw ArgumentError('Please enter height or weight.');
    }

    if (heightCm != null && (!heightCm.isFinite || heightCm <= 0)) {
      throw ArgumentError('Height must be a valid positive number.');
    }

    if (weightKg != null && (!weightKg.isFinite || weightKg <= 0)) {
      throw ArgumentError('Weight must be a valid positive number.');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final measurementDate = DateTime(
      recordedOn.year,
      recordedOn.month,
      recordedOn.day,
    );

    if (measurementDate.isAfter(today)) {
      throw ArgumentError('Measurement date cannot be in the future.');
    }
  }

  static Future<List<Map<String, dynamic>>> getChildGrowthRecords(
    String childId,
  ) async {
    final currentUserId = userId;

    await _verifyChildProfile(childId, currentUserId);

    return await client
        .from('child_growth_records')
        .select()
        .eq('user_id', currentUserId)
        .eq('child_id', childId)
        .order('recorded_on', ascending: false)
        .order('created_at', ascending: false);
  }

  static Future<void> addChildGrowthRecord({
    required String childId,
    required DateTime recordedOn,
    double? heightCm,
    double? weightKg,
    String? notes,
  }) async {
    final currentUserId = userId;

    validateChildGrowthRecord(
      recordedOn: recordedOn,
      heightCm: heightCm,
      weightKg: weightKg,
    );

    await _verifyChildProfile(childId, currentUserId);

    await client.from('child_growth_records').insert({
      'user_id': currentUserId,
      'child_id': childId,
      'recorded_on': recordedOn.toIso8601String().split('T').first,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'notes': notes?.trim(),
    });
  }

  static Future<void> updateChildGrowthRecord({
    required String id,
    required String childId,
    required DateTime recordedOn,
    double? heightCm,
    double? weightKg,
    String? notes,
  }) async {
    final currentUserId = userId;

    validateChildGrowthRecord(
      recordedOn: recordedOn,
      heightCm: heightCm,
      weightKg: weightKg,
    );

    await _verifyChildProfile(childId, currentUserId);

    final response = await client
        .from('child_growth_records')
        .update({
          'recorded_on': recordedOn.toIso8601String().split('T').first,
          'height_cm': heightCm,
          'weight_kg': weightKg,
          'notes': notes?.trim(),
        })
        .eq('id', id)
        .eq('user_id', currentUserId)
        .eq('child_id', childId)
        .select('id');

    if (response.isEmpty) {
      throw Exception('Growth record not found or access denied.');
    }
  }

  static Future<void> deleteChildGrowthRecord({
    required String id,
    required String childId,
  }) async {
    final currentUserId = userId;

    await _verifyChildProfile(childId, currentUserId);

    final response = await client
        .from('child_growth_records')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId)
        .eq('child_id', childId)
        .select('id');

    if (response.isEmpty) {
      throw Exception('Growth record not found or access denied.');
    }
  }

  // ==========================================

  // CHILD DEVELOPMENT MILESTONES
  // ==========================================

  static void validateChildMilestone({
    required String title,
    DateTime? achievedOn,
    String? notes,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('Please enter a milestone title.');
    }

    if (title.trim().length > 120) {
      throw ArgumentError('Milestone title is too long.');
    }

    if (notes != null && notes.trim().length > 1000) {
      throw ArgumentError('Notes are too long.');
    }

    if (achievedOn != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final date = DateTime(
        achievedOn.year,
        achievedOn.month,
        achievedOn.day,
      );

      if (date.isAfter(today)) {
        throw ArgumentError(
          'Achievement date cannot be in the future.',
        );
      }
    }
  }

  // Retrieve milestones for the selected child
  static Future<List<Map<String, dynamic>>> getChildMilestones(
    String childId,
  ) async {
    final currentUserId = userId;

    await _verifyChildProfile(childId, currentUserId);

    return await client
        .from('child_development_milestones')
        .select()
        .eq('user_id', currentUserId)
        .eq('child_id', childId)
        .order('created_at', ascending: false);
  }

  // Add a new milestone
  static Future<void> addChildMilestone({
    required String childId,
    required String title,
    DateTime? achievedOn,
    String? notes,
  }) async {
    final currentUserId = userId;

    validateChildMilestone(
      title: title,
      achievedOn: achievedOn,
      notes: notes,
    );

    await _verifyChildProfile(childId, currentUserId);

    await client.from('child_development_milestones').insert({
      'user_id': currentUserId,
      'child_id': childId,
      'title': title.trim(),
      'achieved_on': achievedOn?.toIso8601String().split('T').first,
      'notes': notes?.trim(),
    });
  }

  // Update an existing milestone
  static Future<void> updateChildMilestone({
    required String id,
    required String childId,
    required String title,
    DateTime? achievedOn,
    String? notes,
  }) async {
    final currentUserId = userId;

    validateChildMilestone(
      title: title,
      achievedOn: achievedOn,
      notes: notes,
    );

    await _verifyChildProfile(childId, currentUserId);

    final response = await client
        .from('child_development_milestones')
        .update({
          'title': title.trim(),
          'achieved_on': achievedOn?.toIso8601String().split('T').first,
          'notes': notes?.trim(),
        })
        .eq('id', id)
        .eq('user_id', currentUserId)
        .eq('child_id', childId)
        .select('id');

    if (response.isEmpty) {
      throw Exception('Milestone not found or access denied.');
    }
  }

  // Delete an existing milestone
  static Future<void> deleteChildMilestone({
    required String id,
    required String childId,
  }) async {
    final currentUserId = userId;

    await _verifyChildProfile(childId, currentUserId);

    final response = await client
        .from('child_development_milestones')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId)
        .eq('child_id', childId)
        .select('id');

    if (response.isEmpty) {
      throw Exception('Milestone not found or access denied.');
    }
  }
}
