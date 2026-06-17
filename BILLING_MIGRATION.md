# Billing migration: Razorpay → Google Play Billing + Apple StoreKit (via RevenueCat)

Razorpay is **not allowed** for in-app digital subscriptions — Apple and Google
require their own billing for digital goods consumed in the app. This migration
replaces Razorpay with native store billing, wrapped by **RevenueCat** (one SDK
that fronts both Google Play Billing and Apple StoreKit, validates receipts, and
sends one webhook to Supabase).

The app still runs today in **simulated mode** (no RevenueCat key configured), so
nothing breaks while you set up the store accounts. Flip to live by providing the
keys in step 4 below.

> **Status (2026-06-16):** The DB migration (Step 0) and the Supabase webhook are
> **done and verified live**. Both platforms now use the unified bundle id
> **`com.axiostudy.app`** — the older `com.axiostudy.axiostudy_app` /
> `com.axiostudy.axiostudyApp` ids previously listed here have been corrected
> below. For the current, authoritative go-live runbook see
> **`BILLING_GO_LIVE.md`**; this file is the historical migration write-up.

---

## Part A — Code changes already done (in this branch)

| Area | Change |
| --- | --- |
| `pubspec.yaml` | Added `purchases_flutter` (RevenueCat SDK). Removed nothing else. |
| `lib/core/billing/revenuecat.dart` | **New.** SDK config + lifecycle (init / identify / logout). Reads public keys from `--dart-define` (`REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`). No-ops until a key exists. |
| `lib/features/subscription/domain/payment_models.dart` | `TrialPlan` now carries `packageId` / `entitlementId` / `productId` instead of `razorpayPlanId`. `MandateResult` → `PurchaseResult` (+ `StorePlatform`). |
| `lib/features/subscription/data/payment_service.dart` | `RazorpayPaymentService` → **`RevenueCatPaymentService`** (real `purchase` + `restore`). `SimulatedPaymentService` kept for offline testing. |
| `lib/features/subscription/data/subscription_providers.dart` | `startTrial` now runs the native purchase; added `restore()`; persists store columns. Backend auto-selects RevenueCat vs simulated. |
| `lib/features/subscription/presentation/paywall_screen.dart` | Removed the fake "Razorpay checkout" sheet (the store shows its own). Added **Restore purchases** (Apple requires it) + updated copy. |
| `lib/features/auth/domain/user_model.dart` | Columns `razorpay_customer_id` / `razorpay_subscription_id` → `subscription_platform` / `store_product_id` / `store_transaction_id`. |
| `lib/features/auth/data/auth_repository.dart` | `activateTrial` → `activateSubscription` (new columns). Sign-out now also logs out of RevenueCat. |
| `lib/main.dart` | Calls `RevenueCat.init()` + identifies an existing session at launch. |
| `supabase/functions/revenuecat-webhook/` | **New** edge function replacing both razorpay functions. |
| `supabase/functions/razorpay-*`, `RAZORPAY_SETUP.md` | **Deleted.** |
| `supabase/migrations/20260614140000_native_billing.sql` | **New** migration (see step 0 — needs to be applied by you). |

### Step 0 — Apply the DB migration ✅ DONE

Applied to the production database — `20260614140000_native_billing` is in the
migration ledger and `profiles` now carries `subscription_status` /
`subscription_tier` / `subscription_expiry` / `subscription_platform` /
`store_product_id` / `store_transaction_id`. No further action needed.

```bash
supabase db push          # applies supabase/migrations/20260614140000_native_billing.sql
# — or paste that file's SQL into the Supabase dashboard → SQL editor.
```

---

## Part B — What you need to register & provide

You haven't enrolled yet. Here's exactly what to create and which values to hand
back to me (or paste where noted). Order matters: **Apple/Google first, then
RevenueCat, then the app keys.**

### B1. Apple — App Store Connect ($99/year)
1. **Enroll** in the Apple Developer Program → https://developer.apple.com/programs/
   - Needs: Apple ID, payment, and for a company: legal entity name + **D-U-N-S number**.
2. Sign the **Paid Apps agreement** and add **banking + tax** info
   (App Store Connect → Business). IAP won't work until this is "Active".
