import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/progress_circle.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/router/swipe_nav_provider.dart';
import '../../../shared/models/enums.dart';
import '../data/analytics_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/analytics_models.dart';
import 'widgets/radar_chart_widget.dart';
import 'widgets/scatter_plot_widget.dart';
import 'widgets/skill_tree_widget.dart';
import 'widgets/area_line_chart_widget.dart';
import 'widgets/strength_meter_card.dart';
import '../domain/chart_data_models.dart';

// AI Analytics Engine Output — Visual Dashboard (now data-driven)
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _ignoreTabListener = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || _ignoreTabListener) return;
    // User tapped a tab manually — update global index
    // Analytics tabs map to global indices 3, 4, 5
    ref.read(swipeNavProvider.notifier).setGlobalIndex(3 + _tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to swipe nav state and sync tab controller
    ref.listen<SwipeNavState>(swipeNavProvider, (prev, next) {
      if (next.navIndex != 2) return; // Only care about Analytics section
      final targetTab = next.analyticsTabIndex;
      if (_tabController.index != targetTab) {
        _ignoreTabListener = true;
        _tabController.animateTo(targetTab);
        Future.delayed(const Duration(milliseconds: 350), () {
          _ignoreTabListener = false;
        });
      }
    });

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
        physics: const NeverScrollableScrollPhysics(),
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

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(userStatsProvider);
        ref.invalidate(subjectMasteryProvider);
        ref.invalidate(topicPerformanceProvider);
        ref.invalidate(currentUserProvider);
        ref.invalidate(scoreHistoryProvider);
        ref.invalidate(studyStreakProvider);
        await ref.read(userStatsProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
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
      ),
    );
  }
}

// Tab 2: Topics — Radar Chart + Weak/Strong Topics + Skill Tree
class _TopicsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weakAsync = ref.watch(weakTopicsProvider);
    final strongAsync = ref.watch(strongTopicsProvider);
    final radarAsync = ref.watch(radarChartDataProvider);
    final skillTreePhysics = ref.watch(skillTreeDataProvider('physics'));
    final skillTreeChemistry = ref.watch(skillTreeDataProvider('chemistry'));
    final skillTreeMaths = ref.watch(skillTreeDataProvider('mathematics'));

    final weakTopics = weakAsync.valueOrNull ?? [];
    final strongTopics = strongAsync.valueOrNull ?? [];
    final radarData = radarAsync.valueOrNull ?? [];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(topicPerformanceProvider);
        ref.invalidate(weakTopicsProvider);
        ref.invalidate(strongTopicsProvider);
        ref.invalidate(radarChartDataProvider);
        ref.invalidate(skillTreeDataProvider('physics'));
        ref.invalidate(skillTreeDataProvider('chemistry'));
        ref.invalidate(skillTreeDataProvider('mathematics'));
        await ref.read(topicPerformanceProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─── Subject Strength (per-subject + chapter-level mastery) ───
          const StrengthMeterCard(),
          const SizedBox(height: 8),

          // ─── Radar Chart ───
          _SectionCard(
            title: 'Mastery Shape',
            subtitle: radarData.isEmpty
                ? 'Take tests to visualize your strengths'
                : 'Your top ${radarData.length} practiced topics',
            icon: LucideIcons.hexagon,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: RadarChartWidget(data: radarData),
              ),
            ),
          ),
          const SizedBox(height: 14),

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
          const SizedBox(height: 14),

          // ─── Skill Trees ───
          _buildSkillTreeSection('Physics', skillTreePhysics),
          const SizedBox(height: 14),
          _buildSkillTreeSection('Chemistry', skillTreeChemistry),
          const SizedBox(height: 14),
          _buildSkillTreeSection('Mathematics', skillTreeMaths),

          const SizedBox(height: 80),
        ],
      ),
      ),
    );
  }

  Widget _buildSkillTreeSection(String subject, AsyncValue<List<SkillTreeNode>> treeAsync) {
    final nodes = treeAsync.valueOrNull ?? [];
    if (nodes.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: '$subject Skill Tree',
      subtitle: 'Prerequisite flow — green = mastered',
      icon: LucideIcons.gitBranch,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SkillTreeWidget(
          nodes: nodes,
          title: subject,
          height: 320,
        ),
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

// Tab 3: Trends — Area Line Chart + Scatter Plot + Consistency
class _TrendsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(areaLineChartDataProvider);
    final scatterAsync = ref.watch(scatterPlotDataProvider);
    final streakAsync = ref.watch(studyStreakProvider);

    final trendData = trendAsync.valueOrNull ?? [];
    final scatterData = scatterAsync.valueOrNull ?? [];
    final streak = streakAsync.valueOrNull ?? const StudyStreak();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(scoreHistoryProvider);
        ref.invalidate(areaLineChartDataProvider);
        ref.invalidate(scatterPlotDataProvider);
        ref.invalidate(studyStreakProvider);
        ref.invalidate(topicPerformanceProvider);
        await ref.read(scoreHistoryProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─── Area Line Chart ───
          _SectionCard(
            title: 'Score Trend',
            subtitle: trendData.isEmpty
                ? 'Take tests to see your progress'
                : 'Progress over ${trendData.length} tests',
            icon: LucideIcons.trendingUp,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AreaLineChartWidget(data: trendData),
            ),
          ),
          const SizedBox(height: 14),

          // ─── Scatter Plot ───
          _SectionCard(
            title: 'Speed vs. Accuracy',
            subtitle: scatterData.isEmpty
                ? 'Complete topics to analyze your patterns'
                : '${scatterData.length} topics analyzed',
            icon: LucideIcons.crosshair,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ScatterPlotWidget(data: scatterData),
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
