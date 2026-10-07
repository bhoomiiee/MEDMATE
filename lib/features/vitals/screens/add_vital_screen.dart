import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class AddVitalScreen extends StatefulWidget {
  const AddVitalScreen({super.key});

  @override
  State<AddVitalScreen> createState() => _AddVitalScreenState();
}

class _AddVitalScreenState extends State<AddVitalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _value1Ctrl = TextEditingController();
  final _value2Ctrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _vitalType = 'blood_pressure';
  bool _saving = false;

  // Units per type
  static const Map<String, String> _units = {
    'blood_pressure': 'mmHg',
    'blood_sugar': 'mg/dL',
    'weight': 'kg',
    'temperature': '°C',
    'heart_rate': 'bpm',
    'oxygen_saturation': '%',
    'other': '',
  };

  @override
  void dispose() {
    _value1Ctrl.dispose();
    _value2Ctrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = await AuthGuard.requireUserId(context);
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await SupabaseService.addVital({
        'user_id': userId,
        'vital_type': _vitalType,
        'value_1': double.tryParse(_value1Ctrl.text.trim()),
        'value_2': _value2Ctrl.text.trim().isNotEmpty
            ? double.tryParse(_value2Ctrl.text.trim()) : null,
        'unit': _units[_vitalType] ?? '',
        'notes': _notesCtrl.text.trim().isEmpty
            ? null : _notesCtrl.text.trim(),
        'recorded_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vital recorded'),
          backgroundColor: AppColors.secondary,
        ),
      );
      context.go('/vitals');
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

  bool get _needsSecondValue =>
      _vitalType == 'blood_pressure' || _vitalType == 'blood_sugar';

  String get _value1Label {
    switch (_vitalType) {
      case 'blood_pressure': return 'Systolic (upper)';
      case 'blood_sugar': return 'Fasting';
      default:
        return AppConstants.vitalTypeLabels[_vitalType] ?? 'Value';
    }
  }

  String get _value2Label {
    switch (_vitalType) {
      case 'blood_pressure': return 'Diastolic (lower)';
      case 'blood_sugar': return 'Post-meal (optional)';
      default: return 'Value 2';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Record Vital'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/vitals'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Vital Type',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.8,
                children: AppConstants.vitalTypeLabels.entries
                    .map((e) => _typeTile(e.key, e.value))
                    .toList(),
              ),
              const SizedBox(height: 24),

              Text('Enter Values',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _value1Ctrl,
                      label: '${_value1Label} (${_units[_vitalType] ?? ''})',
                      hint: 'e.g. 120',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      prefixIcon: Icons.numbers_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required' : null,
                    ),
                  ),
                  if (_needsSecondValue) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _value2Ctrl,
                        label: _value2Label,
                        hint: 'e.g. 80',
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        prefixIcon: Icons.numbers_rounded,
                        validator: _vitalType == 'blood_pressure'
                            ? (v) => (v == null || v.trim().isEmpty)
                                ? 'Required' : null
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _notesCtrl,
                label: 'Notes (optional)',
                hint: 'e.g. After exercise, fasting',
                prefixIcon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Save Vital',
                onPressed: _save,
                loading: _saving,
                icon: Icons.save_rounded,
                color: AppColors.error,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeTile(String type, String label) {
    final sel = _vitalType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _vitalType = type;
          _value1Ctrl.clear();
          _value2Ctrl.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.error : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: sel ? AppColors.error : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(_typeIcon(type),
                size: 18,
                color: sel ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: sel
                          ? Colors.white
                          : AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'blood_pressure': return Icons.monitor_heart_rounded;
      case 'blood_sugar': return Icons.water_drop_rounded;
      case 'heart_rate': return Icons.favorite_rounded;
      case 'oxygen_saturation': return Icons.air_rounded;
      case 'weight': return Icons.monitor_weight_rounded;
      case 'temperature': return Icons.thermostat_rounded;
      default: return Icons.health_and_safety_rounded;
    }
  }
}
