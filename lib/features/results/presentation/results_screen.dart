import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/progress_circle.dart';
import '../../../shared/data/mock_data.dart';
import 'widgets/subject_breakdown_card.dart';
import 'widgets/chapter_analysis_card.dart';
import 'widgets/time_analysis_card.dart';
import 'widgets/accuracy_metrics_card.dart';

class ResultsScreen extends StatelessWidget {
  final String attemptId;
  const ResultsScreen({super.key, required this.attemptId});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with real attempt data from Supabase when test submission flow is complete
    final attempt = MockData.sampleAttempt;

    return GradientBackground(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Test Results'),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Score hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text('Overall Score', style: AppTypography.bodyMedium),
                  const SizedBox(height: 16),
                  ProgressCircle(
                    progress: attempt.scorePercentage / 100,
                    size: 120,
                    strokeWidth: 10,
                    progressColor: _scoreColor(attempt.scorePercentage),
                    centerWidget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${attempt.scorePercentage.round()}%',
                          style: AppTypography.numberLarge.copyWith(
                            color: _scoreColor(attempt.scorePercentage),
                          ),
                        ),
                        Text(
                          '${attempt.score}/${attempt.totalMarks}',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(label: 'Percentile', value: '82nd'),
                      Container(width: 1, height: 30, color: AppColors.divider),
                      _StatColumn(label: 'Accuracy', value: '70%'),
                      Container(width: 1, height: 30, color: AppColors.divider),
                      _StatColumn(label: 'Time', value: '45 min'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SubjectBreakdownCard(),
            const ChapterAnalysisCard(),
            const TimeAnalysisCard(),
            const AccuracyMetricsCard(),
            const SizedBox(height: 16),
            // CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/practice'),
                icon: const Icon(LucideIcons.target),
                label: const Text('Practice Weak Areas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.heading3),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
