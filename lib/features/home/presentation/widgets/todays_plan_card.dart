import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class TodaysPlanCard extends StatefulWidget {
  const TodaysPlanCard({super.key});

  @override
  State<TodaysPlanCard> createState() => _TodaysPlanCardState();
}

class _TodaysPlanCardState extends State<TodaysPlanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_PlanItem> _items;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _items = [
      _PlanItem(icon: LucideIcons.atom, color: AppColors.physics, topic: 'Rotational Motion', subject: 'Physics', subjectId: 'physics', duration: '25 min', done: true),
      _PlanItem(icon: LucideIcons.flaskConical, color: AppColors.chemistry, topic: 'Electrochemistry', subject: 'Chemistry', subjectId: 'chemistry', duration: '30 min', done: false),
      _PlanItem(icon: LucideIcons.sigma, color: AppColors.mathematics, topic: 'Matrices & Determinants', subject: 'Mathematics', subjectId: 'mathematics', duration: '20 min', done: false),
      _PlanItem(icon: LucideIcons.atom, color: AppColors.physics, topic: 'Thermodynamics Review', subject: 'Physics', subjectId: 'physics', duration: '15 min', done: false),
    ];
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
      _items[i] = _items[i].copyWith(done: !_items[i].done);
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _items.where((p) => p.done).length;
    final total = _items.length;
    final allDone = done == total;
    final next = _items.where((p) => !p.done).firstOrNull;
    final progress = done / total;

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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: allDone ? AppColors.greenSurface : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    allDone ? 'Done' : '$done/$total',
                    style: AppTypography.labelSmall.copyWith(
                      color: allDone ? AppColors.primary : AppColors.textMedium,
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

          ...List.generate(_items.length, (i) => _ItemTile(
            item: _items[i],
            isLast: i == _items.length - 1,
            onToggle: () => _toggle(i),
            onNavigate: () => context.push('/subjects/${_items[i].subjectId}'),
          )),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: allDone ? null : () {
                  if (next != null) context.push('/subjects/${next.subjectId}');
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
}

class _PlanItem {
  final IconData icon;
  final Color color;
  final String topic, subject, subjectId, duration;
  final bool done;

  const _PlanItem({
    required this.icon, required this.color, required this.topic,
    required this.subject, required this.subjectId, required this.duration,
    required this.done,
  });

  _PlanItem copyWith({bool? done}) => _PlanItem(
    icon: icon, color: color, topic: topic, subject: subject,
    subjectId: subjectId, duration: duration, done: done ?? this.done,
  );
}

class _ItemTile extends StatelessWidget {
  final _PlanItem item;
  final bool isLast;
  final VoidCallback onToggle, onNavigate;

  const _ItemTile({
    required this.item, required this.isLast,
    required this.onToggle, required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
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
                        color: item.done
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: item.done
                              ? Icon(LucideIcons.checkCircle2, key: const ValueKey('done'), size: 18, color: AppColors.primary)
                              : Icon(item.icon, key: const ValueKey('icon'), size: 16, color: item.color),
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
                            item.topic,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              decoration: item.done ? TextDecoration.lineThrough : null,
                              color: item.done ? AppColors.textLight : AppColors.textDark,
                            ),
                          ),
                          Text(
                            item.subject,
                            style: AppTypography.caption.copyWith(
                              color: item.color,
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
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.clock, size: 11, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(item.duration, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
                      ],
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
}
