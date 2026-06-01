import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/progress_circle.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../shared/models/enums.dart';

// AI Analytics Engine Output — Visual Dashboard
// Processing Layer: Score Calculation, Topic-wise Analysis, Difficulty Pattern Detection,
// Trend Analysis, Comparison with Peers
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Analytics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: AppColors.slate900.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.textDark,
                unselectedLabelColor: AppColors.textLight,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Topics'),
                  Tab(text: 'Trends'),
                ],
              ),
            ),
          ),
        ),
      ),
      child: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(),
          _TopicsTab(),
          _TrendsTab(),
        ],
      ),
    );
  }
}

// Tab 1: Overview — Score Calculation output + Comparison with Peers
class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score summary row
          Row(
            children: [
              Expanded(child: _MetricCard(label: 'Tests Taken', value: '24', icon: LucideIcons.fileCheck, color: AppColors.primary, bg: AppColors.greenSurface)),
              const SizedBox(width: 10),
              Expanded(child: _MetricCard(label: 'Avg Score', value: '72%', icon: LucideIcons.star, color: AppColors.mathematics, bg: AppColors.warningLight)),
              const SizedBox(width: 10),
              Expanded(child: _MetricCard(label: 'Study Streak', value: '7d', icon: LucideIcons.flame, color: AppColors.weak, bg: AppColors.warningLight)),
            ],
          ),
          const SizedBox(height: 14),

          // Percentile — Score Calculation output
          _SectionCard(
            title: 'Percentile Rank',
            subtitle: 'Comparison with Peers',
            icon: LucideIcons.award,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PercentileCircle(label: 'Overall', percentile: 82, color: AppColors.primary),
                    _PercentileCircle(label: 'Physics', percentile: 91, color: AppColors.physics),
                    _PercentileCircle(label: 'Chemistry', percentile: 67, color: AppColors.chemistry),
                    _PercentileCircle(label: 'Maths', percentile: 88, color: AppColors.mathematics),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.greenWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.trendingUp, size: 16, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You scored higher than 82% of students who took this test',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.greenStrong),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Subject comparison circles
          _SectionCard(
            title: 'Subject Mastery',
            subtitle: 'Topic mastery percentage',
            icon: LucideIcons.pieChart,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SubjectCircle(label: 'Physics', progress: 0.65, type: SubjectType.physics, color: AppColors.physics),
                  _SubjectCircle(label: 'Chemistry', progress: 0.58, type: SubjectType.chemistry, color: AppColors.chemistry),
                  _SubjectCircle(label: 'Maths', progress: 0.72, type: SubjectType.mathematics, color: AppColors.mathematics),
                ],
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// Tab 2: Topics — Topic-wise Analysis + Difficulty Pattern Detection
class _TopicsTab extends StatelessWidget {
  final _weakTopics = const [
    _Topic('Electrochemistry', 'Chemistry', 32, AppColors.wrong),
    _Topic('Rotational Dynamics', 'Physics', 41, AppColors.weak),
    _Topic('Matrices & Determinants', 'Mathematics', 45, AppColors.weak),
    _Topic('Thermodynamics 2nd Law', 'Physics', 48, AppColors.weak),
  ];

  final _strongTopics = const [
    _Topic('Thermodynamics', 'Physics', 89, AppColors.primary),
    _Topic('Organic Chemistry', 'Chemistry', 82, AppColors.primary),
    _Topic('Calculus', 'Mathematics', 78, AppColors.primary),
    _Topic('Optics', 'Physics', 76, AppColors.primary),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Heat map — Difficulty Pattern Detection
          _SectionCard(
            title: 'Performance Heat Map',
            subtitle: 'Easy questions missed vs. Difficult questions aced',
            icon: LucideIcons.layoutGrid,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _HeatMap(),
            ),
          ),
          const SizedBox(height: 14),

          // Weak topics
          _SectionCard(
            title: 'Weak Topics',
            subtitle: 'AI-detected areas to focus on',
            icon: LucideIcons.alertTriangle,
            iconColor: AppColors.wrong,
            iconBg: AppColors.errorLight,
            child: Column(
              children: _weakTopics.map((t) => _TopicBar(topic: t)).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Strong topics
          _SectionCard(
            title: 'Strong Topics',
            subtitle: 'Topics you\'ve mastered',
            icon: LucideIcons.checkCircle2,
            iconColor: AppColors.primary,
            iconBg: AppColors.greenSurface,
            child: Column(
              children: _strongTopics.map((t) => _TopicBar(topic: t)).toList(),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// Tab 3: Trends — Trend Analysis + Progress over time
class _TrendsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Score trend — Progress over time
          _SectionCard(
            title: 'Score Trend',
            subtitle: 'Progress over time',
            icon: LucideIcons.trendingUp,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 0.5),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 25,
                          getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppTypography.caption.copyWith(fontSize: 10)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            const labels = ['Apr 1', 'Apr 8', 'Apr 15', 'Apr 22', 'Apr 29', 'May 5'];
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
                    minY: 0, maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [FlSpot(0, 45), FlSpot(1, 52), FlSpot(2, 48), FlSpot(3, 58), FlSpot(4, 65), FlSpot(5, 72.5)],
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                            radius: 4, color: AppColors.primary,
                            strokeWidth: 2, strokeColor: AppColors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.0)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Consistency patterns
          _SectionCard(
            title: 'Consistency Patterns',
            subtitle: 'Study activity over last 30 days',
            icon: LucideIcons.calendar,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _ConsistencyGrid(),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Reusable Components ───

class _SectionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color? iconColor, iconBg;
  final Widget child;

  const _SectionCard({
    required this.title, required this.subtitle,
    required this.icon, required this.child,
    this.iconColor, this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(color: AppColors.slate900.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconBg ?? AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? AppColors.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.heading3),
                    Text(subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, bg;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [BoxShadow(color: AppColors.slate900.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.heading3),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _PercentileCircle extends StatelessWidget {
  final String label;
  final int percentile;
  final Color color;

  const _PercentileCircle({required this.label, required this.percentile, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: percentile / 100),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) => ProgressCircle(
            progress: val,
            size: 64,
            strokeWidth: 6,
            progressColor: color,
            centerWidget: Text(
              '${(val * 100).round()}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SubjectCircle extends StatelessWidget {
  final String label;
  final double progress;
  final SubjectType type;
  final Color color;

  const _SubjectCircle({required this.label, required this.progress, required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) => ProgressCircle(
            progress: val,
            size: 80,
            strokeWidth: 7,
            progressColor: color,
            centerWidget: Icon(type.iconData, size: 22, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        Text('${(progress * 100).round()}%', style: AppTypography.heading3.copyWith(color: color, fontSize: 15)),
      ],
    );
  }
}

class _Topic {
  final String name, subject;
  final int score;
  final Color color;
  const _Topic(this.name, this.subject, this.score, this.color);
}

class _TopicBar extends StatelessWidget {
  final _Topic topic;
  const _TopicBar({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500, fontSize: 14)),
                    Text(topic.subject, style: AppTypography.caption.copyWith(color: topic.color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('${topic.score}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: topic.color)),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: topic.score / 100),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: val,
                minHeight: 5,
                backgroundColor: AppColors.surfaceDark,
                valueColor: AlwaysStoppedAnimation<Color>(topic.color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Heat map for difficulty pattern detection
class _HeatMap extends StatelessWidget {
  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _data = [
    [0.9, 0.6, 0.3, 0.7, 0.8, 0.4, 0.2],
    [0.5, 0.9, 0.7, 0.3, 0.6, 0.8, 0.9],
    [0.2, 0.4, 0.8, 0.9, 0.5, 0.7, 0.6],
    [0.8, 0.3, 0.6, 0.4, 0.9, 0.2, 0.7],
  ];
  static const _rowLabels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 52),
            ..._labels.map((l) => Expanded(
              child: Text(l, textAlign: TextAlign.center, style: AppTypography.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600)),
            )),
          ],
        ),
        const SizedBox(height: 6),
        ..._data.asMap().entries.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(_rowLabels[row.key], style: AppTypography.caption.copyWith(fontSize: 10)),
              ),
              ...row.value.map((val) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: val * 0.85),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              )),
            ],
          ),
        )),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: AppTypography.caption.copyWith(fontSize: 10)),
            const SizedBox(width: 6),
            ...List.generate(5, (i) => Container(
              width: 14, height: 14,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: (i + 1) * 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
            const SizedBox(width: 4),
            Text('More', style: AppTypography.caption.copyWith(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

// Consistency grid (GitHub-style)
class _ConsistencyGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(30, (i) {
        final intensity = (i % 7 == 0 || i % 3 == 0) ? 0.0 : ((i % 5 == 0) ? 0.8 : (i % 2 == 0 ? 0.5 : 0.3));
        return Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: intensity == 0
                ? AppColors.surfaceDark
                : AppColors.primary.withValues(alpha: intensity),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
