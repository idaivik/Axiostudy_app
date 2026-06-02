import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';

class TimeAnalysisCard extends StatelessWidget {
  final double? avgTimeMinutes;
  final double? fastestTimeMinutes;
  final double? slowestTimeMinutes;
  final String? bottleneckMessage;

  const TimeAnalysisCard({
    super.key,
    this.avgTimeMinutes,
    this.fastestTimeMinutes,
    this.slowestTimeMinutes,
    this.bottleneckMessage,
  });

  @override
  Widget build(BuildContext context) {
    final avg = avgTimeMinutes ?? 0;
    final fastest = fastestTimeMinutes ?? 0;
    final slowest = slowestTimeMinutes ?? 0;

    return AxioCard(
      title: 'Time Analysis',
      leading: Icon(Icons.timer_rounded, color: AppColors.physics, size: 22),
      collapsedContent: Text(
        'Avg ${avg.toStringAsFixed(1)} min/question',
        style: AppTypography.bodyMedium,
      ),
      expandedContent: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeStatItem(label: 'Avg Time', value: '${avg.toStringAsFixed(1)} min', icon: Icons.schedule_rounded),
              _TimeStatItem(label: 'Fastest', value: '${fastest.toStringAsFixed(1)} min', icon: Icons.speed_rounded),
              _TimeStatItem(label: 'Slowest', value: '${slowest.toStringAsFixed(1)} min', icon: Icons.hourglass_bottom_rounded),
            ],
          ),
          if (bottleneckMessage != null) ...[
            const SizedBox(height: 16),
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
                      bottleneckMessage!,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
