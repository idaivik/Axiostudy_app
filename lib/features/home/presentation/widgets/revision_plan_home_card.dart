import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/animations.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../revision/data/revision_providers.dart';
import '../../../subscription/domain/entitlements.dart';

/// Home entry point for the Pro spaced-repetition revision plan (Feature 1).
/// Only shows for Pro users with something due — Basic's reminders/roadmap
/// already cover them, so this never clutters their home. Routes to /revision.
class RevisionPlanHomeCard extends ConsumerWidget {
  const RevisionPlanHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null || !user.can(Feature.advancedRevisionPlan)) {
      return const SizedBox.shrink();
    }

    final plan = ref.watch(revisionPlanProvider).valueOrNull;
    final dueCount = plan?.dueToday.length ?? 0;
    if (dueCount == 0) return const SizedBox.shrink();

    return AnimatedEntrance(
      delay: const Duration(milliseconds: 280),
      child: PressableScale(
        onTap: () => context.push('/revision'),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.slate900.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.weak.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(LucideIcons.repeat, color: AppColors.weak, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Revision due today', style: AppTypography.heading3),
                    const SizedBox(height: 2),
                    Text(
                      '$dueCount topic${dueCount == 1 ? '' : 's'} ready to revise — '
                      'tap to start.',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
