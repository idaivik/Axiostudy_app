import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../practice/data/practice_providers.dart';
import '../../../practice/data/practice_repository.dart';
import '../../../subscription/domain/meter_outcome.dart';
import '../../../subscription/presentation/ai_locked_card.dart';
import '../../data/analytics_providers.dart';
import '../../domain/coach_overview.dart';

/// Persistent, account-level AI coach (Plan B) — the centerpiece of the Overview
/// tab. The single hero-gradient surface in the app.
///
/// Two halves, by design:
///   • The Pro **narrative** ("where do I stand & why") — locks behind
///     [AiLockedCard] for free/lapsed users.
///   • The free **#1 focus → Practice** footer — the deterministic weakest
///     chapter, launched with the SAME `moreLikeThis` path as the Weak Chapters
///     card. Works with NO entitlement.
class AiCoachCard extends ConsumerStatefulWidget {
  const AiCoachCard({super.key});

  @override
  ConsumerState<AiCoachCard> createState() => _AiCoachCardState();
}

class _AiCoachCardState extends ConsumerState<AiCoachCard> {
  bool _busy = false;

  /// Same targeted-practice launch as `_WeakChaptersCard._practice` — pulls
  /// `moreLikeThis` at the chapter's mastery band and pushes the session.
  /// [masteryScore] is 0–100 (higher = stronger). FREE: no entitlement needed.
  Future<void> _launchChapterPractice(String chapterId, double masteryScore) async {
    setState(() => _busy = true);
    try {
      final band = PracticeRepository.bandForMastery(masteryScore);
      final test = await ref.read(practiceRepositoryProvider).moreLikeThis(
            chapterId: chapterId,
            currentDifficulty: band.label,
            delta: 0,
          );
      if (test.questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No fresh questions left for that chapter.')),
          );
        }
        return;
      }
      ref.read(activePracticeTestProvider.notifier).state = test;
      if (mounted) context.push('/practice/session');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start practice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coachOverviewProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDarkAccent.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CoachHeader(),
          const SizedBox(height: 16),
          async.when(
            loading: () => const _CoachLoading(),
            error: (_, _) => const _CoachBody(
              co: CoachOverview(outcome: MeterOutcome(MeterStatus.error)),
              busy: false,
              onPractice: null,
            ),
            data: (co) => _CoachBody(
              co: co,
              busy: _busy,
              onPractice: _launchChapterPractice,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachHeader extends StatelessWidget {
  const _CoachHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(LucideIcons.sparkles, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Your AI coach',
            style: AppTypography.heading3.copyWith(color: Colors.white),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.greenLight.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'PRO',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.greenLight,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shimmer placeholder while the coach loads — mirrors the results-screen
/// `_ShimmerLine` treatment, tinted for the dark hero surface.
class _CoachLoading extends StatelessWidget {
  const _CoachLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _ShimmerLine(widthFactor: 1.0),
        SizedBox(height: 9),
        _ShimmerLine(widthFactor: 0.9),
        SizedBox(height: 9),
        _ShimmerLine(widthFactor: 0.55),
      ],
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double widthFactor;
  const _ShimmerLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

/// The body once the coach has loaded: narrative (Pro) or locked teaser, plus
/// the deterministic focus footer — or a first-run prompt when there's no data.
class _CoachBody extends ConsumerWidget {
  final CoachOverview co;
  final bool busy;
  final Future<void> Function(String chapterId, double masteryScore)? onPractice;

  const _CoachBody({required this.co, required this.busy, required this.onPractice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // First run — nothing to coach on yet.
    if (!co.hasFocus && !co.hasNarrative) {
      return _FirstRun();
    }

    final names = ref.watch(chapterNamesProvider).valueOrNull ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (co.hasNarrative)
          Text(
            co.narrative!,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.5,
            ),
          )
        else
          // Locked / capped / error → consistent teaser copy. Sits on the hero
          // surface as a light card; the focus footer below still works.
          AiLockedCard(
            status: co.outcome.isError ? MeterStatus.error : co.outcome.status,
            featureTitle: 'AI coach',
          ),
        if (co.hasFocus) ...[
          const SizedBox(height: 16),
          _DoThisNext(
            chapterId: co.focusChapterId!,
            chapterName: names[co.focusChapterId] ?? co.focusChapterId!,
            masteryScore: co.focusAccuracy ?? 0,
            busy: busy,
            onPractice: onPractice,
          ),
        ],
      ],
    );
  }
}

/// The "DO THIS NEXT" inset panel — free deterministic #1 focus + Practice.
class _DoThisNext extends StatelessWidget {
  final String chapterId;
  final String chapterName;
  final double masteryScore;
  final bool busy;
  final Future<void> Function(String chapterId, double masteryScore)? onPractice;

  const _DoThisNext({
    required this.chapterId,
    required this.chapterName,
    required this.masteryScore,
    required this.busy,
    required this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DO THIS NEXT',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.greenLight,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chapterName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${masteryScore.round()}% mastery — let\'s lift it',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: (busy || onPractice == null)
                ? null
                : () => onPractice!(chapterId, masteryScore),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.greenLight,
              foregroundColor: AppColors.slate900,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.slate900),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Practice',
                          style: AppTypography.button.copyWith(
                              color: AppColors.slate900, fontSize: 14)),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.arrowRight,
                          size: 16, color: AppColors.slate900),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// No tests yet — invite the first test instead of showing an empty coach.
class _FirstRun extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Take your first test and I\'ll build your plan.',
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () => context.push('/test-selection'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.greenLight,
            foregroundColor: AppColors.slate900,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Start a test',
                  style: AppTypography.button.copyWith(
                      color: AppColors.slate900, fontSize: 14)),
              const SizedBox(width: 6),
              const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.slate900),
            ],
          ),
        ),
      ],
    );
  }
}
