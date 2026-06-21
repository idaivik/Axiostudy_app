import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../analytics/data/analytics_providers.dart';
import '../../../practice/data/practice_providers.dart';
import '../../../practice/data/practice_repository.dart';

/// Home's "today's move" — surfaces the SAME deterministic #1 focus as the
/// Overview AI coach (Plan B) and launches the SAME targeted practice. Free:
/// needs no entitlement. Hidden until there's a focus to act on (the diagnostic
/// prompt covers the first-run case).
class TodaysMoveCard extends ConsumerStatefulWidget {
  const TodaysMoveCard({super.key});

  @override
  ConsumerState<TodaysMoveCard> createState() => _TodaysMoveCardState();
}

class _TodaysMoveCardState extends ConsumerState<TodaysMoveCard> {
  bool _busy = false;

  Future<void> _practice(String chapterId, double masteryScore) async {
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
    final co = ref.watch(coachOverviewProvider).valueOrNull;
    if (co == null || !co.hasFocus) return const SizedBox.shrink();

    final names = ref.watch(chapterNamesProvider).valueOrNull ?? const {};
    final chapterName = names[co.focusChapterId] ?? co.focusChapterId!;
    final mastery = co.focusAccuracy ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.greenSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.target, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY\'S MOVE',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  chapterName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${mastery.round()}% mastery — practice now',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed:
                _busy ? null : () => _practice(co.focusChapterId!, mastery),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Practice',
                          style: AppTypography.button.copyWith(fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.arrowRight, size: 15, color: AppColors.white),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
