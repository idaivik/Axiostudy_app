import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/roadmap_models.dart';

/// Hero header for the roadmap: exam countdown + syllabus coverage.
class ExamCountdownHeader extends StatelessWidget {
  final Roadmap roadmap;
  final ExamType examType;

  const ExamCountdownHeader({
    super.key,
    required this.roadmap,
    required this.examType,
  });

  @override
  Widget build(BuildContext context) {
    final days = roadmap.daysToExam;
    final coverage = roadmap.completionFraction;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.target, color: AppColors.greenLight, size: 18),
              const SizedBox(width: 8),
              Text(
                days != null ? 'Countdown to ${examType.label}' : 'Your ${examType.label} plan',
                style: AppTypography.labelSmall.copyWith(color: AppColors.greenLight),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (days != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$days',
                  style: AppTypography.numberLarge.copyWith(color: AppColors.white),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    days == 1 ? 'day to go' : 'days to go',
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.greenSurface),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'On track, one step at a time',
              style: AppTypography.heading2.copyWith(color: AppColors.white),
            ),
          const SizedBox(height: 18),
          // Syllabus coverage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Roadmap progress',
                  style: AppTypography.caption.copyWith(color: AppColors.greenSurface)),
              Text('${(coverage * 100).round()}%',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: coverage.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation(AppColors.greenLight),
            ),
          ),
        ],
      ),
    );
  }
}
