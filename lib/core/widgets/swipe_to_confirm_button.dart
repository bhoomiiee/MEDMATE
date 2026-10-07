import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class SwipeToConfirmButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  final String label;
  final String confirmedLabel;

  const SwipeToConfirmButton({
    super.key,
    required this.onConfirmed,
    this.label = 'Swipe to mark taken',
    this.confirmedLabel = '✓ Marked as Taken',
  });

  @override
  State<SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<SwipeToConfirmButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isConfirmed = false;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  static const double _height = 58.0;
  static const double _thumbPadding = 4.0;
  static const double _thumbSize = _height - (_thumbPadding * 2);

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _resetController.addListener(() {
      setState(() {
        _dragPosition = _resetAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isConfirmed) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxDrag) {
    if (_isConfirmed) return;
    if (_dragPosition >= maxDrag * 0.8) {
      // Threshold reached -> confirm!
      setState(() {
        _dragPosition = maxDrag;
        _isConfirmed = true;
      });
      HapticFeedback.mediumImpact();
      widget.onConfirmed();
    } else {
      // Snap back smoothly
      _resetAnimation = Tween<double>(
        begin: _dragPosition,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _resetController,
        curve: Curves.easeOutCubic,
      ));
      _resetController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 320.0;
        final maxDrag = totalWidth - _thumbSize - (_thumbPadding * 2);
        final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: _height,
          width: totalWidth,
          decoration: BoxDecoration(
            color: _isConfirmed
                ? AppColors.secondary.withValues(alpha: 0.15)
                : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(_height / 2),
            border: Border.all(
              color: _isConfirmed
                  ? AppColors.secondary.withValues(alpha: 0.5)
                  : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Filled Progress Bar
              if (!_isConfirmed && _dragPosition > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _dragPosition + _thumbSize + _thumbPadding,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.primaryLight.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(_height / 2),
                    ),
                  ),
                ),

              // Centered Prompt Label
              Center(
                child: Opacity(
                  opacity: _isConfirmed ? 1.0 : (1.0 - (progress * 1.5)).clamp(0.0, 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isConfirmed ? widget.confirmedLabel : widget.label,
                        style: TextStyle(
                          color: _isConfirmed
                              ? AppColors.secondary
                              : AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (!_isConfirmed) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_double_arrow_right_rounded,
                          size: 18,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Draggable Slider Thumb
              Positioned(
                left: _thumbPadding + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, maxDrag),
                  onHorizontalDragEnd: (d) => _onHorizontalDragEnd(d, maxDrag),
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isConfirmed
                          ? const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                            )
                          : AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: (_isConfirmed ? AppColors.secondary : AppColors.primary)
                              .withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isConfirmed
                          ? Icons.check_rounded
                          : Icons.medication_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
