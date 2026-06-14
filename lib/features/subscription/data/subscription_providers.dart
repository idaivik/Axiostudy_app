import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/enums.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/payment_models.dart';
import 'payment_service.dart';

/// Selected payment backend (simulated vs. real Razorpay) — see [kRazorpayLiveMode].
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return kRazorpayLiveMode
      ? RazorpayPaymentService()
      : SimulatedPaymentService();
});

final subscriptionControllerProvider =
    Provider<SubscriptionController>((ref) => SubscriptionController(ref));

/// Orchestrates the paywall's "Start 7-Day Free Trial" action: authorizes the
/// recurring mandate, persists the trial to the profile, and refreshes state.
class SubscriptionController {
  final Ref _ref;
  SubscriptionController(this._ref);

  static const int trialDays = 7;

  Future<MandateResult> startTrial(SubscriptionTier tier) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) {
      return MandateResult.failure('You need to be signed in to start a trial.');
    }

    final plan = TrialPlan.forTier(tier);
    final result = await _ref
        .read(paymentServiceProvider)
        .authorizeTrialMandate(plan: plan, user: user);

    if (!result.success) return result;

    final now = DateTime.now();
    final trialEnds = now.add(const Duration(days: trialDays));

    await _ref.read(authRepositoryProvider).activateTrial(
          user.id,
          tier: tier,
          status: SubscriptionStatus.trialing,
          trialEndsAt: trialEnds,
          // Access is guaranteed through the trial; the webhook extends this
          // once real billing begins after the trial converts.
          subscriptionExpiry: trialEnds,
          razorpayCustomerId: result.razorpayCustomerId,
          razorpaySubscriptionId: result.razorpaySubscriptionId,
        );

    // NOTE: Do NOT invalidate currentUserProvider here.
    // Invalidating mid-flow puts the provider into a loading state before
    // Navigator.pop returns, which causes the router guard (_onboardingGuard)
    // to see userAsync.isLoading == true and block the context.go() call,
    // leaving the app stuck on the paywall with an infinite spinner.
    // The invalidation is instead triggered by the UI after navigation commits
    // (see _CheckoutSheetState._authorize).
    return result;
  }
}
