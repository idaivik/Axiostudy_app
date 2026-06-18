# Plan: Take native billing live (the billing path, the UI, the connection)

> Hand this file to a fresh chat: "Read `BILLING_GO_LIVE.md` and execute it."
> Everything needed is below. This is the **end-to-end go-live plan** for the
> RevenueCat (Google Play Billing + Apple StoreKit) subscription flow.
>
> Companion docs (already in the repo): `BILLING_MIGRATION.md` (the original
> migration write-up — note its bundle ids are now **stale**, see §1),
> `DEPLOY_REVENUECAT_WEBHOOK.md` (webhook deploy — **done**),
> `supabase/functions/REVENUECAT_SETUP.md` (webhook reference).

---

## 0. Current state (read first)

**Already DONE (verified 2026-06-16 — do NOT redo):**
- ✅ **All app code is written and compiles.** The billing path, paywall UI, and
  persistence are complete (file map in §3). `purchases_flutter: ^10.2.3` is in
  `pubspec.yaml`.
- ✅ **DB migration applied** — `20260614140000_native_billing` is recorded in the
  ledger; `profiles` has `subscription_status / subscription_tier /
  subscription_expiry / subscription_platform / store_product_id /
  store_transaction_id`. Real purchase webhooks will no longer 500.
- ✅ **Webhook deployed + live** — `revenuecat-webhook` is `ACTIVE` on project
  `nxtfbyvacunsiytlsfkl` with `verify_jwt: false`. A no-auth POST returns 401; a
  TEST event returns 200. The `REVENUECAT_WEBHOOK_AUTH` secret is set and the same
  value is registered in the RevenueCat webhook header.

**What is LEFT (this plan):**
1. **Store + RevenueCat setup** (human actions — accounts, products, keys). §4–§6.
2. **Flip the app to live** — provide the two public SDK keys. §7. *(A chat can do this.)*
3. **Verify end-to-end.** §8.
4. **Optional code/UX hardening** the chat can implement now while setup is pending. §9.

> Until a RevenueCat SDK key is present, the app auto-runs the **simulated**
> billing path (`SimulatedPaymentService`) — so it stays fully testable. Flipping
> to live = supplying the keys; **no code change is required** to switch backends.

---

## 1. ⚠️ Identifiers — single source of truth (use these EXACT values)

The bundle id was unified to **`com.axiostudy.app`** on both platforms (this is in
the uncommitted working tree: `android/app/build.gradle.kts` `applicationId` +
`namespace`, and iOS `PRODUCT_BUNDLE_IDENTIFIER` ×3). **`BILLING_MIGRATION.md` is
out of date** — it still lists `com.axiostudy.axiostudy_app` / `com.axiostudy.axiostudyApp`.
**Ignore those. Register stores against `com.axiostudy.app`.** A store product /
app id is permanent once created, so get this right before §4–§5.

| Thing | Value | Where it's referenced in code |
| --- | --- | --- |
| iOS bundle id | `com.axiostudy.app` | `ios/Runner.xcodeproj/project.pbxproj` |
| Android applicationId | `com.axiostudy.app` | `android/app/build.gradle.kts` |
| Supabase project ref | `nxtfbyvacunsiytlsfkl` | — |
| Webhook URL | `https://nxtfbyvacunsiytlsfkl.functions.supabase.co/revenuecat-webhook` | deployed |
| Basic subscription id | `axio_basic` (₹199/mo · ₹2,199/yr) | `TrialPlan.basic.storeProductId` |
| Pro subscription id | `axio_premium` (₹399/mo · ₹4,399/yr) | `TrialPlan.pro.storeProductId` |
| Entitlement ids | `basic`, `pro` | `TrialPlan.*.entitlementId` |
| RevenueCat package ids | `$rc_monthly`, `$rc_annual` (per period) | `TrialPlan.*.packageId(period)` |
| Trial length | 7 days, first purchase, **both** monthly & annual (Play `freetrial` offer) | — |

