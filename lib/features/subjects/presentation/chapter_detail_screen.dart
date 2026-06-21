import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/focal_scroll_list.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/subject_badge.dart';
import '../data/subjects_providers.dart';
import '../domain/subject_models.dart';
import '../domain/chapter_grade.dart';

class ChapterDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;

  /// When set (e.g. deep-linked from the roadmap), this chapter is auto-centred
  /// in the focal list and highlighted so it reads as "opened".
  final String? focusChapterId;

  const ChapterDetailScreen({
    super.key,
    required this.subjectId,
    this.focusChapterId,
  });

  @override
  ConsumerState<ChapterDetailScreen> createState() =>
      _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends ConsumerState<ChapterDetailScreen> {
  /// Selected class tab. Opens on the class of a deep-linked chapter so it's
  /// visible, otherwise defaults to Class 11.
  late ClassLevel _selected = widget.focusChapterId == null
      ? ClassLevel.class11
      : chapterClassLevel(widget.focusChapterId!);

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      loading: () => const GradientBackground(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => const GradientBackground(
        child: Center(child: Text('Error loading data')),
      ),
      data: (subjects) {
        final subject = subjects.firstWhere(
          (s) => s.id == widget.subjectId,
          orElse: () => subjects.first,
        );
        // Show only the selected class, listed bottom-up so the first chapter
        // (lowest id) sits at the bottom — the natural starting point — with
        // later chapters stacked above it in book order.
        final chapters = subject.chapters
            .where((c) => c.classLevel == _selected)
            .toList()
            .reversed
            .toList();

        // Open focused on the first chapter (now the bottom-most), unless a
        // specific chapter was deep-linked.
        var focusIndex = chapters.isEmpty ? 0 : chapters.length - 1;
        if (widget.focusChapterId != null) {
          final i = chapters.indexWhere((c) => c.id == widget.focusChapterId);
          if (i >= 0) focusIndex = i;
        }

        return GradientBackground(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.canPop() ? context.pop() : context.go('/practice'),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(subject.iconData, size: 20, color: AppColors.textDark),
                const SizedBox(width: 8),
                Text(subject.name),
              ],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: _ClassToggle(
                  selected: _selected,
                  onChanged: (level) => setState(() => _selected = level),
                ),
              ),
              Expanded(
                child: chapters.isEmpty
                    ? Center(
                        child: Text('No chapters yet',
                            style: AppTypography.bodyMedium),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        // Reset scroll/focus to the top whenever the class changes.
                        child: FocalScrollList(
                          key: ValueKey(_selected),
                          itemCount: chapters.length,
                          itemExtent: 124,
                          initialFocusIndex: focusIndex,
                          itemBuilder: (context, i) {
                            final chapter = chapters[i];
                            return _ChapterFocalTile(
                              chapter: chapter,
                              highlighted: chapter.id == widget.focusChapterId,
                              onTap: () =>
                                  context.push('/chapter/${chapter.id}'),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

}

/// Segmented "Class 11 / Class 12" switch with a sliding pill indicator.
class _ClassToggle extends StatelessWidget {
  final ClassLevel selected;
  final ValueChanged<ClassLevel> onChanged;

  const _ClassToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          // Sliding white pill behind the selected segment.
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: selected == ClassLevel.class11
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.slate900.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _segment(ClassLevel.class11),
              _segment(ClassLevel.class12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(ClassLevel level) {
    final isSelected = selected == level;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(level),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.textDark : AppColors.textMedium,
            ),
            child: Text(level.label),
          ),
        ),
      ),
    );
  }
}

/// Fixed-height chapter card used inside the focal list.
class _ChapterFocalTile extends StatelessWidget {
  final Chapter chapter;
  final bool highlighted;
  final VoidCallback onTap;

  const _ChapterFocalTile({
    required this.chapter,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted ? AppColors.primary.withValues(alpha: 0.55) : AppColors.divider,
              width: highlighted ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chapter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SubjectBadge(strength: chapter.strength),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${chapter.availableQuestions} questions',
                      style: AppTypography.caption),
                  const Spacer(),
                  Text(
                    '${(chapter.completionPercentage * 100).round()}%',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgressBar(progress: chapter.completionPercentage, height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
