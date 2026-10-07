import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MedicineCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback? onTap;

  const MedicineCard({super.key, required this.medicine, this.onTap});

  Color get _color {
    final hex = medicine['color'] as String?;
    if (hex == null) return AppColors.primary;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = (medicine['current_stock'] as int?) ?? 0;
    final threshold = (medicine['refill_threshold'] as int?) ?? 5;
    final isLowStock = stock <= threshold && stock > 0;
    final isOutOfStock = stock == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOutOfStock
              ? AppColors.error.withValues(alpha: 0.35)
              : isLowStock
                  ? AppColors.warning.withValues(alpha: 0.35)
                  : (isDark ? AppColors.darkBorder : AppColors.borderSubtle),
          width: isOutOfStock || isLowStock ? 1.5 : 1,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: _color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Avatar
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _color.withValues(alpha: 0.22),
                        _color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _formIcon(medicine['form']),
                      color: _color,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              medicine['name'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: -0.3,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOutOfStock)
                            _badge('Out of stock', AppColors.error)
                          else if (isLowStock)
                            _badge('Low stock', AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if ((medicine['dosage'] as String?)?.isNotEmpty ?? false)
                            _pill(
                              medicine['dosage'],
                              _color.withValues(alpha: 0.1),
                              _color,
                            ),
                          _pill(
                            _capitalize(medicine['form'] ?? 'Medicine'),
                            isDark ? AppColors.darkSurfaceElevated : AppColors.backgroundSecondary,
                            isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ],
                      ),
                      if (medicine['notes'] != null &&
                          (medicine['notes'] as String).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          medicine['notes'],
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? AppColors.errorSurface
                            : (isLowStock
                                ? AppColors.warningSurface
                                : (isDark ? AppColors.darkSurfaceElevated : AppColors.backgroundSecondary)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$stock units',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOutOfStock
                              ? AppColors.error
                              : (isLowStock ? AppColors.warning : AppColors.textSecondary),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  IconData _formIcon(String? form) {
    switch (form) {
      case 'tablet':
        return Icons.circle_outlined;
      case 'capsule':
        return Icons.medication_rounded;
      case 'syrup':
        return Icons.water_drop_outlined;
      case 'injection':
        return Icons.vaccines_outlined;
      case 'drops':
        return Icons.opacity_outlined;
      case 'cream':
        return Icons.back_hand_outlined;
      case 'inhaler':
        return Icons.air_outlined;
      case 'patch':
        return Icons.square_outlined;
      default:
        return Icons.medication_outlined;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
