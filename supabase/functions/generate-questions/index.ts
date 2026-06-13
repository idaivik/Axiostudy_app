// generate-questions — AI Weakness-Detection Engine, Phase 2 (the ONLY paid path).
//
// Generates fresh practice questions for a weak chapter with the LLM, runs a
// free code-only structural check, and stores survivors as `probation` in the
// SHARED question pool so one paid generation benefits every level-matched
// student. Metered through user_credits (consume_generation_credit RPC); the
// credit is refunded if nothing usable comes back.
//
// Default practice is plain SQL retrieval (see PracticeRepository) — zero LLM
// cost. This function only runs on an explicit "generate" request.
//
// Input  (POST JSON): { chapter_id, difficulty?: 'easy'|'medium'|'hard', count? }
// Output (JSON): { ok, questions: [...Question], reason?, remaining? }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const MAX_COUNT = 5;

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

const DIFF_LEVEL: Record<string, number> = { easy: 2, medium: 5, hard: 7 };

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
  let creditConsumed = false;
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
    if (!GEMINI_API_KEY) return json({ ok: false, error: "generation unavailable" }, 503);

    db = createClient(supabaseUrl, serviceKey);

    // ── Meter: spend one generation credit (tiered, race-safe) ──
    const { data: credit, error: credErr } = await db.rpc("consume_generation_credit", {
      p_user: userId,
    });
    if (credErr) return json({ ok: false, error: "credit check failed" }, 500);
    if (!credit?.ok) {
      return json({ ok: false, reason: credit?.reason ?? "no_credit", plan: credit?.plan }, 402);
    }
    creditConsumed = true;
    const remaining = credit?.remaining ?? null;

    // ── Context: chapter, its topics, and a few real questions for style ──
    const { data: chapter } = await db
      .from("chapters")
      .select("id, name, subject_id")
      .eq("id", chapterId)
      .single();
    if (!chapter) {
      await db.rpc("refund_generation_credit", { p_user: userId });
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

    // ── Generate ──
    const generated = await generate(
      chapter.name as string, difficulty, count, topicList, (samples ?? []) as GenQ[],
    );

    // ── Free structural validation ──
    const valid = generated.filter((q) => isStructurallyValid(q));
    if (valid.length === 0) {
      await db.rpc("refund_generation_credit", { p_user: userId });
      return json({ ok: false, reason: "generation_empty" }, 200);
    }

    // ── Insert as probation into the shared pool ──
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
      .select("id, text, type, options, correct_answer, image_url, subject_id, chapter_id, topic_id, difficulty, explanation");
    if (insErr) {
      await db.rpc("refund_generation_credit", { p_user: userId });
      return json({ ok: false, error: "insert failed", detail: insErr.message }, 500);
    }

    return json({ ok: true, questions: inserted, remaining, count: inserted?.length ?? 0 });
  } catch (e) {
    // Best-effort refund so a crash never burns the student's credit.
    if (creditConsumed && db && userId) {
      try { await db.rpc("refund_generation_credit", { p_user: userId }); } catch (_) { /* noop */ }
    }
    console.error("generate-questions error:", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});

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
