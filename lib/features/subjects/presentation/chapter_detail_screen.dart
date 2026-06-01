import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../core/widgets/subject_badge.dart';
import '../../../shared/data/mock_data.dart';
import '../domain/subject_models.dart';

class ChapterDetailScreen extends StatelessWidget {
  final String subjectId;
  const ChapterDetailScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context) {
    final subject = MockData.subjects.firstWhere(
      (s) => s.id == subjectId,
      orElse: () => MockData.subjects.first,
    );

    return GradientBackground(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('${subject.icon} ${subject.name}'),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        itemCount: subject.chapters.length,
        itemBuilder: (context, index) {
          final chapter = subject.chapters[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChapterCard(chapter: chapter),
          );
        },
      ),
    );
  }
}

class _ChapterCard extends StatefulWidget {
  final Chapter chapter;
  const _ChapterCard({required this.chapter});

  @override
  State<_ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<_ChapterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ch = widget.chapter;
    return Container(
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
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(ch.name, style: AppTypography.heading3),
                      ),
                      SubjectBadge(strength: ch.strength),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${ch.availableQuestions} questions', style: AppTypography.caption),
                      const Spacer(),
                      Text(
                        '${(ch.completionPercentage * 100).round()}%',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressBar(progress: ch.completionPercentage, height: 6),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  ...ch.topics.map((topic) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SubjectBadge(strength: topic.strength),
                        const SizedBox(width: 8),
                        Expanded(child: Text(topic.name, style: AppTypography.bodyLarge)),
                        Text('${topic.availableQuestions}q', style: AppTypography.caption),
                      ],
                    ),
                  )),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Practice Now'),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}
