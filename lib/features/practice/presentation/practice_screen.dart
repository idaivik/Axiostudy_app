import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/subject_badge.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/router/swipe_nav_provider.dart';
import '../../../shared/models/enums.dart';
import '../../subjects/data/subjects_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../analytics/data/analytics_providers.dart';
import '../../test/data/test_providers.dart';
import '../data/practice_providers.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _ignoreTabListener = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    // Practice tabs map to global indices 1 and 2
    ref.read(swipeNavProvider.notifier).setGlobalIndex(1 + _tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to swipe nav state and sync tab controller
    ref.listen<SwipeNavState>(swipeNavProvider, (prev, next) {
      if (next.navIndex != 1) return; // Only care about Practice section
      final targetTab = next.practiceTabIndex;
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
        title: const Text('Practice & Tests'),
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
                    BoxShadow(
                      color: AppColors.slate900.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: AppColors.slate900.withValues(alpha: 0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.textDark,
                unselectedLabelColor: AppColors.textMedium,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Topics'),
                  Tab(text: 'Mock Tests'),
                ],
              ),
            ),
          ),
        ),
      ),
      child: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _TopicsTab(),
          _TestsTab(),
        ],
      ),
    );
  }
}

// ─── Tab 1: Topics (formerly SubjectsScreen) ───
class _TopicsTab extends ConsumerWidget {
  const _TopicsTab();

  /// Assemble an adaptive session from the user's weak chapters and launch it.
  Future<void> _startAdaptivePractice(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final session = await ref.read(practiceRepositoryProvider).buildAdaptiveSession();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (session.questions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No practice questions available yet — take a test first.'),
          ));
        }
        return;
      }
      ref.read(activePracticeTestProvider.notifier).state = session;
      if (context.mounted) context.push('/practice/session');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start practice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(subjectsProvider);
        ref.invalidate(currentUserProvider);
        await ref.read(subjectsProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
      slivers: [
        // Quick practice section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: PressableScale(
              scale: 0.97,
              onTap: () => _startAdaptivePractice(context, ref),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.greenDarkAccent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI-Recommended Practice',
                            style: AppTypography.heading3.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Based on your areas that need practice',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('All Subjects', style: AppTypography.heading2),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: subjectsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('Failed to load subjects', style: AppTypography.bodyMedium),
              )),
            ),
            data: (subjects) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final subject = subjects[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SubjectCard(
                      name: subject.name,
                      iconData: subject.iconData,
                      completion: subject.completionPercentage,
                      totalQuestions: subject.totalQuestions,
                      chapterCount: subject.chapters.length,
                      gradient: _gradientFor(subject.type),
                      weakChapter: subject.chapters
                          .where((c) => c.strength == TopicStrength.weak)
                          .map((c) => c.name)
                          .firstOrNull,
                      onTap: () => context.push('/subjects/${subject.id}'),
                    ),
                  );
                },
                childCount: subjects.length,
              ),
            ),
          ),
        ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  LinearGradient _gradientFor(SubjectType type) => switch (type) {
    SubjectType.physics => AppColors.physicsGradient,
    SubjectType.chemistry => AppColors.chemistryGradient,
    SubjectType.mathematics => AppColors.mathematicsGradient,
    SubjectType.biology => AppColors.biologyGradient,
  };
}

class _SubjectCard extends StatelessWidget {
  final String name;
  final IconData iconData;
  final double completion;
  final int totalQuestions;
  final int chapterCount;
  final LinearGradient gradient;
  final String? weakChapter;
  final VoidCallback? onTap;

