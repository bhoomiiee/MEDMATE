import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'notification_service.dart';

class FirebaseNotificationService {
  static const String _fcmSendEndpoint = 'https://fcm.googleapis.com/fcm/send';

  /// Send an FCM Push Notification directly to a specific device or topic
  /// Can be used to alert a caregiver's phone when a patient misses a dose.
  static Future<bool> sendPushNotification({
    required String targetTokenOrTopic,
    required String title,
    required String body,
    Map<String, dynamic>? dataPayload,
  }) async {
    final serverKey = AppConstants.fcmServerKey;
    if (serverKey.isEmpty || serverKey.startsWith('YOUR_')) {
      debugPrint('FirebaseNotificationService: FCM Server Key not set in AppConstants. Showing local fallback.');
      // Display locally as fallback
      await NotificationService.showCaregiverAlert(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        patientName: title,
        message: body,
      );
      return false;
    }

    final isTopic = targetTokenOrTopic.startsWith('/topics/');
    final toRecipient = isTopic ? targetTokenOrTopic : targetTokenOrTopic;

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'key=$serverKey',
    };

    final payload = {
      'to': toRecipient,
      'priority': 'high',
      'notification': {
        'title': title,
        'body': body,
        'sound': 'default',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'android_channel_id': AppConstants.caregiverAlertChannelId,
      },
      'data': {
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'title': title,
        'body': body,
        ...?dataPayload,
      },
    };

    try {
      final response = await http.post(
        Uri.parse(_fcmSendEndpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('FirebaseNotificationService: Push notification sent successfully to $targetTokenOrTopic');
        return true;
      } else {
        debugPrint('FirebaseNotificationService: Failed to send FCM. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('FirebaseNotificationService: Exception sending push notification: $e');
      return false;
    }
  }

  /// Send Missed Dose Push Notification to a Caregiver
  static Future<bool> sendCaregiverMissedDosePush({
    required String caregiverFcmToken,
    required String patientName,
    required String medicineName,
    required String scheduledTime,
  }) async {
    return await sendPushNotification(
      targetTokenOrTopic: caregiverFcmToken,
      title: '⚠️ Missed Medication Alert',
      body: '$patientName missed their dose of $medicineName scheduled at $scheduledTime.',
      dataPayload: {
        'type': 'missed_dose',
        'patient_name': patientName,
        'medicine_name': medicineName,
        'scheduled_time': scheduledTime,
      },
    );
  }
}

