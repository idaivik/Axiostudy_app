import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../analytics/data/analytics_providers.dart';
import '../../../analytics/domain/time_tips_engine.dart';

/// Bucket 2 Feature 1 — "Pacing coach" card (Pro, `Feature.aiTimeTips`).
///
/// Renders 2–4 deterministic time-management tips derived from the attempt's
/// analytics (see [TimeTipsEngine]). Distinct from the AI narrative: this is
/// strictly about *how time was spent*, not what to study. Costs no meter and
/// makes no AI call. Hides itself when there's nothing useful to say (e.g. a
/// tiny sample), so it never shows an empty shell.
///
/// Gating is the caller's job: wrap this in `FeatureGate(feature: aiTimeTips)`
/// so Basic sees the upgrade upsell instead.
class TimeTipsCard extends ConsumerWidget {
  final String attemptId;
  const TimeTipsCard({super.key, required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(attemptAnalyticsProvider(attemptId)).valueOrNull;
    if (analytics == null) return const SizedBox.shrink();

    final examType = ref.watch(currentUserProvider).valueOrNull?.examType;
    final tips = TimeTipsEngine.compute(
      analytics: analytics,
      ideal: IdealTimeConfig.forExam(examType),
    );
    if (tips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.timer, color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pacing coach', style: AppTypography.heading3),
                    Text('How you spent your time', style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...tips.asMap().entries.map((e) => _TipRow(
                tip: e.value,
                showBorder: e.key != tips.length - 1,
              )),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final TimeTip tip;
  final bool showBorder;
  const _TipRow({required this.tip, required this.showBorder});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _styleFor(tip.kind);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  tip.message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textDark,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showBorder)
          Divider(color: AppColors.divider, height: 1, thickness: 0.5),
      ],
    );
  }

  (IconData, Color) _styleFor(TimeTipKind kind) {
    switch (kind) {
      case TimeTipKind.rushedWrong:
      case TimeTipKind.rushedOverall:
        return (LucideIcons.zap, AppColors.wrong);
      case TimeTipKind.slowButRight:
        return (LucideIcons.gauge, AppColors.primary);
      case TimeTipKind.slowPace:
      case TimeTipKind.slowOverall:
        return (LucideIcons.clock, AppColors.weak);
      case TimeTipKind.unanswered:
        return (LucideIcons.alertCircle, AppColors.weak);
    }
  }
}
