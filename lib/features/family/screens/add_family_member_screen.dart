import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class AddFamilyMemberScreen extends StatefulWidget {
  const AddFamilyMemberScreen({super.key});

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _relation;
  bool _saving = false;

  final _relations = [
    'Spouse', 'Child', 'Parent', 'Sibling',
    'Grandparent', 'Grandchild', 'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = await AuthGuard.requireUserId(context);
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final phone = _phoneCtrl.text.trim();
      final payload = <String, dynamic>{
        'owner_id': userId,
        'full_name': _nameCtrl.text.trim(),
        'relation': _relation ?? '',
      };
      if (phone.isNotEmpty) {
        payload['phone'] = phone;
      }

      try {
        await SupabaseService.addFamilyMember(payload);
      } catch (e) {
        // If the 'phone' column hasn't been added to family_members yet in the database,
        // retry without the phone field so the member is still saved without blocking the user.
        if (e.toString().toLowerCase().contains('phone') && payload.containsKey('phone')) {
          payload.remove('phone');
          await SupabaseService.addFamilyMember(payload);
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Family member added'),
          backgroundColor: AppColors.secondary,
        ),
      );
      context.go('/family');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Family Member'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/family'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primarySurface,
                  child: const Icon(Icons.person_rounded,
                      size: 44, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),

              // Full Name
              AppTextField(
                controller: _nameCtrl,
                label: 'Full Name *',
                hint: 'e.g. Priya Sharma',
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Relation dropdown
              DropdownButtonFormField<String>(
                value: _relation,
                decoration: InputDecoration(
                  labelText: 'Relation *',
                  prefixIcon: const Icon(Icons.family_restroom_rounded),
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Relation is required' : null,
                items: _relations
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _relation = v),
              ),
              const SizedBox(height: 16),

              // Phone Number
              AppTextField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                hint: 'e.g. +91 98765 43210',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: 36),

              AppButton(
                label: 'Add Family Member',
                onPressed: _save,
                loading: _saving,
                icon: Icons.person_add_rounded,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
