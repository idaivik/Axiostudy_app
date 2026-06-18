// generate-questions — AI Weakness-Detection Engine, Phase 2 (the ONLY paid path).
//
// Billing keystone surface (BILLING_PRICING_AND_TIERS_PLAN.md §5.3/§5.5/§6).
// Assembly order, designed so the 600/mo Pro cap "feels like thousands" while
// the trial/entitlement gate still applies to the WHOLE surface:
//   1. GATE + RESERVE: consume_meter('ai_questions', count) UP FRONT — before any
//      pool is served — and branch on the RPC's reason:
//        trial_ai_locked / no_entitlement → HTTP 402 (the ONLY two 402 reasons).
//          Served before the pool so a trialing/lapsed user gets NO AI practice,
//          pooled or generated.
//        cap_reached → SOFT fallback: return bank/pool questions, HTTP 200,
//          source:'bank' (no wall — for Basic AND Pro; nothing was reserved).
//        ok → `count` is reserved; continue.
//   2. POOL-FIRST: read bank + active AI pool (chapter/difficulty, excluding seen).
//      Whatever the pool serves is REFUNDED, so pool reuse costs ₹0 and the net
//      meter equals only the genuinely novel questions generated.
//   3. Generate the remaining gap on Gemini 2.5 Flash (correctness-critical),
//      validate, store survivors as `probation` in the SHARED pool, and refund
//      every reserved question we didn't produce.
//
// Input  (POST JSON): { chapter_id, difficulty?: 'easy'|'medium'|'hard', count? }
// Output (JSON): { ok, source: 'pool'|'ai'|'bank', questions: [...Question], reason?, remaining? }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
// Model pick is centralized in _shared/gemini.ts (§2.1). Generation stays on
// GEMINI_MODEL — a wrong answer key is worse than no question (§6). The cheap
// model lives in the same module for the narrative/breakdown/formula surfaces.
import { GEMINI_API_KEY, GEMINI_MODEL } from "../_shared/gemini.ts";

const MAX_COUNT = 5;
const METER = "ai_questions";

// Difficulty → difficulty_level window (matches PracticeRepository.bandForLabel).
const DIFF_BAND: Record<string, [number, number]> = {
  easy: [1, 3],
  medium: [3, 6],
  hard: [6, 8],
};
const DIFF_LEVEL: Record<string, number> = { easy: 2, medium: 5, hard: 7 };

// Columns returned to the client — must match Question.fromJson on both the pool
// read and the post-insert select so 'pool'/'bank'/'ai' rows are interchangeable.
const Q_COLS =
  "id, text, type, options, correct_answer, image_url, subject_id, chapter_id, topic_id, difficulty, explanation";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function shuffle<T>(arr: T[]): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

interface GenQ {
  text?: string;
  options?: string[];
  correct_answer?: string;
  explanation?: string;
  topic_id?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  let userId = "";
  let consumed = 0; // questions metered but not yet confirmed (refunded on failure)
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
    if (userErr || !userData?.user) return json({ ok: false, error: "unauthorized" }, 401);
    userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const chapterId: string | undefined = body?.chapter_id;
    const difficulty: string = ["easy", "medium", "hard"].includes(body?.difficulty)
      ? body.difficulty
      : "medium";
    const count = Math.max(1, Math.min(MAX_COUNT, Number(body?.count) || 3));
    if (!chapterId) return json({ ok: false, error: "chapter_id required" }, 400);

    db = createClient(supabaseUrl, serviceKey);

    // ── 1. Gate + reserve: meter the full request UP FRONT ──
    // This MUST run before any pool is served. trial_ai_locked / no_entitlement
    // block the WHOLE AI surface — a trialing or lapsed user gets no AI practice,
    // pooled OR generated. We reserve `count` here and refund below everything we
    // don't actually generate (pool-served + failed), so the net meter equals the
    // genuinely novel questions and pool reuse stays free.
    const { data: credit, error: credErr } = await db.rpc("consume_meter", {
      p_user: userId,
      p_meter: METER,
      p_amount: count,
    });
    if (credErr) return json({ ok: false, error: "credit check failed" }, 500);
    const reason: string | undefined = credit?.reason;
    const plan: string | undefined = credit?.plan;

