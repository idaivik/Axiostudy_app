import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/progress_circle.dart';
import '../../../core/notifications/notification_service.dart';
import '../../analytics/data/analytics_providers.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/domain/chapter_insight_models.dart';
import '../../practice/data/practice_providers.dart';
import '../../practice/data/practice_repository.dart';
import '../../subscription/domain/entitlements.dart';
import '../../subscription/domain/meter_outcome.dart';
import '../../subscription/presentation/ai_locked_card.dart';
import '../../subscription/presentation/feature_gate.dart';
import '../../subscription/presentation/paywall_screen.dart';
import '../../test/domain/test_models.dart';
import '../../../shared/models/enums.dart';
import 'widgets/subject_breakdown_card.dart';
import 'widgets/chapter_analysis_card.dart';
import 'widgets/time_analysis_card.dart';
import 'widgets/accuracy_metrics_card.dart';
import 'widgets/mistakes_review_card.dart';
import 'widgets/formulas_to_learn_card.dart';

// Sequence step 16-18: Display weakness analysis → Show strength areas → Recommend practice tests
class ResultsScreen extends ConsumerStatefulWidget {
  final String attemptId;
  const ResultsScreen({super.key, required this.attemptId});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scoreAnim;
  bool _reminderScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(attemptAnalyticsProvider(widget.attemptId));
    final insights =
        ref.watch(chapterInsightsProvider(widget.attemptId)).valueOrNull ??
            const <ChapterInsight>[];

