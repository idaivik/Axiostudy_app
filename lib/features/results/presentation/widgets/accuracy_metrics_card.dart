import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';
import '../../../../core/widgets/progress_bar.dart';
import '../../../analytics/domain/analytics_models.dart';

class AccuracyMetricsCard extends StatelessWidget {
  final Map<String, DifficultyBreakdown>? breakdown;
  const AccuracyMetricsCard({super.key, this.breakdown});

  @override
  Widget build(BuildContext context) {
    final easy = breakdown?['easy'];
    final medium = breakdown?['medium'];
    final hard = breakdown?['hard'];

    // Build collapsed summary
    final parts = <String>[];
    if (easy != null) parts.add('Easy: ${(easy.accuracy * 100).round()}%');
    if (medium != null) parts.add('Medium: ${(medium.accuracy * 100).round()}%');
    if (hard != null) parts.add('Hard: ${(hard.accuracy * 100).round()}%');
    final summary = parts.isNotEmpty ? parts.join(' • ') : 'No difficulty data yet';

    return AxioCard(
      title: 'Accuracy by Difficulty',
      leading: Icon(Icons.gps_fixed_rounded, color: AppColors.success, size: 22),
      collapsedContent: Text(summary, style: AppTypography.bodyMedium),
      expandedContent: Column(
        children: [
          if (easy != null)
            _DifficultyRow(level: 'Easy', correct: easy.correct, total: easy.total, color: AppColors.success),
          if (easy != null && (medium != null || hard != null))
            const SizedBox(height: 12),
          if (medium != null)
            _DifficultyRow(level: 'Medium', correct: medium.correct, total: medium.total, color: AppColors.warning),
          if (medium != null && hard != null)
            const SizedBox(height: 12),
          if (hard != null)
            _DifficultyRow(level: 'Hard', correct: hard.correct, total: hard.total, color: AppColors.error),
        ],
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final String level;
  final int correct;
  final int total;
  final Color color;

  const _DifficultyRow({
    required this.level,
    required this.correct,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accuracy = total > 0 ? correct / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(level, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$correct/$total correct', style: AppTypography.bodyMedium),
            const SizedBox(width: 8),
            Text(
              '${(accuracy * 100).round()}%',
              style: AppTypography.heading3.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(progress: accuracy, height: 6, progressColor: color),
      ],
    );
  }
}
