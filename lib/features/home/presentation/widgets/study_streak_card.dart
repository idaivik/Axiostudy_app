import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';
import '../../../../core/widgets/progress_bar.dart';

class StudyStreakCard extends StatelessWidget {
  const StudyStreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AxioCard(
      title: '🔥 7 Day Streak',
      subtitle: 'Keep it going!',
      collapsedContent: const ProgressBar(progress: 0.7, height: 6),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Activity', style: AppTypography.bodyMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
              final isActive = e.key < 7; // all 7 days active
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.15 + (e.key * 0.12))
                          : AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: isActive
                          ? Icon(Icons.check, size: 16, color: AppColors.primary)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.value,
                    style: AppTypography.caption.copyWith(fontSize: 10),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(label: 'Best Streak', value: '14 days'),
              const SizedBox(width: 24),
              _StatItem(label: 'Total Active', value: '45 days'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.heading3),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
