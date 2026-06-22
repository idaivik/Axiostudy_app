import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/axio_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../shared/models/enums.dart' show SubscriptionTier;
import '../../subscription/domain/meter_outcome.dart';
import '../../subscription/presentation/paywall_screen.dart';
import '../data/roadmap_providers.dart';
import '../domain/roadmap_models.dart';
import 'widgets/exam_countdown_header.dart';

/// The student's coaching-synced study roadmap: exam countdown, this-week
/// focus, catch-up for overdue items, and the upcoming timeline.
class RoadmapScreen extends ConsumerWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(roadmapProvider);
    final enrollmentAsync = ref.watch(enrollmentProvider);
    final examType = enrollmentAsync.whenOrNull(
          data: (e) => e?.examType,
        ) ??
        ExamType.jee;

    return GradientBackground(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          // Pop when pushed (enables the iOS swipe-back too); otherwise fall
          // back to Home so there's always a way out.
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('My Roadmap'),
        actions: [
          IconButton(
            tooltip: 'Re-plan',
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () {
              ref.read(roadmapControllerProvider).refreshReadiness();
              ref.invalidate(roadmapProvider);
              ref.invalidate(roadmapMeterProvider);
            },
          ),
          IconButton(
            tooltip: 'Edit setup',
            icon: const Icon(LucideIcons.settings2, size: 20),
            onPressed: () => context.push('/roadmap/setup'),
          ),
        ],
      ),
      child: roadmapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: '$e'),
        data: (roadmap) {
          if (roadmap == null) return const _SetupPrompt();
          return _RoadmapContent(roadmap: roadmap, examType: examType);
        },
      ),
    );
  }
}

class _RoadmapContent extends ConsumerWidget {
  final Roadmap roadmap;
  final ExamType examType;
  const _RoadmapContent({required this.roadmap, required this.examType});

  void _onStart(BuildContext context, RoadmapItem item) {
    if (item.type == RoadmapItemType.mock) {
      context.push('/test-selection');
    } else {
      // Open the exact chapter in the subject's practice view (auto-focused).
      context.push('/subjects/${item.subjectId}?chapter=${item.chapterId}');
    }
  }

  Future<void> _toggle(WidgetRef ref, RoadmapItem item) {
    final controller = ref.read(roadmapControllerProvider);
    return controller.setItemStatus(
      item.id,
      item.isDone ? RoadmapItemStatus.upcoming : RoadmapItemStatus.done,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Split the plan at +2 months: the near window is the (preview-locked)
    // detailed zone; everything past it is a chapter-only locked outline.
    final boundary =
        DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 60));
    final detailed = <RoadmapItem>[];
    final lockedNames = <String>[];
    final seen = <String>{};
    for (final item in roadmap.items) {
      if (!DateUtils.dateOnly(item.scheduledStart).isAfter(boundary)) {
        detailed.add(item);
      } else if (item.type != RoadmapItemType.mock && seen.add(item.chapterId)) {
        lockedNames.add(item.chapterName);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AnimatedEntrance(
          child: ExamCountdownHeader(roadmap: roadmap, examType: examType),
        ),
        const SizedBox(height: 16),
        const _CustomizedRoadmapCard(),
        const SizedBox(height: 22),
        const _ZoneHeader(
          icon: LucideIcons.sparkles,
          title: 'Next 2 months',
          subtitle:
              'Generate to break each chapter into topic & subtopic revision steps.',
          badge: 'Preview',
        ),
        const SizedBox(height: 10),
        if (detailed.isEmpty)
          Text('Nothing scheduled in this window yet.',
              style: AppTypography.caption)
        else
          ...detailed.map((item) => _DetailedItemRow(
                item: item,
                onStart: () => _onStart(context, item),
                onToggle: () => _toggle(ref, item),
              )),
        if (lockedNames.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _ZoneHeader(
            icon: LucideIcons.lock,
            title: 'Beyond 2 months',
            subtitle:
                'Chapter outline only — fills in with detail as you get closer.',
          ),
          const SizedBox(height: 10),
          ...lockedNames.map((name) => _LockedChapterRow(name: name)),
        ],
      ],
    );
  }
}

