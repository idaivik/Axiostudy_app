import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';
import '../../../../shared/data/mock_data.dart';

class ScoreTrendsCard extends StatelessWidget {
  const ScoreTrendsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AxioCard(
      title: 'Test Score',
      subtitle: 'Last 6 tests',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '+35%',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      collapsedContent: Row(
        children: [
          Text(
            '72.5%',
            style: AppTypography.numberMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text('latest score', style: AppTypography.caption),
        ],
      ),
      expandedContent: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.divider,
                strokeWidth: 0.5,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 20,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}',
                    style: AppTypography.caption.copyWith(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= MockData.scoreHistory.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      MockData.scoreHistory[idx]['date'] as String,
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    );
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
                spots: List.generate(
                  MockData.scoreHistory.length,
                  (i) => FlSpot(
                    i.toDouble(),
                    (MockData.scoreHistory[i]['score'] as double),
                  ),
                ),
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, xPercentage, bar, index) =>
                      FlDotCirclePainter(
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
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
