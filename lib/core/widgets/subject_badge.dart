import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../shared/models/enums.dart';

/// Color-coded pill badge for topic strength.
class SubjectBadge extends StatelessWidget {
  final TopicStrength strength;
  final String? customLabel;

  const SubjectBadge({super.key, required this.strength, this.customLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _fgColor),
          const SizedBox(width: 4),
          Text(
            customLabel ?? strength.label,
            style: AppTypography.labelSmall.copyWith(
              color: _fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color get _bgColor => switch (strength) {
    TopicStrength.strong => AppColors.successLight,
    TopicStrength.weak => AppColors.warningLight,
    TopicStrength.moderate => AppColors.surfaceDark,
  };

  Color get _fgColor => switch (strength) {
    TopicStrength.strong => AppColors.success,
    TopicStrength.weak => AppColors.warning,
    TopicStrength.moderate => AppColors.textLight,
  };

  IconData get _icon => switch (strength) {
    TopicStrength.strong => Icons.trending_up_rounded,
    TopicStrength.weak => Icons.trending_down_rounded,
    TopicStrength.moderate => Icons.trending_flat_rounded,
  };
}
