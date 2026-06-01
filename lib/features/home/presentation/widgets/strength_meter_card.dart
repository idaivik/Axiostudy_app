import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../subjects/data/subjects_providers.dart';
import '../../../../shared/models/enums.dart';

/// Subject-wise strength meter with positive framing.
/// Shows progress bars for each subject with encouraging language.
/// Replaces the old "Areas to Improve" card.
class StrengthMeterCard extends ConsumerWidget {
  const StrengthMeterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.barChart3,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text('Strength Meter', style: AppTypography.heading3),
            ],
          ),
          const SizedBox(height: 20),
          ...subjects.asMap().entries.map((entry) {
            final subject = entry.value;
            final isLast = entry.key == subjects.length - 1;
            final color = _colorFor(subject.type);
            final strongChapter = subject.chapters
                .reduce((a, b) =>
                    a.completionPercentage >= b.completionPercentage ? a : b)
                .name;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(subject.iconData, size: 18, color: color),
                      const SizedBox(width: 8),
                      Text(
                        subject.name,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(subject.completionPercentage * 100).round()}%',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: subject.completionPercentage,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceDark,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.trendingUp,
                        size: 12,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Strongest: $strongChapter',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _colorFor(SubjectType type) => switch (type) {
    SubjectType.physics => AppColors.physics,
    SubjectType.chemistry => AppColors.chemistry,
    SubjectType.mathematics => AppColors.mathematics,
  };
}