  const _SubjectCard({
    required this.name,
    required this.iconData,
    required this.completion,
    required this.totalQuestions,
    required this.chapterCount,
    required this.gradient,
    this.weakChapter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(iconData, size: 26, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.heading3),
                      Text(
                        '$chapterCount chapters  |  $totalQuestions questions',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(completion * 100).round()}%',
                  style: AppTypography.heading2.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProgressBar(progress: completion, height: 6),
            if (weakChapter != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const SubjectBadge(strength: TopicStrength.weak),
                  const SizedBox(width: 6),
                  Text(weakChapter!, style: AppTypography.caption),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Tab 2: Mock Tests (formerly TestsListScreen) ───
class _TestsTab extends ConsumerWidget {
  const _TestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final tests = (ref.watch(testsProvider).valueOrNull ?? [])
        .where((t) => t.id != 'adaptive_practice')
        .toList();
    final history = ref.watch(scoreHistoryProvider).valueOrNull ?? [];
    // Split tests by whether the student has a finished attempt: not-yet-taken
    // tests go to "Available", taken tests to "Completed".
    final lastByTest =
        ref.watch(lastAttemptByTestProvider).valueOrNull ?? const {};
    final available =
        tests.where((t) => !lastByTest.containsKey(t.id)).toList();
    final completed =
        tests.where((t) => lastByTest.containsKey(t.id)).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(currentUserProvider);
        ref.invalidate(topicPerformanceProvider);
        ref.invalidate(testsProvider);
        ref.invalidate(scoreHistoryProvider);
        ref.invalidate(userAttemptsProvider);
        ref.invalidate(lastAttemptByTestProvider);
        await ref.read(currentUserProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Tests Taken',
                    value: '${user?.testsCompleted ?? 0}',
                    icon: LucideIcons.checkSquare,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    label: 'Avg Score',
                    value: '${user?.averageScore.round() ?? 0}%',
                    icon: LucideIcons.target,
                    color: AppColors.mathematics,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Available tests — not yet attempted (real data from the `tests` table)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Available Tests', style: AppTypography.heading2),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: available.isEmpty
              ? SliverToBoxAdapter(
                  child: _EmptyHint(tests.isEmpty
                      ? 'No tests available yet.'
                      : 'You\'ve attempted every available test — nice work!'),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = available[index];
                      return _TestCard(
                        title: t.name,
                        subtitle:
                            '${t.totalQuestions} questions  |  ${t.duration.inMinutes} min',
                        date: t.type.label,
                        icon: _iconForTest(t.type),
                        isHighlighted: index == 0,
                        onTap: () => context.push('/test/${t.id}'),
                      );
                    },
                    childCount: available.length,
                  ),
                ),
        ),
        // Completed tests — tap to see last-attempt detail + reattempt.
        if (completed.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Completed Tests', style: AppTypography.heading2),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final t = completed[index];
                  final attempt = lastByTest[t.id]!;
                  return _CompletedTestCard(
                    title: t.name,
                    scorePercentage: attempt.scorePercentage,
                    date: _fmtDate(attempt.endTime ?? attempt.startTime),
                    onTap: () => context.push('/completed-test/${t.id}'),
                  );
                },
                childCount: completed.length,
              ),
            ),
          ),
        ],
        // Past results (real data from score_history)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Recent Results', style: AppTypography.heading2),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: history.isEmpty
              ? const SliverToBoxAdapter(
                  child: _EmptyHint('No results yet — take a test to see your analysis.'),
                )
              : SliverList(
                  delegate: SliverChildListDelegate([
                    // Newest first; improvement = delta vs the prior attempt.
                    for (int i = history.length - 1;
                        i >= 0 && history.length - 1 - i < 8;
                        i--)
                      _ResultCard(
                        title: history[i].testName ?? 'Practice Test',
                        score: history[i].scorePercentage,
                        date: _fmtDate(history[i].completedAt),
                        improvement: i > 0
                            ? history[i].scorePercentage -
                                history[i - 1].scorePercentage
                            : 0,
                        onTap: () =>
                            context.push('/results/${history[i].attemptId}'),
                      ),
                    const SizedBox(height: 100),
                  ]),
                ),
        ),
      ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: AppTypography.heading2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final IconData icon;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _TestCard({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighlighted ? AppColors.primarySurface : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: isHighlighted
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isHighlighted
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: isHighlighted ? AppColors.primary : AppColors.textMedium),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(date, style: AppTypography.caption),
                if (isHighlighted) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Next',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final double score;
  final String date;
  final double improvement;
  final VoidCallback? onTap;

  const _ResultCard({
    required this.title,
    required this.score,
    required this.date,
    required this.improvement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${score.round()}%',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(date, style: AppTypography.caption),
                ],
              ),
            ),
            if (improvement.abs() >= 0.5)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: improvement >= 0 ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      improvement >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                      size: 12,
                      color: improvement >= 0 ? AppColors.success : AppColors.wrong,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${improvement >= 0 ? '+' : ''}${improvement.round()}%',
                      style: AppTypography.labelSmall.copyWith(
                        color: improvement >= 0 ? AppColors.success : AppColors.wrong,
                        fontWeight: FontWeight.w700,
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

/// A mock test the student has already finished — shows the last score and
/// opens the completed-test detail screen on tap.
class _CompletedTestCard extends StatelessWidget {
  final String title;
  final double scorePercentage;
  final String date;
  final VoidCallback? onTap;

  const _CompletedTestCard({
    required this.title,
    required this.scorePercentage,
    required this.date,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = scorePercentage.round();
    final scoreColor = pct >= 70
        ? AppColors.success
        : pct >= 40
            ? AppColors.warning
            : AppColors.error;
    return PressableScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.checkCircle2, size: 20, color: scoreColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Last: $pct%  ·  $date', style: AppTypography.caption),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

IconData _iconForTest(TestType type) {
  switch (type) {
    case TestType.diagnostic:
      return LucideIcons.clipboardCheck;
    case TestType.mock:
      return LucideIcons.fileText;
    case TestType.practice:
      return LucideIcons.pencil;
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
        textAlign: TextAlign.center,
      ),
    );
  }
}
