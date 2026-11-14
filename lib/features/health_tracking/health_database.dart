import 'package:supabase_flutter/supabase_flutter.dart';

class HealthDatabase {
  // Use the original MedMate Supabase connection
  static SupabaseClient get client => Supabase.instance.client;

  // Get the currently authenticated MedMate user
  static User? get currentUser => client.auth.currentUser;

  static bool get isSignedIn => currentUser != null;

  // Temporary compatibility with existing tracker screen
  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.user == null) {
      throw Exception('Sign in failed.');
    }
  }

  // Validate health activity values
  static void validateActivity({
    required int waterMl,
    required double sleepHours,
    required int exerciseMinutes,
  }) {
    if (waterMl < 0 ||
        !sleepHours.isFinite ||
        sleepHours < 0 ||
        sleepHours > 24 ||
        exerciseMinutes < 0 ||
        exerciseMinutes > 1440) {
      throw ArgumentError(
        'Invalid health activity values.',
      );
    }
  }

  // Save daily health activity
  static Future<void> saveDailyActivity({
    required int waterMl,
    required double sleepHours,
    required int exerciseMinutes,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'Please log in to your MedMate account.',
      );
    }

    validateActivity(
      waterMl: waterMl,
      sleepHours: sleepHours,
      exerciseMinutes: exerciseMinutes,
    );

    await client.from('daily_health_activities').insert({
      'user_id': user.id,
      'water_ml': waterMl,
      'sleep_hours': sleepHours,
      'exercise_minutes': exerciseMinutes,
    });
  }

  // Retrieve current user's health activities
  static Future<List<Map<String, dynamic>>> getDailyActivities() async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'Please log in to view health activities.',
      );
    }

    final response = await client
        .from('daily_health_activities')
        .select()
        .eq('user_id', user.id)
        .order('recorded_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Edit an existing health activity
  static Future<void> updateDailyActivity({
    required String id,
    required int waterMl,
    required double sleepHours,
    required int exerciseMinutes,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'Please log in before editing.',
      );
    }

    validateActivity(
      waterMl: waterMl,
      sleepHours: sleepHours,
      exerciseMinutes: exerciseMinutes,
    );

    final response = await client
        .from('daily_health_activities')
        .update({
          'water_ml': waterMl,
          'sleep_hours': sleepHours,
          'exercise_minutes': exerciseMinutes,
        })
        .eq('id', id)
        .eq('user_id', user.id)
        .select('id');

    if (response.isEmpty) {
      throw Exception(
        'Activity not found or access denied.',
      );
    }
  }

  // Delete an existing health activity
  static Future<void> deleteDailyActivity({
    required String id,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'Please log in before deleting.',
      );
    }

    final response = await client
        .from('daily_health_activities')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id)
        .select('id');

    if (response.isEmpty) {
      throw Exception(
        'Activity not found or access denied.',
      );
    }
  }

  // Temporary compatibility with existing tracker screen
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
