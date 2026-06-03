import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/progress_circle.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../shared/models/enums.dart';
import '../data/analytics_providers.dart';
import '../domain/analytics_models.dart';

// AI Analytics Engine Output — Visual Dashboard (now data-driven)
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
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
        automaticallyImplyLeading: false,
        title: const Text('Analytics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(color: AppColors.slate900.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                    BoxShadow(color: AppColors.slate900.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.textDark,
                unselectedLabelColor: AppColors.textMedium,
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

// Tab 1: Overview — real data from providers
class _OverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final masteryAsync = ref.watch(subjectMasteryProvider);

    final stats = statsAsync.valueOrNull ?? {};
    final mastery = masteryAsync.valueOrNull ?? {};

    final testsTaken = stats['tests_taken'] ?? 0;
    final avgScore = (stats['avg_score'] as num?)?.toDouble() ?? 0;
    final streak = stats['current_streak'] ?? 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score summary row
          Row(
            children: [
              Expanded(child: _MetricCard(label: 'Tests Taken', value: '$testsTaken', icon: LucideIcons.fileCheck, color: AppColors.primary, bg: AppColors.greenSurface)),
              const SizedBox(width: 10),
              Expanded(child: _MetricCard(label: 'Avg Score', value: '${avgScore.round()}%', icon: LucideIcons.star, color: AppColors.mathematics, bg: AppColors.warningLight)),
              const SizedBox(width: 10),
              Expanded(child: _MetricCard(label: 'Study Streak', value: '${streak}d', icon: LucideIcons.flame, color: AppColors.weak, bg: AppColors.warningLight)),
            ],
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
                  _SubjectCircle(
                    label: 'Physics',
                    progress: mastery['physics'] ?? 0,
                    type: SubjectType.physics,
                    color: AppColors.physics,
                  ),
                  _SubjectCircle(
                    label: 'Chemistry',
                    progress: mastery['chemistry'] ?? 0,
                    type: SubjectType.chemistry,
                    color: AppColors.chemistry,
                  ),
                  _SubjectCircle(
                    label: 'Maths',
                    progress: mastery['mathematics'] ?? 0,
                    type: SubjectType.mathematics,
                    color: AppColors.mathematics,
                  ),
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

// Tab 2: Topics — real weak/strong topics from providers
class _TopicsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weakAsync = ref.watch(weakTopicsProvider);
    final strongAsync = ref.watch(strongTopicsProvider);

    final weakTopics = weakAsync.valueOrNull ?? [];
    final strongTopics = strongAsync.valueOrNull ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weak topics
          _SectionCard(
            title: 'Weak Topics',
            subtitle: weakTopics.isEmpty
                ? 'No weak topics detected yet'
                : 'AI-detected areas to focus on',
            icon: LucideIcons.alertTriangle,
            iconColor: AppColors.wrong,
            iconBg: AppColors.errorLight,
            child: weakTopics.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Take a test to see your weak areas',
                      style: AppTypography.bodyMedium,
                    ),
                  )
                : Column(
                    children: weakTopics.take(5).map((t) {
                      final score = (t.accuracy * 100).round();
                      final color = score < 35 ? AppColors.wrong : AppColors.weak;
                      return _TopicBar(
                        name: _topicDisplayName(t.topicId),
                        subject: _subjectName(t.subjectId),
                        score: score,
                        color: color,
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 14),

          // Strong topics
          _SectionCard(
            title: 'Strong Topics',
            subtitle: strongTopics.isEmpty
                ? 'No mastered topics yet'
                : 'Topics you\'ve mastered',
            icon: LucideIcons.checkCircle2,
            iconColor: AppColors.primary,
            iconBg: AppColors.greenSurface,
            child: strongTopics.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Keep practicing to master topics',
                      style: AppTypography.bodyMedium,
                    ),
                  )
                : Column(
                    children: strongTopics.take(5).map((t) {
                      final score = (t.accuracy * 100).round();
                      return _TopicBar(
                        name: _topicDisplayName(t.topicId),
                        subject: _subjectName(t.subjectId),
                        score: score,
                        color: AppColors.primary,
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _topicDisplayName(String topicId) {
    final parts = topicId.split('_');
    if (parts.length >= 3) {
      return parts.sublist(2).map((s) {
        if (s.isEmpty) return s;
        return s[0].toUpperCase() + s.substring(1);
      }).join(' ');
    }
    return topicId;
  }

  String _subjectName(String id) {
    switch (id) {
      case 'physics': return 'Physics';
      case 'chemistry': return 'Chemistry';
      case 'mathematics': return 'Mathematics';
      default: return id;
    }
  }
}

// Tab 3: Trends — real score history + streak data
class _TrendsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(scoreHistoryProvider);
    final streakAsync = ref.watch(studyStreakProvider);

    final history = historyAsync.valueOrNull ?? [];
    final streak = streakAsync.valueOrNull ?? const StudyStreak();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Score trend chart
          _SectionCard(
            title: 'Score Trend',
            subtitle: history.isEmpty
                ? 'Take tests to see your progress'
                : 'Progress over ${history.length} tests',
            icon: LucideIcons.trendingUp,
            child: history.length < 2
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.greenWash,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.lineChart, size: 20, color: AppColors.primary),
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
                  )
                : Padding(
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
                                  final i = v.toInt();
                                  if (i < 0 || i >= history.length) return const SizedBox.shrink();
                                  final date = history[i].completedAt;
                                  final label = '${date.day}/${date.month}';
                                  return Text(label, style: AppTypography.caption.copyWith(fontSize: 9));
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
                              spots: List.generate(
                                history.length,
                                (i) => FlSpot(i.toDouble(), history[i].scorePercentage.clamp(0, 100)),
                              ),
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

          // Consistency patterns (real streak data)
          _SectionCard(
            title: 'Consistency Patterns',
            subtitle: 'Study activity over last 30 days',
            icon: LucideIcons.calendar,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _ConsistencyGrid(recentActivity: streak.recentActivity),
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
        boxShadow: [
          BoxShadow(color: AppColors.slate900.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 6)),
          BoxShadow(color: AppColors.slate900.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
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
        boxShadow: [
          BoxShadow(color: AppColors.slate900.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4)),
          BoxShadow(color: AppColors.slate900.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
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

class _TopicBar extends StatelessWidget {
  final String name, subject;
  final int score;
  final Color color;

  const _TopicBar({required this.name, required this.subject, required this.score, required this.color});

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
                    Text(name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500, fontSize: 14)),
                    Text(subject, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('$score%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: val,
                minHeight: 5,
                backgroundColor: AppColors.surfaceDark,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Consistency grid using real activity data
class _ConsistencyGrid extends StatelessWidget {
  final List<DayActivity> recentActivity;
  const _ConsistencyGrid({required this.recentActivity});

  @override
  Widget build(BuildContext context) {
    // Build a 30-day grid
    final now = DateTime.now();
    final activityMap = <String, int>{};
    for (final a in recentActivity) {
      activityMap[a.date.toIso8601String().split('T').first] = a.testsTaken;
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(30, (i) {
        final date = now.subtract(Duration(days: 29 - i));
        final dateStr = date.toIso8601String().split('T').first;
        final tests = activityMap[dateStr] ?? 0;
        final intensity = tests == 0 ? 0.0 : (tests >= 3 ? 0.9 : tests >= 2 ? 0.6 : 0.3);

        return Tooltip(
          message: '$dateStr: $tests tests',
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: intensity == 0
                  ? AppColors.surfaceDark
                  : AppColors.primary.withValues(alpha: intensity),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
