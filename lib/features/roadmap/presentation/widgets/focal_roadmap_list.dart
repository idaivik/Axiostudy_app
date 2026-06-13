import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/focal_scroll_list.dart';
import '../../domain/roadmap_models.dart';

/// Apple-Watch–style focal scrolling list of roadmap items.
///
/// Every item (including completed ones, shown checked-off in place) is rendered
/// in a [FocalScrollList], which scales/fades items by distance from the focal
/// line. On open it auto-centres the most relevant item (this week).
class FocalRoadmapList extends StatelessWidget {
  static const double _extent = 116;

  final List<RoadmapItem> items;
  final void Function(RoadmapItem) onStart;
  final void Function(RoadmapItem) onToggleDone;

  const FocalRoadmapList({
    super.key,
    required this.items,
    required this.onStart,
    required this.onToggleDone,
  });

  /// First this-week item, else the first not-done item.
  int get _initialFocusIndex {
    var index = items.indexWhere((i) => i.isThisWeek && !i.isDone);
    if (index < 0) index = items.indexWhere((i) => !i.isDone);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('Nothing scheduled yet.', style: AppTypography.bodyMedium),
      );
    }

    return FocalScrollList(
      itemCount: items.length,
      itemExtent: _extent,
      initialFocusIndex: _initialFocusIndex,
      itemBuilder: (context, i) {
        final item = items[i];
        return _FocalTile(
          item: item,
          onStart: () => onStart(item),
          onToggleDone: () => onToggleDone(item),
        );
      },
    );
  }
}

/// Fixed-height tile used inside the focal list.
class _FocalTile extends StatelessWidget {
  final RoadmapItem item;
  final VoidCallback onStart;
  final VoidCallback onToggleDone;

  const _FocalTile({
    required this.item,
    required this.onStart,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.type.color;
    final done = item.isDone;
    final status = _displayStatus(item);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PressableScale(
        onTap: done ? onToggleDone : onStart,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: done ? AppColors.greenWash : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: status == RoadmapItemStatus.current
                  ? color.withValues(alpha: 0.55)
                  : AppColors.divider,
              width: status == RoadmapItemStatus.current ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.slate900.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: done ? 0.10 : 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.type.iconData, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Pill(label: item.type.label, color: color),
                        const SizedBox(width: 6),
                        _StatusPill(status: status),
                        const Spacer(),
                        Text(_dateRange(item), style: AppTypography.caption),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.chapterName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading3.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PressableScale(
                onTap: onToggleDone,
                child: Icon(
                  done ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  color: done ? AppColors.success : AppColors.textLight,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dateRange(RoadmapItem item) {
    final fmt = DateFormat('d MMM');
    if (DateUtils.isSameDay(item.scheduledStart, item.scheduledEnd)) {
      return fmt.format(item.scheduledStart);
    }
    return '${fmt.format(item.scheduledStart)} – ${fmt.format(item.scheduledEnd)}';
  }

  static RoadmapItemStatus _displayStatus(RoadmapItem item) {
    if (item.isDone) return RoadmapItemStatus.done;
    if (item.isThisWeek) return RoadmapItemStatus.current;
    final today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.dateOnly(item.scheduledEnd).isBefore(today)) {
      return RoadmapItemStatus.overdue;
    }
    return RoadmapItemStatus.upcoming;
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final RoadmapItemStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RoadmapItemStatus.current => AppColors.primary,
      RoadmapItemStatus.overdue => AppColors.warning,
      RoadmapItemStatus.done => AppColors.success,
      _ => AppColors.textLight,
    };
    return Text(
      status.label,
      style: AppTypography.labelSmall.copyWith(color: color, fontSize: 10),
    );
  }
}
