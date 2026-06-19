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

/// Final review + confirmation step before the store purchase. Reached from the
/// paywall's "Continue" once a tier + period are chosen. Shows exactly what the
/// user is about to start — the account it bills to (name + email), the plan,
/// the billing period, and the trial terms — then runs the native purchase.
///
/// The store sheet only opens once the user taps the CTA here, so payment never
/// happens on the plan-selection screen. Back navigation is available right up
/// until that processing begins (see the [PopScope] below); during onboarding a
/// successful purchase continues into AI profiling, while in [upgrade] mode it
/// pops back to the paywall with `true`.
class SubscriptionReviewScreen extends ConsumerStatefulWidget {
  final SubscriptionTier tier;
  final BillingPeriod period;
  final bool upgrade;

  const SubscriptionReviewScreen({
    super.key,
    required this.tier,
    required this.period,
    this.upgrade = false,
  });

  @override
  ConsumerState<SubscriptionReviewScreen> createState() =>
      _SubscriptionReviewScreenState();
}

class _SubscriptionReviewScreenState
    extends ConsumerState<SubscriptionReviewScreen> {
  String? _error;
  bool _processing = false;

  TrialPlan get _plan => TrialPlan.forTier(widget.tier);

  String get _perLabel => widget.period == BillingPeriod.annual ? 'yr' : 'month';

  String get _ctaSubtitle =>
      'Then ${_plan.priceLabel(widget.period)}/$_perLabel after the trial · '
      'Cancel anytime';

  Future<void> _confirm() async {
    setState(() {
      _error = null;
      _processing = true;
    });

    try {
      // The store renders its own purchase sheet; we just await the outcome.
      final result = await ref
          .read(subscriptionControllerProvider)
          .startTrial(widget.tier, widget.period);

      if (!mounted) return;
      if (!result.success) {
        // A user-cancelled sheet is not an error — stay silent.
        setState(() {
          _error = result.userCancelled
              ? null
              : (result.errorMessage ?? 'Payment was not completed.');
        });
        return;
      }
      _onSuccess();
    } catch (e, st) {
      debugPrint('[Review] _confirm threw: $e\n$st');
      if (mounted) {
        setState(() => _error =
            'Something went wrong starting your trial. Please try again.');
      }
    } finally {
      // ALWAYS clear the spinner so the CTA can never hang on an infinite loader
      // and the back gesture is re-enabled after a failure/cancel.
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _error = null;
      _processing = true;
    });

    try {
      final result = await ref.read(subscriptionControllerProvider).restore();

      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _error = result.errorMessage ?? 'No purchase found to restore.';
        });
        return;
      }
      _onSuccess();
    } catch (e, st) {
      debugPrint('[Review] _restore threw: $e\n$st');
      if (mounted) {
        setState(
            () => _error = 'Could not restore purchases. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// In upgrade mode just hand `true` back to the paywall, which closes the
  /// sheet and refreshes the entitlement. A brand-new account instead continues
  /// into the onboarding funnel.
  void _onSuccess() {
    if (widget.upgrade) {
      Navigator.of(context).pop(true);
      return;
    }
    _enterApp();
  }

  void _enterApp() {
    // A brand-new account still needs AI profiling next; an already-onboarded
    // user who re-subscribed goes straight into the app. The controller has
    // already refreshed currentUserProvider to the entitled profile (awaited in
    // startTrial/restore), so this read — and the router guard that evaluates
    // the navigation below — both see the NEW entitlement. No post-frame
    // invalidate here: it fired only `if (mounted)`, but the navigation disposes
    // this screen, so the refresh was being dropped and the app stayed pinned on
    // the paywall until a restart.
    final onboarded =
        ref.read(currentUserProvider).valueOrNull?.onboardingCompleted ?? false;
    context.go(onboarded ? '/' : '/onboarding/profiling');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return PopScope(
      // Back stays available until the final confirmation kicks off processing;
      // once the store flow is running we lock it so a purchase isn't abandoned
      // mid-flight.
      canPop: !_processing,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                onBack:
                    _processing ? null : () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      Text('Review & confirm', style: AppTypography.heading1),
                      const SizedBox(height: 8),
                      Text(
                        'You won\'t be charged today. Here\'s exactly what you\'re '
                        'starting — check the details before you confirm.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      _AccountCard(
                        name: user?.name ?? '—',
                        email: user?.email ?? '—',
                      ),
                      const SizedBox(height: 14),
                      _PlanSummaryCard(plan: _plan, period: widget.period),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
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
              _ConfirmBar(
                processing: _processing,
                subtitle: _ctaSubtitle,
                onConfirm: _confirm,
                onRestore: _processing ? null : _restore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback? onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(LucideIcons.chevronLeft, color: AppColors.textDark),
          ),
          Text('Back', style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

/// "Subscription will start on this account" block — name + the billing email.
class _AccountCard extends StatelessWidget {
  final String name;
  final String email;

  const _AccountCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR ACCOUNT', style: AppTypography.labelSmall),
          const SizedBox(height: 14),
          _DetailRow(icon: LucideIcons.user, label: 'Name', value: name),
          const SizedBox(height: 12),
          _DetailRow(icon: LucideIcons.mail, label: 'Email', value: email),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 14, color: AppColors.textLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your subscription will start on this email.',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  final TrialPlan plan;
  final BillingPeriod period;

  const _PlanSummaryCard({required this.plan, required this.period});

  @override
  Widget build(BuildContext context) {
    final per = period == BillingPeriod.annual ? 'year' : 'month';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR PLAN', style: AppTypography.labelSmall),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(plan.name, style: AppTypography.heading2),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  period.label,
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.greenStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...plan.features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.check, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: AppTypography.bodyMedium)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _PriceRow(label: 'Free trial', value: '7 days'),
          const SizedBox(height: 10),
          _PriceRow(label: 'Due today', value: '₹0', emphasise: true),
          const SizedBox(height: 10),
          _PriceRow(
            label: 'After trial',
            value: '${plan.priceLabel(period)} / $per',
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 14, color: AppColors.textLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Renews automatically after the trial unless cancelled. '
                  'Billed through the app store · cancel anytime.',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textLight),
        const SizedBox(width: 12),
        Text(label, style: AppTypography.bodyMedium),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;

  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Text(
          value,
          style: emphasise
              ? AppTypography.heading3.copyWith(color: AppColors.primary)
              : AppTypography.bodyMedium.copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  final bool processing;
  final String subtitle;
  final VoidCallback onConfirm;
  final VoidCallback? onRestore;

  const _ConfirmBar({
    required this.processing,
    required this.subtitle,
    required this.onConfirm,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            isLoading: processing,
            onPressed: onConfirm,
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onRestore,
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
    );
  }
}
