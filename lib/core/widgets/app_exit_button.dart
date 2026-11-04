import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

enum ExitButtonType {
  back,
  close,
}

/// A premium, accessible button that safely exits the current page.
/// If navigator can pop, it pops; otherwise it navigates to [fallbackRoute].
class AppExitButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String fallbackRoute;
  final ExitButtonType type;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? tooltip;
  final bool isLeading;

  const AppExitButton({
    super.key,
    this.onPressed,
    this.fallbackRoute = '/home',
    this.type = ExitButtonType.back,
    this.backgroundColor,
    this.iconColor,
    this.tooltip,
    this.isLeading = true,
  });

  /// Factory constructor for a 'Close' (X) exit button
  const AppExitButton.close({
    super.key,
    this.onPressed,
    this.fallbackRoute = '/home',
    this.backgroundColor,
    this.iconColor,
    this.tooltip = 'Close & Exit',
    this.isLeading = true,
  }) : type = ExitButtonType.close;

  void _handleExit(BuildContext context) {
    if (onPressed != null) {
      onPressed!();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final button = Tooltip(
      message: tooltip ?? (type == ExitButtonType.close ? 'Close & Exit' : 'Back & Exit'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleExit(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor ??
                  (isDark ? AppColors.darkSurface : AppColors.surface),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              type == ExitButtonType.close
                  ? Icons.close_rounded
                  : Icons.arrow_back_ios_new_rounded,
              size: type == ExitButtonType.close ? 18 : 16,
              color: iconColor ??
                  (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );

    if (isLeading) {
      return Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(child: button),
      );
    }

    return button;
  }
}
