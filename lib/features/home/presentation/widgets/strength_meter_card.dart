import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../subjects/data/subjects_providers.dart';
import '../../../../shared/models/enums.dart';

class StrengthMeterCard extends ConsumerStatefulWidget {
  const StrengthMeterCard({super.key});

  @override
  ConsumerState<StrengthMeterCard> createState() => _StrengthMeterCardState();
}

class _StrengthMeterCardState extends ConsumerState<StrengthMeterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.barChart3, color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Strength Meter', style: AppTypography.heading3)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI Analysis',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.greenStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (subjects.isEmpty)
            _EmptyState()
          else
            ...subjects.asMap().entries.map((e) {
              final isLast = e.key == subjects.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: _SubjectBar(
                  subject: e.value,
                  color: _colorFor(e.value.type),
                  gradientColors: _gradientFor(e.value.type),
                  animController: _controller,
                  delay: e.key * 0.15,
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _colorFor(SubjectType t) => switch (t) {
    SubjectType.physics => AppColors.physics,
    SubjectType.chemistry => AppColors.chemistry,
    SubjectType.mathematics => AppColors.mathematics,
  };

  List<Color> _gradientFor(SubjectType t) => switch (t) {
    SubjectType.physics => [const Color(0xFF818CF8), AppColors.physics],
    SubjectType.chemistry => [const Color(0xFF38BDF8), AppColors.chemistry],
    SubjectType.mathematics => [const Color(0xFFFBBF24), AppColors.mathematics],
  };
}

class _SubjectBar extends StatelessWidget {
  final dynamic subject;
  final Color color;
  final List<Color> gradientColors;
  final AnimationController animController;
  final double delay;

  const _SubjectBar({
    required this.subject, required this.color,
    required this.gradientColors, required this.animController,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final pct = subject.completionPercentage as double;
    final strongChapter = (subject.chapters as List).isNotEmpty
        ? (subject.chapters as List).reduce((a, b) =>
            (a.completionPercentage as double) >= (b.completionPercentage as double) ? a : b).name as String
        : '—';
    final weakChapter = (subject.chapters as List).isNotEmpty
        ? (subject.chapters as List).reduce((a, b) =>
            (a.completionPercentage as double) <= (b.completionPercentage as double) ? a : b).name as String
        : '—';

    final anim = CurvedAnimation(
      parent: animController,
      curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(subject.iconData as IconData, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              subject.name as String,
              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: anim,
              builder: (context, child) => Text(
                '${(pct * 100 * anim.value).round()}%',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: anim,
          builder: (context, child) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: AppColors.surfaceDark),
                FractionallySizedBox(
                  widthFactor: pct * anim.value,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Pill(
              icon: LucideIcons.trendingUp,
              text: strongChapter,
              color: AppColors.primary,
              bg: AppColors.greenSurface,
            ),
            const SizedBox(width: 8),
            _Pill(
              icon: LucideIcons.alertTriangle,
              text: weakChapter,
              color: AppColors.weak,
              bg: AppColors.warningLight,
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color, bg;

  const _Pill({required this.icon, required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.greenWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.brain, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Take a diagnostic test to see your AI-powered strength analysis',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
            ),
          ),
        ],
      ),
    );
  }
}
