import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  List<Map<String, dynamic>> _vitals = [];
  bool _loading = true;
  String _selectedType = 'all';

  final _typeOptions = <String>['all', ...AppConstants.vitalTypeLabels.keys];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getVitals(
        vitalType: _selectedType == 'all' ? null : _selectedType,
      );
      setState(() => _vitals = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Health Vitals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/vitals/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Type filter
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _typeOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _typeOptions[i];
                final sel = _selectedType == t;
                final label = t == 'all'
                    ? 'All Vitals'
                    : AppConstants.vitalTypeLabels[t] ?? t;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedType = t);
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.error
                          : (isDark ? AppColors.darkSurface : AppColors.surface),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? AppColors.error
                            : (isDark ? AppColors.darkBorder : AppColors.borderSubtle),
                      ),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: sel
                            ? Colors.white
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _vitals.isEmpty
                    ? EmptyState(
                        icon: Icons.favorite_outlined,
                        title: 'No vitals recorded',
                        subtitle:
                            'Track blood pressure, sugar, weight, and more with smart logs.',
                        actionLabel: 'Add Vital',
                        onAction: () => context.go('/vitals/add'),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: _vitals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _vitalCard(_vitals[i], isDark),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/vitals/add'),
        backgroundColor: AppColors.error,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Add Vital', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _vitalCard(Map<String, dynamic> v, bool isDark) {
    final type = v['vital_type'] as String? ?? 'other';
    final label = AppConstants.vitalTypeLabels[type] ?? type;
    final v1 = v['value_1'] as num?;
    final v2 = v['value_2'] as num?;
    final unit = v['unit'] as String? ?? '';
    final recordedAt = v['recorded_at'] != null
        ? DateTime.parse(v['recorded_at']).toLocal()
        : null;

    String valueStr;
    if (type == 'blood_pressure' && v2 != null) {
      valueStr = '${v1?.toInt()}/${v2.toInt()} $unit';
    } else if (type == 'blood_sugar' && v2 != null) {
      valueStr = 'F: ${v1?.toStringAsFixed(1)} / PP: ${v2.toStringAsFixed(1)} $unit';
    } else {
      valueStr = '${v1?.toStringAsFixed(1)} $unit';
    }

    final color = _typeColor(type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.2,
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
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(_typeIcon(type), color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                if (v['notes'] != null && (v['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    v['notes'],
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valueStr,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
              if (recordedAt != null)
                Text(
                  DateFormat('d MMM, HH:mm').format(recordedAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'blood_pressure': return AppColors.error;
      case 'blood_sugar': return AppColors.warning;
      case 'heart_rate': return const Color(0xFFEC4899);
      case 'oxygen_saturation': return AppColors.primary;
      case 'weight': return AppColors.secondary;
      case 'temperature': return const Color(0xFFF97316);
      default: return AppColors.textSecondary;
    }
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
