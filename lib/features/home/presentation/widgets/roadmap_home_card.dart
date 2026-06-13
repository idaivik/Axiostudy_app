import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/animations.dart';
import '../../../roadmap/data/roadmap_providers.dart';
import '../../../roadmap/domain/roadmap_models.dart';

/// Home entry point for the coaching-synced roadmap. Surfaces the exam
/// countdown + this-week tasks, and routes into the full roadmap. Falls back to
/// a setup CTA when the student hasn't configured their roadmap yet.
class RoadmapHomeCard extends ConsumerWidget {
  const RoadmapHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(roadmapProvider);

    return roadmapAsync.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (roadmap) {
        if (roadmap == null) return const _RoadmapSetupCta();
        return _RoadmapSummaryCard(roadmap: roadmap);
      },
    );
  }
}

class _RoadmapSetupCta extends StatelessWidget {
  const _RoadmapSetupCta();

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.push('/roadmap/setup'),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(LucideIcons.milestone, color: AppColors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Build your study roadmap',
                      style: AppTypography.heading3.copyWith(color: AppColors.white)),
                  const SizedBox(height: 2),
                  Text('Sync your plan to your coaching syllabus',
                      style: AppTypography.caption.copyWith(color: AppColors.greenSurface)),
                ],
              ),
            ),
            const Icon(LucideIcons.arrowRight, color: AppColors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RoadmapSummaryCard extends StatelessWidget {
  final Roadmap roadmap;
  const _RoadmapSummaryCard({required this.roadmap});

  @override
  Widget build(BuildContext context) {
    final days = roadmap.daysToExam;
    final thisWeek = roadmap.thisWeek;
    final overdue = roadmap.overdue.length;

    return PressableScale(
      onTap: () => context.push('/roadmap'),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(LucideIcons.milestone, color: AppColors.primary, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Today on your roadmap', style: AppTypography.heading3),
                ),
                if (days != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$days days left',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (thisWeek.isEmpty)
              Text(
                overdue > 0
                    ? '$overdue item${overdue == 1 ? '' : 's'} to catch up on — tap to view.'
                    : 'You\'re all caught up. Tap to see what\'s next.',
                style: AppTypography.bodyMedium,
              )
            else
              ...thisWeek.take(2).map((item) => _MiniItem(item: item)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('View full roadmap',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(width: 4),
                const Icon(LucideIcons.arrowRight, size: 14, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniItem extends StatelessWidget {
  final RoadmapItem item;
  const _MiniItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(item.type.iconData, size: 16, color: item.type.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${item.type.label}: ${item.chapterName}',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
