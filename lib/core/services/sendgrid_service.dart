import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';

class SendGridService {
  static const String _sendGridApiUrl = 'https://api.sendgrid.com/v3/mail/send';
  static const String _resendApiUrl = 'https://api.resend.com/emails';

  /// Check if a valid email service API key (Resend or SendGrid) has been configured
  static bool get isConfigured {
    final key = AppConstants.resendApiKey;
    return key.isNotEmpty && !key.startsWith('YOUR_');
  }

  /// Send an email via Resend or SendGrid API.
  /// Automatically detects Resend (`re_...`) or SendGrid (`SG....`).
  /// Returns a map with {'success': bool, 'message': String}
  static Future<Map<String, dynamic>> sendEmail({
    required String toEmail,
    required String subject,
    required String htmlContent,
    String? plainTextContent,
    String? toName,
  }) async {
    final trimmedTo = toEmail.trim();
    if (trimmedTo.isEmpty || !trimmedTo.contains('@')) {
      return {'success': false, 'message': 'Invalid recipient email address.'};
    }

    final apiKey = AppConstants.resendApiKey.isNotEmpty && !AppConstants.resendApiKey.startsWith('YOUR_')
        ? AppConstants.resendApiKey
        : AppConstants.sendGridApiKey;

    if (apiKey.isEmpty || apiKey.startsWith('YOUR_')) {
      debugPrint('EmailService: API key not set in AppConstants. Falling back to mailto.');
      return await _fallbackMailto(
        toEmail: trimmedTo,
        subject: subject,
        body: plainTextContent ?? _stripHtml(htmlContent),
      );
    }

    final isResend = apiKey.startsWith('re_');

    if (isResend) {
      // ── Resend API ──────────────────────────────────────────────────────────
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'from': AppConstants.resendSenderEmail,
        'to': [trimmedTo],
        'subject': subject,
        'html': htmlContent,
        if (plainTextContent != null) 'text': plainTextContent,
      });

