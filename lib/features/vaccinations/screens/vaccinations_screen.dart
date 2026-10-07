import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/empty_state.dart';

class VaccinationsScreen extends StatefulWidget {
  const VaccinationsScreen({super.key});

  @override
  State<VaccinationsScreen> createState() => _VaccinationsScreenState();
}

class _VaccinationsScreenState extends State<VaccinationsScreen> {
  List<Map<String, dynamic>> _vaccinations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getVaccinations();
      setState(() => _vaccinations = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final hospitalCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime? adminDate;
    DateTime? nextDue;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Vaccination'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Vaccine Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hospitalCtrl,
                  decoration: const InputDecoration(labelText: 'Hospital / Clinic'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(adminDate == null
                      ? 'Date Administered'
                      : DateFormat('d MMM yyyy').format(adminDate!)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDlgState(() => adminDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(nextDue == null
                      ? 'Next Due Date (optional)'
                      : DateFormat('d MMM yyyy').format(nextDue!)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                    );
                    if (picked != null) setDlgState(() => nextDue = picked);
                  },
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final userId = await AuthGuard.requireUserId(context);
                if (userId == null) return;
                await SupabaseService.addVaccination({
                  'user_id': userId,
                  'vaccine_name': nameCtrl.text.trim(),
                  'hospital_clinic': hospitalCtrl.text.trim().isEmpty
                      ? null : hospitalCtrl.text.trim(),
                  'administered_date': adminDate != null
                      ? DateFormat('yyyy-MM-dd').format(adminDate!) : null,
                  'next_due_date': nextDue != null
                      ? DateFormat('yyyy-MM-dd').format(nextDue!) : null,
                  'notes': notesCtrl.text.trim().isEmpty
                      ? null : notesCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _vaccinations.where((v) {
      final next = v['next_due_date'] as String?;
      if (next == null) return false;
      final d = DateTime.parse(next);
      return d.isAfter(DateTime.now()) &&
          d.isBefore(DateTime.now().add(const Duration(days: 30)));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vaccinations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (upcoming.isNotEmpty) ...[
                      _sectionTitle('Due Soon (next 30 days)'),
                      const SizedBox(height: 12),
                      ...upcoming.map((v) => _vaccinationCard(v, highlight: true)),
                      const SizedBox(height: 20),
                    ],
                    _sectionTitle('All Vaccinations (${_vaccinations.length})'),
                    const SizedBox(height: 12),
                    if (_vaccinations.isEmpty)
                      const EmptyState(
                        icon: Icons.vaccines_outlined,
                        title: 'No vaccinations recorded',
                        subtitle: 'Track your vaccination history and get reminders for upcoming doses',
                      )
                    else
                      ..._vaccinations.map((v) => _vaccinationCard(v)),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Add Vaccine', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _vaccinationCard(Map<String, dynamic> v, {bool highlight = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adminDate = v['administered_date'] != null
        ? DateTime.parse(v['administered_date'])
        : null;
    final nextDue = v['next_due_date'] != null
        ? DateTime.parse(v['next_due_date'])
        : null;
    final daysLeft = nextDue?.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? (isDark ? AppColors.darkSurfaceElevated : AppColors.secondarySurface)
            : (isDark ? AppColors.darkSurface : AppColors.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? AppColors.secondary.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.borderSubtle),
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.teal.withValues(alpha: 0.2),
                  AppColors.teal.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.teal.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(Icons.vaccines_rounded, color: AppColors.teal, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v['vaccine_name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                if (v['hospital_clinic'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    v['hospital_clinic'],
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (adminDate != null)
                  _infoRow(
                    Icons.check_circle_outline_rounded,
                    'Given: ${DateFormat('d MMM yyyy').format(adminDate)}',
                    AppColors.secondary,
                  ),
                if (nextDue != null)
                  _infoRow(
                    Icons.schedule_rounded,
                    'Next: ${DateFormat('d MMM yyyy').format(nextDue)}',
                    daysLeft != null && daysLeft <= 7
                        ? AppColors.error
                        : AppColors.warning,
                  ),
              ],
            ),
          ),
          if (daysLeft != null && daysLeft >= 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (daysLeft <= 7 ? AppColors.error : AppColors.warning)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$daysLeft',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: daysLeft <= 7 ? AppColors.error : AppColors.warning,
                    ),
                  ),
                  Text(
                    'days',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: daysLeft <= 7 ? AppColors.error : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, Color color) => Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      );

  Widget _sectionTitle(String title) =>
      Text(title, style: Theme.of(context).textTheme.titleMedium);
}
