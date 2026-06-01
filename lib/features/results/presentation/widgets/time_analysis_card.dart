import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';

class TimeAnalysisCard extends StatelessWidget {
  const TimeAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AxioCard(
      title: 'Time Analysis',
      leading: Icon(Icons.timer_rounded, color: AppColors.physics, size: 22),
      collapsedContent: Text('Avg 2.1 min/question', style: AppTypography.bodyMedium),
      expandedContent: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeStatItem(label: 'Avg Time', value: '2.1 min', icon: Icons.schedule_rounded),
              _TimeStatItem(label: 'Fastest', value: '0.8 min', icon: Icons.speed_rounded),
              _TimeStatItem(label: 'Slowest', value: '4.2 min', icon: Icons.hourglass_bottom_rounded),
            ],
          ),
          const SizedBox(height: 16),
          // Bottleneck
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Spent 3.75 min on Q3 (Moment of Inertia) — consider reviewing this topic',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _TimeStatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.physics, size: 24),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.heading3),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
