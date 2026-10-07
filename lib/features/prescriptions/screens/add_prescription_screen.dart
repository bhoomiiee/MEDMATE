import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class AddPrescriptionScreen extends StatefulWidget {
  const AddPrescriptionScreen({super.key});

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _prescribedDate;
  bool _saving = false;

  final List<_PrescriptionItem> _items = [_PrescriptionItem()];

  @override
  void dispose() {
    _doctorCtrl.dispose();
    _hospitalCtrl.dispose();
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _items) item.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _prescribedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _prescribedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = await AuthGuard.requireUserId(context);
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final prescription = await SupabaseService.addPrescription({
        'user_id': userId,
        'doctor_name': _doctorCtrl.text.trim().isEmpty
            ? null
            : _doctorCtrl.text.trim(),
        'hospital_clinic': _hospitalCtrl.text.trim().isEmpty
            ? null
            : _hospitalCtrl.text.trim(),
        'diagnosis': _diagnosisCtrl.text.trim().isEmpty
            ? null
            : _diagnosisCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'prescribed_date': _prescribedDate != null
            ? DateFormat('yyyy-MM-dd').format(_prescribedDate!)
            : null,
        'is_active': true,
      });

      final itemsData = _items
          .where((i) => i.nameCtrl.text.trim().isNotEmpty)
          .map((i) => {
                'prescription_id': prescription['id'],
                'medicine_name': i.nameCtrl.text.trim(),
                'dosage': i.dosageCtrl.text.trim().isEmpty
                    ? null
                    : i.dosageCtrl.text.trim(),
                'frequency': i.frequencyCtrl.text.trim().isEmpty
                    ? null
                    : i.frequencyCtrl.text.trim(),
                'duration': i.durationCtrl.text.trim().isEmpty
                    ? null
                    : i.durationCtrl.text.trim(),
                'instructions': i.instrCtrl.text.trim().isEmpty
                    ? null
                    : i.instrCtrl.text.trim(),
              })
          .toList();

      if (itemsData.isNotEmpty) {
        await SupabaseService.addPrescriptionItems(itemsData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription saved'),
          backgroundColor: AppColors.secondary,
        ),
      );
      context.go('/prescriptions');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error),
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
        title: const Text('Add Prescription'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/prescriptions'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('Prescription Details'),
              const SizedBox(height: 16),
              AppTextField(
                controller: _doctorCtrl,
                label: 'Doctor Name',
                hint: 'e.g. Dr. Sharma',
                prefixIcon: Icons.person_outlined,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _hospitalCtrl,
                label: 'Hospital / Clinic',
                hint: 'e.g. City General Hospital',
                prefixIcon: Icons.local_hospital_outlined,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _diagnosisCtrl,
                label: 'Diagnosis / Condition',
                hint: 'e.g. Type 2 Diabetes, Hypertension',
                prefixIcon: Icons.medical_information_outlined,
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickDate,
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
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        _prescribedDate != null
                            ? DateFormat('d MMM yyyy')
                                .format(_prescribedDate!)
                            : 'Prescribed Date',
                        style: TextStyle(
                          color: _prescribedDate != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _notesCtrl,
                label: 'Notes',
                hint: 'Additional notes...',
                maxLines: 2,
                prefixIcon: Icons.notes_rounded,
              ),
              const SizedBox(height: 24),

              _section('Medicines Prescribed'),
              const SizedBox(height: 16),
              ...List.generate(
                  _items.length, (i) => _buildItemCard(i)),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _items.add(_PrescriptionItem())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Medicine'),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Save Prescription',
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

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Medicine ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: AppColors.error, size: 20),
                  onPressed: () =>
                      setState(() => _items.removeAt(index)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: item.nameCtrl,
            label: 'Medicine Name *',
            hint: 'e.g. Metformin',
            validator: index == 0
                ? (v) => (v == null || v.isEmpty) ? 'Required' : null
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: item.dosageCtrl,
                  label: 'Dosage',
                  hint: '500mg',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  controller: item.frequencyCtrl,
                  label: 'Frequency',
                  hint: 'Twice daily',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: item.durationCtrl,
                  label: 'Duration',
                  hint: '30 days',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  controller: item.instrCtrl,
                  label: 'Instructions',
                  hint: 'After meals',
                ),
              ),
            ],
          ),
        ],
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
}

class _PrescriptionItem {
  final nameCtrl = TextEditingController();
  final dosageCtrl = TextEditingController();
  final frequencyCtrl = TextEditingController();
  final durationCtrl = TextEditingController();
  final instrCtrl = TextEditingController();
  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    frequencyCtrl.dispose();
    durationCtrl.dispose();
    instrCtrl.dispose();
  }
}
