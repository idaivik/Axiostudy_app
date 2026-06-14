import '../../auth/domain/user_model.dart';
import '../domain/payment_models.dart';

/// Master switch for the payment integration.
///
/// `false` (default) -> [SimulatedPaymentService]: the 7-day trial mandate is
/// approved locally so the whole signup flow is testable end-to-end without a
/// Razorpay account.
///
/// `true` -> [RazorpayPaymentService]: real recurring mandate via Razorpay
/// Checkout. Flipping this on additionally requires:
///   1. Add the `razorpay_flutter` package to pubspec.yaml.
///   2. Set the Razorpay plan ids on [TrialPlan.basic]/[TrialPlan.premium].
///   3. Deploy the `razorpay-create-subscription` + `razorpay-webhook` edge
///      functions (see supabase/functions/) with RAZORPAY_KEY_ID /
///      RAZORPAY_KEY_SECRET / RAZORPAY_WEBHOOK_SECRET secrets.
const bool kRazorpayLiveMode = false;

/// Authorizes the recurring mandate that backs the 7-day free trial.
abstract class PaymentService {
  /// Opens the checkout / mandate flow for [plan] and returns the result.
  /// On success the trial is active (₹0 charged today; billing begins after
  /// the trial unless the user cancels).
  Future<MandateResult> authorizeTrialMandate({
    required TrialPlan plan,
    required UserModel user,
  });
}

/// Local stand-in used until Razorpay keys are wired. Mimics the latency and
/// shape of a real mandate authorization and returns synthetic ids.
class SimulatedPaymentService implements PaymentService {
  @override
  Future<MandateResult> authorizeTrialMandate({
    required TrialPlan plan,
    required UserModel user,
  }) async {
    // Simulate the round-trip to the checkout widget.
    await Future.delayed(const Duration(milliseconds: 1400));
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return MandateResult(
      success: true,
      razorpayCustomerId: 'cust_sim_${user.id.substring(0, 8)}',
      razorpaySubscriptionId: 'sub_sim_${plan.tier.name}_$stamp',
    );
  }
}

/// Real Razorpay recurring-mandate flow. Scaffolded but intentionally inert
/// until [kRazorpayLiveMode] is enabled and the dependencies above are in
/// place. Kept as a concrete type so the wiring is real, not hypothetical.
///
/// Intended implementation when enabled:
///   1. Call the `razorpay-create-subscription` edge function with the user id
///      and [TrialPlan.razorpayPlanId]; it creates the customer + subscription
///      server-side (needs the key secret) and returns `subscription_id`.
///   2. Open Razorpay Checkout (`razorpay_flutter`) with that `subscription_id`
///      so the user authorizes the UPI/card mandate (₹0 today).
///   3. Resolve the returned `PaymentSuccessResponse` into a [MandateResult].
///   4. The `razorpay-webhook` edge function flips the profile to `active`
///      when the first real charge succeeds after the trial.
class RazorpayPaymentService implements PaymentService {
  @override
  Future<MandateResult> authorizeTrialMandate({
    required TrialPlan plan,
    required UserModel user,
  }) async {
    throw StateError(
      'Razorpay live mode is enabled but not configured. Add razorpay_flutter, '
      'set plan ids, deploy the edge functions, then implement '
      'RazorpayPaymentService.authorizeTrialMandate. '
      'See supabase/functions/razorpay-create-subscription.',
    );
  }
}
