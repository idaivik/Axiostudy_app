// razorpay-create-subscription — server-side creation of the recurring mandate
// that backs the 7-day free trial. SCAFFOLD: wired but NOT deployed. The app
// currently uses the simulated payment path (kRazorpayLiveMode = false in
// lib/features/subscription/data/payment_service.dart).
//
// To go live:
//   1. supabase secrets set RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=...
//   2. Create recurring Plans in the Razorpay dashboard; pass their ids as
//      `plan_id` from the client (TrialPlan.razorpayPlanId).
//   3. supabase functions deploy razorpay-create-subscription
//   4. Flip kRazorpayLiveMode = true and implement RazorpayPaymentService:
//        - call this function -> get { subscription_id, razorpay_key_id }
//        - open razorpay_flutter Checkout with that subscription_id
//
// Auth: caller's JWT identifies the user; profile writes use the service-role
// client but are constrained to that user's own row.
//
// Input  (POST JSON): { "plan_id": "plan_xxx", "tier": "basic" | "premium" }
// Output (JSON): { ok, subscription_id, razorpay_key_id, customer_id }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";

// 7-day free trial: the first invoice is generated after this delay, so ₹0 is
// charged today while the mandate is authorized up-front.
const TRIAL_DAYS = 7;
// Razorpay caps total_count; 120 monthly cycles = 10 years of recurring billing.
const TOTAL_BILLING_CYCLES = 120;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function basicAuthHeader(): string {
  return "Basic " + btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
}

async function razorpay(path: string, body: Record<string, unknown>) {
  const res = await fetch(`https://api.razorpay.com/v1/${path}`, {
    method: "POST",
    headers: {
      Authorization: basicAuthHeader(),
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(
      `Razorpay ${path} failed: ${data?.error?.description ?? res.status}`,
    );
  }
  return data;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ ok: false, error: "POST only" }, 405);

  if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
    return json({ ok: false, error: "Razorpay secrets not configured" }, 500);
  }

  try {
    const { plan_id } = await req.json();
    if (!plan_id) return json({ ok: false, error: "plan_id required" }, 400);

    // Identify the caller from their JWT.
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: auth } = await userClient.auth.getUser();
    const user = auth?.user;
    if (!user) return json({ ok: false, error: "Unauthorized" }, 401);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: profile } = await admin
      .from("profiles")
      .select("name, email, razorpay_customer_id")
      .eq("id", user.id)
      .single();

    // Reuse an existing Razorpay customer, else create one.
    let customerId = profile?.razorpay_customer_id as string | undefined;
    if (!customerId) {
      const customer = await razorpay("customers", {
        name: profile?.name ?? "AxioStudy User",
        email: profile?.email ?? user.email,
        fail_existing: 0,
      });
      customerId = customer.id;
    }

    const startAt = Math.floor(Date.now() / 1000) + TRIAL_DAYS * 24 * 60 * 60;
    const subscription = await razorpay("subscriptions", {
      plan_id,
      total_count: TOTAL_BILLING_CYCLES,
      customer_notify: 1,
      // First charge only after the free trial.
      start_at: startAt,
      notes: { user_id: user.id },
    });

    await admin
      .from("profiles")
      .update({
        razorpay_customer_id: customerId,
        razorpay_subscription_id: subscription.id,
      })
      .eq("id", user.id);

    return json({
      ok: true,
      subscription_id: subscription.id,
      customer_id: customerId,
      razorpay_key_id: RAZORPAY_KEY_ID,
    });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