      try {
        final response = await http.post(
          Uri.parse(_resendApiUrl),
          headers: headers,
          body: body,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('EmailService: Email sent via Resend to $trimmedTo');
          return {
            'success': true,
            'message': 'Email sent successfully to $trimmedTo',
          };
        } else {
          final errorMsg = 'Resend error (${response.statusCode}): ${response.body}';
          debugPrint('EmailService: $errorMsg');
          return {
            'success': false,
            'message': errorMsg,
          };
        }
      } catch (e) {
        debugPrint('EmailService: Exception sending email via Resend: $e');
        return {
          'success': false,
          'message': 'Network error while sending email: $e',
        };
      }
    } else {
      // ── SendGrid API ────────────────────────────────────────────────────────
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'personalizations': [
          {
            'to': [
              {
                'email': trimmedTo,
                if (toName != null && toName.isNotEmpty) 'name': toName,
              }
            ],
            'subject': subject,
          }
        ],
        'from': {
          'email': AppConstants.sendGridSenderEmail,
          'name': AppConstants.sendGridSenderName,
        },
        'content': [
          if (plainTextContent != null)
            {'type': 'text/plain', 'value': plainTextContent},
          {'type': 'text/html', 'value': htmlContent},
        ],
      });

      try {
        final response = await http.post(
          Uri.parse(_sendGridApiUrl),
          headers: headers,
          body: body,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('EmailService: Email sent via SendGrid to $trimmedTo');
          return {
            'success': true,
            'message': 'Email sent successfully to $trimmedTo',
          };
        } else {
          final errorMsg = 'SendGrid error (${response.statusCode}): ${response.body}';
          debugPrint('EmailService: $errorMsg');
          return {
            'success': false,
            'message': errorMsg,
          };
        }
      } catch (e) {
        debugPrint('EmailService: Exception sending email via SendGrid: $e');
        return {
          'success': false,
          'message': 'Network error while sending email: $e',
        };
      }
    }
  }

  /// Send Caregiver Invitation Email
  static Future<Map<String, dynamic>> sendCaregiverInvitation({
    required String toEmail,
    required String patientName,
    String? inviteCode,
  }) async {
    final subject = '🤝 $patientName invited you to be their Caregiver on MEDMATE';
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #F8FAFC; margin: 0; padding: 24px; color: #1E293B; }
    .card { max-width: 540px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06); border: 1px solid #E2E8F0; }
    .header { background: linear-gradient(135deg, #7C3AED 0%, #3B82F6 100%); padding: 32px 24px; text-align: center; color: white; }
    .header h1 { margin: 0; font-size: 24px; font-weight: 700; }
    .header p { margin: 8px 0 0; opacity: 0.9; font-size: 14px; }
    .content { padding: 32px 24px; line-height: 1.6; }
    .badge { display: inline-block; background: #EDE9FE; color: #6D28D9; padding: 4px 12px; border-radius: 999px; font-size: 12px; font-weight: 600; margin-bottom: 16px; }
    .features { background: #F1F5F9; border-radius: 12px; padding: 16px 20px; margin: 20px 0; }
    .features li { margin-bottom: 8px; font-size: 14px; color: #334155; }
    .btn { display: block; text-align: center; background: #7C3AED; color: #FFFFFF !important; text-decoration: none; padding: 14px 28px; border-radius: 12px; font-weight: 600; font-size: 15px; margin: 24px 0; }
    .code-box { background: #F8FAFC; border: 1px dashed #CBD5E1; border-radius: 8px; text-align: center; padding: 12px; font-mono; font-size: 18px; font-weight: 700; letter-spacing: 2px; color: #0F172A; }
    .footer { text-align: center; font-size: 12px; color: #94A3B8; padding-bottom: 24px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>MEDMATE</h1>
      <p>Smart Medicine & Health Management</p>
    </div>
    <div class="content">
      <div class="badge">Caregiver Invitation</div>
      <h2>Hello!</h2>
      <p><strong>$patientName</strong> has added you as a trusted caregiver on <strong>MEDMATE</strong> to help coordinate their health and medication routine.</p>
      
      <div class="features">
        <strong style="display:block;margin-bottom:8px;color:#0F172A;">As a caregiver, you can:</strong>
        <ul style="padding-left: 20px; margin: 0;">
          <li>Receive instant notifications if doses are missed</li>
          <li>View upcoming medicine schedules and prescriptions</li>
          <li>Get low stock and refill alerts</li>
          <li>Help track vaccinations and vital health indicators</li>
        </ul>
      </div>

      ${inviteCode != null ? '<p>Your invitation code:</p><div class="code-box">$inviteCode</div>' : ''}

      <a href="https://medmate.app" class="btn">Open MEDMATE App</a>

      <p style="font-size: 13px; color: #64748B;">If you do not have the app installed yet, install MEDMATE and log in with this email (<strong>$toEmail</strong>) to accept the connection.</p>
    </div>
    <div class="footer">
      Sent with care by MEDMATE • Your Health Companion
    </div>
  </div>
</body>
</html>
''';

    final plainText = '''
Hello!

$patientName has invited you to be their caregiver on MEDMATE.

As a caregiver, you will receive real-time alerts for missed doses, view medicine schedules, and track health vitals.

Log in to the MEDMATE app with $toEmail to view and accept the invitation.
${inviteCode != null ? "Invite Code: $inviteCode\n" : ""}
Best regards,
The MEDMATE Team
''';

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: html,
      plainTextContent: plainText,
    );
  }

  /// Send Missed Medication Alert Email
  static Future<Map<String, dynamic>> sendMissedDoseAlert({
    required String toEmail,
    required String patientName,
    required String medicineName,
    required String scheduledTime,
    String? dosage,
  }) async {
    final subject = '⚠️ URGENT: $patientName missed dose of $medicineName';
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #FFF1F2; margin: 0; padding: 24px; color: #1E293B; }
    .card { max-width: 520px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 16px rgba(225, 29, 72, 0.12); border: 2px solid #FECDD3; }
    .header { background: #E11D48; padding: 24px; text-align: center; color: white; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 700; }
    .content { padding: 28px 24px; }
    .alert-box { background: #FFF1F2; border-left: 4px solid #E11D48; padding: 16px; border-radius: 8px; margin: 16px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #F1F5F9; font-size: 14px; }
    .footer { text-align: center; font-size: 12px; color: #94A3B8; padding: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>⚠️ Medication Alert</h1>
    </div>
    <div class="content">
      <p style="font-size: 16px; margin-top: 0;"><strong>Caregiver Alert:</strong></p>
      <div class="alert-box">
        <p style="margin: 0; font-size: 15px; color: #9F1239; font-weight: 600;">
          $patientName has missed or skipped a scheduled dose.
        </p>
      </div>
      <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
        <tr><td style="padding: 8px 0; color: #64748B;">Patient:</td><td style="padding: 8px 0; font-weight: 600; text-align: right;">$patientName</td></tr>
        <tr><td style="padding: 8px 0; color: #64748B;">Medicine:</td><td style="padding: 8px 0; font-weight: 600; text-align: right;">$medicineName</td></tr>
        ${dosage != null ? '<tr><td style="padding: 8px 0; color: #64748B;">Dosage:</td><td style="padding: 8px 0; font-weight: 600; text-align: right;">$dosage</td></tr>' : ''}
        <tr><td style="padding: 8px 0; color: #64748B;">Scheduled Time:</td><td style="padding: 8px 0; font-weight: 600; text-align: right; color: #E11D48;">$scheduledTime</td></tr>
      </table>
      <p style="font-size: 14px; color: #475569;">Please reach out to $patientName to ensure they take their medicine safely or address any difficulties.</p>
    </div>
    <div class="footer">
      MEDMATE Automated Health Monitor
    </div>
  </div>
</body>
</html>
''';

    final plainText = '''
MEDMATE EMERGENCY ALERT:
$patientName has missed or skipped their scheduled dose of $medicineName at $scheduledTime.

Please check in with them as soon as possible.
''';

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: html,
      plainTextContent: plainText,
    );
  }

  /// Send Refill Reminder Alert Email
  static Future<Map<String, dynamic>> sendRefillAlert({
    required String toEmail,
    required String patientName,
    required String medicineName,
    required int currentStock,
    required int threshold,
  }) async {
    final subject = '📦 Low Stock Alert: $medicineName is running low ($currentStock left)';
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #FFFBEB; margin: 0; padding: 24px; color: #1E293B; }
    .card { max-width: 520px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 14px rgba(217, 119, 6, 0.1); border: 1px solid #FDE68A; }
    .header { background: #D97706; padding: 24px; text-align: center; color: white; }
    .content { padding: 28px 24px; }
    .footer { text-align: center; font-size: 12px; color: #94A3B8; padding: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1 style="margin:0;font-size:22px;">📦 Refill Reminder</h1>
    </div>
    <div class="content">
      <h2>Time to refill $medicineName</h2>
      <p>This is a reminder that <strong>$patientName</strong>'s stock of <strong>$medicineName</strong> is down to <strong>$currentStock units</strong> (minimum threshold: $threshold).</p>
      <p>Please reorder or visit the pharmacy soon to prevent missing future scheduled doses.</p>
    </div>
    <div class="footer">
      MEDMATE Refill Monitor
    </div>
  </div>
</body>
</html>
''';

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: html,
      plainTextContent: 'Low Stock Alert for $patientName: $medicineName has only $currentStock units remaining. Please refill soon.',
    );
  }

  /// Fallback to device mail client if SendGrid API is not configured yet
  static Future<Map<String, dynamic>> _fallbackMailto({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: toEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return {
          'success': true,
          'message': 'Opened mail app with pre-filled message (configure SendGrid API key for direct background sending).',
        };
      }
    } catch (e) {
      debugPrint('SendGridService: Fallback mailto failed: $e');
    }

    return {
      'success': false,
      'message': 'SendGrid API key not set. Add your SENDGRID_API_KEY in app_constants.dart.',
    };
  }

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

typedef EmailService = SendGridService;

