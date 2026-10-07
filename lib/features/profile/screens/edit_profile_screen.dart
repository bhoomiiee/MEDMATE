import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();

  String? _gender;
  String? _bloodGroup;
  DateTime? _dob;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return;
      final profile = await SupabaseService.getProfile(userId);
      if (profile != null && mounted) {
        _nameCtrl.text = profile['full_name'] ?? '';
        _phoneCtrl.text = profile['phone'] ?? '';
        _emergencyNameCtrl.text =
            profile['emergency_contact_name'] ?? '';
        _emergencyPhoneCtrl.text =
            profile['emergency_contact_phone'] ?? '';
        final allergies =
            (profile['allergies'] as List?)?.cast<String>() ?? [];
        _allergiesCtrl.text = allergies.join(', ');
        setState(() {
          _gender = profile['gender'];
          _bloodGroup = profile['blood_group'];
          _dob = profile['date_of_birth'] != null
              ? DateTime.parse(profile['date_of_birth'])
              : null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = await AuthGuard.requireUserId(context);
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final allergies = _allergiesCtrl.text.isEmpty
          ? <String>[]
          : _allergiesCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      await SupabaseService.upsertProfile({
        'id': userId,
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty
            ? null : _phoneCtrl.text.trim(),
        'date_of_birth': _dob != null
            ? DateFormat('yyyy-MM-dd').format(_dob!) : null,
        'gender': _gender,
        'blood_group': _bloodGroup,
        'allergies': allergies,
        'emergency_contact_name':
            _emergencyNameCtrl.text.trim().isEmpty
                ? null : _emergencyNameCtrl.text.trim(),
        'emergency_contact_phone':
            _emergencyPhoneCtrl.text.trim().isEmpty
                ? null : _emergencyPhoneCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppColors.secondary,
        ),
      );
      context.go('/profile');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _allergiesCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('Personal Information'),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _nameCtrl,
                      label: 'Full Name *',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _pickDob,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Text(
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _dropdown('Gender', _gender,
                        ['male', 'female', 'other'],
                        {'male': 'Male', 'female': 'Female', 'other': 'Other'},
                        Icons.wc_outlined,
                        (v) => setState(() => _gender = v)),
                    const SizedBox(height: 14),
                    _dropdown('Blood Group', _bloodGroup,
                        AppConstants.bloodGroups, null,
                        Icons.bloodtype_outlined,
                        (v) => setState(() => _bloodGroup = v)),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _allergiesCtrl,
                      label: 'Allergies',
                      hint: 'e.g. Penicillin, Aspirin (comma separated)',
                      prefixIcon: Icons.warning_amber_outlined,
                    ),
                    const SizedBox(height: 24),
                    _section('Emergency Contact'),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _emergencyNameCtrl,
                      label: 'Contact Name',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _emergencyPhoneCtrl,
                      label: 'Contact Phone',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      label: 'Save Changes',
                      onPressed: _save,
                      loading: _saving,
                      icon: Icons.save_rounded,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _section(String title) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Divider(),
        ],
      );

  Widget _dropdown(
    String label,
    String? value,
    List<String> items,
    Map<String, String>? names,
    IconData icon,
    void Function(String?) onChanged,
  ) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
        ),
        items: items
            .map((e) => DropdownMenuItem(
                value: e, child: Text(names?[e] ?? e)))
            .toList(),
        onChanged: onChanged,
      );
}
