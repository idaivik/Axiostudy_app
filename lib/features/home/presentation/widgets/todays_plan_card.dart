import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../analytics/data/analytics_providers.dart';
import '../../../analytics/domain/analytics_models.dart';

class TodaysPlanCard extends ConsumerStatefulWidget {
  const TodaysPlanCard({super.key});

  @override
  ConsumerState<TodaysPlanCard> createState() => _TodaysPlanCardState();
}

class _TodaysPlanCardState extends ConsumerState<TodaysPlanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Set<int> _completedItems = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(int i) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_completedItems.contains(i)) {
        _completedItems.remove(i);
      } else {
        _completedItems.add(i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recsAsync = ref.watch(recommendationsProvider);
    final recommendations = recsAsync.valueOrNull ?? [];

    // Convert recommendations to plan items
    final items = recommendations.take(4).toList();

    // If no recommendations, show empty state with default items
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    final done = _completedItems.length;
    final total = items.length;
    final allDone = done == total;
    final nextIdx = Iterable.generate(total).where((i) => !_completedItems.contains(i)).firstOrNull;
    final progress = total > 0 ? done / total : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.greenSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.listChecks, color: AppColors.primary, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Focus", style: AppTypography.heading3),
                      Text(
                        allDone ? 'All topics completed!' : '$done of $total completed',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.greenSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'AI Plan',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.greenStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: val,
                  minHeight: 5,
                  backgroundColor: AppColors.surfaceDark,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          ...List.generate(items.length, (i) {
            final rec = items[i];
            final isDone = _completedItems.contains(i);
            return _ItemTile(
              rec: rec,
              isDone: isDone,
              isLast: i == items.length - 1,
              onToggle: () => _toggle(i),
              onNavigate: () {
                if (rec.subjectId != null) {
                  context.push('/subjects/${rec.subjectId}');
                }
              },
            );
          }),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: allDone ? null : () {
                  if (nextIdx != null && items[nextIdx].subjectId != null) {
                    context.push('/subjects/${items[nextIdx].subjectId}');
                  }
                },
                icon: Icon(allDone ? LucideIcons.checkCircle2 : LucideIcons.play, size: 16),
                label: Text(
                  allDone ? 'All done for today!' : done > 0 ? 'Continue studying' : 'Start studying',
                  style: AppTypography.button,
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: allDone ? AppColors.primary.withValues(alpha: 0.7) : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.greenSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.brain, color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Focus", style: AppTypography.heading3),
                const SizedBox(height: 3),
                Text(
                  'Take a test to get your AI-powered study plan',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Recommendation rec;
  final bool isDone;
  final bool isLast;
  final VoidCallback onToggle, onNavigate;

  const _ItemTile({
    required this.rec, required this.isDone, required this.isLast,
    required this.onToggle, required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(rec.type, rec.subjectId);
    final color = _colorForSubject(rec.subjectId);
    final subject = _subjectName(rec.subjectId);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, isLast ? 16 : 0),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isDone
                              ? Icon(LucideIcons.checkCircle2, key: const ValueKey('done'), size: 18, color: AppColors.primary)
                              : Icon(icon, key: const ValueKey('icon'), size: 16, color: color),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onNavigate,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec.title,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone ? AppColors.textLight : AppColors.textDark,
                            ),
                          ),
                          Text(
                            subject,
                            style: AppTypography.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _tagColor(rec.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      _tagLabel(rec.type),
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _tagColor(rec.type),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isLast)
            Divider(color: AppColors.divider.withValues(alpha: 0.6), height: 1, thickness: 0.5),
        ],
      ),
    );
  }

  IconData _iconForType(String type, String? subjectId) {
    switch (subjectId) {
      case 'physics': return LucideIcons.atom;
      case 'chemistry': return LucideIcons.flaskConical;
      case 'mathematics': return LucideIcons.sigma;
      default: return LucideIcons.bookOpen;
    }
  }

  Color _colorForSubject(String? subjectId) {
    switch (subjectId) {
      case 'physics': return AppColors.physics;
      case 'chemistry': return AppColors.chemistry;
      case 'mathematics': return AppColors.mathematics;
      default: return AppColors.primary;
    }
  }

  String _subjectName(String? subjectId) {
    switch (subjectId) {
      case 'physics': return 'Physics';
      case 'chemistry': return 'Chemistry';
      case 'mathematics': return 'Mathematics';
      default: return 'General';
    }
  }

  Color _tagColor(String type) {
    switch (type) {
      case 'weak_topic_drill': return AppColors.wrong;
      case 'revision': return AppColors.weak;
      case 'challenge': return AppColors.primary;
      default: return AppColors.textMedium;
    }
  }

  String _tagLabel(String type) {
    switch (type) {
      case 'weak_topic_drill': return 'Weak';
      case 'revision': return 'Revise';
      case 'challenge': return 'Challenge';
      case 'chapter_test': return 'Test';
      default: return 'Focus';
    }
  }
}
