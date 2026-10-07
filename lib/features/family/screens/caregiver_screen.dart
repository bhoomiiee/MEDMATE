import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Caregiver Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/family'),
        ),
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

            Text('Invite a Caregiver',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'The person must already have a MEDMATE account. They will receive an invitation to connect.',
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
              label: 'Send Invitation',
              onPressed: () {
                if (_emailCtrl.text.isEmpty) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Caregiver invitation requires an Edge Function. Configure your Supabase project to enable email-based lookup.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              },
              icon: Icons.send_rounded,
            ),
            const SizedBox(height: 24),

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
