import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/subject_badge.dart';
import '../data/subjects_providers.dart';
import '../domain/subject_models.dart';

/// Practice drill-down level 1: the topics inside a chapter. Tapping a topic
/// opens its subtopics; the book icon opens AI study notes for the topic.
class ChapterTopicsScreen extends ConsumerWidget {
  final String chapterId;
  const ChapterTopicsScreen({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      loading: () => const GradientBackground(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const GradientBackground(
        child: Center(child: Text('Error loading data')),
      ),
      data: (subjects) {
        Subject? foundSubject;
        Chapter? foundChapter;
        for (final s in subjects) {
          for (final c in s.chapters) {
            if (c.id == chapterId) {
              foundSubject = s;
              foundChapter = c;
              break;
            }
          }
          if (foundChapter != null) break;
        }

        if (foundChapter == null || foundSubject == null) {
          return GradientBackground(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => context.pop(),
              ),
            ),
            child: Center(
              child: Text('Chapter not found', style: AppTypography.bodyMedium),
            ),
          );
        }

        final subject = foundSubject;
        final chapter = foundChapter;
        final topics = chapter.topics;

        return GradientBackground(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.pop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(subject.iconData, size: 20, color: AppColors.textDark),
                const SizedBox(width: 8),
                Flexible(child: Text(chapter.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          child: topics.isEmpty
              ? Center(
                  child: Text('No topics yet for this chapter.',
                      style: AppTypography.bodyMedium),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: topics.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final t = topics[i];
                    return _TopicTile(
                      topic: t,
                      onTap: () => context.push(
                        Uri(
                          path: '/topic/${t.id}',
                          queryParameters: {
                            'name': t.name,
                            'chapter': t.chapterId,
                            'subject': subject.id,
                          },
                        ).toString(),
                      ),
                      onNotes: () => context.push(
                        Uri(
                          path: '/notes/${t.id}',
                          queryParameters: {
                            'name': t.name,
                            'chapter': t.chapterId,
                            'subject': subject.id,
                          },
                        ).toString(),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _TopicTile extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;
  final VoidCallback onNotes;

  const _TopicTile({
    required this.topic,
    required this.onTap,
    required this.onNotes,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SubjectBadge(strength: topic.strength),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.name,
                      style: AppTypography.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Tap to choose a subtopic', style: AppTypography.caption),
                ],
              ),
            ),
            IconButton(
              tooltip: 'AI study notes',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.bookOpen, size: 18, color: AppColors.primary),
              onPressed: onNotes,
            ),
            const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
