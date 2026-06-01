import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/axio_card.dart';
import '../../../core/widgets/progress_circle.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../shared/models/enums.dart';

/// Detailed analytics screen — accessible from Profile > Detailed Analytics.
/// Not a tab anymore, it's a deep-linked page.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Detailed Analytics'),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Progress', style: AppTypography.heading1),
            const SizedBox(height: 4),
            Text('Track your improvement over time', style: AppTypography.bodyMedium),
            const SizedBox(height: 20),
            // Summary row
            Row(
              children: [
                Expanded(child: _SummaryCard(label: 'Tests', value: '24', icon: LucideIcons.fileCheck, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _SummaryCard(label: 'Avg Score', value: '72%', icon: LucideIcons.star, color: AppColors.secondary)),
                const SizedBox(width: 12),
                Expanded(child: _SummaryCard(label: 'Streak', value: '7', icon: LucideIcons.flame, color: AppColors.mathematics)),
              ],
            ),
            const SizedBox(height: 16),
            // Score trend chart
            AxioCard(
              title: 'Score Trend',
              initiallyExpanded: true,
              expandedContent: SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (v) =>
                          FlLine(color: AppColors.divider, strokeWidth: 0.5),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 25,
                          getTitlesWidget: (v, _) => Text(
                            '${v.toInt()}',
                            style: AppTypography.caption.copyWith(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            final labels = ['Apr 1', 'Apr 8', 'Apr 15', 'Apr 22', 'Apr 29', 'May 5'];
                            final i = v.toInt();
                            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                            return Text(labels[i], style: AppTypography.caption.copyWith(fontSize: 9));
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 45),
                          FlSpot(1, 52),
                          FlSpot(2, 48),
                          FlSpot(3, 58),
                          FlSpot(4, 65),
                          FlSpot(5, 72.5),
                        ],
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (_, a, b, c) => FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.primary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.15),
                              AppColors.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Subject comparison
            AxioCard(
              title: 'Subject Comparison',
              initiallyExpanded: true,
              expandedContent: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SubjectCircle(
                    label: 'Physics',
                    progress: 0.65,
                    iconData: SubjectType.physics.iconData,
                    color: AppColors.physics,
                  ),
                  _SubjectCircle(
                    label: 'Chemistry',
                    progress: 0.58,
                    iconData: SubjectType.chemistry.iconData,
                    color: AppColors.chemistry,
                  ),
                  _SubjectCircle(
                    label: 'Maths',
                    progress: 0.72,
                    iconData: SubjectType.mathematics.iconData,
                    color: AppColors.mathematics,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.heading3),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _SubjectCircle extends StatelessWidget {
  final String label;
  final double progress;
  final IconData iconData;
  final Color color;

  const _SubjectCircle({
    required this.label,
    required this.progress,
    required this.iconData,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ProgressCircle(
          progress: progress,
          size: 80,
          strokeWidth: 7,
          progressColor: color,
          centerWidget: Icon(iconData, size: 24, color: color),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTypography.bodyMedium),
        Text(
          '${(progress * 100).round()}%',
          style: AppTypography.heading3.copyWith(color: color),
        ),
      ],
    );
  }
}
