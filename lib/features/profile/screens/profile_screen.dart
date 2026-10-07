import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = AuthService.currentUser?.id;
      if (userId != null) {
        final data = await SupabaseService.getProfile(userId);
        setState(() => _profile = data);
      } else {
        setState(() => _profile = {'full_name': 'Guest'});
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?'),
        content: const Text('You will be signed out of MEDMATE.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await AuthService.signOut();
      } catch (e) {
        debugPrint('Sign out exception (handled): $e');
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out successfully. You are now in Guest mode.'),
          backgroundColor: AppColors.secondary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile?['full_name'] as String?) ?? 'User';
    final email = AuthService.currentUser?.email ?? '';
    final dob = _profile?['date_of_birth'] != null
        ? DateFormat('d MMM yyyy')
            .format(DateTime.parse(_profile!['date_of_birth']))
        : null;
    final blood = _profile?['blood_group'] as String?;
    final phone = _profile?['phone'] as String?;
    final gender = _profile?['gender'] as String?;
    final allergies =
        (_profile?['allergies'] as List?)?.cast<String>() ?? [];
    final emergencyName =
        _profile?['emergency_contact_name'] as String?;
    final emergencyPhone =
        _profile?['emergency_contact_phone'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          color: Colors.white),
                      onPressed: () => context.go('/profile/edit'),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Health ID card
                      if (blood != null || dob != null)
                        _healthCard(blood, dob, gender),
                      const SizedBox(height: 16),

                      // Personal info
                      _sectionCard('Personal Information', [
                        _infoRow(Icons.person_outline_rounded, 'Name', name),
                        if (phone != null)
                          _infoRow(Icons.phone_outlined, 'Phone', phone),
                        if (dob != null)
                          _infoRow(Icons.cake_outlined, 'Date of Birth', dob),
                        if (gender != null)
                          _infoRow(Icons.wc_outlined, 'Gender',
                              _capitalize(gender)),
                        if (blood != null)
                          _infoRow(
                              Icons.bloodtype_outlined, 'Blood Group', blood),
                      ]),
                      const SizedBox(height: 14),

                      // Allergies
                      if (allergies.isNotEmpty) ...[
                        _sectionCard('Allergies & Medical Conditions', [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allergies
                                .map((a) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.errorSurface,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.error
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        a,
                                        style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ]),
                        const SizedBox(height: 14),
                      ],

                      // Emergency Contact
                      if (emergencyName != null || emergencyPhone != null)
                        _sectionCard('Emergency Contact', [
                          if (emergencyName != null)
                            _infoRow(Icons.person_outline_rounded,
                                'Contact Person', emergencyName),
                          if (emergencyPhone != null)
                            _infoRow(Icons.phone_outlined,
                                'Emergency Phone', emergencyPhone),
                        ]),
                      const SizedBox(height: 14),

                      // Quick links
                      _sectionCard('Health Tools & Records', [
                        _linkRow(Icons.history_rounded, 'Dose History',
                            () => context.go('/history')),
                        _linkRow(Icons.vaccines_outlined, 'Vaccinations',
                            () => context.go('/vaccinations')),
                        _linkRow(Icons.favorite_rounded, 'Health Vitals',
                            () => context.go('/vitals')),
                        _linkRow(Icons.family_restroom_rounded,
                            'Family & Caregivers',
                            () => context.go('/family')),
                        _linkRow(Icons.search_rounded, 'Medicine Search',
                            () => context.go('/search')),
                      ]),
                      const SizedBox(height: 20),

                      // Sign in or Sign out button
                      if (AuthService.currentUser == null)
                        ElevatedButton.icon(
                          onPressed: () => context.go('/login'),
                          icon: const Icon(Icons.login_rounded, color: Colors.white),
                          label: const Text(
                            'Sign In or Create Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout_rounded,
                              color: AppColors.error),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.4),
                            ),
                            backgroundColor: AppColors.errorSurface,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'MEDMATE • Smart Medicine Management',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _healthCard(String? blood, String? dob, String? gender) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.15),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: AppColors.error,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Health ID',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (blood != null) _pill('Blood: $blood', AppColors.error),
                  if (gender != null) ...[
                    const SizedBox(width: 6),
                    _pill(_capitalize(gender), AppColors.error),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _sectionCard(String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(
              '$label: ',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _linkRow(IconData icon, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      );

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
