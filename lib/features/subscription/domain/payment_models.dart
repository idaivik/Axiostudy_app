import '../../../shared/models/enums.dart';

/// Billing cadence the user picks on the paywall. Entitlements are **tier-level**
/// and never inspect this — only the price, the store package, and the paywall
/// copy vary by period.
enum BillingPeriod {
  monthly,
  annual;

  String get label => this == BillingPeriod.annual ? 'Annual' : 'Monthly';
}

/// One of the two paid tiers offered on the paywall. Each tier is a **single**
/// store subscription (`axio_basic` / `axio_premium`) with **monthly and annual
/// base plans** and a first-purchase 7-day `freetrial` offer on both.
/// The period is the base plan — not a separate product id — so a tier has one
/// [storeProductId] plus per-period prices and RevenueCat packages.
class TrialPlan {
  final SubscriptionTier tier;
  final String name;
  final String tagline;
  final List<String> features;
  final bool isPopular;

  /// RevenueCat **entitlement** identifier this tier unlocks (`basic` / `pro`).
  /// The app checks `customerInfo.entitlements.active[entitlementId]`.
  final String entitlementId;

  /// Permanent store **subscription** identifier (App Store Connect / Play
  /// Console). The RevenueCat webhook derives the tier from a substring of this
  /// (`axio_premium` → `pro`). Used for display + as a fallback when matching
  /// the package in an Offering.
  final String storeProductId;

  final int monthlyPriceInr;
  final int annualPriceInr;

  const TrialPlan({
    required this.tier,
    required this.name,
    required this.tagline,
    required this.features,
    required this.entitlementId,
    required this.storeProductId,
    required this.monthlyPriceInr,
    required this.annualPriceInr,
    this.isPopular = false,
  });

  int priceInr(BillingPeriod period) =>
      period == BillingPeriod.annual ? annualPriceInr : monthlyPriceInr;

  String priceLabel(BillingPeriod period) => '₹${priceInr(period)}';

  /// Canonical RevenueCat package identifier for [period]. The store flow matches
  /// by tier × period; this is the exact-id fast path before the substring/type
  /// fallbacks in `_findPackage`.
  String packageId(BillingPeriod period) =>
      period == BillingPeriod.annual ? r'$rc_annual' : r'$rc_monthly';

  /// Whole-percent saving of the annual plan vs paying 12× monthly (~8%).
  int get annualSavingsPercent {
    final twelveMonths = monthlyPriceInr * 12;
    if (twelveMonths == 0) return 0;
    return ((twelveMonths - annualPriceInr) / twelveMonths * 100).round();
  }

  static const basic = TrialPlan(
    tier: SubscriptionTier.basic,
    name: 'Basic',
    tagline: 'See exactly where you\'re weak',
    entitlementId: 'basic',
    storeProductId: 'axio_basic',
    monthlyPriceInr: 199,
    annualPriceInr: 2199,
    features: [
      'Adaptive tests + diagnostic from the question bank',
      'Full analysis — every chart (mistakes, strengths, weak topics, trends)',
      'Basic study roadmap',
      'Limited AI test generation + templated question breakdowns',
    ],
  );

  static const pro = TrialPlan(
    tier: SubscriptionTier.pro,
    name: 'Pro',
    tagline: 'Your AI coach — interprets, generates, and plans',
    isPopular: true,
    entitlementId: 'pro',
    storeProductId: 'axio_premium',
    monthlyPriceInr: 399,
    annualPriceInr: 4399,
    features: [
      'Everything in Basic',
      'AI-generated adaptive questions + full AI practice — a fresh session daily',
      'AI coaching-synced study roadmaps',
      'AI analysis narrative + advanced breakdowns with formulas to learn',
    ],
  );

  static const all = [basic, pro];

  static TrialPlan forTier(SubscriptionTier tier) =>
      all.firstWhere((p) => p.tier == tier, orElse: () => pro);

  /// Resolve a plan from the entitlement that backs an active subscription
  /// (used when restoring purchases, where the tier isn't chosen up-front).
  static TrialPlan? forEntitlement(String entitlementId) {
    for (final p in all) {
      if (p.entitlementId == entitlementId) return p;
    }
    return null;
  }
}

/// Which app store processed the purchase. Persisted to
/// `profiles.subscription_platform` so support/analytics know where to manage it.
enum StorePlatform {
  playStore,
  appStore,
  none;

  String get dbValue => switch (this) {
        StorePlatform.playStore => 'play_store',
        StorePlatform.appStore => 'app_store',
        StorePlatform.none => 'none',
      };
}

/// Outcome of a native store purchase (or restore). Replaces the old Razorpay
/// `MandateResult`.
class PurchaseResult {
  final bool success;

  /// User dismissed the store sheet — not an error; the paywall stays silent.
  final bool userCancelled;

  /// Resolved access state. `trialing` while in the free-trial phase, otherwise
  /// `active`. The RevenueCat webhook is the long-term source of truth.
  final SubscriptionStatus status;

  /// Tier actually granted. May differ from the tapped plan on a restore.
  final SubscriptionTier? tier;

  final StorePlatform platform;
  final String? productId;
  final String? storeTransactionId;

  /// When the current period (trial or paid) ends, per the store.
  final DateTime? expiresAt;

  final String? errorMessage;

  const PurchaseResult({
    required this.success,
    this.userCancelled = false,
    this.status = SubscriptionStatus.none,
    this.tier,
    this.platform = StorePlatform.none,
    this.productId,
    this.storeTransactionId,
    this.expiresAt,
    this.errorMessage,
  });

  factory PurchaseResult.failure(String message) =>
      PurchaseResult(success: false, errorMessage: message);

  factory PurchaseResult.cancelled() =>
      const PurchaseResult(success: false, userCancelled: true);
}
