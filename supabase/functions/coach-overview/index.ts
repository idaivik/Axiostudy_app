// coach-overview — Plan B (ANALYTICS_PLAN_B_AI_COACH.md), account-level AI coach.
//
// The Overview-tab counterpart to `analysis-narrative`. Where that function is
// per-attempt, this one answers "where do I stand & why" for the whole account,
// and ships TWO things:
//
//   1. A DETERMINISTIC focus — the weakest `user_weak_chapters` row + its weakest
//      topic. This is the "#1 focus → Practice" target and is returned to EVERY
//      caller (free or Pro, entitled or locked, metering live or not). The client
//      footer launches practice from it with no entitlement.
//   2. A Pro narrative paragraph (cheap model, §2.1) — gated + metered EXACTLY
//      like `analysis-narrative` (same `ai_analysis_narrative` meter; NO new
//      meter is introduced).
//
// Meter protection (the whole reason for `source_hash`):
//   • source_hash = fingerprint of (latest attempt id + sorted weak-chapter
//     mastery). If the cached row's hash matches → return the cached narrative
//     and DO NOT spend a meter. Re-opening Overview is free.
//   • Else consume_meter BEFORE the model call (trial_ai_locked / no_entitlement
//     → 402; cap_reached → 200 ok:false). On model failure → refund_meter.
//   • If the metering layer isn't installed yet (usage_meters migration pending),
//     consume_meter errors — we DEGRADE to a soft error for the narrative but
//     STILL return the deterministic focus (never a 500). Mirrors how Bucket 1's
//     other AI surfaces stay dormant until metering goes live.
//
// Input  (POST JSON): {}  — uses the authed user.
// Output (JSON): { ok, narrative?, cached?, remaining?, reason?, plan?,
//                  focus_chapter_id?, focus_topic_id?, focus_accuracy? }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { callGemini, GEMINI_API_KEY, pickModel } from "../_shared/gemini.ts";

// Reuse analysis-narrative's meter — do NOT invent a new one (the account coach
// is the same "cheap prose over computed numbers" cost surface).
const METER = "ai_analysis_narrative";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface Focus {
  focus_chapter_id: string | null;
  focus_topic_id: string | null;
  focus_accuracy: number | null;
}
const NO_FOCUS: Focus = {
  focus_chapter_id: null,
  focus_topic_id: null,
  focus_accuracy: null,
};

