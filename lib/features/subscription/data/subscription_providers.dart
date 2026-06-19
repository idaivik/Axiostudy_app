import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/billing/revenuecat.dart';
import '../../../shared/models/enums.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/payment_models.dart';
import 'payment_service.dart';

/// Selected payment backend: the real store flow (RevenueCat) once an SDK key is
/// configured, otherwise a local simulation so signup is testable offline.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return RevenueCatConfig.isConfigured
      ? RevenueCatPaymentService()
      : SimulatedPaymentService();
});

final subscriptionControllerProvider =
    Provider<SubscriptionController>((ref) => SubscriptionController(ref));

/// Orchestrates the paywall actions: run the native purchase (or restore),
/// then optimistically persist the entitlement to the profile so the router
/// clears the paywall immediately. The RevenueCat webhook keeps the profile in
/// sync afterwards (renewals, cancellations, billing issues).
class SubscriptionController {
  final Ref _ref;
  SubscriptionController(this._ref);

  static const int trialDays = 7;

  Future<PurchaseResult> startTrial(
    SubscriptionTier tier,
    BillingPeriod period,
  ) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) {
      return PurchaseResult.failure('You need to be signed in to start a trial.');
    }

    final plan = TrialPlan.forTier(tier);
    final result = await _ref
        .read(paymentServiceProvider)
        .purchase(plan: plan, period: period, user: user);

    if (!result.success) return result;

    // The store purchase already succeeded here. The optimistic profile write
    // below can still fail (network/RLS/timeout) — but if we let it throw, the
    // exception unwinds all the way to the paywall and strands the spinner. So
    // catch it and return a recoverable failure instead. The RevenueCat webhook
    // reconciles the entitlement server-side regardless; "Restore purchases"
    // re-applies it once connectivity returns.
    try {
      await _persist(user.id, result, fallbackTier: tier);
    } catch (e, st) {
      debugPrint('[Subscription] persist after purchase failed: $e\n$st');
      return PurchaseResult.failure(
        'Your trial started, but we couldn\'t finish setting up your account. '
        'Check your connection and tap "Restore purchases".',
      );
    }
    // Refresh the cached profile to the just-entitled row BEFORE returning, so
    // the screen's follow-up navigation (context.go) is evaluated by the router
    // guard against the NEW entitlement — not the stale pre-purchase profile,
    // which reports `hasActiveAccess == false` and bounces the user straight
    // back to the paywall.
    //
    // We *await* the refetch here rather than firing a post-frame invalidate
    // from the review screen: that screen is disposed by the navigation that
    // follows success, so its `if (mounted)` invalidate was being skipped —
    // leaving currentUserProvider stale and the app pinned on the paywall until
    // a full restart re-fetched the profile from scratch. Awaiting to `data`
    // (not loading) before we return also avoids stranding the guard mid-flow.
    await _refreshProfile();
    return result;
  }

  Future<PurchaseResult> restore() async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) {
      return PurchaseResult.failure(
        'You need to be signed in to restore purchases.',
      );
    }

    final result = await _ref.read(paymentServiceProvider).restore(user: user);
    if (!result.success) return result;

    // Restore succeeded at the store. The optimistic profile write can still
    // fail (network/RLS/timeout) — don't let that exception unwind into the UI
    // as a generic "Could not restore", which would mask a restore that actually
    // worked. The RevenueCat webhook reconciles the entitlement server-side
    // regardless.
    try {
      await _persist(
        user.id,
        result,
        fallbackTier: result.tier ?? SubscriptionTier.pro,
      );
    } catch (e, st) {
      debugPrint('[Subscription] persist after restore failed: $e\n$st');
      return PurchaseResult.failure(
        'We restored your subscription but couldn\'t finish syncing your '
        'account. Check your connection and try again.',
      );
    }
    await _refreshProfile();
    return result;
  }

  /// Invalidate + re-read the profile so the router guard re-evaluates against
  /// the freshly-entitled row. Awaited (not fire-and-forget) so the value has
  /// settled to `data` before callers navigate; capped so a hung fetch can't
  /// hang the success path — the optimistic write is already persisted, and the
  /// next guard pass / restart picks it up. Never throws.
  Future<void> _refreshProfile() async {
    try {
      _ref.invalidate(currentUserProvider);
      await _ref
          .read(currentUserProvider.future)
          .timeout(const Duration(seconds: 12));
    } catch (e, st) {
      debugPrint('[Subscription] profile refresh failed: $e\n$st');
    }
  }

  Future<void> _persist(
    String userId,
    PurchaseResult result, {
    required SubscriptionTier fallbackTier,
  }) async {
    final tier = result.tier ?? fallbackTier;
    final now = DateTime.now();
    final expiry = result.expiresAt ?? now.add(const Duration(days: trialDays));
    final trialEnds =
        result.status == SubscriptionStatus.trialing ? expiry : null;

    await _ref
        .read(authRepositoryProvider)
        .activateSubscription(
          userId,
          tier: tier,
          status: result.status == SubscriptionStatus.none
              ? SubscriptionStatus.trialing
              : result.status,
          trialEndsAt: trialEnds,
          subscriptionExpiry: expiry,
          platform: result.platform.dbValue,
          storeProductId: result.productId,
          storeTransactionId: result.storeTransactionId,
        )
        // Don't let a stalled connection hang the write (and the spinner)
        // indefinitely — fail fast so the caller can surface a retry.
        .timeout(const Duration(seconds: 15));
  }
}
