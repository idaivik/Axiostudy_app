import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/chart_data_models.dart';

/// Premium Area Line Chart for score trends with gradient fill,
/// smooth monotone curve, scrubbable crosshair, and floating tooltip.
class AreaLineChartWidget extends StatefulWidget {
  final List<TrendDataPoint> data;
  final double height;

  const AreaLineChartWidget({
    super.key,
    required this.data,
    this.height = 220,
  });

  @override
  State<AreaLineChartWidget> createState() => _AreaLineChartWidgetState();
}

class _AreaLineChartWidgetState extends State<AreaLineChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.greenWash,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Take at least 2 tests to see your score trend',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        // Animate by showing only a portion of the data
        final visibleCount = (_animation.value * widget.data.length).ceil().clamp(2, widget.data.length);
        final visibleData = widget.data.sublist(0, visibleCount);

        return SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.slate900.withValues(alpha: 0.04),
                  strokeWidth: 0.5,
                  dashArray: [6, 4],
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 25,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= widget.data.length) {
                        return const SizedBox.shrink();
                      }
                      // Show every other label to avoid crowding
                      if (widget.data.length > 6 && i % 2 != 0 && i != widget.data.length - 1) {
                        return const SizedBox.shrink();
                      }
                      final date = widget.data[i].date;
                      final label = '${date.day}/${date.month}';
                      return Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLight,
                        ),
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
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.slate900,
                  tooltipRoundedRadius: 10,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final i = spot.x.toInt();
                      final d = i >= 0 && i < widget.data.length ? widget.data[i] : null;
                      final dateStr = d != null
                          ? '${d.date.day}/${d.date.month}/${d.date.year}'
                          : '';
                      final testName = d?.testName ?? '';
                      return LineTooltipItem(
                        '${spot.y.round()}%',
                        const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(
                            text: '\n$dateStr',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          if (testName.isNotEmpty)
                            TextSpan(
                              text: '\n$testName',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      );
                    }).toList();
                  },
                ),
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                          radius: 6,
                          color: AppColors.primary,
                          strokeWidth: 2.5,
                          strokeColor: AppColors.white,
                        ),
                      ),
                    );
                  }).toList();
                },
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    visibleCount,
                    (i) => FlSpot(
                      i.toDouble(),
                      visibleData[i].score.clamp(0, 100),
                    ),
                  ),
                  isCurved: true,
                  curveSmoothness: 0.35,
                  preventCurveOverShooting: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                      radius: 3.5,
                      color: AppColors.white,
                      strokeWidth: 2,
                      strokeColor: AppColors.primary,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.20),
                        AppColors.primary.withValues(alpha: 0.02),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          ),
        );
      },
    );
  }
}

/// Reused AnimatedBuilder pattern.
class _AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const _AnimatedBuilder({
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
