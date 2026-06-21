import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/subjects_providers.dart';
import '../domain/subject_models.dart';
import '../../practice/data/practice_repository.dart';

/// Practice drill-down level 2: the subtopics inside a topic. Each subtopic
/// shows how many "Practice Test N" sets its questions yield. Tapping opens
/// that subtopic's test list.
class TopicSubtopicsScreen extends ConsumerWidget {
  final String topicId;
  final String? topicName;
  const TopicSubtopicsScreen({super.key, required this.topicId, this.topicName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subtopicsForTopicProvider(topicId));

    return GradientBackground(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(topicName ?? 'Topic', overflow: TextOverflow.ellipsis),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load subtopics', style: AppTypography.bodyMedium),
        ),
        data: (subtopics) {
          if (subtopics.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No subtopics yet for this topic.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: subtopics.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final st = subtopics[i];
              return _SubtopicTile(
                subtopic: st,
                onTap: () => context.push(
                  Uri(
                    path: '/subtopic/${st.id}',
                    queryParameters: {'name': st.name},
                  ).toString(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SubtopicTile extends StatelessWidget {
  final Subtopic subtopic;
  final VoidCallback onTap;

  const _SubtopicTile({required this.subtopic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tests = PracticeRepository.testsFromCounts(
      subtopic.easyCount,
      subtopic.mediumCount,
      subtopic.hardCount,
    );
    final testLabel = tests.isEmpty
        ? 'No tests yet'
        : '${tests.length} practice test${tests.length == 1 ? '' : 's'}';

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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.layers,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtopic.name,
                      style: AppTypography.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${subtopic.questionCount} questions · $testLabel',
                      style: AppTypography.caption),
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
