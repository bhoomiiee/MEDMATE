import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final String? medicineId;
  const AddEditMedicineScreen({super.key, this.medicineId});

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _genericCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _thresholdCtrl = TextEditingController(text: '5');
  final _notesCtrl = TextEditingController();

  String _form = 'tablet';
  String _unit = 'mg';
  String? _selectedColor;
  bool _loading = false;
  bool _isEdit = false;

  final List<String> _units = ['mg', 'ml', 'mcg', 'g', 'IU', '%', 'units'];
  final List<Map<String, dynamic>> _colorOptions = [
    {'name': 'Lavender', 'hex': '#7F56D9'},
    {'name': 'Lilac', 'hex': '#A855F7'},
    {'name': 'Periwinkle', 'hex': '#6366F1'},
    {'name': 'Sage', 'hex': '#22C55E'},
    {'name': 'Honey', 'hex': '#F59E0B'},
    {'name': 'Rose', 'hex': '#F43F5E'},
    {'name': 'Blossom', 'hex': '#EC4899'},
    {'name': 'Sky', 'hex': '#06B6D4'},
    {'name': 'Wisteria', 'hex': '#5B30A6'},
  ];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.medicineId != null;
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final med = await SupabaseService.getMedicine(widget.medicineId!);
      if (med != null && mounted) {
        _nameCtrl.text = med['name'] ?? '';
        _genericCtrl.text = med['generic_name'] ?? '';
        _dosageCtrl.text = med['dosage'] ?? '';
        _stockCtrl.text = med['current_stock']?.toString() ?? '0';
        _thresholdCtrl.text = med['refill_threshold']?.toString() ?? '5';
        _notesCtrl.text = med['notes'] ?? '';
        setState(() {
          _form = med['form'] ?? 'tablet';
          _unit = med['unit'] ?? 'mg';
          _selectedColor = med['color'];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = await AuthGuard.requireUserId(context);
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final data = {
        'user_id': userId,
        'name': _nameCtrl.text.trim(),
        'generic_name': _genericCtrl.text.trim().isEmpty
            ? null
            : _genericCtrl.text.trim(),
        'form': _form,
        'dosage': _dosageCtrl.text.trim(),
        'unit': _unit,
        'current_stock': int.tryParse(_stockCtrl.text) ?? 0,
        'refill_threshold': int.tryParse(_thresholdCtrl.text) ?? 5,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'color': _selectedColor,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isEdit) {
        await SupabaseService.updateMedicine(widget.medicineId!, data);
      } else {
        await SupabaseService.addMedicine(data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit
              ? 'Medicine updated successfully'
              : 'Medicine added successfully'),
          backgroundColor: AppColors.secondary,
        ),
      );
      context.go('/medicines');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _genericCtrl.dispose();
    _dosageCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Medicine' : 'Add Medicine',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              onTap: () => context.go('/medicines'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.softShadow,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
      body: _loading && _isEdit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Details
                    _cardSection(
                      title: 'Medicine Details',
                      icon: Icons.medication_rounded,
                      children: [
                        AppTextField(
                          controller: _nameCtrl,
                          label: 'Medicine Name *',
                          hint: 'e.g. Paracetamol 500mg',
                          prefixIcon: Icons.medication_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Medicine name is required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _genericCtrl,
                          label: 'Generic Name',
                          hint: 'e.g. Acetaminophen',
                          prefixIcon: Icons.science_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Form type
                        _label('Medicine Form'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AppConstants.medicineForms
                              .map((f) => _formChip(f))
                              .toList(),
                        ),
                        const SizedBox(height: 16),

                        // Dosage + Unit
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                controller: _dosageCtrl,
                                label: 'Dosage *',
                                hint: 'e.g. 500',
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.straighten_rounded,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _unit,
                                decoration: InputDecoration(
                                  labelText: 'Unit',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
                                  ),
                                ),
                                items: _units
                                    .map((u) => DropdownMenuItem(
                                        value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (v) => setState(() => _unit = v!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section 2: Stock
                    _cardSection(
                      title: 'Stock Management',
                      icon: Icons.inventory_2_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _stockCtrl,
                                label: 'Current Stock',
                                hint: '0',
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.inventory_2_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: _thresholdCtrl,
                                label: 'Refill Reminder at',
                                hint: '5',
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.notification_important_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You will receive a notification to refill once stock reaches the threshold.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section 3: Appearance
                    _cardSection(
                      title: 'Appearance & Tag',
                      icon: Icons.palette_outlined,
                      children: [
                        _label('Label Color'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _colorOptions.map((c) {
                            final hex = c['hex'] as String;
                            final color = Color(
                                int.parse(hex.replaceFirst('#', '0xFF')));
                            final selected = _selectedColor == hex;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColor = hex),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: selected
                                      ? Border.all(
                                          color: AppColors.textPrimary,
                                          width: 3)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(
                                          alpha: selected ? 0.5 : 0.2),
                                      blurRadius: selected ? 10 : 4,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: selected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 20)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section 4: Notes
                    _cardSection(
                      title: 'Additional Notes',
                      icon: Icons.notes_rounded,
                      children: [
                        AppTextField(
                          controller: _notesCtrl,
                          label: 'Doctor instructions / Dietary notes',
                          hint:
                              'e.g. Take with warm water after meals, avoid caffeine...',
                          maxLines: 3,
                          prefixIcon: Icons.notes_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    AppButton(
                      label: _isEdit ? 'Update Medicine' : 'Add Medicine',
                      onPressed: _save,
                      loading: _loading,
                      icon: _isEdit ? Icons.save_rounded : Icons.add_rounded,
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _cardSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary));

  Widget _formChip(String form) {
    final selected = _form == form;
    final label = form[0].toUpperCase() + form.substring(1);
    return GestureDetector(
      onTap: () => setState(() => _form = form),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
          boxShadow: selected ? AppColors.glow(AppColors.primary) : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
