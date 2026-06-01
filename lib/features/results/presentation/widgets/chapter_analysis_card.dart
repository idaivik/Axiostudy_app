import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';
import '../../../../core/widgets/subject_badge.dart';
import '../../../../shared/models/enums.dart';

class ChapterAnalysisCard extends StatelessWidget {
  const ChapterAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AxioCard(
      title: 'Chapter Analysis',
      leading: Icon(LucideIcons.lineChart, color: AppColors.warning, size: 22),
      collapsedContent: Text('3 weak chapters identified', style: AppTypography.bodyMedium),
      expandedContent: Column(
        children: const [
          _ChapterRow(name: 'Rotational Motion', subject: 'Physics', score: 35, strength: TopicStrength.weak),
          SizedBox(height: 8),
          _ChapterRow(name: 'Physical Chemistry', subject: 'Chemistry', score: 40, strength: TopicStrength.weak),
          SizedBox(height: 8),
          _ChapterRow(name: 'Thermodynamics', subject: 'Physics', score: 55, strength: TopicStrength.moderate),
          SizedBox(height: 8),
          _ChapterRow(name: 'Algebra', subject: 'Mathematics', score: 60, strength: TopicStrength.moderate),
          SizedBox(height: 8),
          _ChapterRow(name: 'Calculus', subject: 'Mathematics', score: 85, strength: TopicStrength.strong),
          SizedBox(height: 8),
          _ChapterRow(name: 'Mechanics', subject: 'Physics', score: 80, strength: TopicStrength.strong),
          SizedBox(height: 8),
          _ChapterRow(name: 'Organic Chemistry', subject: 'Chemistry', score: 70, strength: TopicStrength.strong),
        ],
      ),
    );
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
