# Razorpay recurring-trial setup

The signup flow charges ₹0 today and starts a **7-day free trial** backed by a
Razorpay **recurring mandate**. The app ships in **simulated mode** so the whole
flow is testable without a Razorpay account. This document is the checklist to
go live.

## Current state (simulated)

- `kRazorpayLiveMode = false` in
  `lib/features/subscription/data/payment_service.dart`.
- `SimulatedPaymentService` approves the mandate locally and returns synthetic
  `cust_sim_*` / `sub_sim_*` ids.
- `SubscriptionController.startTrial` writes the trial to `profiles`
  (`subscription_status = 'trialing'`, `trial_ends_at = now + 7d`).
- These two edge functions are **scaffolded but NOT deployed**.

## Going live

1. **Razorpay dashboard**
   - Create two recurring **Plans** (monthly): Basic ₹199, Premium ₹299.
   - Copy each `plan_id` into `TrialPlan.basic/premium.razorpayPlanId`
     (`lib/features/subscription/domain/payment_models.dart`).

2. **Secrets**
   ```bash
   supabase secrets set RAZORPAY_KEY_ID=rzp_live_xxx
   supabase secrets set RAZORPAY_KEY_SECRET=xxx
   supabase secrets set RAZORPAY_WEBHOOK_SECRET=xxx
   ```

3. **Deploy functions**
   ```bash
   supabase functions deploy razorpay-create-subscription
   supabase functions deploy razorpay-webhook --no-verify-jwt
   ```
   Register the `razorpay-webhook` URL in the dashboard and subscribe to the
   `subscription.*` events.

4. **Flutter client**
   - Add the package: `flutter pub add razorpay_flutter` (+ native setup per the
     plugin docs).
   - Implement `RazorpayPaymentService.authorizeTrialMandate`:
     1. POST to `razorpay-create-subscription` with the tier's `plan_id`.
     2. Open Razorpay Checkout with the returned `subscription_id`.
     3. Map the `PaymentSuccessResponse` to a `MandateResult`.
   - Flip `kRazorpayLiveMode = true`.

## Lifecycle → `profiles.subscription_status`

| Source | Status |
| --- | --- |
| Trial authorized (client) | `trialing` |
| `subscription.charged` / `activated` (webhook) | `active` |
| `subscription.cancelled` / `completed` (webhook) | `cancelled` |
| `subscription.halted` / `pending` (webhook) | `past_due` |

`UserModel.isEntitled` (`trialing` or `active`) is what the router's onboarding
guard uses to clear the hard paywall.
