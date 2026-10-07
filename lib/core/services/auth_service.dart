import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  static final _client = SupabaseService.client;

  /// Redirect URL for email confirmation links.
  /// On web: use the current page origin so the link opens in the same browser.
  /// On Android/iOS: use a deep-link scheme.
  static String get _redirectUrl {
    if (kIsWeb) {
      // Will open confirmation link in the same browser tab running the app
      return '${Uri.base.origin}/';
    }
    return 'medmate://callback';
  }

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static User? get currentUser => _client.auth.currentUser;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: _redirectUrl,
    );
    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Ignore if session was already cleared or missing
    }
  }

  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: _redirectUrl,
    );
  }

  static Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: _redirectUrl,
    );
  }

  static Future<Session?> refreshSession() async {
    final response = await _client.auth.refreshSession();
    return response.session;
  }

  static Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  static Future<bool> isProfileComplete() async {
    final userId = currentUser?.id;
    if (userId == null) return false;
    final profile = await SupabaseService.getProfile(userId);
    if (profile == null) return false;
    return profile['date_of_birth'] != null &&
        profile['gender'] != null &&
        profile['phone'] != null;
  }
}
