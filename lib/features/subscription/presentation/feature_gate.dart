import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/enums.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/entitlements.dart';
import 'paywall_screen.dart';

/// Wraps a gated surface: builds [child] when the signed-in user `can(feature)`,
/// otherwise builds the [locked] state (a default "Upgrade to unlock" card when
/// not supplied). Keeps call sites a one-liner:
///
/// ```dart
/// FeatureGate(
///   feature: Feature.aiRoadmap,
///   child: (_) => const RoadmapCard(),
/// )
/// ```
///
/// Client gating is **UX only** — anything that costs money or unlocks real value
/// must also be enforced server-side (see steps 6/8). The locked CTA opens the
/// paywall in upgrade mode, preselecting [upsellTier].
class FeatureGate extends ConsumerWidget {
  final Feature feature;
  final WidgetBuilder child;
  final WidgetBuilder? locked;

  /// Tier to preselect on the paywall when the user upgrades. Defaults to Pro —
  /// the tier that unlocks the most gated surfaces.
  final SubscriptionTier upsellTier;

  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.locked,
    this.upsellTier = SubscriptionTier.pro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final allowed = user?.can(feature) ?? false;
    if (allowed) return child(context);
    return (locked ?? (ctx) => _LockedFeature(upsellTier: upsellTier))(context);
  }
}

class _LockedFeature extends StatelessWidget {
  final SubscriptionTier upsellTier;
  const _LockedFeature({required this.upsellTier});

  @override
  Widget build(BuildContext context) {
    final tierName = upsellTier == SubscriptionTier.basic ? 'Basic' : 'Pro';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.lock, size: 26, color: AppColors.textLight),
          const SizedBox(height: 10),
          Text(
            'Upgrade to $tierName to unlock this',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () =>
                PaywallScreen.showUpgrade(context, tier: upsellTier),
            icon: const Icon(LucideIcons.sparkles, size: 16),
            label: const Text('Upgrade to unlock'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
