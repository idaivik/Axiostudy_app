import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/test_models.dart';

/// Renders a single question with answer options.
class QuestionView extends StatelessWidget {
  final Question question;
  final String? selectedAnswer;
  final bool isMarkedForReview;
  final ValueChanged<String> onAnswerSelected;
  final VoidCallback onToggleReview;

  const QuestionView({
    super.key,
    required this.question,
    this.selectedAnswer,
    required this.isMarkedForReview,
    required this.onAnswerSelected,
    required this.onToggleReview,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Difficulty + review button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _difficultyColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  question.difficulty.label,
                  style: AppTypography.labelSmall.copyWith(
                    color: _difficultyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onToggleReview,
                child: Row(
                  children: [
                    Icon(
                      isMarkedForReview
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      size: 20,
                      color: isMarkedForReview
                          ? AppColors.warning
                          : AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Review',
                      style: AppTypography.caption.copyWith(
                        color: isMarkedForReview
                            ? AppColors.warning
                            : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Question text
          Text(
            question.text,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 17,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          // Answer options
          if (question.type == QuestionType.mcq && question.options != null)
            ...question.options!.asMap().entries.map((entry) {
              final optionLabel = String.fromCharCode(65 + entry.key);
              final isSelected = selectedAnswer == entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => onAnswerSelected(entry.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              optionLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMedium,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: AppTypography.bodyLarge.copyWith(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textDark,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          // Numerical input
          if (question.type == QuestionType.numerical)
            TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => onAnswerSelected(value),
              decoration: InputDecoration(
                hintText: 'Enter your answer',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              style: AppTypography.heading3,
            ),
        ],
      ),
    );
  }

  Color get _difficultyColor => switch (question.difficulty) {
    Difficulty.easy => AppColors.success,
    Difficulty.medium => AppColors.warning,
    Difficulty.hard => AppColors.error,
  };
}