// Every response carries the deterministic focus so the free "#1 focus →
// Practice" action works regardless of entitlement / metering state.
function json(body: unknown, focus: Focus, status = 200): Response {
  return new Response(JSON.stringify({ ...focus, ...(body as object) }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

interface WeakChapterRow {
  chapter_id: string;
  subject_id: string | null;
  weakness_score: number; // 0–100 mastery (higher = stronger)
  status: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let userId = "";
  let consumed = false; // metered-but-unconfirmed → refunded on model failure
  let db: ReturnType<typeof createClient> | null = null;
  let focus: Focus = NO_FOCUS; // resolved early so error paths still ship it

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
      return json({ ok: false, error: "unauthorized" }, NO_FOCUS, 401);
    }
    userId = userData.user.id;

    db = createClient(supabaseUrl, serviceKey);

    // ── Source signals: latest attempt + the user's chapter-mastery map ───────
    const { data: latestAttempt } = await db
      .from("test_attempts")
      .select("id")
      .eq("user_id", userId)
      .in("status", ["submitted", "analyzed"])
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    const latestAttemptId = (latestAttempt?.id as string | null) ?? "none";

    const { data: weakRowsRaw } = await db
      .from("user_weak_chapters")
      .select("chapter_id, subject_id, weakness_score, status")
      .eq("user_id", userId)
      .order("weakness_score", { ascending: true });
    const weakRows = (weakRowsRaw ?? []) as WeakChapterRow[];

    // ── Deterministic focus = weakest tracked-weak chapter (fallback: weakest
    //    of any). Always computed, always returned. ────────────────────────────
    const focusRow = weakRows.find((w) => w.status === "weak") ?? weakRows[0];
    if (focusRow) {
      // Its weakest topic (best-effort; the practice footer only needs the
      // chapter + accuracy, so a null topic is fine).
      const { data: focusTopic } = await db
        .from("topic_performance")
        .select("topic_id")
        .eq("user_id", userId)
        .eq("chapter_id", focusRow.chapter_id)
        .order("accuracy", { ascending: true })
        .limit(1)
        .maybeSingle();
      focus = {
        focus_chapter_id: focusRow.chapter_id,
        focus_topic_id: (focusTopic?.topic_id as string | null) ?? null,
        focus_accuracy: Number(focusRow.weakness_score),
      };
    }

    // ── source_hash: changes when a new test is taken OR mastery moves ────────
    const masteryFingerprint = weakRows
      .map((w) => `${w.chapter_id}:${Math.round(Number(w.weakness_score))}`)
      .sort()
      .join(",");
    const sourceHash = await sha256Hex(`${latestAttemptId}|${masteryFingerprint}`);

    // ── Cache hit: return the cached narrative WITHOUT metering ───────────────
    const { data: cachedRow } = await db
      .from("account_coach_overview")
      .select("narrative, source_hash")
      .eq("user_id", userId)
      .maybeSingle();
    const cachedNarrative = (cachedRow?.narrative as string | null)?.trim();
    if (cachedNarrative && cachedRow?.source_hash === sourceHash) {
      return json({ ok: true, narrative: cachedNarrative, cached: true }, focus);
    }

    // ── Gate + reserve BEFORE the model call (mirrors analysis-narrative) ─────
    const { data: credit, error: credErr } = await db.rpc("consume_meter", {
      p_user: userId,
      p_meter: METER,
      p_amount: 1,
    });
    if (credErr) {
      // Metering layer not installed yet (usage_meters migration pending) — keep
      // the focus flowing, surface a soft error for the narrative half. NEVER 500.
      console.warn("consume_meter unavailable:", credErr.message);
      return json({ ok: false, reason: "generation_error" }, focus);
    }
    const reason: string | undefined = credit?.reason;
    const plan: string | undefined = credit?.plan;

    if (reason === "trial_ai_locked" || reason === "no_entitlement") {
      return json({ ok: false, reason, plan }, focus, 402);
    }
    if (reason === "cap_reached") {
      return json(
        { ok: false, reason: "cap_reached", plan, remaining: credit?.remaining ?? 0 },
        focus,
      );
    }
    if (!credit?.ok) {
      return json({ ok: false, reason: reason ?? "no_credit", plan }, focus, 402);
    }
    consumed = true;

    if (!GEMINI_API_KEY) {
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: 1 });
      consumed = false;
      return json({ ok: false, reason: "generation_error" }, focus);
    }

    // ── Build a GROUNDED summary from data we already computed ────────────────
    const { data: profile } = await db
      .from("profiles").select("exam_type").eq("id", userId).single();
    const exam = ((profile?.exam_type as string | null) ?? "jee").toUpperCase();

    // Recent score trajectory (last 5 finished tests).
    const { data: history } = await db
      .from("score_history")
      .select("score_percentage, test_name, completed_at")
      .eq("user_id", userId)
      .order("completed_at", { ascending: false })
      .limit(5);

    // Top weak topics (well-sampled, worst first).
    const { data: weakTopicsRaw } = await db
      .from("topic_performance")
      .select("topic_id, subject_id, accuracy, total_questions")
      .eq("user_id", userId)
      .gte("total_questions", 3)
      .order("accuracy", { ascending: true })
      .limit(5);
    const weakTopics = weakTopicsRaw ?? [];

    // Resolve chapter / topic ids to human names so the prose reads naturally.
    const topWeakChapters = weakRows.slice(0, 5);
    const chapterIds = topWeakChapters.map((w) => w.chapter_id);
    const topicIds = (weakTopics as Array<{ topic_id: string }>).map((t) => t.topic_id);
    const [chapterNames, topicNames] = await Promise.all([
      chapterIds.length
        ? db.from("chapters").select("id, name").in("id", chapterIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      topicIds.length
        ? db.from("topics").select("id, name").in("id", topicIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
    ]);
    const chapterName = new Map(
      ((chapterNames.data ?? []) as Array<{ id: string; name: string }>)
        .map((c) => [c.id, c.name]),
    );
    const topicName = new Map(
      ((topicNames.data ?? []) as Array<{ id: string; name: string }>)
        .map((t) => [t.id, t.name]),
    );
    const pct = (n: number | undefined) => Math.round((n ?? 0));

    const summary = {
      recent_test_scores_pct: (history ?? []).map((h) => ({
        test: (h.test_name as string | null) ?? "Test",
        score: pct(Number(h.score_percentage)),
      })),
      weak_chapters: topWeakChapters.map((w) => ({
        name: chapterName.get(w.chapter_id) ?? w.chapter_id,
        mastery_pct: pct(Number(w.weakness_score)),
      })),
      weak_topics: (weakTopics as Array<
        { topic_id: string; accuracy: number }
      >).map((t) => ({
        name: topicName.get(t.topic_id) ?? t.topic_id,
        accuracy_pct: pct(Number(t.accuracy) * 100),
      })),
    };

    const prompt =
`You are an encouraging ${exam} coach speaking to ONE student about their progress SO FAR (across all their tests, not a single one).
Write 2-3 short sentences (max ~55 words) of plain text — no markdown, no bullets, no headings.
Say where they stand and the ONE area to focus on next for the most marks with the least time, naming ONLY chapters/topics from the data.
Be specific, warm and forward-looking; do NOT invent any chapter, topic, number or fact not in the JSON. Do NOT restate every number.

Student's progress (JSON):
${JSON.stringify(summary)}

Return ONLY the paragraph text.`;

    let narrative = "";
    try {
      narrative = (await callGemini(prompt, {
        model: pickModel("narrative"),
        temperature: 0.4,
      })).trim();
    } catch (e) {
      console.error("coach-overview gemini failed:", e);
    }

    if (!narrative) {
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: 1 });
      consumed = false;
      return json({ ok: false, reason: "generation_error" }, focus);
    }

    // ── Cache (narrative + focus + hash) so a re-open doesn't re-bill ─────────
    await db.from("account_coach_overview").upsert({
      user_id: userId,
      narrative,
      focus_chapter_id: focus.focus_chapter_id,
      focus_topic_id: focus.focus_topic_id,
      focus_accuracy: focus.focus_accuracy,
      source_hash: sourceHash,
      generated_at: new Date().toISOString(),
    }, { onConflict: "user_id" });
    consumed = false;

    return json(
      { ok: true, narrative, cached: false, remaining: credit?.remaining ?? null },
      focus,
    );
  } catch (e) {
    if (consumed && db && userId) {
      try {
        await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: 1 });
      } catch (_) { /* noop */ }
    }
    console.error("coach-overview error:", e);
    // Even on an unexpected failure, hand back whatever focus we resolved.
    return json({ ok: false, error: String(e) }, focus, 500);
  }
});
