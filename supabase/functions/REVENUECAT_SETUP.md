# RevenueCat webhook setup

`revenuecat-webhook` keeps `profiles.subscription_status / subscription_tier /
subscription_expiry / subscription_platform / store_product_id` in sync with the
store billing lifecycle. RevenueCat validates receipts with Apple/Google and
POSTs a normalized event on every change.

> The app ships in **simulated mode** (no RevenueCat key) so the signup flow is
> testable without store credentials. This is the checklist to go live. See the
> repo-root `BILLING_MIGRATION.md` for the full picture and the accounts/keys you
> need to gather first.

## Deploy

```bash
# A long random string you'll also paste into the RevenueCat dashboard.
supabase secrets set REVENUECAT_WEBHOOK_AUTH=$(openssl rand -hex 32)
supabase functions deploy revenuecat-webhook --no-verify-jwt
```

`--no-verify-jwt` is required because RevenueCat (not a signed-in user) calls it.
`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are injected automatically.

## Register in RevenueCat

Dashboard → Project → Integrations → **Webhooks** → Add:

- **URL**: `https://<project-ref>.functions.supabase.co/revenuecat-webhook`
  (project-ref = `nxtfbyvacunsiytlsfkl`)
- **Authorization header**: paste the same `REVENUECAT_WEBHOOK_AUTH` value.

Send a **Test** event from the dashboard; it should return `200 ignored`.

## Event → `profiles.subscription_status`

| RevenueCat event | status | notes |
| --- | --- | --- |
| `INITIAL_PURCHASE`, `RENEWAL`, `UNCANCELLATION`, `PRODUCT_CHANGE`, `SUBSCRIPTION_EXTENDED`, `NON_RENEWING_PURCHASE` | `active` (or `trialing` if `period_type = TRIAL`) | refreshes `subscription_expiry`, tier, platform |
| `CANCELLATION` | `cancelled` | auto-renew off; access continues until `subscription_expiry` |
| `BILLING_ISSUE` | `past_due` | grace/retry period |
| `EXPIRATION` | `none` | lapsed |
| `TEST`, `TRANSFER`, `SUBSCRIPTION_PAUSED` | ignored | — |

`app_user_id` equals the Supabase profile id because the app calls
`Purchases.logIn(<user id>)` before purchasing. Anonymous ids are ignored.

Tier is derived from `product_id` (`*premium*` → premium, `*basic*` → basic) —
keep that in sync with `TrialPlan.productId` in the Flutter app.
