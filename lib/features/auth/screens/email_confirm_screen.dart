import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';

class EmailConfirmScreen extends StatefulWidget {
  final String email;
  const EmailConfirmScreen({super.key, required this.email});

  @override
  State<EmailConfirmScreen> createState() => _EmailConfirmScreenState();
}

class _EmailConfirmScreenState extends State<EmailConfirmScreen> {
  bool _resending = false;
  bool _resent = false;
  bool _checking = false;

  Future<void> _resendEmail() async {
    setState(() { _resending = true; _resent = false; });
    try {
      await AuthService.resendConfirmation(widget.email);
      setState(() => _resent = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not resend. Please try again shortly.')),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _checkConfirmed() async {
    setState(() => _checking = true);
    try {
      // Try signing in to check if email is now confirmed
      final session = await AuthService.refreshSession();
      if (session != null && mounted) {
        context.go('/profile-setup');
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not confirmed yet. Please check your inbox.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              // Icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.mark_email_unread_rounded,
                    size: 52, color: AppColors.primary),
              ),
              const SizedBox(height: 28),
              Text(
                'Check your inbox',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a confirmation link to',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Click the link in the email to verify your account, then come back here.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              // Steps
              _StepCard(
                icon: Icons.inbox_rounded,
                title: 'Open your email app',
                subtitle: 'Look for an email from MEDMATE or Supabase',
              ),
              const SizedBox(height: 10),
              _StepCard(
                icon: Icons.link_rounded,
                title: 'Click the confirmation link',
                subtitle: 'This verifies your email address',
              ),
              const SizedBox(height: 10),
              _StepCard(
                icon: Icons.check_circle_rounded,
                title: 'Come back and tap below',
                subtitle: 'Then complete your profile setup',
                color: AppColors.secondary,
              ),
              const Spacer(),

              if (_resent) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.secondary, size: 16),
                      SizedBox(width: 8),
                      Text('Confirmation email resent!',
                          style: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              AppButton(
                label: "I've confirmed my email",
                onPressed: _checkConfirmed,
                loading: _checking,
                icon: Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive it? ",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  TextButton(
                    onPressed: _resending ? null : _resendEmail,
                    child: _resending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Resend email',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to Sign In',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _StepCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
