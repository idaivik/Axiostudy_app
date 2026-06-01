import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/subject_badge.dart';
import '../data/subjects_providers.dart';
import '../../../shared/models/enums.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Practice', style: AppTypography.heading1),
                  const SizedBox(height: 4),
                  Text('Choose a subject to practice', style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
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
          // Quick practice section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Quick Practice', style: AppTypography.heading2),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => context.push('/test-selection'),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
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
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  LinearGradient _gradientFor(SubjectType type) => switch (type) {
    SubjectType.physics => AppColors.physicsGradient,
    SubjectType.chemistry => AppColors.chemistryGradient,
    SubjectType.mathematics => AppColors.mathematicsGradient,
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
    return GestureDetector(
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
