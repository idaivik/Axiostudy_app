import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/chart_data_models.dart';

/// Apple-inspired Scatter Plot showing Speed vs. Accuracy
/// across topics, with semantic quadrant coloring.
class ScatterPlotWidget extends StatefulWidget {
  final List<ScatterDataPoint> data;
  final double height;

  const ScatterPlotWidget({
    super.key,
    required this.data,
    this.height = 280,
  });

  @override
  State<ScatterPlotWidget> createState() => _ScatterPlotWidgetState();
}

class _ScatterPlotWidgetState extends State<ScatterPlotWidget> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Complete more topics to see speed vs. accuracy analysis',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Compute axis ranges
    final maxTime = widget.data
        .map((d) => d.avgTimeSeconds)
        .reduce((a, b) => a > b ? a : b);
    final timeUpperBound = (maxTime * 1.3).clamp(30.0, 300.0);
    final timeMidpoint = timeUpperBound / 2;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // Quadrant labels (drawn behind chart)
          _QuadrantLabels(timeMidpoint: timeMidpoint, timeMax: timeUpperBound),
          // The chart itself
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ScatterChart(
              ScatterChartData(
                minX: 0,
                maxX: timeUpperBound,
                minY: 0,
                maxY: 1.0,
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  horizontalInterval: 0.5,
                  verticalInterval: timeMidpoint,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: value == 0.5
                        ? AppColors.slate900.withValues(alpha: 0.08)
                        : AppColors.slate900.withValues(alpha: 0.03),
                    strokeWidth: value == 0.5 ? 1.0 : 0.5,
                    dashArray: value == 0.5 ? null : [4, 4],
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: (value - timeMidpoint).abs() < 1
                        ? AppColors.slate900.withValues(alpha: 0.08)
                        : AppColors.slate900.withValues(alpha: 0.03),
                    strokeWidth: (value - timeMidpoint).abs() < 1 ? 1.0 : 0.5,
                    dashArray: (value - timeMidpoint).abs() < 1 ? null : [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: Text('Accuracy',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textLight)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 0.25,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${(v * 100).toInt()}%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textLight),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text('Avg. Time (s)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textLight)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: timeMidpoint,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}s',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textLight),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                scatterSpots: widget.data.asMap().entries.map((entry) {
                  final i = entry.key;
                  final d = entry.value;
                  final isTouched = _touchedIndex == i;
                  return ScatterSpot(
                    d.avgTimeSeconds,
                    d.accuracy,
                    dotPainter: FlDotCirclePainter(
                      radius: isTouched ? 8.0 : 6.0,
                      color: _colorForQuadrant(d.quadrant),
                      strokeWidth: 2,
                      strokeColor: AppColors.white,
                    ),
                  );
                }).toList(),
                scatterTouchData: ScatterTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent || event is FlLongPressStart) {
                      setState(() {
                        _touchedIndex = response?.touchedSpot?.spotIndex;
                      });
                    } else if (event is FlTapCancelEvent || event is FlLongPressEnd) {
                      setState(() => _touchedIndex = null);
                    }
                  },
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipColor: (_) => AppColors.slate900,
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItems: (touchedSpot) {
                      // Find matching data point by coordinates
                      final d = widget.data.cast<ScatterDataPoint?>().firstWhere(
                        (d) => d != null &&
                            (d.avgTimeSeconds - touchedSpot.x).abs() < 0.01 &&
                            (d.accuracy - touchedSpot.y).abs() < 0.01,
                        orElse: () => null,
                      );
                      if (d == null) return null;
                      return ScatterTooltipItem(
                        '',
                        children: [
                          TextSpan(
                            text: d.topicName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: '\n${(d.accuracy * 100).round()}% · ${d.avgTimeSeconds.round()}s',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForQuadrant(ScatterQuadrant q) => switch (q) {
    ScatterQuadrant.mastered => AppColors.primary,
    ScatterQuadrant.slowButSteady => AppColors.chemistry,
    ScatterQuadrant.guessing => AppColors.warning,
    ScatterQuadrant.needsReview => AppColors.wrong,
  };
}

/// Faint quadrant labels rendered behind the chart.
class _QuadrantLabels extends StatelessWidget {
  final double timeMidpoint;
  final double timeMax;

  const _QuadrantLabels({required this.timeMidpoint, required this.timeMax});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textLight.withValues(alpha: 0.3),
      letterSpacing: 0.5,
    );

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(46, 24, 8, 36),
        child: Stack(
          children: [
            // Top-left: Slow but Steady
            Align(
              alignment: const Alignment(-0.85, -0.85),
              child: Text('SLOW BUT STEADY', style: style),
            ),
            // Top-right: Mastered
            Align(
              alignment: const Alignment(0.85, -0.85),
              child: Text('MASTERED', style: style),
            ),
            // Bottom-left: Needs Review
            Align(
              alignment: const Alignment(-0.85, 0.85),
              child: Text('NEEDS REVIEW', style: style),
            ),
            // Bottom-right: Guessing
            Align(
              alignment: const Alignment(0.85, 0.85),
              child: Text('GUESSING', style: style),
            ),
          ],
        ),
      ),
    );
  }
}