Each tier is **one** Play subscription with **monthly + annual base plans** (the period
is the base plan, not a separate product id) and a first-purchase `freetrial` offer.
`TrialPlan` lives in `lib/features/subscription/domain/payment_models.dart`. The webhook
derives tier from the `product_id` substring (`*basic*`→basic, `*pro*`/`*premium*`→pro)
in `supabase/functions/revenuecat-webhook/index.ts` — this is the single bridge from the
permanent store id `axio_premium` to the internal `pro` tier. **If you change any id,
change it in those two files (and re-create the store product).**

---

## 2. The billing path — how it connects (so you understand what you're wiring)

```
New account
  → router gate: onboardingStepFor(user)   [lib/features/onboarding/data/onboarding_providers.dart]
      exam_type null? → /onboarding/exam
      !user.isEntitled? → /paywall          ← hard paywall, every new user
  → PaywallScreen: tap "Start 7-Day Free Trial"   [.../presentation/paywall_screen.dart]
  → SubscriptionController.startTrial(tier)        [.../data/subscription_providers.dart]
  → paymentServiceProvider picks backend:
        RevenueCatConfig.isConfigured ? RevenueCatPaymentService : SimulatedPaymentService
  → RevenueCatPaymentService.purchase()            [.../data/payment_service.dart]
        RevenueCat.identify(user.id)   // logIn → app_user_id == supabase id
        Purchases.getOfferings() → current offering → find package (id 'basic'/'premium')
        Purchases.purchase(package)    // <-- the NATIVE store sheet renders here
        map CustomerInfo.entitlements.active[...] → PurchaseResult
  → on success: _persist() → authRepository.activateSubscription()  // optimistic write
        writes subscription_status='trialing', tier, expiry, platform, product_id, txn_id
  → PaywallScreen._enterApp(): context.go('/onboarding/profiling'); invalidate currentUserProvider
  → router re-evaluates: user.isEntitled == true → paywall cleared

Meanwhile, asynchronously and authoritatively:
  Store event → RevenueCat → POST revenuecat-webhook → UPDATE profiles
        INITIAL_PURCHASE/RENEWAL/… → active|trialing ; CANCELLATION → cancelled ;
        BILLING_ISSUE → past_due ; EXPIRATION → none   (keeps DB true over time)
```

**The "connection" in one line:** the client write after purchase is *optimistic*
(clears the paywall instantly); the **webhook is the source of truth** for
renewals, cancellations, billing issues, refunds. Access anywhere in the app is
`user.isEntitled` = `subscriptionStatus ∈ {trialing, active}`
(`lib/shared/models/enums.dart`).

**Identity:** the app calls `Purchases.logIn(supabaseUserId)` before buying
(`RevenueCat.identify`), and again at launch for a returning session
(`lib/main.dart`). So the webhook's `app_user_id` == the `profiles.id` to update.
Sign-out calls `RevenueCat.logoutBestEffort()` so a shared device doesn't leak
entitlements.

---

## 3. File map (what's already implemented — for reference, not action)

| File | Role |
| --- | --- |
| `lib/core/billing/revenuecat.dart` | SDK lifecycle: `init` / `identify` / `logoutBestEffort`; reads keys from `--dart-define`. No-ops until a key exists. |
| `lib/features/subscription/domain/payment_models.dart` | `TrialPlan` (ids/pricing), `PurchaseResult`, `StorePlatform`. |
| `lib/features/subscription/data/payment_service.dart` | `RevenueCatPaymentService` (real purchase/restore) + `SimulatedPaymentService`. |
| `lib/features/subscription/data/subscription_providers.dart` | `paymentServiceProvider` (auto-selects backend), `SubscriptionController` (`startTrial` / `restore` / `_persist`). |
| `lib/features/subscription/presentation/paywall_screen.dart` | Hard paywall UI + Restore button. |
| `lib/features/auth/data/auth_repository.dart` | `activateSubscription()` write; `signOut()` logs out RevenueCat. |
| `lib/features/onboarding/data/onboarding_providers.dart` | `onboardingStepFor()` router gate. |
| `lib/main.dart` | `RevenueCat.init()` + identify existing session at launch. |
| `supabase/functions/revenuecat-webhook/index.ts` | Webhook (deployed). |

