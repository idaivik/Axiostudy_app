// razorpay-webhook — keeps profiles.subscription_status in sync with the real
// billing lifecycle. SCAFFOLD: wired but NOT deployed (app uses the simulated
// payment path today). Deploy with --no-verify-jwt since Razorpay calls it.
//
//   supabase secrets set RAZORPAY_WEBHOOK_SECRET=...
//   supabase functions deploy razorpay-webhook --no-verify-jwt
//   Then add the function URL as a webhook in the Razorpay dashboard and
//   subscribe to subscription.* events.
//
// Signature: HMAC-SHA256 of the raw body with RAZORPAY_WEBHOOK_SECRET, compared
// to the X-Razorpay-Signature header (constant-time).
//
// Event -> profiles.subscription_status mapping:
//   subscription.charged    -> active   (+ extend subscription_expiry ~1 month)
//   subscription.activated   -> active
//   subscription.cancelled   -> cancelled
//   subscription.completed   -> cancelled
//   subscription.halted      -> past_due
//   subscription.pending     -> past_due

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { createHmac } from "node:crypto";

const WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";

const STATUS_BY_EVENT: Record<string, string> = {
  "subscription.charged": "active",
  "subscription.activated": "active",
  "subscription.cancelled": "cancelled",
  "subscription.completed": "cancelled",
  "subscription.halted": "past_due",
  "subscription.pending": "past_due",
};

function verify(rawBody: string, signature: string | null): boolean {
  if (!signature || !WEBHOOK_SECRET) return false;
  const expected = createHmac("sha256", WEBHOOK_SECRET)
    .update(rawBody)
    .digest("hex");
  // Lengths match for hex of same algo; guard anyway.
  if (expected.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("POST only", { status: 405 });
  }

  const raw = await req.text();
  if (!verify(raw, req.headers.get("X-Razorpay-Signature"))) {
    return new Response("Invalid signature", { status: 401 });
  }

  const event = JSON.parse(raw);
  const eventName: string = event?.event ?? "";
  const newStatus = STATUS_BY_EVENT[eventName];
  if (!newStatus) return new Response("ignored", { status: 200 });

  const subscription = event?.payload?.subscription?.entity;
  const subscriptionId: string | undefined = subscription?.id;
  const userId: string | undefined = subscription?.notes?.user_id;
  if (!subscriptionId && !userId) {
    return new Response("no subscription ref", { status: 200 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const update: Record<string, unknown> = { subscription_status: newStatus };
  if (eventName === "subscription.charged") {
    // Extend access ~1 month from this successful charge.
    const expiry = new Date();
    expiry.setMonth(expiry.getMonth() + 1);
    update.subscription_expiry = expiry.toISOString();
  }

  let query = admin.from("profiles").update(update);
  query = userId
    ? query.eq("id", userId)
    : query.eq("razorpay_subscription_id", subscriptionId!);
  const { error } = await query;
  if (error) return new Response(error.message, { status: 500 });

  return new Response("ok", { status: 200 });
});
