import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/enums.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../subscription/domain/entitlements.dart';
import '../../../subscription/domain/meter_outcome.dart';
import '../../../subscription/presentation/paywall_screen.dart';
import '../../data/breakdown_providers.dart';
import '../../domain/question_breakdown.dart';

/// Feature 2 — "Review your mistakes". Lists the answered-wrong questions for an
/// attempt; tapping one meters `question_breakdown` and opens the stored
/// explanation (text + zoomable JPEG) with a templated stat line. NO AI.
///
/// Gated by the UNION of basicQuestionBreakdown (Basic) and advancedBreakdown
/// (Pro) — the surface exists in both flavors, so it checks both (entitlements
/// note). Non-entitled users see a Basic upsell; entitled users with no mistakes
/// see nothing.
class MistakesReviewCard extends ConsumerWidget {
  final String attemptId;
  const MistakesReviewCard({super.key, required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final entitled = user != null &&
        (user.can(Feature.basicQuestionBreakdown) ||
            user.can(Feature.advancedBreakdown));
    if (!entitled) {
      return _LockedMistakes(loggedIn: user != null);
    }

    final wrong = ref.watch(wrongAnswersProvider(attemptId)).valueOrNull;
    if (wrong == null || wrong.isEmpty) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(LucideIcons.bookOpenCheck,
                    color: AppColors.wrong, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Review your mistakes', style: AppTypography.heading3),
                    Text('Tap a question for the worked solution',
                        style: AppTypography.caption),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${wrong.length}',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.wrong, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...wrong.asMap().entries.map((e) => _MistakeRow(
                item: e.value,
                showBorder: e.key != wrong.length - 1,
                onTap: () => _openBreakdown(context, ref, e.value),
              )),
        ],
      ),
    );
  }

  Future<void> _openBreakdown(
      BuildContext context, WidgetRef ref, QuestionBreakdown item) async {
    final id = item.question.id;
    final unlocked = ref.read(unlockedBreakdownsProvider.notifier);

    MeterOutcome outcome = const MeterOutcome(MeterStatus.ok);
    if (!unlocked.contains(id)) {
      outcome = await ref.read(breakdownRepositoryProvider).unlockBreakdown();
      if (outcome.ok) unlocked.markUnlocked(id);
    }
    if (!context.mounted) return;

    if (outcome.ok) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            _BreakdownSheet(item: item, remaining: outcome.remaining),
      );
      return;
    }
    if (outcome.isCapReached) {
      _showCapDialog(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't open the breakdown — please try again.")));
    }
  }

  void _showCapDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        icon: Icon(LucideIcons.gauge, color: AppColors.weak),
        title: const Text('Out of breakdowns this month'),
        content: const Text(
          "You've opened all your question breakdowns for this month. They "
          'reset next month — or upgrade to Pro for a much higher limit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              PaywallScreen.showUpgrade(context, tier: SubscriptionTier.pro);
            },
            child: const Text('See Pro'),
          ),
        ],
      ),
    );
  }
}

class _LockedMistakes extends StatelessWidget {
  final bool loggedIn;
  const _LockedMistakes({required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.bookOpenCheck, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Review your mistakes',
                      style: AppTypography.heading3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'See the worked solution and a diagram for every question you got '
            'wrong. Included on Basic and Pro.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => PaywallScreen.showUpgrade(context,
                  tier: SubscriptionTier.basic),
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('Upgrade to unlock'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakeRow extends StatelessWidget {
  final QuestionBreakdown item;
  final bool showBorder;
  final VoidCallback onTap;
  const _MistakeRow(
      {required this.item, required this.showBorder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.question.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge
                            .copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(_statLine(item), style: AppTypography.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight,
                    size: 16, color: AppColors.textLight),
              ],
            ),
          ),
        ),
        if (showBorder)
          Divider(color: AppColors.divider, height: 1, thickness: 0.5),
      ],
    );
  }
}

/// "Medium · Rotational Motion · you're at 45% in this topic" — only the parts
/// we actually have.
String _statLine(QuestionBreakdown item) {
  final parts = <String>[item.question.difficulty.label];
  final chapter = item.chapterName;
  if (chapter != null && chapter.isNotEmpty) parts.add(chapter);
  final pct = item.topicAccuracyPct;
  final base = parts.join(' · ');
  return pct == null ? base : "$base · you're at $pct% in this topic";
}

class _BreakdownSheet extends StatelessWidget {
  final QuestionBreakdown item;
  final int? remaining;
  const _BreakdownSheet({required this.item, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final q = item.question;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(_statLine(item),
                      style: AppTypography.caption
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(q.text, style: AppTypography.bodyLarge),
                  const SizedBox(height: 16),

                  // Answers.
                  _AnswerChip(
                    label: 'Your answer',
                    value: item.selectedAnswer ?? '—',
                    color: AppColors.wrong,
                    icon: LucideIcons.x,
                  ),
                  const SizedBox(height: 8),
                  _AnswerChip(
                    label: 'Correct answer',
                    value: q.correctAnswer,
                    color: AppColors.primary,
                    icon: LucideIcons.check,
                  ),
                  const SizedBox(height: 20),

                  // Explanation text.
                  if (item.hasExplanation) ...[
                    Text('Explanation', style: AppTypography.heading3),
                    const SizedBox(height: 8),
                    Text(q.explanation!,
                        style: AppTypography.bodyMedium
                            .copyWith(height: 1.45, color: AppColors.textDark)),
                    const SizedBox(height: 16),
                  ],

                  // Zoomable diagram (graceful when missing).
                  if (item.hasImage)
                    _ZoomableImage(url: item.explanationImageUrl!)
                  else if (!item.hasExplanation)
                    _EmptyExplanation(),

                  if (remaining != null) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        '$remaining breakdown${remaining == 1 ? '' : 's'} left this month',
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.textLight),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _AnswerChip(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text('$label: ',
              style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(value,
                style:
                    AppTypography.bodyMedium.copyWith(color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatelessWidget {
  final String url;
  const _ZoomableImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.image, size: 14, color: AppColors.textLight),
            const SizedBox(width: 6),
            Text('Worked solution — pinch to zoom',
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textLight)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.fitWidth,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, _, _) => _EmptyExplanation(
                  message: "Couldn't load the diagram. Check your connection."),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyExplanation extends StatelessWidget {
  final String? message;
  const _EmptyExplanation({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.imageOff, size: 22, color: AppColors.textLight),
          const SizedBox(height: 8),
          Text(
            message ?? 'A diagram for this question is on the way.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}
