import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The primary CTA card on the home screen.
/// Shows today's AI-recommended study topics with actionable items.
/// Tapping items toggles completion. "Start Studying" navigates to practice.
class TodaysPlanCard extends StatefulWidget {
  const TodaysPlanCard({super.key});

  @override
  State<TodaysPlanCard> createState() => _TodaysPlanCardState();
}

class _TodaysPlanCardState extends State<TodaysPlanCard> {
  late List<_PlanItem> _planItems;

  @override
  void initState() {
    super.initState();
    // Generate plan from actual weak topics in mock data
    _planItems = [
      _PlanItem(
        icon: LucideIcons.atom,
        iconColor: AppColors.physics,
        topic: 'Rotational Motion',
        subject: 'Physics',
        subjectId: 'physics',
        duration: '25 min',
        isCompleted: true,
      ),
      _PlanItem(
        icon: LucideIcons.flaskConical,
        iconColor: AppColors.chemistry,
        topic: 'Electrochemistry',
        subject: 'Chemistry',
        subjectId: 'chemistry',
        duration: '30 min',
        isCompleted: false,
      ),
      _PlanItem(
        icon: LucideIcons.sigma,
        iconColor: AppColors.mathematics,
        topic: 'Matrices & Determinants',
        subject: 'Mathematics',
        subjectId: 'mathematics',
        duration: '20 min',
        isCompleted: false,
      ),
      _PlanItem(
        icon: LucideIcons.atom,
        iconColor: AppColors.physics,
        topic: 'Thermodynamics Review',
        subject: 'Physics',
        subjectId: 'physics',
        duration: '15 min',
        isCompleted: false,
      ),
    ];
  }

  void _toggleItem(int index) {
    setState(() {
      _planItems[index] = _PlanItem(
        icon: _planItems[index].icon,
        iconColor: _planItems[index].iconColor,
        topic: _planItems[index].topic,
        subject: _planItems[index].subject,
        subjectId: _planItems[index].subjectId,
        duration: _planItems[index].duration,
        isCompleted: !_planItems[index].isCompleted,
      );
    });
  }

  void _navigateToSubject(String subjectId) {
    context.push('/subjects/$subjectId');
  }

  @override
  Widget build(BuildContext context) {
    final completed = _planItems.where((p) => p.isCompleted).length;
    final total = _planItems.length;
    final allDone = completed == total;

    // Find first incomplete item for "Start Studying"
    final nextItem = _planItems.where((p) => !p.isCompleted).firstOrNull;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.listChecks,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Focus", style: AppTypography.heading3),
                      Text(
                        allDone
                            ? 'All topics completed!'
                            : '$completed of $total topics completed',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: allDone
                        ? AppColors.successLight
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    allDone ? 'Done' : '$completed/$total',
                    style: AppTypography.labelSmall.copyWith(
                      color: allDone
                          ? AppColors.success
                          : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Plan items
          ...List.generate(_planItems.length, (index) {
            final item = _planItems[index];
            final isLast = index == _planItems.length - 1;
            return _PlanItemTile(
              item: item,
              isLast: isLast,
              onTap: () => _toggleItem(index),
              onNavigate: () => _navigateToSubject(item.subjectId),
            );
          }),
          // CTA Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: allDone
                    ? null
                    : () {
                        if (nextItem != null) {
                          _navigateToSubject(nextItem.subjectId);
                        }
                      },
                icon: Icon(
                  allDone ? LucideIcons.checkCircle : LucideIcons.play,
                  size: 18,
                ),
                label: Text(
                  allDone
                      ? 'All Done for Today!'
                      : completed > 0
                          ? 'Continue Studying'
                          : 'Start Studying',
                  style: AppTypography.button,
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: allDone ? AppColors.success : null,
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
  final Color iconColor;
  final String topic;
  final String subject;
  final String subjectId;
  final String duration;
  final bool isCompleted;

  const _PlanItem({
    required this.icon,
    required this.iconColor,
    required this.topic,
    required this.subject,
    required this.subjectId,
    required this.duration,
    required this.isCompleted,
  });
}

class _PlanItemTile extends StatelessWidget {
  final _PlanItem item;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onNavigate;

  const _PlanItemTile({
    required this.item,
    required this.isLast,
    required this.onTap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, isLast ? 16 : 0),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // Checkbox-style indicator
                  GestureDetector(
                    onTap: onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.isCompleted
                            ? AppColors.success.withValues(alpha: 0.1)
                            : item.iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: item.isCompleted
                            ? Icon(LucideIcons.checkCircle, size: 18, color: AppColors.success)
                            : Icon(item.icon, size: 16, color: item.iconColor),
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
                              decoration: item.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item.isCompleted
                                  ? AppColors.textLight
                                  : AppColors.textDark,
                            ),
                          ),
                          Text(
                            item.subject,
                            style: AppTypography.caption.copyWith(
                              color: item.iconColor,
                              fontWeight: FontWeight.w500,
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.clock, size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(
                          item.duration,
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Divider(
                color: AppColors.divider.withValues(alpha: 0.5),
                height: 20,
              ),
            ),
        ],
      ),
    );
  }
}
