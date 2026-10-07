import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();

  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;
  bool _loading = false;
  int _step = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _allergiesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }
      final userId = user.id;

      // Ensure full_name is present to satisfy NOT NULL constraint
      final existingProfile = await SupabaseService.getProfile(userId);
      String fullName = (existingProfile?['full_name'] as String?)?.trim() ?? '';
      if (fullName.isEmpty) {
        final metaName = (user.userMetadata?['full_name'] as String?)?.trim();
        if (metaName != null && metaName.isNotEmpty) {
          fullName = metaName;
        } else {
          fullName = user.email?.split('@').first ?? 'User';
        }
      }

      final allergies = _allergiesCtrl.text.isEmpty
          ? <String>[]
          : _allergiesCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      await SupabaseService.upsertProfile({
        'id': userId,
        'full_name': fullName,
        'phone': _phoneCtrl.text.trim(),
        'date_of_birth': _dob?.toIso8601String().split('T').first,
        'gender': _gender,
        'blood_group': _bloodGroup,
        'allergies': allergies,
        'emergency_contact_name': _emergencyNameCtrl.text.trim(),
        'emergency_contact_phone': _emergencyPhoneCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medication_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('MEDMATE',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Complete your profile',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This helps personalise your medicine care',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  // Progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / 2,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Step ${_step + 1} of 2',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: _step == 0 ? _buildStep1() : _buildStep2(),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _step == 0
                  ? AppButton(
                      label: 'Next',
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          setState(() => _step = 1);
                        }
                      },
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _step = 0),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AppButton(
                            label: 'Save Profile',
                            onPressed: _save,
                            loading: _loading,
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

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Basic Information'),
        const SizedBox(height: 16),
        AppTextField(
          controller: _phoneCtrl,
          label: 'Phone Number',
          hint: '+91 XXXXX XXXXX',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Phone number is required' : null,
        ),
        const SizedBox(height: 16),
        // Date of birth
        GestureDetector(
          onTap: _pickDob,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _dob == null
                        ? 'Date of Birth'
                        : DateFormat('dd MMM yyyy').format(_dob!),
                    style: TextStyle(
                      color: _dob == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Gender
        _buildDropdown(
          label: 'Gender',
          value: _gender,
          items: const ['male', 'female', 'other'],
          displayNames: const {'male': 'Male', 'female': 'Female', 'other': 'Other'},
          icon: Icons.wc_outlined,
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 16),
        // Blood Group
        _buildDropdown(
          label: 'Blood Group',
          value: _bloodGroup,
          items: AppConstants.bloodGroups,
          icon: Icons.bloodtype_outlined,
          onChanged: (v) => setState(() => _bloodGroup = v),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Health & Emergency Info'),
        const SizedBox(height: 6),
        Text('Optional — you can update this later in your profile',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        AppTextField(
          controller: _allergiesCtrl,
          label: 'Allergies',
          hint: 'e.g. Penicillin, Aspirin (comma separated)',
          prefixIcon: Icons.warning_amber_outlined,
        ),
        const SizedBox(height: 20),
        _sectionLabel('Emergency Contact'),
        const SizedBox(height: 16),
        AppTextField(
          controller: _emergencyNameCtrl,
          label: 'Contact Name',
          hint: 'e.g. Family member name',
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _emergencyPhoneCtrl,
          label: 'Contact Phone',
          hint: '+91 XXXXX XXXXX',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    Map<String, String>? displayNames,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(displayNames?[e] ?? e),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
