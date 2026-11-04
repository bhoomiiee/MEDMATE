import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

class EmergencyContactService {
  static const MethodChannel _smsChannel = MethodChannel('com.medmate.medmate/sms');

  /// Request SMS permission from the user so background SMS can be dispatched directly
  static Future<bool> requestSmsPermission() async {
    try {
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        final res = await Permission.sms.request();
        return res.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('EmergencyContactService: Error requesting SMS permission: $e');
      return false;
    }
  }

  /// Sends a direct SMS message without any one-tap dialog or opening the SMS app.
  /// On Android, this uses Android's native SmsManager via MethodChannel.
  static Future<bool> sendDirectSms({
    required String phoneNumber,
    required String message,
  }) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return false;

    // Direct background sending via native SmsManager on Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final hasPermission = await requestSmsPermission();
        if (hasPermission) {
          final bool? sent = await _smsChannel.invokeMethod<bool>('sendDirectSms', {
            'phone': cleaned,
            'message': message,
          });
          debugPrint('EmergencyContactService: Direct background SMS sent to $cleaned: $sent');
          return sent ?? false;
        } else {
          debugPrint('EmergencyContactService: SMS permission not granted by user.');
        }
      } catch (e) {
        debugPrint('EmergencyContactService: Direct SMS failed via MethodChannel: $e');
      }
    }

    // Fallback: If on another platform or native fails, launch SMS URI
    try {
      final uri = Uri(
        scheme: 'sms',
        path: cleaned,
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('EmergencyContactService: Fallback launchUrl failed: $e');
    }

    return false;
  }

  /// Automatically called whenever a medicine or vaccine dose is missed or skipped.
  /// Dispatches the alert DIRECTLY to the emergency contact's registered phone number.
  static Future<bool> notifyMissedDoseDirectly({
    required String medicineName,
    required String scheduledTime,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return false;

    try {
      final profile = await SupabaseService.getProfile(user.id);
      final emergencyPhone = profile?['emergency_contact_phone'] as String?;
      final patientName = profile?['full_name'] as String? ?? 'Your family member';

      if (emergencyPhone == null || emergencyPhone.trim().isEmpty) {
        debugPrint('EmergencyContactService: No emergency contact phone registered in profile.');
        return false;
      }

      final message =
          'MEDMATE EMERGENCY ALERT: $patientName has MISSED/SKIPPED their scheduled dose of $medicineName at $scheduledTime. Please check in with them immediately.';

      debugPrint('EmergencyContactService: Dispatching direct emergency SMS to $emergencyPhone...');
      return await sendDirectSms(
        phoneNumber: emergencyPhone,
        message: message,
      );
    } catch (e) {
      debugPrint('EmergencyContactService: Error notifying emergency contact directly: $e');
      return false;
    }
  }

  /// Sends a direct SMS with custom recipient and medicine info
  static Future<bool> sendMissedDoseSms({
    required String phoneNumber,
    required String medicineName,
    required String scheduledTime,
  }) async {
    final user = AuthService.currentUser;
    String patientName = 'Your family member';
    if (user != null) {
      final profile = await SupabaseService.getProfile(user.id);
      patientName = profile?['full_name'] ?? 'Your family member';
    }
    final message =
        'MEDMATE Alert: $patientName missed/skipped their scheduled dose of $medicineName ($scheduledTime). Please check in.';
    return await sendDirectSms(
      phoneNumber: phoneNumber,
      message: message,
    );
  }

  /// Place a direct phone call to the emergency contact
  static Future<bool> callEmergencyContact(String phoneNumber) async {
    try {
      final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri.parse('tel:$cleaned');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error calling emergency contact: $e');
    }
    return false;
  }
}
