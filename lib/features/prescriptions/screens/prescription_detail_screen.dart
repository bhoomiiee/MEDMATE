import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

class PrescriptionDetailScreen extends StatefulWidget {
  final String prescriptionId;
  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  @override
  State<PrescriptionDetailScreen> createState() =>
      _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState
    extends State<PrescriptionDetailScreen> {
  Map<String, dynamic>? _prescription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data =
          await SupabaseService.getPrescription(widget.prescriptionId);
      setState(() => _prescription = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_prescription == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prescription')),
        body: const Center(child: Text('Not found')),
      );
    }

    final p = _prescription!;
    final items =
        (p['prescription_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final date = p['prescribed_date'] != null
        ? DateFormat('d MMMM yyyy')
            .format(DateTime.parse(p['prescribed_date']))
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Prescription Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/prescriptions'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Delete Prescription?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.error))),
                  ],
                ),
              );
              if (ok == true) {
                await SupabaseService.deletePrescription(p['id']);
                if (!mounted) return;
                context.go('/prescriptions');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description_rounded,
                      color: Colors.white, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    p['doctor_name'] != null
                        ? 'Dr. ${p['doctor_name']}'
                        : 'Prescription',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  if (p['hospital_clinic'] != null)
                    Text(p['hospital_clinic'],
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14)),
                  if (date != null)
                    Text(date,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (p['diagnosis'] != null)
              _infoCard('Diagnosis', p['diagnosis'],
                  Icons.medical_information_outlined),
            if (p['notes'] != null)
              _infoCard('Notes', p['notes'], Icons.notes_rounded),

            // Medicines
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: const Border.fromBorderSide(
                    BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.medication_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Medicines (${items.length})',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Text('No medicines recorded',
                        style: TextStyle(color: AppColors.textSecondary))
                  else
                    ...items.map((item) => _medicineItem(item)),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, String content, IconData icon) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: const Border.fromBorderSide(
              BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Text(content,
                style: const TextStyle(fontSize: 14)),
          ],
        ),
      );

  Widget _medicineItem(Map<String, dynamic> item) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['medicine_name'] ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: [
                if (item['dosage'] != null)
                  _detail('Dosage', item['dosage']),
                if (item['frequency'] != null)
                  _detail('Frequency', item['frequency']),
                if (item['duration'] != null)
                  _detail('Duration', item['duration']),
              ],
            ),
            if (item['instructions'] != null) ...[
              const SizedBox(height: 4),
              Text(item['instructions'],
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ],
        ),
      );

  Widget _detail(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(color: AppColors.textMuted)),
            TextSpan(
                text: value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
