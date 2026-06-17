import '../../../shared/models/enums.dart';

/// The two paid tiers offered on the hard paywall. Both start with a 7-day free
/// trial — delivered as the store's native "introductory offer" (App Store) /
/// "free trial offer phase" (Google Play). The store charges ₹0 today and
/// auto-renews after the trial unless the user cancels.
class TrialPlan {
  final SubscriptionTier tier;
  final String name;
  final int monthlyPriceInr;
  final String tagline;
  final List<String> features;
  final bool isPopular;

  /// Identifier of the RevenueCat **package** inside the current Offering that
  /// sells this tier. Configure the Offering in the RevenueCat dashboard and
  /// give each package these identifiers (or rely on the [productId] fallback).
  final String packageId;

  /// RevenueCat **entitlement** identifier this plan unlocks. The app checks
  /// `customerInfo.entitlements.active[entitlementId]` to confirm access.
  final String entitlementId;

  /// Store **product** identifier (App Store Connect / Play Console). Used for
  /// display + as a fallback when matching the package in an Offering.
  final String productId;

  const TrialPlan({
    required this.tier,
    required this.name,
    required this.monthlyPriceInr,
    required this.tagline,
    required this.features,
    required this.packageId,
    required this.entitlementId,
    required this.productId,
    this.isPopular = false,
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
    // TODO: keep these in sync with the store + RevenueCat dashboard.
    packageId: 'basic',
    entitlementId: 'basic',
    productId: 'axio_basic_monthly',
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
    packageId: 'premium',
    entitlementId: 'premium',
    productId: 'axio_premium_monthly',
  );

  static const all = [basic, premium];

  static TrialPlan forTier(SubscriptionTier tier) =>
      all.firstWhere((p) => p.tier == tier, orElse: () => premium);

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
