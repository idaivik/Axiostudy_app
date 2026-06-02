import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';
import '../../../../core/widgets/subject_badge.dart';
import '../../../../shared/models/enums.dart';
import '../../../analytics/domain/analytics_models.dart';

class ChapterAnalysisCard extends StatelessWidget {
  final Map<String, ChapterBreakdown>? breakdown;
  const ChapterAnalysisCard({super.key, this.breakdown});

  @override
  Widget build(BuildContext context) {
    final chapters = breakdown?.values.toList() ?? [];

    if (chapters.isEmpty) {
      return AxioCard(
        title: 'Chapter Analysis',
        leading: Icon(LucideIcons.lineChart, color: AppColors.warning, size: 22),
        collapsedContent: Text('No chapter data yet', style: AppTypography.bodyMedium),
        expandedContent: const SizedBox.shrink(),
      );
    }

    // Sort by accuracy ascending (weak first)
    final sorted = List<ChapterBreakdown>.from(chapters)
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    final weakCount = sorted.where((c) => c.accuracy < 0.5).length;

    return AxioCard(
      title: 'Chapter Analysis',
      leading: Icon(LucideIcons.lineChart, color: AppColors.warning, size: 22),
      collapsedContent: Text(
        weakCount > 0 ? '$weakCount weak chapters identified' : 'All chapters performing well',
        style: AppTypography.bodyMedium,
      ),
      expandedContent: Column(
        children: sorted.asMap().entries.map((entry) {
          final c = entry.value;
          final score = (c.accuracy * 100).round();
          final strength = score < 40
              ? TopicStrength.weak
              : score < 70
                  ? TopicStrength.moderate
                  : TopicStrength.strong;
          final subjectName = _subjectName(c.subjectId);

          return Padding(
            padding: EdgeInsets.only(bottom: entry.key == sorted.length - 1 ? 0 : 8),
            child: _ChapterRow(
              name: c.chapterName,
              subject: subjectName,
              score: score,
              strength: strength,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _subjectName(String id) {
    switch (id) {
      case 'physics': return 'Physics';
      case 'chemistry': return 'Chemistry';
      case 'mathematics': return 'Mathematics';
      default: return id;
    }
  }
}

class _ChapterRow extends StatelessWidget {
  final String name;
  final String subject;
  final int score;
  final TopicStrength strength;

  const _ChapterRow({
    required this.name,
    required this.subject,
    required this.score,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                Text(subject, style: AppTypography.caption),
              ],
            ),
          ),
          Text('$score%', style: AppTypography.heading3),
          const SizedBox(width: 8),
          SubjectBadge(strength: strength),
        ],
      ),
    );
  }
}