/// The Pro gate for the customized (AI, pace-tuned) roadmap: shows the monthly
/// generation counter and routes a "Generate" tap through the data-readiness +
/// entitlement checks. No branch here spends a credit — the AI generation
/// itself is wired up when the model API goes live.
class _CustomizedRoadmapCard extends ConsumerWidget {
  const _CustomizedRoadmapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meterAsync = ref.watch(roadmapMeterProvider);
    final readiness = ref.watch(roadmapReadinessProvider).valueOrNull;
    final meter = meterAsync.valueOrNull;
    // Three states: still resolving the meter, entitled (Basic/Pro), or locked
    // (free / signed-out). Don't flash "Unlock with Pro" while still loading.
    final resolving = meter == null && meterAsync.isLoading;
    final entitled = meter != null && !meter.isNoEntitlement;
    final notReady = readiness != null && !readiness.ready;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.sparkles,
                    color: AppColors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    Text('Customized roadmap', style: AppTypography.heading3),
              ),
              if (entitled && meter.plan != null) _PlanPill(plan: meter.plan!),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            resolving
                ? 'Checking your plan…'
                : entitled
                    ? _counterText(meter)
                    : 'A pace-tuned plan built from your own performance — a Pro feature.',
            style: AppTypography.bodyMedium,
          ),
          if (entitled) ...[
            const SizedBox(height: 2),
            Text(
              meter.resetsAt != null
                  ? 'Used ${meter.used ?? 0} this month · resets ${_fmtMonthDay(meter.resetsAt!)}'
                  : 'Used ${meter.used ?? 0} this month',
              style: AppTypography.caption,
            ),
          ],
          if (entitled && notReady) ...[
            const SizedBox(height: 12),
            _ReadinessProgress(readiness: readiness),
          ],
          const SizedBox(height: 14),
          AxioButton(
            label: entitled ? 'Generate customized roadmap' : 'Unlock with Pro',
            icon: entitled ? LucideIcons.wand2 : LucideIcons.crown,
            onPressed: resolving ? null : () => _onGenerate(context, ref),
          ),
        ],
      ),
    );
  }

  String _counterText(MeterOutcome m) {
    final limit = m.limit ?? 0;
    final remaining = m.remaining ?? (limit - (m.used ?? 0));
    return '$remaining of $limit generations left this month';
  }

  Future<void> _onGenerate(BuildContext context, WidgetRef ref) async {
    final meter = await ref.read(roadmapMeterProvider.future);
    if (!context.mounted) return;
    if (meter.isNoEntitlement) {
      PaywallScreen.showUpgrade(context, tier: SubscriptionTier.pro);
      return;
    }
    if (meter.isTrialLocked) {
      _showInfo(context, 'Unlocks when your trial converts',
          'Customized roadmaps are a Pro AI feature. They switch on automatically once your trial converts to a paid plan.');
      return;
    }
    if (meter.isCapReached) {
      final resets = meter.resetsAt != null
          ? ' They reset on ${_fmtMonthDay(meter.resetsAt!)}.'
          : '';
      _showInfo(context, 'Monthly limit reached',
          'You\'ve used all your customized-roadmap generations this month.$resets No credit was used.');
      return;
    }
    final readiness = await ref.read(roadmapReadinessProvider.future);
    if (!context.mounted) return;
    if (!readiness.ready) {
      _showInfo(context, 'Keep practising', _notReadyMessage(readiness));
      return;
    }
    _showInfo(context, 'Almost ready',
        'Your data\'s ready! Customized AI roadmaps are switching on shortly — we\'ll build yours the moment they\'re live. No generation used.');
  }
}

class _PlanPill extends StatelessWidget {
  final String plan;
  const _PlanPill({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(plan.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
    );
  }
}

class _ReadinessProgress extends StatelessWidget {
  final RoadmapReadiness readiness;
  const _ReadinessProgress({required this.readiness});

  @override
  Widget build(BuildContext context) {
    final r = readiness;
    final eta = r.predictedReadyDate != null
        ? ' · unlocks ~${_fmtMonthDay(r.predictedReadyDate!)}'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: r.progress,
            minHeight: 7,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${r.distinctChapters}/${r.minChapters} chapters · ${r.passingTests}/${r.minTests} tests$eta',
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

class _ZoneHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  const _ZoneHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: AppTypography.heading3),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.lock,
                        size: 10, color: AppColors.warning),
                    const SizedBox(width: 3),
                    Text(badge!,
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.warning)),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTypography.caption),
      ],
    );
  }
}

class _DetailedItemRow extends StatelessWidget {
  final RoadmapItem item;
  final VoidCallback onStart;
  final VoidCallback onToggle;
  const _DetailedItemRow({
    required this.item,
    required this.onStart,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.type.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 1.2),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Icon(
                item.isDone ? LucideIcons.checkCircle2 : item.type.iconData,
                size: 22,
                color: item.isDone ? AppColors.success : color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.chapterName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration:
                          item.isDone ? TextDecoration.lineThrough : null,
                      color:
                          item.isDone ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${item.type.label} · ${_fmtMonthDay(item.scheduledStart)}',
                      style: AppTypography.caption.copyWith(color: color)),
                ],
              ),
            ),
            if (!item.isDone)
              _StartChip(
                onTap: onStart,
                label: item.type == RoadmapItemType.mock ? 'Take' : 'Start',
              ),
          ],
        ),
      ),
    );
  }
}

class _StartChip extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _StartChip({required this.onTap, this.label = 'Start'});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: AppTypography.labelSmall
                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _LockedChapterRow extends StatelessWidget {
  final String name;
  const _LockedChapterRow({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.textLight.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.lock, size: 14, color: AppColors.textLight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textLight)),
            ),
          ],
        ),
      ),
    );
  }
}

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _fmtMonthDay(DateTime d) => '${d.day} ${_monthAbbr[d.month - 1]}';

String _notReadyMessage(RoadmapReadiness r) {
  const base = 'Not enough data available to generate your customised roadmap — '
      'keep practising until we have enough.';
  if (r.predictedReadyDate != null) {
    return '$base\n\nAt your current pace this should unlock around '
        '${_fmtMonthDay(r.predictedReadyDate!)} ${r.predictedReadyDate!.year}. '
        'No credit was used.';
  }
  return '$base No credit was used.';
}

void _showInfo(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: AppTypography.heading3),
      content: Text(message, style: AppTypography.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _SetupPrompt extends StatelessWidget {
  const _SetupPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(LucideIcons.milestone, color: AppColors.white, size: 34),
            ),
            const SizedBox(height: 20),
            Text('Build your study roadmap',
                style: AppTypography.heading2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Tell us your coaching and exam date, and we\'ll sync your practice '
              'to your class and pace it toward the exam.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AxioButton(
              label: 'Get started',
              icon: LucideIcons.sparkles,
              width: 220,
              onPressed: () => context.push('/roadmap/setup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text('Couldn\'t load your roadmap',
                style: AppTypography.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                style: AppTypography.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
