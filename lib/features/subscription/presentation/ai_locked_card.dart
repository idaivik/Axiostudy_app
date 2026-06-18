import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/enums.dart';
import '../domain/meter_outcome.dart';
import 'paywall_screen.dart';

/// Renders the non-`ok` states of a metered AI surface from one place
/// (BILLING_BUCKET1_BUILD_PROMPT.md §2.2). Drop it in wherever a feature got a
/// [MeterStatus] other than `ok`, so trial-lock / paywall / cap copy stays
/// consistent across the narrative, breakdown, etc.
///
/// `ok` should never reach here (callers render the feature instead); it falls
/// back to an empty box so a mis-wire fails quiet, not loud.
class AiLockedCard extends StatelessWidget {
  final MeterStatus status;

  /// Short human name of the feature, e.g. "AI coach summary". Used in the
  /// cap-reached copy ("You've used all your AI coach summaries this month").
  final String featureTitle;

  /// Tier to upsell to on the paywall / cap states. Defaults to Pro.
  final SubscriptionTier upsellTier;

  const AiLockedCard({
    super.key,
    required this.status,
    required this.featureTitle,
    this.upsellTier = SubscriptionTier.pro,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MeterStatus.trialLocked:
        return _Frame(
          icon: LucideIcons.lock,
          iconColor: AppColors.primary,
          title: 'Unlocks when your trial converts',
          body:
              'Your $featureTitle switches on the moment your free trial becomes '
              'a paid plan. Everything else is live right now.',
        );
      case MeterStatus.noEntitlement:
        final tierName = upsellTier == SubscriptionTier.basic ? 'Basic' : 'Pro';
        return _Frame(
          icon: LucideIcons.sparkles,
          iconColor: AppColors.primary,
          title: 'A $tierName feature',
          body: 'Upgrade to $tierName to unlock your $featureTitle.',
          action: _UpgradeButton(tier: upsellTier, label: 'Upgrade to $tierName'),
        );
      case MeterStatus.capReached:
        return _Frame(
          icon: LucideIcons.gauge,
          iconColor: AppColors.weak,
          title: "You've used all your ${_plural(featureTitle)} this month",
          body:
              'Your monthly allowance resets at the start of next month. Upgrade '
              'for a higher limit.',
          action: _UpgradeButton(tier: upsellTier, label: 'See plans'),
        );
      case MeterStatus.error:
        return _Frame(
          icon: LucideIcons.cloudOff,
          iconColor: AppColors.textLight,
          title: 'Couldn\'t load this just now',
          body: 'Check your connection and reopen this result to try again.',
        );
      case MeterStatus.ok:
        return const SizedBox.shrink();
    }
  }

  static String _plural(String s) =>
      s.endsWith('y') ? '${s.substring(0, s.length - 1)}ies' : '${s}s';
}

class _Frame extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget? action;
  const _Frame({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTypography.heading3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: AppTypography.caption),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final SubscriptionTier tier;
  final String label;
  const _UpgradeButton({required this.tier, required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => PaywallScreen.showUpgrade(context, tier: tier),
        icon: const Icon(LucideIcons.sparkles, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
    );
  }
}
