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
import '../../../shared/models/enums.dart';
import '../../practice/data/practice_providers.dart';

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
            .where((c) => chapterClassLevel(c.id) == _selected)
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
                                  _showChapterSheet(context, subject, chapter),
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

  void _showChapterSheet(BuildContext context, Subject subject, Chapter chapter) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ChapterSheet(subject: subject, chapter: chapter),
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

/// Bottom sheet showing a chapter's topics + a Practice Now action.
class _ChapterSheet extends ConsumerStatefulWidget {
  final Subject subject;
  final Chapter chapter;
  const _ChapterSheet({required this.subject, required this.chapter});

  @override
  ConsumerState<_ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends ConsumerState<_ChapterSheet> {
  bool _busy = false;

  Future<void> _startPractice() async {
    setState(() => _busy = true);
    try {
      final chapter = widget.chapter;
      // Derive difficulty from the chapter's strength / completion.
      final difficulty = chapter.strength == TopicStrength.strong
          ? 'hard'
          : chapter.strength == TopicStrength.weak
              ? 'easy'
              : 'medium';
      final test = await ref.read(practiceRepositoryProvider).moreLikeThis(
            chapterId: chapter.id,
            currentDifficulty: difficulty,
            delta: 0,
          );
      if (!mounted) return;
      if (test.questions.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No practice questions available for this chapter yet.')),
        );
        return;
      }
      ref.read(activePracticeTestProvider.notifier).state = test;
      Navigator.of(context).pop();
      context.push('/practice/session');
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start practice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final chapter = widget.chapter;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(subject.iconData, size: 20, color: AppColors.textMedium),
                const SizedBox(width: 8),
                Expanded(child: Text(chapter.name, style: AppTypography.heading2)),
                SubjectBadge(strength: chapter.strength),
              ],
            ),
            const SizedBox(height: 16),
            if (chapter.topics.isEmpty)
              Text('No topics listed for this chapter yet.',
                  style: AppTypography.bodyMedium)
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: chapter.topics
                        .map((topic) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  SubjectBadge(strength: topic.strength),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(topic.name,
                                        style: AppTypography.bodyLarge),
                                  ),
                                  Text('${topic.availableQuestions}q',
                                      style: AppTypography.caption),
                                  IconButton(
                                    tooltip: 'AI study notes',
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(LucideIcons.bookOpen,
                                        size: 18, color: AppColors.primary),
                                    onPressed: () => context.push(
                                      Uri(
                                        path: '/notes/${topic.id}',
                                        queryParameters: {
                                          'name': topic.name,
                                          'chapter': topic.chapterId,
                                          'subject': subject.id,
                                        },
                                      ).toString(),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _startPractice,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Practice Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
