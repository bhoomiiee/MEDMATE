import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String _filter = 'all';
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();

  final _filters = ['all', 'taken', 'skipped', 'pending'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getReminderLogs(
        from: DateTime(_from.year, _from.month, _from.day),
        to: DateTime(_to.year, _to.month, _to.day, 23, 59, 59),
      );
      setState(() => _logs = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered =>
      _filter == 'all' ? _logs : _logs.where((l) => l['status'] == _filter).toList();

  Map<String, int> get _stats => {
    'taken': _logs.where((l) => l['status'] == 'taken').length,
    'skipped': _logs.where((l) => l['status'] == 'skipped').length,
    'pending': _logs.where((l) => l['status'] == 'pending').length,
  };

  double get _adherenceRate {
    final total = _logs.length;
    if (total == 0) return 0;
    return (_stats['taken']! / total) * 100;
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range != null) {
      setState(() { _from = range.start; _to = range.end; });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dose History'),
        actions: [
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(
              '${DateFormat('d MMM').format(_from)} – ${DateFormat('d MMM').format(_to)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Adherence summary
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Medication Adherence',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    Text('${_adherenceRate.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 28)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _adherenceRate / 100,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBadge('${_stats['taken']}', 'Taken', Colors.white),
                    _statBadge('${_stats['skipped']}', 'Skipped', Colors.white70),
                    _statBadge('${_stats['pending']}', 'Pending', Colors.white60),
                    _statBadge('${_logs.length}', 'Total', Colors.white),
                  ],
                ),
              ],
            ),
          ),

          // Filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final sel = _filter == f;
                return FilterChip(
                  label: Text(_capitalize(f)),
                  selected: sel,
                  onSelected: (_) => setState(() => _filter = f),
                  backgroundColor: AppColors.surface,
                  selectedColor: _filterColor(f),
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: sel ? _filterColor(f) : AppColors.border),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('${_filtered.length} records',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No records found',
                        subtitle: 'Dose history will appear here once you start tracking',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _logTile(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _logTile(Map<String, dynamic> log) {
    final status = log['status'] as String? ?? 'pending';
    final scheduledAt = log['scheduled_at'] != null
        ? DateTime.parse(log['scheduled_at']).toLocal()
        : null;
    final schedule = log['schedules'] as Map<String, dynamic>?;
    final medicine = schedule?['user_medicines'] as Map<String, dynamic>?;
    final name = medicine?['name'] ?? 'Medicine';
    final dosage = medicine?['dosage'] ?? '';
    final takenAt = log['taken_at'] != null
        ? DateTime.parse(log['taken_at']).toLocal()
        : null;

    Color color;
    IconData icon;
    switch (status) {
      case 'taken':
        color = AppColors.secondary;
        icon = Icons.check_circle_rounded;
        break;
      case 'skipped':
        color = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
      default:
        color = AppColors.warning;
        icon = Icons.pending_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(dosage, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                if (takenAt != null)
                  Text('Taken at ${DateFormat('HH:mm').format(takenAt)}',
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (scheduledAt != null) ...[
                Text(DateFormat('d MMM').format(scheduledAt),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text(DateFormat('HH:mm').format(scheduledAt),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String value, String label, Color color) => Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      );

  Color _filterColor(String f) {
    switch (f) {
      case 'taken': return AppColors.secondary;
      case 'skipped': return AppColors.error;
      case 'pending': return AppColors.warning;
      default: return AppColors.primary;
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
