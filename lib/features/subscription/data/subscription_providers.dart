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
    await _persist(user.id, result, fallbackTier: tier);
    // NOTE: Do NOT invalidate currentUserProvider here — doing so mid-flow puts
    // the provider into a loading state before navigation commits, which makes
    // the router guard block on isLoading and strands the paywall. The paywall
    // invalidates AFTER it navigates (see PaywallScreen).
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
    if (result.success) {
      await _persist(
        user.id,
        result,
        fallbackTier: result.tier ?? SubscriptionTier.pro,
      );
    }
    return result;
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

    await _ref.read(authRepositoryProvider).activateSubscription(
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
        );
  }
}
