import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Compact score trends card showing recent performance.
/// Collapsed: headline improvement stat + mini sparkline.
/// Expanded: full chart with test history.
class ScoreTrendsCard extends StatefulWidget {
  const ScoreTrendsCard({super.key});

  @override
  State<ScoreTrendsCard> createState() => _ScoreTrendsCardState();
}

class _ScoreTrendsCardState extends State<ScoreTrendsCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  // TODO: Replace with real test attempt history from Supabase once enough data exists
  static final List<Map<String, dynamic>> _scoreHistory = [
    {'date': '1 Apr', 'score': 45.0},
    {'date': '8 Apr', 'score': 52.0},
    {'date': '15 Apr', 'score': 48.0},
    {'date': '22 Apr', 'score': 58.0},
    {'date': '29 Apr', 'score': 65.0},
    {'date': '5 May', 'score': 72.5},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      _isExpanded ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = _scoreHistory;
    final latestScore = history.last['score'] as double;
    final firstScore = history.first['score'] as double;
    final improvement = latestScore - firstScore;

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Collapsed content — always visible
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.greenSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.trendingUp,
                      color: AppColors.primary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Performance',
                          style: AppTypography.heading3,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '+${improvement.round()}%',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              ' improvement over ${history.length} tests',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Mini sparkline
                  SizedBox(
                    width: 60,
                    height: 30,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minY: 30,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              history.length,
                              (i) => FlSpot(
                                i.toDouble(),
                                (history[i]['score'] as double),
                              ),
                            ),
                            isCurved: true,
                            color: AppColors.success,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.success.withValues(alpha: 0.15),
                                  AppColors.success.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                        lineTouchData: const LineTouchData(enabled: false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded content — full chart
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      color: AppColors.divider.withValues(alpha: 0.5),
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: SizedBox(
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
                                  style: AppTypography.caption
                                      .copyWith(fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= history.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    history[idx]['date'] as String,
                                    style: AppTypography.caption
                                        .copyWith(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                history.length,
                                (i) => FlSpot(
                                  i.toDouble(),
                                  (history[i]['score'] as double),
                                ),
                              ),
                              isCurved: true,
                              color: AppColors.primary,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, xPercentage, bar,
                                        index) =>
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
