import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/axio_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/roadmap_providers.dart';
import '../domain/roadmap_models.dart';
import 'widgets/exam_countdown_header.dart';
import 'widgets/focal_roadmap_list.dart';

/// The student's coaching-synced study roadmap: exam countdown, this-week
/// focus, catch-up for overdue items, and the upcoming timeline.
class RoadmapScreen extends ConsumerWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(roadmapProvider);
    final enrollmentAsync = ref.watch(enrollmentProvider);
    final examType = enrollmentAsync.whenOrNull(
          data: (e) => e?.examType,
        ) ??
        ExamType.jee;

    return GradientBackground(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          // Pop when pushed (enables the iOS swipe-back too); otherwise fall
          // back to Home so there's always a way out.
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('My Roadmap'),
        actions: [
          IconButton(
            tooltip: 'Re-plan',
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () => ref.invalidate(roadmapProvider),
          ),
          IconButton(
            tooltip: 'Edit setup',
            icon: const Icon(LucideIcons.settings2, size: 20),
            onPressed: () => context.push('/roadmap/setup'),
          ),
        ],
      ),
      child: roadmapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: '$e'),
        data: (roadmap) {
          if (roadmap == null) return const _SetupPrompt();
          return _RoadmapContent(roadmap: roadmap, examType: examType);
        },
      ),
    );
  }
}

class _RoadmapContent extends ConsumerWidget {
  final Roadmap roadmap;
  final ExamType examType;
  const _RoadmapContent({required this.roadmap, required this.examType});

  void _onStart(BuildContext context, RoadmapItem item) {
    if (item.type == RoadmapItemType.mock) {
      context.push('/test-selection');
    } else {
      // Open the exact chapter in the subject's practice view (auto-focused).
      context.push('/subjects/${item.subjectId}?chapter=${item.chapterId}');
    }
  }

  Future<void> _toggle(WidgetRef ref, RoadmapItem item) {
    final controller = ref.read(roadmapControllerProvider);
    return controller.setItemStatus(
      item.id,
      item.isDone ? RoadmapItemStatus.upcoming : RoadmapItemStatus.done,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneCount = roadmap.items.where((i) => i.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AnimatedEntrance(
            child: ExamCountdownHeader(roadmap: roadmap, examType: examType),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              const Icon(LucideIcons.zap, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your plan, in order — scroll through it',
                  style: AppTypography.caption,
                ),
              ),
              Text('$doneCount/${roadmap.items.length} done',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
            ],
          ),
        ),
        // Apple-Watch-style focal scroll: all chapters (done ones checked off in
        // place), the centred one in focus. Auto-centres on this week.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FocalRoadmapList(
              items: roadmap.items,
              onStart: (item) => _onStart(context, item),
              onToggleDone: (item) => _toggle(ref, item),
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupPrompt extends StatelessWidget {
  const _SetupPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(LucideIcons.milestone, color: AppColors.white, size: 34),
            ),
            const SizedBox(height: 20),
            Text('Build your study roadmap',
                style: AppTypography.heading2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Tell us your coaching and exam date, and we\'ll sync your practice '
              'to your class and pace it toward the exam.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AxioButton(
              label: 'Get started',
              icon: LucideIcons.sparkles,
              width: 220,
              onPressed: () => context.push('/roadmap/setup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text('Couldn\'t load your roadmap',
                style: AppTypography.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                style: AppTypography.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
