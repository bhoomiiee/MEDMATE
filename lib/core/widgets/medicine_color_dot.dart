import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MedicineColorDot extends StatelessWidget {
  final String? colorHex;
  final double size;

  const MedicineColorDot({super.key, this.colorHex, this.size = 12});

  Color get _color {
    if (colorHex == null) return AppColors.primary;
    try {
      return Color(int.parse(colorHex!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
    );
  }
}
