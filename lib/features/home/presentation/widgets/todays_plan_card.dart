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
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late PageController _pageController;
  final Set<int> _completedItems = {};
  bool _isExpanded = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
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

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() => _isExpanded = !_isExpanded);
  }

  void _collapse() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recsAsync = ref.watch(recommendationsProvider);
    final recommendations = recsAsync.valueOrNull ?? [];
    final items = recommendations.take(6).toList();

    if (items.isEmpty) {
      return _buildEmptyState();
    }

    final done = _completedItems.length;
    final total = items.length;
    final allDone = done == total;
    final nextIdx = Iterable.generate(total)
        .where((i) => !_completedItems.contains(i))
        .firstOrNull;

    return TapRegion(
      onTapOutside: (_) => _collapse(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
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
            // ─── Header ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.greenSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(LucideIcons.listChecks,
                        color: AppColors.primary, size: 17),
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
                              : '$done of $total completed',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
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
                  const SizedBox(width: 4),
                  // Animated Chevron
                  GestureDetector(
                    onTap: _toggleExpanded,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: 20,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Timeline Indicator ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _TimelineIndicator(
                total: total,
                currentPage: _currentPage,
                completedItems: _completedItems,
                pulseAnimation: _pulseController,
              ),
            ),
            const SizedBox(height: 16),

            // ─── Content: Pager or List ───────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 350),
              sizeCurve: Curves.easeInOutCubic,
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildPager(items),
              secondChild: _buildExpandedList(items),
            ),

            // ─── CTA Button ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: allDone
                      ? null
                      : () {
                          if (nextIdx != null &&
                              items[nextIdx].subjectId != null) {
                            context
                                .push('/subjects/${items[nextIdx].subjectId}');
                          }
                        },
                  icon: Icon(
                      allDone
                          ? LucideIcons.checkCircle2
                          : LucideIcons.play,
                      size: 16),
                  label: Text(
                    allDone
                        ? 'All done for today!'
                        : done > 0
                            ? 'Continue studying'
                            : 'Start studying',
                    style: AppTypography.button,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    backgroundColor: allDone
                        ? AppColors.primary.withValues(alpha: 0.7)
                        : AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Horizontal Pager (Collapsed View) ────────────────
  Widget _buildPager(List<Recommendation> items) {
    return SizedBox(
      height: 120,
      child: PageView.builder(
        controller: _pageController,
        itemCount: items.length,
        onPageChanged: (page) {
          setState(() => _currentPage = page);
        },
        itemBuilder: (context, index) {
          final rec = items[index];
          final isDone = _completedItems.contains(index);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PagerCard(
              rec: rec,
              isDone: isDone,
              index: index,
              onToggle: () => _toggle(index),
              onNavigate: () {
                if (rec.subjectId != null) {
                  context.push('/subjects/${rec.subjectId}');
                }
              },
            ),
          );
        },
      ),
    );
  }

  // ─── Vertical List (Expanded View) ────────────────────
  Widget _buildExpandedList(List<Recommendation> items) {
    return Column(
      children: List.generate(items.length, (i) {
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
    );
  }

  // ─── Empty State ──────────────────────────────────────
  Widget _buildEmptyState() {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.greenSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(LucideIcons.brain, color: AppColors.primary, size: 17),
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
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Custom Timeline Indicator
// ═══════════════════════════════════════════════════════════

class _TimelineIndicator extends StatelessWidget {
  final int total;
  final int currentPage;
  final Set<int> completedItems;
  final AnimationController pulseAnimation;

  const _TimelineIndicator({
    required this.total,
    required this.currentPage,
    required this.completedItems,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: CustomPaint(
        size: const Size(double.infinity, 24),
        painter: _TimelinePainter(
          total: total,
          currentPage: currentPage,
          completedItems: completedItems,
          pulseValue: pulseAnimation,
          primaryColor: AppColors.primary,
          mutedColor: AppColors.surfaceDark,
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final int total;
  final int currentPage;
  final Set<int> completedItems;
  final Animation<double> pulseValue;
  final Color primaryColor;
  final Color mutedColor;

  _TimelinePainter({
    required this.total,
    required this.currentPage,
    required this.completedItems,
    required this.pulseValue,
    required this.primaryColor,
    required this.mutedColor,
  }) : super(repaint: pulseValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 1) return;

    final centerY = size.height / 2;
    final nodeRadius = 5.0;
    final hPad = 16.0;
    final usableWidth = size.width - hPad * 2;
    final step = usableWidth / (total - 1);

    // Draw connecting lines first
    for (int i = 0; i < total - 1; i++) {
      final startX = hPad + i * step;
      final endX = hPad + (i + 1) * step;
      final isCompleted = completedItems.contains(i);

      if (isCompleted) {
        // Solid green line for completed segments
        final paint = Paint()
          ..color = primaryColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(startX, centerY), Offset(endX, centerY), paint);
      } else {
        // Dashed muted line for upcoming segments
        final paint = Paint()
          ..color = mutedColor
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;

        const dashLength = 5.0;
        const gapLength = 4.0;
        double x = startX;
        while (x < endX) {
          final dashEnd = (x + dashLength).clamp(startX, endX);
          canvas.drawLine(Offset(x, centerY), Offset(dashEnd, centerY), paint);
          x += dashLength + gapLength;
        }
      }
    }

    // Draw nodes
    for (int i = 0; i < total; i++) {
      final x = hPad + i * step;
      final isCompleted = completedItems.contains(i);
      final isCurrent = i == currentPage;

      if (isCompleted) {
        // Completed: filled green circle with checkmark
        final fill = Paint()..color = primaryColor;
        canvas.drawCircle(Offset(x, centerY), nodeRadius, fill);

        // White check mark
        final checkPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final path = Path()
          ..moveTo(x - 2.5, centerY)
          ..lineTo(x - 0.5, centerY + 2.5)
          ..lineTo(x + 3, centerY - 2);
        canvas.drawPath(path, checkPaint);
      } else if (isCurrent) {
        // Current: glowing dot
        final glowRadius = nodeRadius + 4 * pulseValue.value;
        final glowPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.15 + 0.1 * pulseValue.value)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(x, centerY), glowRadius, glowPaint);

        // Outer ring
        final ringPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset(x, centerY), nodeRadius + 2, ringPaint);

        // Inner dot
        final dotPaint = Paint()..color = primaryColor;
        canvas.drawCircle(Offset(x, centerY), nodeRadius - 1, dotPaint);
      } else {
        // Upcoming: empty circle
        final borderPaint = Paint()
          ..color = mutedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset(x, centerY), nodeRadius, borderPaint);

        final innerPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(x, centerY), nodeRadius - 1, innerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.currentPage != currentPage ||
        oldDelegate.completedItems != completedItems;
  }
}

// ═══════════════════════════════════════════════════════════
// Pager Card — Single task shown in PageView
// ═══════════════════════════════════════════════════════════

class _PagerCard extends StatelessWidget {
  final Recommendation rec;
  final bool isDone;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onNavigate;

  const _PagerCard({
    required this.rec,
    required this.isDone,
    required this.index,
    required this.onToggle,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconForSubject(rec.subjectId);
    final color = _colorForSubject(rec.subjectId);
    final subject = _subjectName(rec.subjectId);

    return GestureDetector(
      onTap: onNavigate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.greenSurface.withValues(alpha: 0.4)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDone
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isDone
                            ? Icon(LucideIcons.checkCircle2,
                                key: const ValueKey('done'),
                                size: 18,
                                color: AppColors.primary)
                            : Icon(icon,
                                key: const ValueKey('icon'),
                                size: 16,
                                color: color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.title,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                          color:
                              isDone ? AppColors.textLight : AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            if (rec.subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                rec.subtitle!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMedium,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Expanded List Item
// ═══════════════════════════════════════════════════════════

class _ItemTile extends StatelessWidget {
  final Recommendation rec;
  final bool isDone;
  final bool isLast;
  final VoidCallback onToggle, onNavigate;

  const _ItemTile({
    required this.rec,
    required this.isDone,
    required this.isLast,
    required this.onToggle,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconForSubject(rec.subjectId);
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
                              ? Icon(LucideIcons.checkCircle2,
                                  key: const ValueKey('done'),
                                  size: 18,
                                  color: AppColors.primary)
                              : Icon(icon,
                                  key: const ValueKey('icon'),
                                  size: 16,
                                  color: color),
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
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                              color: isDone
                                  ? AppColors.textLight
                                  : AppColors.textDark,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            Divider(
                color: AppColors.surfaceDark.withValues(alpha: 0.6),
                height: 1,
                thickness: 0.5),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Shared Helpers
// ═══════════════════════════════════════════════════════════

IconData _iconForSubject(String? subjectId) {
  switch (subjectId) {
    case 'physics':
      return LucideIcons.atom;
    case 'chemistry':
      return LucideIcons.flaskConical;
    case 'mathematics':
      return LucideIcons.sigma;
    default:
      return LucideIcons.bookOpen;
  }
}

Color _colorForSubject(String? subjectId) {
  switch (subjectId) {
    case 'physics':
      return AppColors.physics;
    case 'chemistry':
      return AppColors.chemistry;
    case 'mathematics':
      return AppColors.mathematics;
    default:
      return AppColors.primary;
  }
}

String _subjectName(String? subjectId) {
  switch (subjectId) {
    case 'physics':
      return 'Physics';
    case 'chemistry':
      return 'Chemistry';
    case 'mathematics':
      return 'Mathematics';
    default:
      return 'General';
  }
}

Color _tagColor(String type) {
  switch (type) {
    case 'weak_topic_drill':
      return AppColors.wrong;
    case 'revision':
      return AppColors.weak;
    case 'challenge':
      return AppColors.primary;
    default:
      return AppColors.textMedium;
  }
}

String _tagLabel(String type) {
  switch (type) {
    case 'weak_topic_drill':
      return 'Weak';
    case 'revision':
      return 'Revise';
    case 'challenge':
      return 'Challenge';
    case 'chapter_test':
      return 'Test';
    default:
      return 'Focus';
  }
}
