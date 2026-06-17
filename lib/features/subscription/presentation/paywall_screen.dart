import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/axio_button.dart';
import '../../../shared/models/enums.dart';
import '../../auth/data/auth_providers.dart';
import '../data/subscription_providers.dart';
import '../domain/payment_models.dart';

/// Hard paywall. Every new account must start a 7-day free trial (₹0 today) —
/// billed through Google Play / the App Store — before entering the app.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  SubscriptionTier _selected = SubscriptionTier.premium;
  String? _error;
  bool _processing = false;

  TrialPlan get _plan => TrialPlan.forTier(_selected);

  Future<void> _startTrial() async {
    setState(() {
      _error = null;
      _processing = true;
    });

    // The store renders its own purchase sheet; we just await the outcome.
    final result =
        await ref.read(subscriptionControllerProvider).startTrial(_selected);

    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _processing = false;
        // A user-cancelled sheet is not an error — stay silent.
        _error = result.userCancelled
            ? null
            : (result.errorMessage ?? 'Payment was not completed.');
      });
      return;
    }
    _enterApp();
  }

  Future<void> _restore() async {
    setState(() {
      _error = null;
      _processing = true;
    });

    final result = await ref.read(subscriptionControllerProvider).restore();

    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _processing = false;
        _error = result.errorMessage ?? 'No purchase found to restore.';
      });
      return;
    }
    _enterApp();
  }

  void _enterApp() {
    // A brand-new account still needs AI profiling next; an already-onboarded
    // user who just re-subscribed/restored after a lapse goes straight into the
    // app instead of being dragged back through profiling. Read the pre-refresh
    // profile (invalidation below happens after navigation).
    final onboarded =
        ref.read(currentUserProvider).valueOrNull?.onboardingCompleted ?? false;
    context.go(onboarded ? '/' : '/onboarding/profiling');
    // Invalidate AFTER navigation so the router guard sees the new entitled
    // profile on the *next* evaluation cycle, not mid-navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(currentUserProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.greenSurface,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.gift,
                              size: 14, color: AppColors.greenStrong),
                          const SizedBox(width: 6),
                          Text(
                            '7 DAYS FREE',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.greenStrong,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Unlock your full potential',
                        style: AppTypography.heading1),
                    const SizedBox(height: 8),
                    Text(
                      '₹0 due today. Try everything free for 7 days — cancel '
                      'anytime before it ends and you won\'t be charged.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ...TrialPlan.all.map(
                      (plan) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _PlanCard(
                          plan: plan,
                          selected: _selected == plan.tier,
                          onTap: _processing
                              ? null
                              : () => setState(() => _selected = plan.tier),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.wrong),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Sticky CTA
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.slate900.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AxioButton(
                    label: 'Start 7-Day Free Trial',
                    icon: LucideIcons.sparkles,
                    isLoading: _processing,
                    onPressed: _startTrial,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Then ${_plan.priceLabel}/month after the trial · Cancel anytime',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _processing ? null : _restore,
                    child: Text(
                      'Restore purchases',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final TrialPlan plan;
  final bool selected;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RadioDot(selected: selected),
                const SizedBox(width: 12),
                Text(plan.name, style: AppTypography.heading3),
                if (plan.isPopular) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'POPULAR',
                      style: AppTypography.labelSmall
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(plan.priceLabel, style: AppTypography.heading2),
                    Text('/mo', style: AppTypography.caption),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.check,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: AppTypography.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.textLight,
          width: 2,
        ),
        color: selected ? AppColors.primary : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check, size: 13, color: Colors.white)
          : null,
    );
  }
}
