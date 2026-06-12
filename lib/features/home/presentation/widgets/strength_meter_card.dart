import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../subjects/data/subjects_providers.dart';
import '../../../subjects/domain/subject_models.dart';
import '../../../../shared/models/enums.dart';

class StrengthMeterCard extends ConsumerStatefulWidget {
  const StrengthMeterCard({super.key});

  @override
  ConsumerState<StrengthMeterCard> createState() => _StrengthMeterCardState();
}

class _StrengthMeterCardState extends ConsumerState<StrengthMeterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showAll = false;
  static const int _initialCount = 3;

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

  /// Deduplicate subjects by SubjectType, keeping the first occurrence.
  List<Subject> _deduplicateSubjects(List<Subject> subjects) {
    final seen = <SubjectType>{};
    final result = <Subject>[];
    for (final s in subjects) {
      if (!seen.contains(s.type)) {
        seen.add(s.type);
        result.add(s);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final rawSubjects = ref.watch(subjectsProvider).valueOrNull ?? [];
    final subjects = _deduplicateSubjects(rawSubjects);

    final displaySubjects = _showAll
        ? subjects
        : subjects.take(_initialCount).toList();
    final hasMore = subjects.length > _initialCount;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
          const SizedBox(height: 16),
          if (subjects.isEmpty)
            _EmptyState()
          else ...[
            ...displaySubjects.asMap().entries.map((e) {
              final isLast = e.key == displaySubjects.length - 1;
              return Column(
                children: [
                  _SubjectBar(
                    subject: e.value,
                    color: _colorFor(e.value.type),
                    gradientColors: _gradientFor(e.value.type),
                    animController: _controller,
                    delay: e.key * 0.15,
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppColors.surfaceDark,
                      ),
                    ),
                ],
              );
            }),
            // Show more / show less toggle
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _showAll = !_showAll),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.greenSurface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _showAll
                              ? 'Show less'
                              : 'Show ${subjects.length - _initialCount} more',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _showAll ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: Icon(
                            LucideIcons.chevronDown,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _colorFor(SubjectType t) => switch (t) {
    SubjectType.physics => AppColors.physics,
    SubjectType.chemistry => AppColors.chemistry,
    SubjectType.mathematics => AppColors.mathematics,
    SubjectType.biology => AppColors.biology,
  };

  List<Color> _gradientFor(SubjectType t) => switch (t) {
    SubjectType.physics => [const Color(0xFF818CF8), AppColors.physics],
    SubjectType.chemistry => [const Color(0xFF38BDF8), AppColors.chemistry],
    SubjectType.mathematics => [const Color(0xFFFBBF24), AppColors.mathematics],
    SubjectType.biology => [const Color(0xFFF472B6), AppColors.biology],
  };
}

class _SubjectBar extends StatelessWidget {
  final Subject subject;
  final Color color;
  final List<Color> gradientColors;
  final AnimationController animController;
  final double delay;

  const _SubjectBar({
    required this.subject,
    required this.color,
    required this.gradientColors,
    required this.animController,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final pct = subject.completionPercentage;
    final chapters = subject.chapters;
    final hasProgress = chapters.any((c) => c.completionPercentage > 0);
    final strongChapter = hasProgress
        ? chapters.reduce((a, b) =>
            a.completionPercentage >= b.completionPercentage ? a : b).name
        : '—';
    final weakChapter = hasProgress
        ? chapters.reduce((a, b) =>
            a.completionPercentage <= b.completionPercentage ? a : b).name
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
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(subject.iconData, size: 15, color: color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subject.name,
                style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                Container(height: 7, color: AppColors.surfaceDark),
                FractionallySizedBox(
                  widthFactor: pct * anim.value,
                  child: Container(
                    height: 7,
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
        const SizedBox(height: 10),
        Row(
          children: [
            Flexible(
              child: _Pill(
                icon: LucideIcons.trendingUp,
                text: strongChapter,
                color: AppColors.primary,
                bg: AppColors.greenSurface,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _Pill(
                icon: LucideIcons.alertTriangle,
                text: weakChapter,
                color: AppColors.warning,
                bg: AppColors.warningLight,
              ),
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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
