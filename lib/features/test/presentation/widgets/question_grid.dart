import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/enums.dart';

/// 90-circle navigation grid overlay for test questions.
class QuestionGrid extends StatelessWidget {
  final int totalQuestions;
  final int currentIndex;
  final AnswerStatus Function(int) statusFor;
  final ValueChanged<int> onQuestionTap;
  final VoidCallback onClose;

  const QuestionGrid({
    super.key,
    required this.totalQuestions,
    required this.currentIndex,
    required this.statusFor,
    required this.onQuestionTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // prevent pass-through
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('Question Navigator', style: AppTypography.heading3),
                      const Spacer(),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Legend
                  Row(
                    children: [
                      _LegendItem(color: AppColors.success, label: 'Answered'),
                      const SizedBox(width: 12),
                      _LegendItem(color: AppColors.warning, label: 'Review'),
                      const SizedBox(width: 12),
                      _LegendItem(color: AppColors.surfaceDark, label: 'Unanswered'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: totalQuestions,
                    itemBuilder: (context, index) {
                      final status = statusFor(index);
                      return GestureDetector(
                        onTap: () => onQuestionTap(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _colorFor(status),
                            borderRadius: BorderRadius.circular(8),
                            border: status == AnswerStatus.current
                                ? Border.all(color: AppColors.primary, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: status == AnswerStatus.current
                                    ? AppColors.primary
                                    : status == AnswerStatus.answered
                                        ? Colors.white
                                        : AppColors.textMedium,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFor(AnswerStatus status) => switch (status) {
    AnswerStatus.answered => AppColors.success,
    AnswerStatus.markedForReview => AppColors.warning,
    AnswerStatus.current => AppColors.primarySurface,
    AnswerStatus.unanswered => AppColors.surfaceDark,
  };
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
