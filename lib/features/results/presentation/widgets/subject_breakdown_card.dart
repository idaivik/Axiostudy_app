import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/axio_card.dart';
import '../../../../core/widgets/progress_bar.dart';

class SubjectBreakdownCard extends StatelessWidget {
  const SubjectBreakdownCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AxioCard(
      title: 'Subject Breakdown',
      leading: Icon(LucideIcons.pieChart, color: AppColors.primary, size: 22),
      expandedContent: Column(
        children: [
          _SubjectBar(name: 'Physics', score: 0.85, icon: LucideIcons.atom, color: AppColors.physics),
          const SizedBox(height: 14),
          _SubjectBar(name: 'Chemistry', score: 0.60, icon: LucideIcons.flaskConical, color: AppColors.chemistry),
          const SizedBox(height: 14),
          _SubjectBar(name: 'Mathematics', score: 0.90, icon: LucideIcons.sigma, color: AppColors.mathematics),
        ],
      ),
      collapsedContent: Row(
        children: [
          _MiniScore(label: 'PHY', score: '85%', color: AppColors.physics),
          const SizedBox(width: 12),
          _MiniScore(label: 'CHE', score: '60%', color: AppColors.chemistry),
          const SizedBox(width: 12),
          _MiniScore(label: 'MAT', score: '90%', color: AppColors.mathematics),
        ],
      ),
    );
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
