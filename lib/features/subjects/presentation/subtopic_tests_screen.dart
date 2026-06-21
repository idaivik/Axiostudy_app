import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../practice/data/practice_providers.dart';
import '../../practice/domain/practice_models.dart';

/// Practice drill-down level 3: the named "Practice Test N" sets for a subtopic.
/// Each test is a fixed 10/10/10 set (or the smaller final remainder). Tapping
/// one assembles its questions and launches the shared test runner.
class SubtopicTestsScreen extends ConsumerWidget {
  final String subtopicId;
  final String? subtopicName;
  const SubtopicTestsScreen({
    super.key,
    required this.subtopicId,
    this.subtopicName,
  });

  Future<void> _startTest(
    BuildContext context,
    WidgetRef ref,
    SubtopicTest test,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final session = await ref.read(practiceRepositoryProvider).buildSubtopicTest(
            subtopicId: subtopicId,
            testIndex: test.index,
            subtopicName: subtopicName,
          );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (session.questions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No questions available for this test yet.')),
          );
        }
        return;
      }
      ref.read(activePracticeTestProvider.notifier).state = session;
      if (context.mounted) context.push('/practice/session');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start test: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subtopicTestsProvider(subtopicId));

    return GradientBackground(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(subtopicName ?? 'Practice', overflow: TextOverflow.ellipsis),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load tests', style: AppTypography.bodyMedium),
        ),
        data: (tests) {
          if (tests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No questions yet for this subtopic.\nCheck back soon.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: tests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final t = tests[i];
              return _TestTile(test: t, onTap: () => _startTest(context, ref, t));
            },
          );
        },
      ),
    );
  }
}

class _TestTile extends StatelessWidget {
  final SubtopicTest test;
  final VoidCallback onTap;

  const _TestTile({required this.test, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final breakdown =
        '${test.easyCount} easy · ${test.mediumCount} medium · ${test.hardCount} hard';
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.pencil, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(test.name,
                          style: AppTypography.bodyLarge
                              .copyWith(fontWeight: FontWeight.w600)),
                      if (test.isPartial) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Partial',
                              style: AppTypography.labelSmall
                                  .copyWith(color: AppColors.warning)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${test.questionCount} questions · $breakdown',
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
