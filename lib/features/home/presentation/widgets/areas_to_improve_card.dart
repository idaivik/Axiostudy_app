import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/data/mock_data.dart';
import '../../../../shared/models/enums.dart';

class AreasToImproveCard extends StatelessWidget {
  const AreasToImproveCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('Areas to Improve', style: AppTypography.heading2),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: MockData.areasToImprove.length,
            separatorBuilder: (_, i) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final area = MockData.areasToImprove[index];
              final subjectType = area['color'] as SubjectType;
              return _SubjectAreaCard(
                subject: area['subject'] as String,
                icon: area['icon'] as String,
                weakTopic: area['weakTopic'] as String,
                strongTopic: area['strongTopic'] as String,
                score: area['score'] as double,
                gradient: _gradientFor(subjectType),
                onTap: () {
                  final subjectId = subjectType.name;
                  context.push('/subjects/$subjectId');
                },
              );
            },
          ),
        ),
      ],
    );
  }

  LinearGradient _gradientFor(SubjectType type) {
    switch (type) {
      case SubjectType.physics:
        return AppColors.physicsGradient;
      case SubjectType.chemistry:
        return AppColors.chemistryGradient;
      case SubjectType.mathematics:
        return AppColors.mathematicsGradient;
    }
  }
}

class _SubjectAreaCard extends StatelessWidget {
  final String subject;
  final String icon;
  final String weakTopic;
  final String strongTopic;
  final double score;
  final LinearGradient gradient;
  final VoidCallback? onTap;

  const _SubjectAreaCard({
    required this.subject,
    required this.icon,
    required this.weakTopic,
    required this.strongTopic,
    required this.score,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subject,
                    style: AppTypography.heading3,
                  ),
                ),
                Text(
                  '${(score * 100).round()}%',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _TopicRow(
              label: 'Weak',
              topic: weakTopic,
              color: AppColors.warning,
              icon: Icons.trending_down_rounded,
            ),
            const SizedBox(height: 6),
            _TopicRow(
              label: 'Strong',
              topic: strongTopic,
              color: AppColors.success,
              icon: Icons.trending_up_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final String label;
  final String topic;
  final Color color;
  final IconData icon;

  const _TopicRow({
    required this.label,
    required this.topic,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            topic,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