---

## 4. Apple — App Store Connect ($99/yr)  *(human actions)*

1. Enroll: https://developer.apple.com/programs/ (company needs legal name + **D-U-N-S**).
2. App Store Connect → Business → sign **Paid Apps agreement** + add **banking & tax**.
   IAP does nothing until this shows **Active**.
3. Create the app record with bundle id **`com.axiostudy.app`**.
4. Create a **Subscription Group** with **four** auto-renewable subscriptions (Apple
   has no base-plan concept — each duration is its own product), each with a **7-day
   free introductory offer**. Keep the tier substring (`basic`/`premium`) in the id so
   the webhook's `tierForProduct` resolves it:
   - `axio_basic_monthly` — ₹199/month
   - `axio_basic_yearly` — ₹2,199/year
   - `axio_premium_monthly` — ₹399/month
   - `axio_premium_yearly` — ₹4,399/year
5. Create a few **Sandbox testers** (Users and Access → Sandbox).
6. For RevenueCat: Users and Access → **Integrations → In-App Purchase** → generate
   key → download the **`.p8`**. Collect: **`.p8`** + **Key ID** + **Issuer ID** +
   **App-Specific Shared Secret** (App Information).

## 5. Google — Play Console ($25 one-time)  *(human actions)*

1. Register: https://play.google.com/console/signup (org verification/**D-U-N-S** can
   take days — start early).
2. Setup → **Payments** merchant profile.
3. Create the app with package **`com.axiostudy.app`**; upload at least one build to
   an internal-testing track (subscriptions require an uploaded AAB).
4. Create two **subscriptions**, each with a **monthly + an annual base plan** and a
   first-purchase **`freetrial` offer (7 days)** on both base plans:
   - `axio_basic` — monthly ₹199, annual ₹2,199
   - `axio_premium` — monthly ₹399, annual ₹4,399
5. Setup → **License testing** → add tester Google accounts.
6. Create a **Google Cloud service account** with Play Developer API access, grant it
   in Play Console → Users & permissions (follow RevenueCat's guide). Collect: the
   service-account **JSON key**.

## 6. RevenueCat  *(human actions; webhook already done)*

1. Project at https://app.revenuecat.com → add an **App Store app** (bundle
   `com.axiostudy.app`) and a **Play Store app** (package `com.axiostudy.app`).
2. Upload the Apple key/shared secret (§4.6) and Play service-account JSON (§5.6).
3. **Products** matching the store product ids → **Entitlements** `basic` and
   `pro` (the Play subscription `axio_premium` attaches to the `pro`
   entitlement), attach each product to its entitlement.
4. **Offering** (set as `current`) with the monthly + annual **Packages** for each
   tier, using the canonical package types **`$rc_monthly`** and **`$rc_annual`**.
   *(Code matches by tier × period — package type for the period and the product-id
   substring for the tier — then falls back to product id / `offering.monthly` /
   `offering.annual`; see `_findPackage` in `payment_service.dart`.)*
5. **Webhook is already deployed and registered** — just confirm in
   Integrations → Webhooks that the URL/header match §1 and "Send test event" → 200.
6. Collect the two **public SDK keys**: `appl_…` (iOS) and `goog_…` (Android).

---

## 7. Flip to live  *(a chat can do this once §6.6 keys are provided)*

Two options — prefer **A** (keys stay out of git):

**A. Build-time defines (recommended):**
```bash
flutter run \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
  --dart-define=REVENUECAT_IOS_KEY=appl_xxx
```
For release builds pass the same `--dart-define`s to `flutter build`.

**B. Paste as defaults** in `lib/core/billing/revenuecat.dart` (`androidApiKey` /
`iosApiKey` `defaultValue`s). Simpler but commits public keys into the binary/source.

The moment a key is present for the running platform, `RevenueCatConfig.isConfigured`
becomes true and `paymentServiceProvider` returns `RevenueCatPaymentService` — no
other change needed. Confirm with `flutter analyze` (expect no new issues).

