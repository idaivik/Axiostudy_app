// analysis-narrative — Feature 3 (BILLING_BUCKET1_BUILD_PROMPT.md §5), Pro-only.
//
// A 2–3 sentence "AI coach" paragraph over the analytics we ALREADY computed for
// an attempt. The cheap model (§2.1) turns the existing numbers into a short
// "where to target for max marks / least time" nudge — it invents NOTHING; the
// prompt is grounded strictly in the supplied weak/strong topics + accuracies.
//
// Billing (meter: ai_analysis_narrative, Pro 60):
//   • Cache first: if attempt_analytics.ai_narrative is set, return it WITHOUT
//     metering — re-opening a result never spends a second credit.
//   • Else consume_meter BEFORE the model call:
//       trial_ai_locked / no_entitlement → HTTP 402 (locked / paywall).
//       cap_reached                      → HTTP 200 ok:false (feature-specific;
//                                          there's no fallback prose to serve).
//       ok                               → generate, cache, return.
//   • On model failure → refund_meter (a flaky model never burns a credit).
//
// Input  (POST JSON): { "attempt_id": "attempt_xxxxxxxx" }
// Output (JSON): { ok, narrative?, cached?, remaining?, reason?, plan? }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { callGemini, GEMINI_API_KEY, pickModel } from "../_shared/gemini.ts";

const METER = "ai_analysis_narrative";

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

interface TopicRow {
  topic_name?: string;
  subject_name?: string;
  accuracy?: number; // 0–1
}
interface BreakdownRow {
  accuracy?: number; // 0–1
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let userId = "";
  let consumed = false; // metered-but-unconfirmed → refunded on model failure
  let db: ReturnType<typeof createClient> | null = null;

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await authClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ ok: false, error: "unauthorized" }, 401);
    }
    userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const attemptId: string | undefined = body?.attempt_id;
    if (!attemptId) return json({ ok: false, error: "attempt_id required" }, 400);

    db = createClient(supabaseUrl, serviceKey);

    // ── Load the already-computed analytics (and verify ownership) ──
    const { data: row, error: rowErr } = await db
      .from("attempt_analytics")
      .select(
        "user_id, accuracy, total_correct, total_wrong, total_unanswered, " +
          "avg_time_per_question, weak_topics, strong_topics, " +
          "subject_breakdown, difficulty_breakdown, ai_narrative",
      )
      .eq("attempt_id", attemptId)
      .single();
    if (rowErr || !row) return json({ ok: false, error: "analytics not found" }, 404);
    if (row.user_id !== userId) return json({ ok: false, error: "forbidden" }, 403);

    // ── Cache hit: never re-bill ──
    const cached = (row.ai_narrative as string | null)?.trim();
    if (cached) {
      return json({ ok: true, narrative: cached, cached: true });
    }

    // ── Gate + reserve BEFORE the model call ──
    const { data: credit, error: credErr } = await db.rpc("consume_meter", {
      p_user: userId,
      p_meter: METER,
      p_amount: 1,
    });
    if (credErr) return json({ ok: false, error: "credit check failed" }, 500);
    const reason: string | undefined = credit?.reason;
    const plan: string | undefined = credit?.plan;

    if (reason === "trial_ai_locked" || reason === "no_entitlement") {
      return json({ ok: false, reason, plan }, 402);
    }
    if (reason === "cap_reached") {
      // No fallback prose for narrative — surface the cap to the client at 200.
      return json(
        { ok: false, reason: "cap_reached", plan, remaining: credit?.remaining ?? 0 },
        200,
      );
    }
    if (!credit?.ok) {
      return json({ ok: false, reason: reason ?? "no_credit", plan }, 402);
    }
    consumed = true;

    if (!GEMINI_API_KEY) {
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: 1 });
      consumed = false;
      return json({ ok: false, reason: "generation_error" }, 200);
    }

    // ── Student's exam track (tone only) ──
    const { data: profile } = await db
      .from("profiles").select("exam_type").eq("id", userId).single();
    const exam = ((profile?.exam_type as string | null) ?? "jee").toUpperCase();

    // ── Build a compact, GROUNDED summary (only numbers we already have) ──
    const pct = (n: number | undefined) => Math.round((n ?? 0) * 100);
    const topics = (arr: unknown): Array<{ name: string; score: number }> =>
      (Array.isArray(arr) ? (arr as TopicRow[]) : [])
        .slice(0, 5)
        .map((t) => ({
          name: `${t.topic_name ?? ""}${t.subject_name ? ` (${t.subject_name})` : ""}`
            .trim(),
          score: pct(t.accuracy),
        }))
        .filter((t) => t.name.length > 0);
    const breakdown = (obj: unknown): Array<{ name: string; score: number }> => {
      if (!obj || typeof obj !== "object") return [];
      return Object.entries(obj as Record<string, BreakdownRow>).map(([k, v]) => ({
        name: k,
        score: pct(v?.accuracy),
      }));
    };

    const summary = {
      overall_accuracy_pct: pct(row.accuracy as number),
      correct: row.total_correct ?? 0,
      wrong: row.total_wrong ?? 0,
      unanswered: row.total_unanswered ?? 0,
      avg_time_per_question_sec: Math.round(Number(row.avg_time_per_question) || 0),
      weak_topics: topics(row.weak_topics),
      strong_topics: topics(row.strong_topics),
      subject_accuracy_pct: breakdown(row.subject_breakdown),
      difficulty_accuracy_pct: breakdown(row.difficulty_breakdown),
    };

    const prompt =
`You are an encouraging ${exam} coach writing to ONE student about ONE test they just finished.
Write 2-3 short sentences (max ~55 words) of plain text — no markdown, no bullet points, no headings.
Tell them where to focus next for the most marks with the least time, naming ONLY topics/subjects from the data.
Be specific and warm; do NOT invent any topic, number, or fact that is not in the JSON. Do NOT restate every number.

Student's result (JSON):
${JSON.stringify(summary)}

Return ONLY the paragraph text.`;

    let narrative = "";
    try {
      narrative = (await callGemini(prompt, {
        model: pickModel("narrative"),
        temperature: 0.4,
      })).trim();
    } catch (e) {
      console.error("narrative gemini failed:", e);
    }

    if (!narrative) {
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: 1 });
      consumed = false;
      return json({ ok: false, reason: "generation_error" }, 200);
    }

    // ── Cache so re-opening the result doesn't re-bill ──
    await db
      .from("attempt_analytics")
      .update({ ai_narrative: narrative, ai_narrative_at: new Date().toISOString() })
      .eq("attempt_id", attemptId);
    consumed = false;

    return json({
      ok: true,
      narrative,
      cached: false,
      remaining: credit?.remaining ?? null,
    });
  } catch (e) {
    if (consumed && db && userId) {
      try {
        await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: 1 });
      } catch (_) { /* noop */ }
    }
    console.error("analysis-narrative error:", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
