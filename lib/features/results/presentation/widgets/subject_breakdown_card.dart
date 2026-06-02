import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';
import '../../../../core/widgets/progress_bar.dart';
import '../../../analytics/domain/analytics_models.dart';

class SubjectBreakdownCard extends StatelessWidget {
  final Map<String, SubjectBreakdown>? breakdown;
  const SubjectBreakdownCard({super.key, this.breakdown});

  @override
  Widget build(BuildContext context) {
    final subjects = breakdown?.values.toList() ?? [];

    // Fallback label & data
    if (subjects.isEmpty) {
      return AxioCard(
        title: 'Subject Breakdown',
        leading: Icon(LucideIcons.pieChart, color: AppColors.primary, size: 22),
        collapsedContent: Text('No subject data yet', style: AppTypography.bodyMedium),
        expandedContent: const SizedBox.shrink(),
      );
    }

    return AxioCard(
      title: 'Subject Breakdown',
      leading: Icon(LucideIcons.pieChart, color: AppColors.primary, size: 22),
      expandedContent: Column(
        children: subjects.map((s) {
          final color = _colorFor(s.subjectId);
          final icon = _iconFor(s.subjectId);
          return Padding(
            padding: EdgeInsets.only(bottom: s == subjects.last ? 0 : 14),
            child: _SubjectBar(name: s.subjectName, score: s.accuracy, icon: icon, color: color),
          );
        }).toList(),
      ),
      collapsedContent: Row(
        children: subjects.map((s) {
          final color = _colorFor(s.subjectId);
          final label = s.subjectName.substring(0, 3).toUpperCase();
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _MiniScore(label: label, score: '${(s.accuracy * 100).round()}%', color: color),
          );
        }).toList(),
      ),
    );
  }

  Color _colorFor(String subjectId) {
    switch (subjectId) {
      case 'physics': return AppColors.physics;
      case 'chemistry': return AppColors.chemistry;
      case 'mathematics': return AppColors.mathematics;
      default: return AppColors.primary;
    }
  }

  IconData _iconFor(String subjectId) {
    switch (subjectId) {
      case 'physics': return LucideIcons.atom;
      case 'chemistry': return LucideIcons.flaskConical;
      case 'mathematics': return LucideIcons.sigma;
      default: return LucideIcons.bookOpen;
    }
  }
}

class _SubjectBar extends StatelessWidget {
  final String name;
  final double score;
  final IconData icon;
  final Color color;

  const _SubjectBar({
    required this.name,
    required this.score,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${(score * 100).round()}%', style: AppTypography.heading3.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(progress: score, height: 8, progressColor: color),
      ],
    );
  }
}

class _MiniScore extends StatelessWidget {
  final String label;
  final String score;
  final Color color;
  const _MiniScore({required this.label, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $score',
        style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
