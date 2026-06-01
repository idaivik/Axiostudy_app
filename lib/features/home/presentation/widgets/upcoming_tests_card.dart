import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';

class UpcomingTestsCard extends StatelessWidget {
  const UpcomingTestsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AxioCard(
      title: 'Upcoming Tests',
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.event_rounded, color: AppColors.secondary, size: 22),
      ),
      collapsedContent: Row(
        children: [
          const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textLight),
          const SizedBox(width: 4),
          Text('Mock Test in 2 days', style: AppTypography.bodyMedium),
        ],
      ),
      expandedContent: Column(
        children: [
          _TestItem(
            title: 'JEE Full Mock Test #5',
            subtitle: '90 questions • 3 hours',
            date: 'May 9, 2026',
            isNext: true,
          ),
          const SizedBox(height: 10),
          _TestItem(
            title: 'Physics Practice Test',
            subtitle: '30 questions • 1 hour',
            date: 'May 12, 2026',
            isNext: false,
          ),
          const SizedBox(height: 10),
          _TestItem(
            title: 'Chemistry Mock Test',
            subtitle: '30 questions • 1 hour',
            date: 'May 15, 2026',
            isNext: false,
          ),
        ],
      ),
    );
  }
}

class _TestItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final bool isNext;

  const _TestItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNext ? AppColors.primarySurface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: isNext
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: isNext ? AppColors.primary : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: AppTypography.caption),
              ],
            ),
          ),
          Text(date, style: AppTypography.caption),
        ],
      ),
    );
  }
}
