import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../analytics/data/analytics_providers.dart';

/// Compact score trends card showing recent performance.
/// Collapsed: headline improvement stat + mini sparkline.
/// Expanded: full chart with test history.
class ScoreTrendsCard extends ConsumerStatefulWidget {
  const ScoreTrendsCard({super.key});

  @override
  ConsumerState<ScoreTrendsCard> createState() => _ScoreTrendsCardState();
}

class _ScoreTrendsCardState extends ConsumerState<ScoreTrendsCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

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
    final historyAsync = ref.watch(scoreHistoryProvider);
    final history = historyAsync.valueOrNull ?? [];

    // If no history, show empty state
    if (history.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.greenSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.trendingUp, color: AppColors.primary, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Performance', style: AppTypography.heading3),
                  const SizedBox(height: 2),
                  Text('Take a test to see your trends', style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final latestScore = history.last.scorePercentage;
    final firstScore = history.first.scorePercentage;
    final improvement = latestScore - firstScore;

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
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
                              '${improvement >= 0 ? '+' : ''}${improvement.round()}%',
                              style: AppTypography.bodyMedium.copyWith(
                                color: improvement >= 0 ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              ' over ${history.length} tests',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Mini sparkline
                  if (history.length >= 2)
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
                                (i) => FlSpot(i.toDouble(), history[i].scorePercentage.clamp(0, 100)),
                              ),
                              isCurved: true,
                              color: improvement >= 0 ? AppColors.success : AppColors.error,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    (improvement >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                                    (improvement >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.0),
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
                                  if (idx < 0 || idx >= history.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final date = history[idx].completedAt;
                                  return Text(
                                    '${date.day}/${date.month}',
                                    style: AppTypography.caption.copyWith(fontSize: 10),
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
                                (i) => FlSpot(i.toDouble(), history[i].scorePercentage.clamp(0, 100)),
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
