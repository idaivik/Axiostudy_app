// revenuecat-webhook — keeps profiles.subscription_status / tier / expiry in
// sync with the store billing lifecycle, via RevenueCat's webhook. RevenueCat
// sits in front of Google Play Billing + Apple StoreKit, validates receipts,
// and POSTs a normalized event here on every change (purchase, renewal,
// cancellation, billing issue, expiration, refund).
//
// SCAFFOLD: deploy when you go live:
//   supabase secrets set REVENUECAT_WEBHOOK_AUTH=<a long random string>
//   supabase functions deploy revenuecat-webhook --no-verify-jwt
//   Then in RevenueCat → Project → Integrations → Webhooks:
//     URL    = https://<project-ref>.functions.supabase.co/revenuecat-webhook
//     Header = Authorization: <the same REVENUECAT_WEBHOOK_AUTH value>
//
// Auth: RevenueCat doesn't sign payloads; instead it sends a fixed Authorization
// header you configure. We compare it (constant-time) to REVENUECAT_WEBHOOK_AUTH.
//
// app_user_id: the app calls Purchases.logIn(<supabase user id>) before buying,
// so event.app_user_id is the profile id. Anonymous ids ($RCAnonymousID:*) are
// ignored (they reconcile on the next identified event).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const WEBHOOK_AUTH = Deno.env.get("REVENUECAT_WEBHOOK_AUTH") ?? "";

// RevenueCat event type -> our subscription_status. Access is also bounded by
// subscription_expiry, which we always refresh from expiration_at_ms.
//   - "active":    entitled now (the period_type decides trialing vs active)
//   - "cancelled": auto-renew off but still entitled until expiry
//   - "past_due":  billing problem, in grace/retry
//   - "none":      lapsed, no access
//   - null:        event we intentionally ignore
const STATUS_BY_EVENT: Record<string, string | null> = {
  INITIAL_PURCHASE: "active",
  RENEWAL: "active",
  UNCANCELLATION: "active",
  PRODUCT_CHANGE: "active",
  SUBSCRIPTION_EXTENDED: "active",
  NON_RENEWING_PURCHASE: "active",
  CANCELLATION: "cancelled",
  EXPIRATION: "none",
  BILLING_ISSUE: "past_due",
  // Informational events we don't act on:
  TEST: null,
  TRANSFER: null,
  SUBSCRIPTION_PAUSED: null,
};

function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length || a.length === 0) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// Map the purchased store product id to our internal tier. Keep in sync with
// TrialPlan.storeProductId in the Flutter app. This is the SINGLE bridge point
// between the permanent store id and the consolidated `pro` tier: the Play
// subscription `axio_premium` (and any per-period variant like
// `axio_premium:annual`) maps to `pro`. Check `basic` first — the two
// substrings don't overlap, so order is only for clarity.
function tierForProduct(productId: string | undefined): string | null {
  if (!productId) return null;
  const id = productId.toLowerCase();
  if (id.includes("basic")) return "basic";
  if (id.includes("pro") || id.includes("premium")) return "pro";
  return null;
}

function storePlatform(store: string | undefined): string | null {
  switch (store) {
    case "APP_STORE":
    case "MAC_APP_STORE":
      return "app_store";
    case "PLAY_STORE":
      return "play_store";
    default:
      return null;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });

  const auth = req.headers.get("Authorization") ?? "";
  if (!WEBHOOK_AUTH || !constantTimeEquals(auth, WEBHOOK_AUTH)) {
    return new Response("Unauthorized", { status: 401 });
  }

  let event: Record<string, unknown>;
  try {
    const body = JSON.parse(await req.text());
    event = (body?.event ?? {}) as Record<string, unknown>;
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }

  const type = (event.type as string) ?? "";
  const status = STATUS_BY_EVENT[type];
  if (status === undefined || status === null) {
    return new Response("ignored", { status: 200 });
  }

  const userId = event.app_user_id as string | undefined;
  // Skip anonymous ids — they're reconciled once the user identifies.
  if (!userId || userId.startsWith("$RCAnonymousID")) {
    return new Response("no identified user", { status: 200 });
  }

  const update: Record<string, unknown> = { subscription_status: status };

  // Trial vs paid is carried on period_type for active events.
  if (status === "active" && (event.period_type as string) === "TRIAL") {
    update.subscription_status = "trialing";
  }

  const expirationMs = event.expiration_at_ms as number | undefined;
  if (typeof expirationMs === "number") {
    update.subscription_expiry = new Date(expirationMs).toISOString();
  }

  const tier = tierForProduct(event.product_id as string | undefined);
  if (tier) update.subscription_tier = tier;

  const platform = storePlatform(event.store as string | undefined);
  if (platform) update.subscription_platform = platform;

  const productId = event.product_id as string | undefined;
  if (productId) update.store_product_id = productId;

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { error } = await admin.from("profiles").update(update).eq("id", userId);
  if (error) return new Response(error.message, { status: 500 });

  return new Response("ok", { status: 200 });
});