    return GradientBackground(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Text('AI Analysis'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2, size: 18),
            onPressed: () {},
          ),
        ],
      ),
      child: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading analytics: $e')),
        data: (analytics) => _buildContent(analytics, insights),
      ),
    );
  }

  Widget _buildContent(
      AttemptAnalyticsResult? analytics, List<ChapterInsight> insights) {
    // Skipped-practice nudge: if this test surfaced weak chapters, schedule a
    // 24h reminder. Starting any practice session cancels it (see TestScreen).
    if (insights.any((i) => i.isWeak) && !_reminderScheduled) {
      _reminderScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.requestPermission();
        NotificationService.instance.schedulePracticeReminder();
      });
    }

    // Compute display values from analytics or use defaults
    final scorePercentage = analytics?.scorePercentage ?? 0;
    final totalCorrect = analytics?.totalCorrect ?? 0;
    final totalQuestions = (analytics?.totalCorrect ?? 0) +
        (analytics?.totalWrong ?? 0) +
        (analytics?.totalUnanswered ?? 0);
    final accuracy = analytics?.accuracy ?? 0;
    final avgTimeMin = (analytics?.avgTimePerQuestion ?? 0) / 60;
    final fastestMin = (analytics?.fastestQuestionSeconds ?? 0) / 60;
    final slowestMin = (analytics?.slowestQuestionSeconds ?? 0) / 60;
    final totalTimeMin = (analytics?.totalTimeSeconds ?? 0) ~/ 60;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Score Hero — dark premium card
          FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.greenDarkAccent.withValues(alpha: 0.3),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.greenLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.brain, size: 12, color: AppColors.greenLight),
                            const SizedBox(width: 5),
                            Text(
                              analytics != null ? 'AI Analysis Complete' : 'Analysis Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.greenLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        analytics?.testId ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _scoreAnim,
                    builder: (context, child) => ProgressCircle(
                      progress: (scorePercentage / 100) * _scoreAnim.value,
                      size: 130,
                      strokeWidth: 10,
                      progressColor: _scoreColor(scorePercentage),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      centerWidget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(scorePercentage * _scoreAnim.value).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                            ),
                          ),
                          Text(
                            '$totalCorrect/$totalQuestions',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatChip(label: 'Accuracy', value: '${(accuracy * 100).round()}%', icon: LucideIcons.target),
                      _StatChip(label: 'Time Used', value: '$totalTimeMin min', icon: LucideIcons.clock),
                      _StatChip(label: 'Correct', value: '$totalCorrect', icon: LucideIcons.checkCircle2),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Feature 3 — AI coach summary (Pro), above the charts. FeatureGate
          // shows the upgrade upsell to Basic; Pro renders the metered card.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FeatureGate(
              feature: Feature.aiAnalysisNarrative,
              child: (_) => _AiNarrativeCard(attemptId: widget.attemptId),
            ),
          ),
          const SizedBox(height: 12),

          // AI chapter insights (server weakness engine) — primary guidance.
          if (insights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ChapterInsightsCard(insights: insights),
            ),
          if (insights.isNotEmpty) const SizedBox(height: 12),

          // What next? — the 3 post-result paths (Phase 2).
          if (insights.any((i) => i.isWeak))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PostResultActionsCard(
                weakest: _weakestChapter(insights),
              ),
            ),
          if (insights.any((i) => i.isWeak)) const SizedBox(height: 12),

          // Step 16: Display weakness analysis
          if (analytics != null && analytics.weakTopics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _WeaknessAnalysisCard(weakTopics: analytics.weakTopics),
            ),

          if (analytics != null && analytics.weakTopics.isNotEmpty)
            const SizedBox(height: 12),

          // Step 17: Show strength areas
          if (analytics != null && analytics.strongTopics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StrengthAreasCard(strongTopics: analytics.strongTopics),
            ),

          if (analytics != null && analytics.strongTopics.isNotEmpty)
            const SizedBox(height: 12),

          // Feature 2 — Review your mistakes (Basic/Pro; metered per open).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MistakesReviewCard(attemptId: widget.attemptId),
          ),
          const SizedBox(height: 12),

          // Feature 4 — Formulas to learn (Pro). Hidden for Basic (no upsell);
          // the card hides itself when nothing is curated for the weak topics.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FeatureGate(
              feature: Feature.advancedBreakdown,
              locked: (_) => const SizedBox.shrink(),
              child: (_) => FormulasToLearnCard(attemptId: widget.attemptId),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SubjectBreakdownCard(breakdown: analytics?.subjectBreakdown),
                const SizedBox(height: 12),
                ChapterAnalysisCard(breakdown: analytics?.chapterBreakdown),
                const SizedBox(height: 12),
                TimeAnalysisCard(
                  avgTimeMinutes: avgTimeMin,
                  fastestTimeMinutes: fastestMin,
                  slowestTimeMinutes: slowestMin,
                  bottleneckMessage: slowestMin > 3
                      ? 'Slowest question took ${slowestMin.toStringAsFixed(1)} min — consider reviewing that topic'
                      : null,
                ),
                const SizedBox(height: 12),
                AccuracyMetricsCard(breakdown: analytics?.difficultyBreakdown),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Step 18: Recommend practice tests — rule-based engine, now a
          // FALLBACK shown only when the AI chapter insights are unavailable.
          if (insights.isEmpty &&
              analytics != null &&
              analytics.recommendations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _RecommendedPracticeCard(recommendations: analytics.recommendations),
            ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.fileText, size: 16),
                    label: const Text('Download PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/practice'),
                    icon: const Icon(LucideIcons.zap, size: 16),
                    label: const Text('Practice Now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.greenLight;
    if (score >= 50) return const Color(0xFFFBBF24);
    return const Color(0xFFFC8181);
  }

  /// The most urgent weak chapter (highest AI priority) to target post-result.
  ChapterInsight _weakestChapter(List<ChapterInsight> insights) {
    final weak = insights.where((i) => i.isWeak).toList()
      ..sort((a, b) => (b.priorityScore ?? 0).compareTo(a.priorityScore ?? 0));
    return weak.isNotEmpty ? weak.first : insights.first;
  }
}

/// Maps a coarse difficulty label from a chapter's 0–100 score.
String _difficultyForScore(double scorePercentage) {
  if (scorePercentage < 35) return 'easy';
  if (scorePercentage <= 65) return 'medium';
  return 'hard';
}

String _prettyChapter(WidgetRef ref, String chapterId) {
  final names = ref.watch(chapterNamesProvider).valueOrNull;
  return names?[chapterId] ?? chapterId;
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;

  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.6)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Step 16 — Weakness Analysis (now data-driven)