---

## 8. Verify end-to-end  *(after §7)*

Use a **Sandbox** (Apple) / **license-test** (Google) account — never a real card.

1. **Purchase:** new account → exam → paywall → "Start 7-Day Free Trial" → native
   sheet appears → complete. App should advance to `/onboarding/profiling`.
2. **DB write (optimistic):** `profiles` row for that user → `subscription_status =
   'trialing'`, `subscription_tier`, `subscription_expiry`, `subscription_platform`,
   `store_product_id` populated. (Query via Supabase MCP `execute_sql`.)
3. **Webhook (authoritative):** RevenueCat → Customer → confirm an `INITIAL_PURCHASE`
   event was delivered 200; the row stays `trialing` (or flips to `active` after the
   trial). Check `supabase` function logs if not.
4. **Restore:** reinstall / second device with same store account → paywall →
   "Restore purchases" → should re-enter the app without re-charging.
5. **Cancel & lapse:** cancel in the store → webhook sets `cancelled`, then
   `none`/`EXPIRATION` at period end. Confirm the row updates.
6. **Sign-out isolation:** sign out, sign in as a different user on the same device →
   the new user is NOT entitled from the previous purchase.

---

## 9. Optional code/UX hardening (the chat CAN implement these now)

These are real gaps the chat can do **while store setup is pending** — they don't
need keys. Confirm scope with the user before building; each is independent.

1. **Working "Manage Subscription" + Restore in Profile.**
   `lib/features/profile/presentation/profile_screen.dart:148` currently shows a
   placeholder dialog ("available at axiostudy.com in a future update"). Replace with:
   - a **Restore purchases** action → `subscriptionControllerProvider.restore()`
     (Apple requires restore to be reachable outside the paywall), and
   - **Manage subscription** → open the native management URL
     (`Purchases.showManageSubscriptions()` / store deep link), plus show current
     `subscription_status` + renewal/expiry date from the profile.

2. **Decide post-onboarding lapse behavior.** By design
   (`onboardingStepFor`), once `onboarding_completed = true` a user is **never**
   sent back to the paywall even if `subscription_status = 'none'` (lapsed) — they
   keep full access. If the business wants paid features to actually lock on lapse,
   add an `isEntitled` gate on premium surfaces (or a soft re-paywall). **This is a
   product decision — ask the user before changing it.**

3. **Tier enforcement (basic vs premium).** The paywall sells two tiers but verify
   the app actually gates premium-only features (AI question generation, coaching
   roadmap) on `user.subscriptionTier`. If not enforced, decide whether that's
   intended.

4. **Doc cleanup.** Update `BILLING_MIGRATION.md` bundle ids to `com.axiostudy.app`
   (§1) and mark Step 0 (migration) + webhook as **done** so the docs stop
   contradicting reality. Optionally delete the now-stale Razorpay references.

5. **Hardcoded dev user.** `lib/features/auth/data/auth_providers.dart:13` pins
   `subscriptionTier: SubscriptionTier.premium` on some fallback/dev user — confirm
   it can't leak entitlement in production.

---

## 10. Gotchas

- **Bundle id is permanent.** Register `com.axiostudy.app` everywhere; you can't
  rename a store product/app later. Ignore the old ids in `BILLING_MIGRATION.md`.
- **Agreements gate IAP.** Apple "Paid Apps" + Google merchant profile must be
  **active**, or offerings come back empty and the paywall shows "Subscriptions are
  unavailable right now."
- **Empty offering** also happens if the RevenueCat `current` Offering isn't set or
  packages aren't `basic`/`premium` — that's the most common live-test failure.
- **Store fees** 15–30% — factor into ₹199/₹299 if needed.
- **Webhook is source of truth**; the client write is only to clear the paywall
  instantly. Never rely solely on the optimistic write for renewals/cancellations.
- Keep `TrialPlan` ids (`payment_models.dart`) and the webhook tier mapping
  (`revenuecat-webhook/index.ts`) in sync with whatever you create in the stores.
```
