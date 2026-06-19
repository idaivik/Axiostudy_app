import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../shared/models/enums.dart';
import '../../subscription/domain/entitlements.dart';
import '../../subscription/presentation/feature_gate.dart';
import '../../subscription/presentation/paywall_screen.dart';
import '../data/revision_providers.dart';
import '../domain/revision_models.dart';

/// Feature 1 (Pro) — the spaced-repetition revision plan: a viewable surface +
/// review loop over the SAME SM-2 schedule the reminder engine maintains.
/// "Due today" / "Upcoming"; each item starts a practice set or advances the
/// curve. Pro-gated (Basic sees the upsell); deterministic, no meter.
class RevisionPlanScreen extends ConsumerWidget {
  const RevisionPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GradientBackground(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Revision Plan'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () => ref.invalidate(revisionPlanProvider),
          ),
        ],
      ),
      child: FeatureGate(
        feature: Feature.advancedRevisionPlan,
        locked: (_) => const _RevisionLocked(),
        child: (_) => const _RevisionContent(),
      ),
    );
  }
}

class _RevisionContent extends ConsumerWidget {
  const _RevisionContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(revisionPlanProvider);
    return planAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _RevisionError(),
      data: (plan) {
        final due = plan.dueToday;
        final upcoming = plan.upcoming;
        if (due.isEmpty && upcoming.isEmpty) return const _RevisionEmpty();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            _IntroCard(dueCount: due.length),
            const SizedBox(height: 16),
            if (due.isNotEmpty) ...[
              _SectionHeader(
                icon: LucideIcons.alarmClock,
                title: 'Due today',
                count: due.length,
                color: AppColors.weak,
              ),
              const SizedBox(height: 10),
              ...due.asMap().entries.map((e) => AnimatedEntrance(
                    delay: Duration(milliseconds: 60 * (e.key + 1)),
                    child: _DueItemCard(item: e.value),
                  )),
              const SizedBox(height: 20),
            ],
            if (upcoming.isNotEmpty) ...[
              _SectionHeader(
                icon: LucideIcons.calendarClock,
                title: 'Upcoming',
                count: upcoming.length,
                color: AppColors.primary,
              ),
              const SizedBox(height: 10),
              ...upcoming.take(15).map((i) => _UpcomingItemRow(item: i)),
            ],
          ],
        );
      },
    );
  }
}

class _IntroCard extends StatelessWidget {
  final int dueCount;
  const _IntroCard({required this.dueCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(LucideIcons.repeat, color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dueCount == 0
                      ? 'Nothing due right now'
                      : '$dueCount topic${dueCount == 1 ? '' : 's'} to revise today',
                  style: AppTypography.heading3.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Spaced practice locks weak topics into long-term memory.',
                  style: AppTypography.caption.copyWith(color: AppColors.greenSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.heading3),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: AppTypography.labelSmall.copyWith(
                  color: color, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _DueItemCard extends ConsumerStatefulWidget {
  final RevisionItem item;
  const _DueItemCard({required this.item});

  @override
  ConsumerState<_DueItemCard> createState() => _DueItemCardState();
}

class _DueItemCardState extends ConsumerState<_DueItemCard> {
  bool _busy = false;

  Future<void> _review(int quality) async {
    setState(() => _busy = true);
    final state = await ref
        .read(revisionControllerProvider)
        .markReviewed(widget.item.topicId, quality: quality);
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);
    if (state == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Couldn\'t save that — check your connection.')));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(quality < 3
            ? 'No worries — we\'ll bring "${widget.item.displayName}" back tomorrow.'
            : 'Nice! Next review in ${state.intervalDays} '
                'day${state.intervalDays == 1 ? '' : 's'}.'),
      ));
    }
  }

  void _startPractice() {
    final item = widget.item;
    // Open the chapter in the subject view (same entry the roadmap uses).
    context.push('/subjects/${item.subjectId}?chapter=${item.chapterId}');
  }

  void _openNotes() {
    final item = widget.item;
    context.push(Uri(path: '/notes/${item.topicId}', queryParameters: {
      'name': item.displayName,
      if (item.chapterId.isNotEmpty) 'chapter': item.chapterId,
      if (item.subjectId.isNotEmpty) 'subject': item.subjectId,
    }).toString());
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.displayName,
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              if (item.isWeak) _Pill(label: 'Weak', color: AppColors.weak),
              if (item.isNew) ...[
                const SizedBox(width: 6),
                _Pill(label: 'New', color: AppColors.primary),
              ],
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Study notes',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(LucideIcons.bookOpen, size: 18, color: AppColors.primary),
                onPressed: _busy ? null : _openNotes,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.isNew
                ? 'Not reviewed yet — a quick set starts the spaced curve.'
                : 'Last accuracy ${(item.accuracy * 100).round()}% • '
                    'reviewed ${item.srs.reps}×',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _startPractice,
                  icon: const Icon(LucideIcons.target, size: 15),
                  label: const Text('Practice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _review(5),
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white))
                      : const Icon(LucideIcons.check, size: 15),
                  label: const Text('Reviewed'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : () => _review(2),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textLight,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Still shaky — show again soon'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingItemRow extends StatelessWidget {
  final RevisionItem item;
  const _UpcomingItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.clock, size: 15, color: AppColors.textLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.displayName,
                style: AppTypography.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(_dueLabel(item.dueAt),
              style: AppTypography.caption.copyWith(color: AppColors.textMedium)),
        ],
      ),
    );
  }

  static String _dueLabel(DateTime? due) {
    if (due == null) return 'soon';
    final now = DateTime.now();
    final days = DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'tomorrow';
    if (days < 7) return 'in $days days';
    final weeks = (days / 7).round();
    return 'in $weeks wk${weeks == 1 ? '' : 's'}';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
          style: AppTypography.labelSmall
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _RevisionEmpty extends StatelessWidget {
  const _RevisionEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle, size: 40, color: AppColors.success),
            const SizedBox(height: 14),
            Text('All caught up', style: AppTypography.heading2),
            const SizedBox(height: 6),
            Text(
              'Take a few practice tests and your weak topics will show up here on '
              'a spaced-repetition schedule.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevisionError extends StatelessWidget {
  const _RevisionError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudOff, size: 36, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text("Couldn't load your plan",
                style: AppTypography.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Check your connection and pull to refresh.',
                textAlign: TextAlign.center, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

/// Full-screen upsell shown to Basic / lapsed users (the gate's `locked` slot).
class _RevisionLocked extends StatelessWidget {
  const _RevisionLocked();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(LucideIcons.repeat, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('Spaced-repetition revision', style: AppTypography.heading2),
            const SizedBox(height: 8),
            Text(
              'A Pro plan that resurfaces your weak topics on a memory-optimised '
              'schedule — revise the right topic at the right time, every day.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => PaywallScreen.showUpgrade(context,
                  tier: SubscriptionTier.pro),
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('Upgrade to Pro'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
