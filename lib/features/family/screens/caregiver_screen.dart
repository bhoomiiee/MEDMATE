import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sendgrid_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_exit_button.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _sendingEmail = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendEmailInvitation() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid caregiver email address.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _sendingEmail = true);

    try {
      final user = AuthService.currentUser;
      String patientName = 'Your family member';
      if (user != null) {
        final profile = await SupabaseService.getProfile(user.id);
        patientName = profile?['full_name'] ?? 'Your family member';
      }

      final result = await SendGridService.sendCaregiverInvitation(
        toEmail: email,
        patientName: patientName,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Invitation sent!'),
            backgroundColor: AppColors.secondary,
            duration: const Duration(seconds: 4),
          ),
        );
        _emailCtrl.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Could not send invitation email.'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  Future<void> _sendSmsOrWhatsAppInvite({required bool isWhatsApp}) async {
    final phone = _phoneCtrl.text.trim();
    final user = AuthService.currentUser;
    String patientName = 'Your family member';
    if (user != null) {
      final profile = await SupabaseService.getProfile(user.id);
      patientName = profile?['full_name'] ?? 'Your family member';
    }

    final message =
        'Hi! $patientName has invited you to be their Caregiver on MEDMATE. Download the app to monitor doses and get health alerts: https://medmate.app';

    if (isWhatsApp) {
      final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
      final url = clean.isNotEmpty
          ? 'https://wa.me/$clean?text=${Uri.encodeComponent(message)}'
          : 'https://wa.me/?text=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    } else {
      final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri(
        scheme: 'sms',
        path: clean,
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open SMS messenger.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Caregiver Setup'),
        leading: const AppExitButton(fallbackRoute: '/family'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      color: Colors.white, size: 36),
                  const SizedBox(height: 12),
                  const Text('Family Caregiver',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Connect a trusted person as your caregiver. They will receive notifications for:',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    '💊 Missed medication doses',
                    '📦 Low medicine stock alerts',
                    '💉 Upcoming vaccination reminders',
                    '📋 Important health updates',
                  ].map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(t,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Invite via Email (SendGrid)',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Enter the caregiver\'s email address. They will receive a branded invitation email.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _emailCtrl,
              label: 'Caregiver Email',
              hint: 'caregiver@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Send Email Invitation',
              loading: _sendingEmail,
              onPressed: _sendEmailInvitation,
              icon: Icons.mark_email_read_rounded,
            ),
            const SizedBox(height: 28),

            // Share via WhatsApp / SMS
            Text('Or Invite via Message',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Optionally enter their phone number or directly share an invite message via SMS or WhatsApp.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _phoneCtrl,
              label: 'Caregiver Phone Number (Optional)',
              hint: '+1234567890',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendSmsOrWhatsAppInvite(isWhatsApp: true),
                    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                    label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendSmsOrWhatsAppInvite(isWhatsApp: false),
                    icon: const Icon(Icons.sms_outlined, color: AppColors.primary),
                    label: const Text('SMS Text', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Permissions info
            Text('Caregiver Permissions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...[
              _PermItem(Icons.visibility_outlined, 'View Medicines',
                  'Caregiver can see your medicine list', true),
              _PermItem(Icons.alarm_outlined, 'View Reminders',
                  'Caregiver can see your reminder schedule', true),
              _PermItem(Icons.notifications_outlined, 'Receive Alerts',
                  'Caregiver gets notified on missed doses', true),
              _PermItem(Icons.edit_outlined, 'Edit Medicines',
                  'Caregiver can add or modify medicines', false),
            ].map((p) => _permTile(p)),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.privacy_tip_outlined,
                      color: AppColors.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your health data is only shared with caregivers you explicitly invite and approve.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permTile(_PermItem p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(p.icon,
              color: p.enabled ? AppColors.primary : AppColors.textMuted,
              size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(p.subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Icon(
            p.enabled
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: p.enabled ? AppColors.secondary : AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _PermItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  const _PermItem(this.icon, this.title, this.subtitle, this.enabled);
}
