import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/progress_circle.dart';
import '../../../shared/data/mock_data.dart';
import 'widgets/subject_breakdown_card.dart';
import 'widgets/chapter_analysis_card.dart';
import 'widgets/time_analysis_card.dart';
import 'widgets/accuracy_metrics_card.dart';

// Sequence step 16-18: Display weakness analysis → Show strength areas → Recommend practice tests
class ResultsScreen extends StatefulWidget {
  final String attemptId;
  const ResultsScreen({super.key, required this.attemptId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
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
    final attempt = MockData.sampleAttempt;

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
      child: SingleChildScrollView(
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
                                'AI Analysis Complete',
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
                          'JEE Mock Test #5',
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
                        progress: (attempt.scorePercentage / 100) * _scoreAnim.value,
                        size: 130,
                        strokeWidth: 10,
                        progressColor: _scoreColor(attempt.scorePercentage),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        centerWidget: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(attempt.scorePercentage * _scoreAnim.value).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                              ),
                            ),
                            Text(
                              '${attempt.score}/${attempt.totalMarks}',
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
                        _StatChip(label: 'Percentile', value: '82nd', icon: LucideIcons.award),
                        _StatChip(label: 'Accuracy', value: '70%', icon: LucideIcons.target),
                        _StatChip(label: 'Time Used', value: '45 min', icon: LucideIcons.clock),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Step 16: Display weakness analysis
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _WeaknessAnalysisCard(),
            ),

            const SizedBox(height: 12),

            // Step 17: Show strength areas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StrengthAreasCard(),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SubjectBreakdownCard(),
                  const SizedBox(height: 12),
                  const ChapterAnalysisCard(),
                  const SizedBox(height: 12),
                  const TimeAnalysisCard(),
                  const SizedBox(height: 12),
                  const AccuracyMetricsCard(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Step 18: Recommend practice tests
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _RecommendedPracticeCard(),
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

// Step 16 — Weakness Analysis
class _WeaknessAnalysisCard extends StatelessWidget {
  final _weakTopics = const [
    _TopicItem('Electrochemistry', 'Chemistry', 32, AppColors.wrong),
    _TopicItem('Rotational Dynamics', 'Physics', 41, AppColors.weak),
    _TopicItem('Matrices & Determinants', 'Mathematics', 45, AppColors.weak),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
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
                child: Text('3 topics', style: AppTypography.labelSmall.copyWith(color: AppColors.wrong, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._weakTopics.map((t) => _TopicRow(topic: t, showBorder: t != _weakTopics.last)),
        ],
      ),
    );
  }
}

// Step 17 — Strength Areas
class _StrengthAreasCard extends StatelessWidget {
  final _strongTopics = const [
    _TopicItem('Thermodynamics', 'Physics', 89, AppColors.primary),
    _TopicItem('Organic Chemistry', 'Chemistry', 82, AppColors.primary),
    _TopicItem('Calculus', 'Mathematics', 78, AppColors.primary),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
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
          ..._strongTopics.map((t) => _TopicRow(topic: t, showBorder: t != _strongTopics.last)),
        ],
      ),
    );
  }
}

// Step 18 — Recommended Practice Tests
class _RecommendedPracticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
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
                decoration: BoxDecoration(color: AppColors.greenSurface, borderRadius: BorderRadius.circular(12)),
                child: Icon(LucideIcons.brain, color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Text('Recommended Practice', style: AppTypography.heading3),
            ],
          ),
          const SizedBox(height: 16),
          _RecommendCard(
            title: 'Electrochemistry Drill',
            subtitle: '15 targeted questions • Chemistry',
            tag: 'Weak area',
            tagColor: AppColors.wrong,
            onTap: () => context.push('/subjects/chemistry'),
          ),
          const SizedBox(height: 10),
          _RecommendCard(
            title: 'Rotational Motion Practice',
            subtitle: '20 questions • Physics',
            tag: 'Weak area',
            tagColor: AppColors.weak,
            onTap: () => context.push('/subjects/physics'),
          ),
          const SizedBox(height: 10),
          _RecommendCard(
            title: 'Full Chapter Test — Matrices',
            subtitle: '30 questions • Mathematics',
            tag: 'Suggested',
            tagColor: AppColors.primary,
            onTap: () => context.push('/subjects/mathematics'),
          ),
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
          border: Border.all(color: AppColors.divider, width: 0.5),
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

class _TopicItem {
  final String name, subject;
  final int score;
  final Color color;
  const _TopicItem(this.name, this.subject, this.score, this.color);
}

class _TopicRow extends StatelessWidget {
  final _TopicItem topic;
  final bool showBorder;
  const _TopicRow({required this.topic, required this.showBorder});

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
                    Text(topic.name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500, fontSize: 14)),
                    Text(topic.subject, style: AppTypography.caption.copyWith(color: topic.color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text(
                '${topic.score}%',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: topic.color),
              ),
            ],
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: topic.score / 100),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: val,
              minHeight: 4,
              backgroundColor: AppColors.surfaceDark,
              valueColor: AlwaysStoppedAnimation<Color>(topic.color),
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