class _WeaknessAnalysisCard extends StatelessWidget {
  final List<TopicInsight> weakTopics;
  const _WeaknessAnalysisCard({required this.weakTopics});

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
                decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12)),
                child: Icon(LucideIcons.alertTriangle, color: AppColors.wrong, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weakness Analysis', style: AppTypography.heading3),
                    Text('AI detected these weak areas', style: AppTypography.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${weakTopics.length} topics',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.wrong, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...weakTopics.asMap().entries.map((entry) {
            final t = entry.value;
            final isLast = entry.key == weakTopics.length - 1;
            return _TopicRow(
              name: t.topicName,
              subject: t.subjectName,
              score: t.scorePercentage,
              color: t.scorePercentage < 35 ? AppColors.wrong : AppColors.weak,
              showBorder: !isLast,
            );
          }),
        ],
      ),
    );
  }
}

// Step 17 — Strength Areas (now data-driven)
class _StrengthAreasCard extends StatelessWidget {
  final List<TopicInsight> strongTopics;
  const _StrengthAreasCard({required this.strongTopics});

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
                decoration: BoxDecoration(color: AppColors.greenSurface, borderRadius: BorderRadius.circular(12)),
                child: Icon(LucideIcons.trendingUp, color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Strength Areas', style: AppTypography.heading3),
                    Text('Topics you\'ve mastered', style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...strongTopics.asMap().entries.map((entry) {
            final t = entry.value;
            final isLast = entry.key == strongTopics.length - 1;
            return _TopicRow(
              name: t.topicName,
              subject: t.subjectName,
              score: t.scorePercentage,
              color: AppColors.primary,
              showBorder: !isLast,
            );
          }),
        ],
      ),
    );
  }
}

