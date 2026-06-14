import '../../../shared/models/enums.dart';

/// The two paid tiers offered on the hard paywall. Both start with a 7-day
/// free trial (₹0 charged today) backed by a Razorpay recurring mandate.
class TrialPlan {
  final SubscriptionTier tier;
  final String name;
  final int monthlyPriceInr;
  final String tagline;
  final List<String> features;
  final bool isPopular;

  /// Razorpay plan id used to create the recurring subscription in live mode.
  /// Configure these in the Razorpay dashboard (Subscriptions → Plans) and
  /// drop the ids here / into env for the edge function.
  final String? razorpayPlanId;

  const TrialPlan({
    required this.tier,
    required this.name,
    required this.monthlyPriceInr,
    required this.tagline,
    required this.features,
    this.isPopular = false,
    this.razorpayPlanId,
  });

  String get priceLabel => '₹$monthlyPriceInr';

  static const basic = TrialPlan(
    tier: SubscriptionTier.basic,
    name: 'Basic',
    monthlyPriceInr: 199,
    tagline: 'Everything to get started',
    features: [
      'Adaptive practice across all chapters',
      'Diagnostic test + weakness detection',
      'Daily study plan',
      'Progress analytics',
    ],
    razorpayPlanId: null, // TODO: set live plan id (plan_xxx)
  );

  static const premium = TrialPlan(
    tier: SubscriptionTier.premium,
    name: 'Premium',
    monthlyPriceInr: 299,
    tagline: 'AI coaching, fully unlocked',
    isPopular: true,
    features: [
      'Everything in Basic',
      'AI-driven coaching-synced roadmap',
      'Unlimited AI question generation',
      'Priority full-length mock tests',
      'Deep chapter-level insights',
    ],
    razorpayPlanId: null, // TODO: set live plan id (plan_xxx)
  );

  static const all = [basic, premium];

  static TrialPlan forTier(SubscriptionTier tier) =>
      all.firstWhere((p) => p.tier == tier, orElse: () => premium);
}

/// Result of authorizing the recurring mandate at the payment step.
class MandateResult {
  final bool success;
  final String? razorpayCustomerId;
  final String? razorpaySubscriptionId;
  final String? errorMessage;

  const MandateResult({
    required this.success,
    this.razorpayCustomerId,
    this.razorpaySubscriptionId,
    this.errorMessage,
  });

  factory MandateResult.failure(String message) =>
      MandateResult(success: false, errorMessage: message);
}
