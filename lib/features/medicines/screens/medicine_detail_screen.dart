import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/reminder_monitor_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';

class MedicineDetailScreen extends StatefulWidget {
  final String medicineId;
  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  Map<String, dynamic>? _medicine;
  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getMedicine(widget.medicineId),
        SupabaseService.getSchedules(widget.medicineId),
      ]);
      setState(() {
        _medicine = results[0] as Map<String, dynamic>?;
        _schedules = results[1] as List<Map<String, dynamic>>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color get _color {
    final hex = _medicine?['color'] as String?;
    if (hex == null) return AppColors.primary;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Future<void> _updateStock(int delta) async {
    final current = (_medicine?['current_stock'] as int?) ?? 0;
    final newStock = (current + delta).clamp(0, 9999);
    await SupabaseService.updateStock(widget.medicineId, newStock);
    _load();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Medicine?'),
        content: const Text(
            'This will deactivate the medicine and all its schedules.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Remove',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteMedicine(widget.medicineId);
      if (!mounted) return;
      context.go('/medicines');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_medicine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medicine')),
        body: const Center(child: Text('Medicine not found')),
      );
    }

    final stock = (_medicine!['current_stock'] as int?) ?? 0;
    final threshold = (_medicine!['refill_threshold'] as int?) ?? 5;
    final isLow = stock <= threshold;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: _color,
            elevation: 0,
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
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 18),
                ),
                onPressed: () =>
                    context.go('/medicines/edit/${widget.medicineId}'),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white, size: 18),
                ),
                onPressed: _delete,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _color,
                      _color.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.medication_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _medicine!['name'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3),
                    ),
                    if (_medicine!['generic_name'] != null)
                      Text(
                        _medicine!['generic_name'],
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick info row
                Row(
                  children: [
                    _infoChip(Icons.straighten_rounded,
                        '${_medicine!['dosage']} ${_medicine!['unit'] ?? ''}'),
                    const SizedBox(width: 8),
                    _infoChip(Icons.medication_outlined,
                        _capitalize(_medicine!['form'] ?? '')),
                  ],
                ),
                const SizedBox(height: 16),

                // Stock card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isLow
                        ? AppColors.warningSurface
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isLow
                            ? AppColors.warning.withValues(alpha: 0.4)
                            : AppColors.border),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isLow ? AppColors.warning : AppColors.primary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.inventory_2_outlined,
                                size: 18,
                                color: isLow
                                    ? AppColors.warning
                                    : AppColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Text('Inventory & Stock',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  )),
                          const Spacer(),
                          if (isLow)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.warning.withValues(alpha: 0.4)),
                              ),
                              child: const Text('Low Stock',
                                  style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _stockBtn(Icons.remove_rounded, () => _updateStock(-1)),
                          const SizedBox(width: 28),
                          Column(
                            children: [
                              Text('$stock',
                                  style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                      color: isLow
                                          ? AppColors.warning
                                          : AppColors.textPrimary)),
                              const Text('units remaining',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(width: 28),
                          _stockBtn(Icons.add_rounded, () => _updateStock(1)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Refill reminder trigger at $threshold units',
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Schedules
                _sectionCard(
                  'Reminder Schedules',
                  Icons.alarm_rounded,
                  trailing: FilledButton.tonalIcon(
                    onPressed: () =>
                        context.go('/reminders/add/${widget.medicineId}'),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primarySurface,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  child: _schedules.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.alarm_off_outlined,
                                    color: AppColors.textMuted, size: 32),
                                const SizedBox(height: 8),
                                const Text('No schedules set',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                                AppButton(
                                  label: 'Add Schedule',
                                  onPressed: () => context.go(
                                      '/reminders/add/${widget.medicineId}'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            // Dedicated test alert row with clean alignment
                            Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.notifications_active_outlined,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Test Reminder Alarm & Swipe',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      ReminderMonitorService.instance
                                          .testReminderNow(
                                        context,
                                        medicineName:
                                            _medicine?['name'] ?? 'Medicine',
                                        dosage: _medicine?['dosage'] ?? '',
                                        medicineId: widget.medicineId,
                                        scheduleId:
                                            _schedules.first['id'] as String?,
                                        onDoseTaken: _load,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: BorderSide(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4),
                                      ),
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Test Alert',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._schedules
                                .map((s) => _scheduleItem(s))
                                .toList(),
                          ],
                        ),
                ),
                const SizedBox(height: 16),

                // Notes
                if (_medicine!['notes'] != null &&
                    (_medicine!['notes'] as String).isNotEmpty)
                  _sectionCard(
                    'Notes',
                    Icons.notes_rounded,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_medicine!['notes'],
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    ),
                  ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      );

  Widget _stockBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.softShadow,
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      );

  Widget _sectionCard(String title, IconData icon,
      {required Widget child, Widget? trailing}) {
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
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _scheduleItem(Map<String, dynamic> schedule) {
    final times = List<String>.from(schedule['times'] ?? []);
    final freq = schedule['frequency'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.alarm_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.frequencyDisplayNames[freq] ?? freq,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  times.join(' • '),
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: () async {
              await SupabaseService.deleteSchedule(schedule['id']);
              _load();
            },
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
