import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Full-screen swipe card shown when a reminder is due.
/// Swipe RIGHT → Taken  |  Swipe LEFT → Skip
/// Tap the action buttons as an alternative to swiping.
class MedicineSwipeScreen extends StatefulWidget {
  /// List of pending reminder maps with keys:
  ///   id, medicine_name, dosage, form, scheduled_time (DateTime),
  ///   with_food (bool), instructions (String?)
  final List<Map<String, dynamic>> pendingReminders;

  /// Called with (reminderId, 'taken' | 'skipped') for each card dismissed.
  final Future<void> Function(String reminderId, String status) onAction;

  /// Called when all cards are dismissed.
  final VoidCallback onDone;

  const MedicineSwipeScreen({
    super.key,
    required this.pendingReminders,
    required this.onAction,
    required this.onDone,
  });

  @override
  State<MedicineSwipeScreen> createState() => _MedicineSwipeScreenState();
}

class _MedicineSwipeScreenState extends State<MedicineSwipeScreen>
    with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _stack;
  Offset _dragOffset = Offset.zero;
  bool _acting = false;

  // How far to drag before triggering action (logical pixels)
  static const double _threshold = 120;

  @override
  void initState() {
    super.initState();
    _stack = List.from(widget.pendingReminders);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_acting) return;
    setState(() => _dragOffset += Offset(d.delta.dx, d.delta.dy * 0.3));
  }

  void _onDragEnd(DragEndDetails _) {
    if (_dragOffset.dx > _threshold) {
      _dismiss('taken');
    } else if (_dragOffset.dx < -_threshold) {
      _dismiss('skipped');
    } else {
      // Snap back
      setState(() => _dragOffset = Offset.zero);
    }
  }

  Future<void> _dismiss(String status) async {
    if (_acting || _stack.isEmpty) return;
    setState(() => _acting = true);

    final reminder = _stack.first;
    final targetX =
        status == 'taken' ? 600.0 : -600.0;

    // Animate out
    setState(() => _dragOffset = Offset(targetX, _dragOffset.dy));

    await Future.delayed(const Duration(milliseconds: 250));
    await widget.onAction(reminder['id'] as String, status);

    if (!mounted) return;
    setState(() {
      _stack.removeAt(0);
      _dragOffset = Offset.zero;
      _acting = false;
    });

    if (_stack.isEmpty) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    if (_stack.isEmpty) return const SizedBox.shrink();

    final reminder = _stack.first;
    final medicineName = reminder['medicine_name'] as String? ?? 'Medicine';
    final dosage = reminder['dosage'] as String? ?? '';
    final form = reminder['form'] as String? ?? '';
    final withFood = reminder['with_food'] as bool? ?? false;
    final instructions = reminder['instructions'] as String?;
    final scheduledTime = reminder['scheduled_time'] as DateTime?;
    final remaining = _stack.length;

    // Derived visual values from drag
    final rotation = (_dragOffset.dx / 300) * 0.15; // radians
    final opacity = (1.0 - (_dragOffset.dx.abs() / 400)).clamp(0.0, 1.0);
    final isTaken = _dragOffset.dx > 30;
    final isSkipped = _dragOffset.dx < -30;

    final hex = reminder['color'] as String?;
    final cardColor = hex != null
        ? Color(int.parse(hex.replaceFirst('#', '0xFF')))
        : AppColors.primary;

    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Stack(
          children: [
            // Background hint arrows
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Skip hint (left)
                    AnimatedOpacity(
                      opacity: isSkipped
                          ? (_dragOffset.dx.abs() / _threshold).clamp(0.0, 1.0)
                          : 0.0,
                      duration: const Duration(milliseconds: 100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.error, width: 2),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: AppColors.error, size: 40),
                          ),
                          const SizedBox(height: 12),
                          const Text('SKIP',
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2)),
                        ],
                      ),
                    ),
                    // Taken hint (right)
                    AnimatedOpacity(
                      opacity: isTaken
                          ? (_dragOffset.dx / _threshold).clamp(0.0, 1.0)
                          : 0.0,
                      duration: const Duration(milliseconds: 100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.secondary, width: 2),
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: AppColors.secondary, size: 40),
                          ),
                          const SizedBox(height: 12),
                          const Text('TAKEN',
                              style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stack count indicator
            if (remaining > 1)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$remaining reminders pending',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),

            // Swipe instruction hint at bottom
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity:
                    _dragOffset.dx.abs() < 20 && !_acting ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back_rounded,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    const Text('Swipe to respond',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),

            // The draggable card
            Center(
              child: GestureDetector(
                onPanUpdate: _onDragUpdate,
                onPanEnd: _onDragEnd,
                child: AnimatedContainer(
                  duration: _acting
                      ? const Duration(milliseconds: 250)
                      : Duration.zero,
                  transform: Matrix4.identity()
                    ..translate(_dragOffset.dx, _dragOffset.dy)
                    ..rotateZ(rotation),
                  transformAlignment: Alignment.bottomCenter,
                  child: _ReminderCard(
                    medicineName: medicineName,
                    dosage: dosage,
                    form: form,
                    withFood: withFood,
                    instructions: instructions,
                    scheduledTime: scheduledTime,
                    color: cardColor,
                    onTaken: () => _dismiss('taken'),
                    onSkipped: () => _dismiss('skipped'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final String medicineName;
  final String dosage;
  final String form;
  final bool withFood;
  final String? instructions;
  final DateTime? scheduledTime;
  final Color color;
  final VoidCallback onTaken;
  final VoidCallback onSkipped;

  const _ReminderCard({
    required this.medicineName,
    required this.dosage,
    required this.form,
    required this.withFood,
    required this.instructions,
    required this.scheduledTime,
    required this.color,
    required this.onTaken,
    required this.onSkipped,
  });

  IconData get _formIcon {
    switch (form) {
      case 'tablet': return Icons.circle_outlined;
      case 'capsule': return Icons.medication_rounded;
      case 'syrup': return Icons.water_drop_outlined;
      case 'injection': return Icons.vaccines_outlined;
      case 'drops': return Icons.opacity_outlined;
      case 'inhaler': return Icons.air_outlined;
      default: return Icons.medication_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = scheduledTime != null
        ? '${scheduledTime!.hour.toString().padLeft(2, '0')}:${scheduledTime!.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colored header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // Bell animation
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_formIcon, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Time for your medicine',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 6),
                Text(medicineName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Scheduled at $timeStr',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Dosage chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.straighten_rounded, color: color, size: 16),
                      const SizedBox(width: 8),
                      Text(dosage,
                          style: TextStyle(
                              color: color,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text(_capitalize(form),
                          style: TextStyle(
                              color: color.withValues(alpha: 0.7),
                              fontSize: 14)),
                    ],
                  ),
                ),
                if (withFood) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.restaurant_outlined,
                          color: AppColors.warning, size: 16),
                      const SizedBox(width: 6),
                      Text('Take with food',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
                if (instructions != null && instructions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(instructions!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                const Text('Swipe or tap to respond',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    // Skip button
                    Expanded(
                      child: GestureDetector(
                        onTap: onSkipped,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.errorSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.close_rounded,
                                  color: AppColors.error, size: 28),
                              SizedBox(height: 6),
                              Text('Skip',
                                  style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Taken button
                    Expanded(
                      child: GestureDetector(
                        onTap: onTaken,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.secondarySurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.secondary
                                    .withValues(alpha: 0.4)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: AppColors.secondary, size: 28),
                              SizedBox(height: 6),
                              Text('Taken',
                                  style: TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
