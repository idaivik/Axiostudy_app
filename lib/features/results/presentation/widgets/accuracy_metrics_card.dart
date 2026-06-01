import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';
import '../../../../core/widgets/progress_bar.dart';

class AccuracyMetricsCard extends StatelessWidget {
  const AccuracyMetricsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AxioCard(
      title: 'Accuracy by Difficulty',
      leading: Icon(Icons.gps_fixed_rounded, color: AppColors.success, size: 22),
      collapsedContent: Text('Easy: 90% • Medium: 65% • Hard: 40%', style: AppTypography.bodyMedium),
      expandedContent: Column(
        children: const [
          _DifficultyRow(level: 'Easy', correct: 9, total: 10, color: AppColors.success),
          SizedBox(height: 12),
          _DifficultyRow(level: 'Medium', correct: 13, total: 20, color: AppColors.warning),
          SizedBox(height: 12),
          _DifficultyRow(level: 'Hard', correct: 4, total: 10, color: AppColors.error),
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
