import 'package:flutter/services.dart' show PlatformException;
// Hide RevenueCat's PurchaseResult to avoid a name clash with our domain
// PurchaseResult; we only consume RC's return value via type inference.
import 'package:purchases_flutter/purchases_flutter.dart' hide PurchaseResult;

import '../../../core/billing/revenuecat.dart';
import '../../auth/domain/user_model.dart';
import '../../../shared/models/enums.dart';
import '../domain/payment_models.dart';

/// Authorizes / restores the subscription that backs the 7-day free trial.
///
/// The concrete backend is chosen at runtime by `paymentServiceProvider`:
/// [RevenueCatPaymentService] once a RevenueCat SDK key is configured
/// ([RevenueCatConfig.isConfigured]), otherwise [SimulatedPaymentService] so the
/// whole signup flow stays testable on a machine without store credentials.
abstract class PaymentService {
  /// Opens the native store purchase sheet for [plan] at the chosen [period]. On
  /// success the trial is active (₹0 today; the store auto-renews after the trial
  /// unless cancelled).
  Future<PurchaseResult> purchase({
    required TrialPlan plan,
    required BillingPeriod period,
    required UserModel user,
  });

  /// Re-applies an existing subscription bought on this store account (Apple
  /// requires a visible "Restore Purchases" affordance).
  Future<PurchaseResult> restore({required UserModel user});
}

/// Local stand-in used until RevenueCat keys are wired. Mimics the latency and
/// shape of a real purchase and returns synthetic ids so the funnel completes.
class SimulatedPaymentService implements PaymentService {
  @override
  Future<PurchaseResult> purchase({
    required TrialPlan plan,
    required BillingPeriod period,
    required UserModel user,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1400));
    final stamp = DateTime.now().millisecondsSinceEpoch;
    // The first-purchase trial is offered on BOTH periods, so the simulated path
    // always starts in `trialing`; the period only changes how far the period
    // end is. (The real store decides trial eligibility per account.)
    final periodLength =
        period == BillingPeriod.annual ? const Duration(days: 365) : const Duration(days: 30);
    return PurchaseResult(
      success: true,
      status: SubscriptionStatus.trialing,
      tier: plan.tier,
      platform: StorePlatform.none,
      productId: plan.storeProductId,
      storeTransactionId: 'sim_${plan.tier.name}_${period.name}_$stamp',
      expiresAt: DateTime.now().add(periodLength),
    );
  }

  @override
  Future<PurchaseResult> restore({required UserModel user}) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return PurchaseResult.failure('No previous purchase found to restore.');
  }
}

/// Real store flow via RevenueCat (Google Play Billing + Apple StoreKit). The
/// store renders its own purchase sheet; we only fetch the offering, kick off
/// the purchase, and map the resulting entitlement back into a [PurchaseResult].
class RevenueCatPaymentService implements PaymentService {
  @override
  Future<PurchaseResult> purchase({
    required TrialPlan plan,
    required BillingPeriod period,
    required UserModel user,
  }) async {
    try {
      await RevenueCat.identify(user.id);

      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      if (offering == null) {
        return PurchaseResult.failure(
          'Subscriptions are unavailable right now. Please try again later.',
        );
      }

      final package = _findPackage(offering, plan, period);
      if (package == null) {
        return PurchaseResult.failure(
          'The ${plan.name} plan is not available on your store account yet.',
        );
      }

      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _fromCustomerInfo(
        result.customerInfo,
        preferredTier: plan.tier,
        transaction: result.storeTransaction,
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled();
      }
      return PurchaseResult.failure(_messageFor(code, e));
    } catch (e) {
      return PurchaseResult.failure('Purchase failed: $e');
    }
  }

  @override
  Future<PurchaseResult> restore({required UserModel user}) async {
    try {
      await RevenueCat.identify(user.id);
      final info = await Purchases.restorePurchases();
      final restored = _fromCustomerInfo(info);
      if (!restored.success) {
        return PurchaseResult.failure(
          'No active subscription was found on this store account.',
        );
      }
      return restored;
    } on PlatformException catch (e) {
      return PurchaseResult.failure(
        _messageFor(PurchasesErrorHelper.getErrorCode(e), e),
      );
    } catch (e) {
      return PurchaseResult.failure('Restore failed: $e');
    }
  }

  /// Match the package selling [plan] at [period]. The current offering may hold
  /// all four packages (2 tiers × 2 periods) or be split per tier, so we select
  /// by **tier × period**:
  ///   1. period type (monthly/annual) AND the product-id substring for the tier;
  ///   2. the canonical package identifier (`$rc_monthly` / `$rc_annual`);
  ///   3. the offering's typed package for the period;
  /// so a partially-misconfigured offering still sells the right thing.
  Package? _findPackage(Offering offering, TrialPlan plan, BillingPeriod period) {
    final wantType =
        period == BillingPeriod.annual ? PackageType.annual : PackageType.monthly;
    // `axio_premium` → matches "premium"; `axio_basic` → "basic".
    final tierHint = plan.storeProductId.toLowerCase();

    bool matchesTier(Package p) {
      final id = p.storeProduct.identifier.toLowerCase();
      return id.contains(tierHint) ||
          (plan.tier == SubscriptionTier.pro &&
              (id.contains('premium') || id.contains('pro'))) ||
          (plan.tier == SubscriptionTier.basic && id.contains('basic'));
    }

    for (final p in offering.availablePackages) {
      if (p.packageType == wantType && matchesTier(p)) return p;
    }
    for (final p in offering.availablePackages) {
      if (p.identifier == plan.packageId(period)) return p;
    }
    return period == BillingPeriod.annual ? offering.annual : offering.monthly;
  }

  /// Translate the post-purchase [CustomerInfo] into our domain result by
  /// reading the highest entitlement that is currently active.
  PurchaseResult _fromCustomerInfo(
    CustomerInfo info, {
    SubscriptionTier? preferredTier,
    StoreTransaction? transaction,
  }) {
    // Prefer pro over basic when both somehow resolve.
    EntitlementInfo? entitlement;
    TrialPlan? plan;
    for (final candidate in [TrialPlan.pro, TrialPlan.basic]) {
      final e = info.entitlements.active[candidate.entitlementId];
      if (e != null && e.isActive) {
        entitlement = e;
        plan = candidate;
        break;
      }
    }

    if (entitlement == null || plan == null) {
      return PurchaseResult.failure(
        'The purchase did not unlock access. Contact support if you were charged.',
      );
    }

    final status = entitlement.periodType == PeriodType.trial
        ? SubscriptionStatus.trialing
        : SubscriptionStatus.active;

    return PurchaseResult(
      success: true,
      status: status,
      tier: preferredTier ?? plan.tier,
      platform: _platformFor(entitlement.store),
      productId: entitlement.productIdentifier,
      storeTransactionId: transaction?.transactionIdentifier,
      expiresAt: _parseDate(entitlement.expirationDate),
    );
  }

  StorePlatform _platformFor(Store store) => switch (store) {
        Store.appStore => StorePlatform.appStore,
        Store.playStore => StorePlatform.playStore,
        _ => StorePlatform.none,
      };

  DateTime? _parseDate(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);

  String _messageFor(PurchasesErrorCode code, PlatformException e) {
    switch (code) {
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Your payment is pending approval. Access unlocks once it clears.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already own this subscription. Try "Restore purchases".';
      case PurchasesErrorCode.networkError:
        return 'Network error. Check your connection and try again.';
      case PurchasesErrorCode.storeProblemError:
        return 'The store is having trouble right now. Please try again later.';
      default:
        return e.message ?? 'Payment could not be completed.';
    }
  }
}
