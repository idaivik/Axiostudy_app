import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/progress_circle.dart';
import '../../analytics/data/analytics_providers.dart';
import '../../analytics/domain/analytics_models.dart';
import 'widgets/subject_breakdown_card.dart';
import 'widgets/chapter_analysis_card.dart';
import 'widgets/time_analysis_card.dart';
import 'widgets/accuracy_metrics_card.dart';

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
        data: (analytics) => _buildContent(analytics),
      ),
    );
  }

  Widget _buildContent(AttemptAnalyticsResult? analytics) {
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

          // Step 18: Recommend practice tests
          if (analytics != null && analytics.recommendations.isNotEmpty)
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