3. Create the app record with **Bundle ID** `com.axiostudy.app`.
4. Create a **Subscription Group** and two **auto-renewable subscriptions** with a
   **7-day free introductory offer**:
   - `axio_basic_monthly` — ₹199/month
   - `axio_premium_monthly` — ₹299/month
5. Create a few **Sandbox test accounts** (Users and Access → Sandbox).
6. Generate an **In-App Purchase key** for RevenueCat: App Store Connect → Users
   and Access → **Integrations → In-App Purchase** → generate. Download the `.p8`.

   **Give me / upload to RevenueCat:** the `.p8` file + **Key ID** + **Issuer ID**,
   and the **App-Specific Shared Secret** (App Information → App-Specific Shared Secret).

### B2. Google — Play Console ($25 one-time)
1. **Register** → https://play.google.com/console/signup (identity verification;
   for an org, **D-U-N-S** + verification can take days — start early).
2. Set up the **payments/merchant profile** (Play Console → Setup → Payments).
3. Create the app with **package name** `com.axiostudy.app`, then upload
   at least one build to an internal testing track (products need an uploaded AAB).
4. Create two **subscriptions** with a base plan + **free-trial offer (7 days)**:
   - `axio_basic_monthly` — ₹199/month
   - `axio_premium_monthly` — ₹299/month
5. Add **license test accounts** (Setup → License testing).
6. Create a **Google Cloud service account** with Play Developer API access and
   grant it in Play Console → Users & permissions (RevenueCat's guide walks this).

   **Give me / upload to RevenueCat:** the service-account **JSON key**.

### B3. RevenueCat (free up to ~$2.5k/mo revenue)
1. Create a project at https://app.revenuecat.com → add an **App Store app** and a
   **Play Store app**.
2. Upload the **Apple in-app-purchase key/shared secret** (B1.6) and the **Play
   service-account JSON** (B2.6).
3. Create **Products** matching the store product ids, then **Entitlements**
   `basic` and `premium`, attaching each product to its entitlement.
4. Create an **Offering** (the default/"current") with two **Packages** identified
   `basic` and `premium`, pointing at the two products.
5. **Webhook** → ✅ already deployed and registered (`revenuecat-webhook`, live on
   project `nxtfbyvacunsiytlsfkl`, `verify_jwt: false`). Just confirm the URL +
   auth header match and "Send test event" → 200. See
   `supabase/functions/REVENUECAT_SETUP.md`.

   **Give me:** the two **public SDK keys** — `appl_…` (iOS) and `goog_…` (Android).

> If you change any of the identifiers above, update them in one place:
> `TrialPlan.basic/premium` in
> `lib/features/subscription/domain/payment_models.dart` (and the tier-mapping in
> `revenuecat-webhook/index.ts`).

---

## Part C — Flip to live (after B is done)

1. **Migration applied** (step 0). ✅ done
2. **Webhook deployed** (`revenuecat-webhook`, live). ✅ done —
   `supabase/functions/REVENUECAT_SETUP.md`.
3. **Provide the SDK keys.** Either pass at build time:
   ```bash
   flutter run \
     --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
     --dart-define=REVENUECAT_IOS_KEY=appl_xxx
   ```
   …or paste them as the `defaultValue`s in `lib/core/billing/revenuecat.dart`.
   The app switches to the real store flow automatically once a key is present.
4. **Test** with a Sandbox (Apple) / license-test (Google) account: buy → confirm
   the profile flips to `trialing`, then `active` after the trial; test **Restore**
   and **Cancel**.

---

## Notes / decisions
- **Store fees:** Apple & Google take 15–30% (15% under their small-business
  programs / after year 1). Factor this into ₹199 / ₹299 pricing if needed.
- **Free trial** is now the store's native intro offer — the store charges ₹0 up
  front and auto-converts after 7 days; we no longer authorize a mandate ourselves.
- **Source of truth:** the client write after purchase is optimistic (clears the
  paywall instantly); the RevenueCat webhook is authoritative for renewals,
  cancellations, billing issues, and refunds.
- **Bundle id unified:** both platforms now use **`com.axiostudy.app`** (Android
  `applicationId` + `namespace`, iOS `PRODUCT_BUNDLE_IDENTIFIER`). Register every
  store/RevenueCat app against that exact id — it is permanent once a product is
  created.