    // The ONLY two surviving 402s — no pool is served on these paths.
    if (reason === "trial_ai_locked" || reason === "no_entitlement") {
      return json({ ok: false, reason, plan }, 402);
    }

    // ── 2. Read bank + active AI pool (excludes already-seen) ──
    const seen = await seenQuestionIds(db, userId);
    const [lo, hi] = DIFF_BAND[difficulty];
    const { data: poolData } = await db
      .from("questions")
      .select(Q_COLS)
      .eq("chapter_id", chapterId)
      .eq("status", "active")
      .gte("difficulty_level", lo)
      .lte("difficulty_level", hi)
      .limit(count * 5);
    const pool = shuffle(((poolData ?? []) as { id: string }[]).filter((q) => !seen.has(q.id)));
    const poolPick = pool.slice(0, count);

    // Soft cap → no wall: serve bank/pool at HTTP 200 (cap_reached reserves nothing).
    if (reason === "cap_reached") {
      return json({
        ok: true,
        source: "bank",
        questions: poolPick,
        reason: "cap_reached",
        remaining: credit?.remaining ?? 0,
        count: poolPick.length,
      });
    }
    if (!credit?.ok) {
      // Unexpected non-ok reason: fail closed (nothing was reserved).
      return json({ ok: false, reason: reason ?? "no_credit", plan }, 402);
    }
    consumed = count; // reserved; refunded below for everything we don't generate

    // ── 3. Pool-first: if the pool fills the request, generate nothing ──
    const gap = count - poolPick.length;
    if (gap <= 0 || !GEMINI_API_KEY) {
      // Whole request served from the pool (or generation unavailable) — refund all.
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: consumed });
      consumed = 0;
      return json({ ok: true, source: "pool", questions: poolPick, remaining: null, count: poolPick.length });
    }

    // ── 4. Generation context (only now that we're actually generating) ──
    const { data: chapter } = await db
      .from("chapters")
      .select("id, name, subject_id")
      .eq("id", chapterId)
      .single();
    if (!chapter) {
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: consumed });
      consumed = 0;
      return json({ ok: false, reason: "chapter_not_found" }, 404);
    }
    const { data: topics } = await db
      .from("topics")
      .select("id, name")
      .eq("chapter_id", chapterId);
    const topicList = (topics ?? []) as { id: string; name: string }[];
    const validTopicIds = new Set(topicList.map((t) => t.id));
    const { data: samples } = await db
      .from("questions")
      .select("text, options, correct_answer")
      .eq("chapter_id", chapterId)
      .eq("type", "mcq")
      .limit(3);

    let fallbackTopic = topicList[0]?.id ?? "";
    if (!fallbackTopic) {
      const { data: anyQ } = await db
        .from("questions").select("topic_id").eq("chapter_id", chapterId).limit(1);
      fallbackTopic = (anyQ?.[0]?.topic_id as string) ?? `${chapterId}t1`;
    }

    // ── Generate the gap ──
    const generated = await generate(
      chapter.name as string, difficulty, gap, topicList, (samples ?? []) as GenQ[],
    );
    const valid = generated.filter((q) => isStructurallyValid(q));
    if (valid.length === 0) {
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: consumed });
      consumed = 0;
      // Nothing usable came back, but the free pool may still have some.
      if (poolPick.length > 0) {
        return json({ ok: true, source: "pool", questions: poolPick, remaining: null, count: poolPick.length });
      }
      return json({ ok: false, reason: "generation_empty" }, 200);
    }

    // ── Store survivors as probation in the shared pool ──
    const rows = valid.map((q) => {
      const topicId = q.topic_id && validTopicIds.has(q.topic_id) ? q.topic_id : fallbackTopic;
      return {
        id: `gen_${crypto.randomUUID().slice(0, 12)}`,
        text: q.text!.trim(),
        type: "mcq",
        options: q.options!.map((o) => o.trim()),
        correct_answer: q.correct_answer!.trim(),
        subject_id: chapter.subject_id,
        chapter_id: chapterId,
        topic_id: topicId,
        difficulty,
        difficulty_level: DIFF_LEVEL[difficulty],
        explanation: q.explanation?.trim() ?? null,
        is_ai_generated: true,
        is_verified: false,
        status: "probation",
        generated_by_model: GEMINI_MODEL,
      };
    });

    const { data: inserted, error: insErr } = await db
      .from("questions")
      .insert(rows)
      .select(Q_COLS);
    if (insErr) {
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: consumed });
      consumed = 0;
      return json({ ok: false, error: "insert failed", detail: insErr.message }, 500);
    }

    // Refund the questions we metered but couldn't produce.
    const produced = inserted?.length ?? 0;
    if (produced < consumed) {
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: consumed - produced });
    }
    consumed = 0;

    // Combine the free pool questions with the freshly generated ones.
    const questions = [...poolPick, ...(inserted ?? [])];
    // We reserved `count`; net spend is `produced`, so add back the refund
    // (count - produced) to the remaining the RPC reported after reserving count.
    const remaining = credit?.remaining == null
      ? null
      : (credit.remaining as number) + (count - produced);
    return json({ ok: true, source: "ai", questions, remaining, count: questions.length });
  } catch (e) {
    // Best-effort refund so a crash never burns the student's meter.
    if (consumed > 0 && db && userId) {
      try {
        await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: consumed });
      } catch (_) { /* noop */ }
    }
    console.error("generate-questions error:", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});

