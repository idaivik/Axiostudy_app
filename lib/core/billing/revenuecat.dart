import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat public SDK keys. These are *public* (safe to ship in the binary) —
/// they only allow fetching offerings and making purchases attributed to the
/// signed-in user. The secret keys (used for server validation / webhooks) live
/// in RevenueCat + Supabase, never in the app.
///
/// Provide them at build time with --dart-define, e.g.
///   flutter run --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
///               --dart-define=REVENUECAT_IOS_KEY=appl_xxx
/// or paste them into the defaultValue below once you have a RevenueCat project.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    // Public Play Store SDK key (safe to ship). Override at build time with
    // --dart-define=REVENUECAT_ANDROID_KEY=... if you ever rotate it.
    defaultValue: 'goog_haZYreJikXkeLccglbFZsTbUMZZ',
  );
  static const String iosApiKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY', defaultValue: '');

  /// The key for the platform we're running on. Empty when not yet configured,
  /// which keeps the app on the [SimulatedPaymentService] path.
  static String get apiKeyForPlatform {
    if (Platform.isIOS || Platform.isMacOS) return iosApiKey;
    return androidApiKey; // Android (the only other store target).
  }

  /// True once a usable SDK key exists for this platform. Drives whether the
  /// real store flow is used (see `paymentServiceProvider`).
  static bool get isConfigured => apiKeyForPlatform.isNotEmpty;
}

/// Thin wrapper around the RevenueCat SDK lifecycle. All calls are no-ops until
/// [RevenueCatConfig.isConfigured] is true, so the app runs unchanged before
/// the billing keys are wired.
class RevenueCat {
  RevenueCat._();

  /// Initialize the SDK once at startup (call from main before runApp).
  static Future<void> init() async {
    if (!RevenueCatConfig.isConfigured) return;
    if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(
      PurchasesConfiguration(RevenueCatConfig.apiKeyForPlatform),
    );
  }

  /// Attribute purchases to the Supabase user id. The same id is what the
  /// RevenueCat webhook reports as `app_user_id`, so the server can match the
  /// profile row. Safe to call repeatedly.
  static Future<void> identify(String userId) async {
    if (!RevenueCatConfig.isConfigured) return;
    try {
      await Purchases.logIn(userId);
    } catch (_) {
      // Non-fatal: a failed identify just means the purchase falls back to the
      // anonymous id; the webhook still has original_app_user_id to reconcile.
    }
  }

  /// Detach the current user from RevenueCat on sign-out so the next account
  /// doesn't inherit this one's entitlements on a shared device.
  static Future<void> logoutBestEffort() async {
    if (!RevenueCatConfig.isConfigured) return;
    try {
      if (!await Purchases.isAnonymous) await Purchases.logOut();
    } catch (_) {}
  }

  /// The store's native subscription-management deep link for the current
  /// customer (Play Store / App Store). Returns null when the SDK isn't
  /// configured, the customer has no managed subscription, or the lookup fails —
  /// callers then fall back to the platform's generic subscriptions page.
  static Future<String?> managementUrl() async {
    if (!RevenueCatConfig.isConfigured) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.managementURL;
    } catch (_) {
      return null;
    }
  }
}