// Step 18 — Recommended Practice Tests (now data-driven)
class _RecommendedPracticeCard extends StatelessWidget {
  final List<Recommendation> recommendations;
  const _RecommendedPracticeCard({required this.recommendations});

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
                decoration: BoxDecoration(color: AppColors.greenSurface, borderRadius: BorderRadius.circular(12)),
                child: Icon(LucideIcons.brain, color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Text('Recommended Practice', style: AppTypography.heading3),
            ],
          ),
          const SizedBox(height: 16),
          ...recommendations.take(5).map((r) {
            final tagColor = r.type == 'weak_topic_drill'
                ? AppColors.wrong
                : r.type == 'revision'
                    ? AppColors.weak
                    : AppColors.primary;
            final tag = r.type == 'weak_topic_drill'
                ? 'Weak area'
                : r.type == 'revision'
                    ? 'Revision'
                    : r.type == 'challenge'
                        ? 'Challenge'
                        : 'Suggested';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecommendCard(
                title: r.title,
                subtitle: r.subtitle ?? '',
                tag: tag,
                tagColor: tagColor,
                onTap: () {
                  if (r.subjectId != null) {
                    context.push('/subjects/${r.subjectId}');
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RecommendCard extends StatelessWidget {
  final String title, subtitle, tag;
  final Color tagColor;
  final VoidCallback onTap;

  const _RecommendCard({
    required this.title, required this.subtitle,
    required this.tag, required this.tagColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tagColor)),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 15, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final String name, subject;
  final int score;
  final Color color;
  final bool showBorder;
  const _TopicRow({required this.name, required this.subject, required this.score, required this.color, required this.showBorder});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
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
              Text(
                '$score%',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: score / 100),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: val,
              minHeight: 4,
              backgroundColor: AppColors.surfaceDark,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        if (showBorder) ...[
          const SizedBox(height: 4),
          Divider(color: AppColors.divider, height: 1, thickness: 0.5),
        ],
      ],
    );
  }
}

// ── AI Chapter Insights (server weakness engine) ──────────────────────────────
class _ChapterInsightsCard extends ConsumerWidget {
  final List<ChapterInsight> insights;
  const _ChapterInsightsCard({required this.insights});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = [...insights]
      ..sort((a, b) => (b.priorityScore ?? 0).compareTo(a.priorityScore ?? 0));
    final top = ranked.take(4).toList();

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
                decoration: BoxDecoration(color: AppColors.greenSurface, borderRadius: BorderRadius.circular(12)),
                child: Icon(LucideIcons.brain, color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Chapter Insights', style: AppTypography.heading3),
                    Text('Ranked by what to fix first', style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...top.map((i) => _InsightRow(
                insight: i,
                chapterName: _prettyChapter(ref, i.chapterId),
              )),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final ChapterInsight insight;
  final String chapterName;
  const _InsightRow({required this.insight, required this.chapterName});

  @override
  Widget build(BuildContext context) {
    final score = insight.scorePercentage.round();
    final color = insight.isWeak
        ? AppColors.wrong
        : insight.isStrong
            ? AppColors.primary
            : AppColors.weak;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(chapterName,
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              if (insight.errorPattern != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(insight.errorPattern!,
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textMedium)),
                ),
                const SizedBox(width: 8),
              ],
              Text('$score%',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              if (insight.improvementFromLastTest != null) ...[
                const SizedBox(width: 6),
                Text(
                  '${insight.improvementFromLastTest! >= 0 ? '+' : ''}${insight.improvementFromLastTest!.round()}',
                  style: AppTypography.labelSmall.copyWith(
                    color: insight.improvementFromLastTest! >= 0 ? AppColors.success : AppColors.wrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (insight.weaknessReasoning != null) ...[
            const SizedBox(height: 4),
            Text(insight.weaknessReasoning!, style: AppTypography.caption),
          ],
          if (insight.recommendedAction != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.greenSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.target, size: 13, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(insight.recommendedAction!,
                        style: AppTypography.caption.copyWith(color: AppColors.textDark)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Feature 3: AI coach summary (Pro, metered) ───────────────────────────────
class _AiNarrativeCard extends ConsumerWidget {
  final String attemptId;
  const _AiNarrativeCard({required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(analysisNarrativeProvider(attemptId));
    return async.when(
      loading: () => const _NarrativeBody(text: null),
      error: (_, _) => const AiLockedCard(
        status: MeterStatus.error,
        featureTitle: 'AI coach summary',
      ),
      data: (res) {
        final text = res.narrative;
        if (res.outcome.ok && text != null && text.isNotEmpty) {
          return _NarrativeBody(text: text);
        }
        return AiLockedCard(
          status: res.outcome.status,
          featureTitle: 'AI coach summary',
        );
      },
    );
  }
}

/// The narrative card itself. A null [text] renders the loading state so the
/// card never pops in/out (it holds its place above the charts).
class _NarrativeBody extends StatelessWidget {
  final String? text;
  const _NarrativeBody({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.sparkles, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text('Your AI coach', style: AppTypography.heading3),
            ],
          ),
          const SizedBox(height: 12),
          if (text == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _ShimmerLine(widthFactor: 1.0),
                SizedBox(height: 8),
                _ShimmerLine(widthFactor: 0.92),
                SizedBox(height: 8),
                _ShimmerLine(widthFactor: 0.6),
              ],
            )
          else
            Text(
              text!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textDark,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double widthFactor;
  const _ShimmerLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ── Post-result actions: the 3 practice paths (Phase 2) ──────────────────────
class _PostResultActionsCard extends ConsumerStatefulWidget {
  final ChapterInsight weakest;
  const _PostResultActionsCard({required this.weakest});

  @override
  ConsumerState<_PostResultActionsCard> createState() => _PostResultActionsCardState();
}

class _PostResultActionsCardState extends ConsumerState<_PostResultActionsCard> {
  bool _busy = false;

  Future<void> _launch(Test test, {String emptyMsg = 'No questions available.'}) async {
    if (test.questions.isEmpty) {
      _toast(emptyMsg);
      return;
    }
    ref.read(activePracticeTestProvider.notifier).state = test;
    if (mounted) context.push('/practice/session');
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _toast('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adaptive() => _run(() async {
        final test = await ref.read(practiceRepositoryProvider).buildAdaptiveSession();
        await _launch(test, emptyMsg: 'No weak-chapter questions available yet.');
      });

  Future<void> _moreLikeThis(int delta) => _run(() async {
        final w = widget.weakest;
        final test = await ref.read(practiceRepositoryProvider).moreLikeThis(
              chapterId: w.chapterId,
              currentDifficulty: _difficultyForScore(w.scorePercentage),
              delta: delta,
            );
        await _launch(test, emptyMsg: 'No more questions in that band — try another difficulty.');
      });

  Future<void> _generate() => _run(() async {
        final w = widget.weakest;
        final result = await ref.read(practiceRepositoryProvider).generateQuestions(
              chapterId: w.chapterId,
              difficulty: _difficultyForScore(w.scorePercentage),
              count: 3,
            );
        if (!result.ok) {
          // Per §5.5 the only surviving failure paths (HTTP 402) are the trial
          // AI lock and no-entitlement — every active paid tier instead succeeds
          // or silently falls back to bank questions (ok:true) above.
          if (result.isTrialLocked) {
            _showTrialLocked();
          } else if (result.isNoEntitlement) {
            if (mounted) {
              await PaywallScreen.showUpgrade(context, tier: SubscriptionTier.pro);
            }
          } else {
            _toast(result.message); // generation_empty / transient error
          }
          return;
        }
        // ok — questions may be freshly generated ('ai'), or served from the
        // shared pool / bank ('pool'/'bank'). The fallback is silent: no wall.
        final qs = result.questions;
        await _launch(
          Test(
            id: PracticeRepository.adaptiveTestId,
            name: 'AI Generated Practice',
            type: TestType.practice,
            duration: Duration(minutes: (qs.length * 1.5).ceil().clamp(5, 60)),
            totalQuestions: qs.length,
            subjectIds: qs.map((q) => q.subjectId).toSet().toList(),
            questions: qs,
          ),
          emptyMsg: 'No questions available for that chapter yet — try again soon.',
        );
      });

  /// The 7-day-trial AI hard-lock state. The student is already paying (trialing),
  /// so this is NOT the paywall — it tells them when AI switches on.
  void _showTrialLocked() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        icon: Icon(LucideIcons.lock, color: AppColors.primary),
        title: const Text('Unlocks when your trial converts'),
        content: const Text(
          'AI question generation switches on the moment your free trial becomes '
          'a paid plan. Everything else — adaptive practice, your full analysis, '
          'and the question bank — is live right now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _prettyChapter(ref, widget.weakest.chapterId);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.greenDarkAccent.withValues(alpha: 0.25), blurRadius: 22, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.zap, color: AppColors.greenLight, size: 18),
              const SizedBox(width: 8),
              Text('What next?',
                  style: AppTypography.heading3.copyWith(color: Colors.white)),
              const Spacer(),
              if (_busy)
                const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Targeting your weakest chapter: $chapter',
              style: AppTypography.caption.copyWith(color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 14),

          // (1) Adaptive practice across weak chapters.
          _ActionButton(
            icon: LucideIcons.brain,
            label: 'Practice my weak chapters',
            onTap: _busy ? null : _adaptive,
          ),
          const SizedBox(height: 8),

          // (2) More like this — easier / same / harder, same chapter.
          Text('More like this',
              style: AppTypography.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _MiniButton(label: 'Easier', onTap: _busy ? null : () => _moreLikeThis(-1))),
              const SizedBox(width: 8),
              Expanded(child: _MiniButton(label: 'Same', onTap: _busy ? null : () => _moreLikeThis(0))),
              const SizedBox(width: 8),
              Expanded(child: _MiniButton(label: 'Harder', onTap: _busy ? null : () => _moreLikeThis(1))),
            ],
          ),
          const SizedBox(height: 10),

          // (3) Custom AI generation (paid).
          _ActionButton(
            icon: LucideIcons.sparkles,
            label: 'Generate fresh AI questions',
            onTap: _busy ? null : _generate,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: AppTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(LucideIcons.chevronRight, size: 16, color: Colors.white.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _MiniButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(label,
            style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
