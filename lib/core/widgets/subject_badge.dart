import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../shared/models/enums.dart';

/// Color-coded pill badge for topic strength.
/// Uses positive framing: "Needs Practice" instead of "Needs Work".
class SubjectBadge extends StatelessWidget {
  final TopicStrength strength;
  final String? customLabel;

  const SubjectBadge({super.key, required this.strength, this.customLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
            customLabel ?? _label,
            style: AppTypography.labelSmall.copyWith(
              color: _fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Positive framing labels
  String get _label => switch (strength) {
    TopicStrength.strong => 'Mastered',
    TopicStrength.moderate => 'In Progress',
    TopicStrength.weak => 'Needs Practice',
  };

  Color get _bgColor => switch (strength) {
    TopicStrength.strong => AppColors.successLight,
    TopicStrength.moderate => AppColors.warningLight,
    TopicStrength.weak => AppColors.errorLight,
  };

  Color get _fgColor => switch (strength) {
    TopicStrength.strong => AppColors.success,
    TopicStrength.moderate => AppColors.warning,
    TopicStrength.weak => AppColors.wrong,
  };

  IconData get _icon => switch (strength) {
    TopicStrength.strong => LucideIcons.trendingUp,
    TopicStrength.moderate => LucideIcons.minus,
    TopicStrength.weak => LucideIcons.target,           // "Practice target" not "trending down"
  };
}