/// Question ids the caller has already answered (so we don't re-serve them).
async function seenQuestionIds(
  db: ReturnType<typeof createClient>,
  userId: string,
): Promise<Set<string>> {
  try {
    const { data } = await db
      .from("user_answers")
      .select("question_id, test_attempts!inner(user_id)")
      .eq("test_attempts.user_id", userId)
      .limit(500);
    return new Set(((data ?? []) as { question_id: string }[]).map((r) => r.question_id));
  } catch (_) {
    return new Set<string>();
  }
}

async function generate(
  chapterName: string,
  difficulty: string,
  count: number,
  topics: { id: string; name: string }[],
  samples: GenQ[],
): Promise<GenQ[]> {
  const topicHint = topics.length
    ? `Assign each question a topic_id from this list (use the id, not the name): ${
      JSON.stringify(topics.map((t) => ({ id: t.id, name: t.name })))
    }.`
    : "";
  const styleHint = samples.length
    ? `Match the style/format of these existing questions: ${JSON.stringify(samples)}.`
    : "";
  const prompt =
`Generate ${count} ${difficulty}-difficulty multiple-choice questions for the JEE/NEET chapter "${chapterName}".
Each question must have:
- text: the question stem (self-contained, no images).
- options: an array of EXACTLY 4 distinct option strings.
- correct_answer: the EXACT text of the one correct option (must match one option verbatim).
- explanation: 1-2 sentences explaining the correct answer.
- topic_id: ${topics.length ? "from the list below" : "leave as empty string"}.
${topicHint}
${styleHint}
Use clear, exam-accurate physics/chemistry/maths/biology. Return ONLY JSON of the form:
{"questions":[{"text":"...","options":["..","..","..",".."],"correct_answer":"..","explanation":"..","topic_id":".."}]}`;

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.7, responseMimeType: "application/json" },
    }),
  });
  if (!resp.ok) throw new Error(`gemini ${resp.status}: ${await resp.text()}`);
  const data = await resp.json();
  const text: string =
    data?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("") ?? "";
  const parsed = JSON.parse(text);
  return Array.isArray(parsed?.questions) ? parsed.questions as GenQ[] : [];
}

function isStructurallyValid(q: GenQ): boolean {
  if (!q || typeof q.text !== "string" || q.text.trim().length < 8) return false;
  if (!Array.isArray(q.options) || q.options.length !== 4) return false;
  if (q.options.some((o) => typeof o !== "string" || o.trim().length === 0)) return false;
  // distinct options
  const set = new Set(q.options.map((o) => o.trim().toLowerCase()));
  if (set.size !== 4) return false;
  // exactly one option equals the correct answer
  if (typeof q.correct_answer !== "string" || q.correct_answer.trim().length === 0) return false;
  const matches = q.options.filter(
    (o) => o.trim().toLowerCase() === q.correct_answer!.trim().toLowerCase(),
  );
  return matches.length === 1;
}
