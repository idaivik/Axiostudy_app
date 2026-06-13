// compute-analytics — AI Weakness-Detection & Adaptive Practice Engine, Phase 1.
//
// Server-side port of analytics_engine.dart + weakness_detector.dart, scoped to
// the CHAPTER level, plus ONE gated LLM "insight" call that ranks weak chapters,
// classifies the error type, and writes a recommended_action per chapter.
//
// Cost model: exactly one LLM call per submitted test. Everything else is SQL.
// The LLM is currently Gemini (cheap) standing in for Claude Haiku until the
// Anthropic key is provisioned — swap GEMINI_* for an Anthropic call later; the
// request/response shape and the rest of the function stay identical.
//
// Auth: caller's JWT identifies the user; DB work uses the service-role client
// but every read/write is constrained to attempts owned by that user.
//
// Input  (POST JSON): { "attempt_id": "attempt_xxxxxxxx" }
// Output (JSON): { ok, ai_used, chapters: [...], weak_chapters: [...] }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// gemini-2.5-flash is the cheap/fast default (confirmed available on this key;
// gemini-2.0-flash reports free-tier limit:0). Override with the GEMINI_MODEL
// secret without redeploying — e.g. point at Claude Haiku's stand-in later.
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const WEAK_THRESHOLD = 50; // score_percentage below this = weak chapter
const STRONG_THRESHOLD = 75; // above this = mastered/strong

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

// ── Shapes ────────────────────────────────────────────────────────────────
interface AnswerRow {
  question_id: string;
  selected_answer: string | null;
  time_taken_seconds: number;
  visited_count: number;
  is_correct: boolean | null;
}
interface QuestionRow {
  id: string;
  chapter_id: string;
  subject_id: string;
  topic_id: string;
  correct_answer: string;
}
interface ChapterStat {
  chapter_id: string;
  subject_id: string;
  chapter_name: string;
  correct: number;
  wrong: number;
  unanswered: number;
  total: number;
  time_total: number;
  // per-question error tallies (wrong answers only)
  silly: number;
  conceptual: number;
  calculation: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // Identify the caller from their JWT.
    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await authClient.auth.getUser();
    if (userErr || !userData?.user) return json({ ok: false, error: "unauthorized" }, 401);
    const userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const attemptId: string | undefined = body?.attempt_id;
    if (!attemptId) return json({ ok: false, error: "attempt_id required" }, 400);

    // Service-role client for the heavy DB work (still scoped to this user).
    const db = createClient(supabaseUrl, serviceKey);

    // ── Load the attempt (and verify ownership) ──
    const { data: attempt, error: aErr } = await db
      .from("test_attempts")
      .select("id, user_id, test_id, start_time, end_time")
      .eq("id", attemptId)
      .single();
    if (aErr || !attempt) return json({ ok: false, error: "attempt not found" }, 404);
    if (attempt.user_id !== userId) return json({ ok: false, error: "forbidden" }, 403);

    // ── Load answers + their questions ──
    const { data: answers } = await db
      .from("user_answers")
      .select("question_id, selected_answer, time_taken_seconds, visited_count, is_correct")
      .eq("attempt_id", attemptId);
    const answerRows = (answers ?? []) as AnswerRow[];
    if (answerRows.length === 0) return json({ ok: false, error: "no answers" }, 422);

    const questionIds = answerRows.map((a) => a.question_id);
    const { data: questions } = await db
      .from("questions")
      .select("id, chapter_id, subject_id, topic_id, correct_answer")
      .in("id", questionIds);
    const qById = new Map<string, QuestionRow>(
      ((questions ?? []) as QuestionRow[]).map((q) => [q.id, q]),
    );

    // ── Grade + per-chapter aggregation + error classification ──
    // Average time across answered questions (for the silly/calculation split).
    const answeredTimes = answerRows
      .filter((a) => a.selected_answer && a.time_taken_seconds > 0)
      .map((a) => a.time_taken_seconds);
    const avgTime = answeredTimes.length
      ? answeredTimes.reduce((s, t) => s + t, 0) / answeredTimes.length
      : 60;

    const chapters = new Map<string, ChapterStat>();
    let totalCorrect = 0, totalWrong = 0, totalUnanswered = 0, totalTime = 0;

    for (const ans of answerRows) {
      const q = qById.get(ans.question_id);
      if (!q) continue;
      const stat = chapters.get(q.chapter_id) ?? {
        chapter_id: q.chapter_id,
        subject_id: q.subject_id,
        chapter_name: q.chapter_id,
        correct: 0, wrong: 0, unanswered: 0, total: 0, time_total: 0,
        silly: 0, conceptual: 0, calculation: 0,
      };
      stat.total++;
      stat.time_total += ans.time_taken_seconds;
      totalTime += ans.time_taken_seconds;

      const answered = !!ans.selected_answer && ans.selected_answer.length > 0;
      const correct = ans.is_correct ??
        (answered &&
          ans.selected_answer!.trim().toLowerCase() ===
            q.correct_answer.trim().toLowerCase());

      if (!answered) {
        stat.unanswered++;
        totalUnanswered++;
      } else if (correct) {
        stat.correct++;
        totalCorrect++;
      } else {
        stat.wrong++;
        totalWrong++;
        // Heuristic error type (refined by the LLM downstream):
        //   fast + wrong       → silly (careless)
        //   slow/engaged + wrong → calculation (knew it, slipped)
        //   otherwise wrong    → conceptual (doesn't know)
        const t = ans.time_taken_seconds;
        if (t > 0 && t < avgTime * 0.5) stat.silly++;
        else if (t > avgTime * 1.5 || ans.visited_count >= 2) stat.calculation++;
        else stat.conceptual++;
      }
      chapters.set(q.chapter_id, stat);
    }

    // Chapter names for nicer copy + the LLM prompt.
    const chapterIds = [...chapters.keys()];
    const { data: chapterRows } = await db
      .from("chapters")
      .select("id, name")
      .in("id", chapterIds);
    for (const c of (chapterRows ?? []) as { id: string; name: string }[]) {
      const s = chapters.get(c.id);
      if (s) s.chapter_name = c.name;
    }

    // Student's exam track (weighting hint for the LLM).
    const { data: profile } = await db
      .from("profiles")
      .select("exam_type")
      .eq("id", userId)
      .single();
    const examType = (profile?.exam_type as string | null) ?? "jee";

    // ── Build per-chapter computed records (pre-AI) ──
    const records = [] as Array<{
      chapter_id: string; subject_id: string; chapter_name: string;
      score: number; correct: number; wrong: number; unanswered: number;
      avg_time: number; error_pattern: string; improvement: number | null;
    }>;

    for (const stat of chapters.values()) {
      const score = stat.total > 0 ? (stat.correct / stat.total) * 100 : 0;
      const avgPerQ = stat.total > 0 ? stat.time_total / stat.total : 0;

      // Dominant heuristic error pattern among wrong answers.
      let errorPattern: string | null = null;
      if (stat.wrong > 0) {
        const pairs: Array<[string, number]> = [
          ["silly", stat.silly],
          ["conceptual", stat.conceptual],
          ["calculation", stat.calculation],
        ];
        pairs.sort((a, b) => b[1] - a[1]);
        errorPattern = pairs[0][1] > 0 ? pairs[0][0] : "conceptual";
      }

      // improvement_from_last_test: most recent prior score for this chapter.
      const { data: prior } = await db
        .from("chapter_analytics")
        .select("score_percentage")
        .eq("user_id", userId)
        .eq("chapter_id", stat.chapter_id)
        .neq("attempt_id", attemptId)
        .order("computed_at", { ascending: false })
        .limit(1);
      const priorScore = prior && prior.length > 0
        ? Number(prior[0].score_percentage)
        : null;
      const improvement = priorScore == null ? null : Math.round((score - priorScore) * 10) / 10;

      records.push({
        chapter_id: stat.chapter_id,
        subject_id: stat.subject_id,
        chapter_name: stat.chapter_name,
        score: Math.round(score * 10) / 10,
        correct: stat.correct,
        wrong: stat.wrong,
        unanswered: stat.unanswered,
        avg_time: Math.round(avgPerQ * 10) / 10,
        error_pattern: errorPattern ?? "none",
        improvement,
      });
    }

    // ── The one LLM call: insight enrichment ──
    let aiUsed = false;
    let aiByChapter = new Map<string, {
      error_type?: string; weakness_reasoning?: string;
      recommended_action?: string; priority_score?: number;
    }>();
    if (GEMINI_API_KEY) {
      try {
        aiByChapter = await fetchInsights(examType, records);
        aiUsed = aiByChapter.size > 0;
      } catch (e) {
        console.error("gemini insight failed:", e);
      }
    }

    // ── Persist: chapter_analytics (upsert) + user_weak_chapters (blend) ──
    const computedAt = new Date().toISOString();
    const outChapters = [] as unknown[];

    for (const r of records) {
      const ai = aiByChapter.get(r.chapter_id);
      const isWeak = r.score < WEAK_THRESHOLD;
      const isStrong = r.score > STRONG_THRESHOLD;
      const recommended = ai?.recommended_action ?? fallbackAction(r, isWeak);

      await db.from("chapter_analytics").upsert({
        user_id: userId,
        attempt_id: attemptId,
        chapter_id: r.chapter_id,
        subject_id: r.subject_id,
        score_percentage: r.score,
        correct_count: r.correct,
        wrong_count: r.wrong,
        unanswered_count: r.unanswered,
        avg_time_per_question: r.avg_time,
        is_weak: isWeak,
        is_strong: isStrong,
        improvement_from_last_test: r.improvement,
        error_pattern: ai?.error_type ?? (r.error_pattern === "none" ? null : r.error_pattern),
        weakness_reasoning: ai?.weakness_reasoning ?? null,
        recommended_action: recommended,
        priority_score: ai?.priority_score ?? (isWeak ? Math.round(WEAK_THRESHOLD - r.score) + 50 : 0),
        computed_at: computedAt,
      }, { onConflict: "attempt_id,chapter_id" });

      // Blend into the persistent mastery score.
      const { data: existing } = await db
        .from("user_weak_chapters")
        .select("weakness_score, attempts_count")
        .eq("user_id", userId)
        .eq("chapter_id", r.chapter_id)
        .maybeSingle();

      const prevScore = existing ? Number(existing.weakness_score) : null;
      const prevCount = existing ? Number(existing.attempts_count) : 0;
      const blended = prevScore == null
        ? r.score
        : Math.round((r.score * 0.6 + prevScore * 0.4) * 10) / 10;
      const status = blended < WEAK_THRESHOLD
        ? "weak"
        : blended > STRONG_THRESHOLD
        ? "strong"
        : "improving";

      await db.from("user_weak_chapters").upsert({
        user_id: userId,
        chapter_id: r.chapter_id,
        subject_id: r.subject_id,
        weakness_score: blended,
        attempts_count: prevCount + 1,
        status,
        last_updated: computedAt,
      }, { onConflict: "user_id,chapter_id" });

      outChapters.push({
        chapter_id: r.chapter_id,
        chapter_name: r.chapter_name,
        subject_id: r.subject_id,
        score_percentage: r.score,
        is_weak: isWeak,
        is_strong: isStrong,
        improvement_from_last_test: r.improvement,
        error_pattern: ai?.error_type ?? (r.error_pattern === "none" ? null : r.error_pattern),
        weakness_reasoning: ai?.weakness_reasoning ?? null,
        recommended_action: recommended,
        priority_score: ai?.priority_score ?? (isWeak ? Math.round(WEAK_THRESHOLD - r.score) + 50 : 0),
      });
    }

    // ── Cache the grade summary back onto the attempt ──
    const startMs = attempt.start_time ? Date.parse(attempt.start_time) : 0;
    const endMs = attempt.end_time ? Date.parse(attempt.end_time) : 0;
    const elapsed = startMs && endMs ? Math.round((endMs - startMs) / 1000) : totalTime;
    await db.from("test_attempts").update({
      total_correct: totalCorrect,
      total_wrong: totalWrong,
      total_unanswered: totalUnanswered,
      time_taken_seconds: elapsed,
    }).eq("id", attemptId);

    const weakChapters = (outChapters as Array<{ is_weak: boolean }>)
      .filter((c) => c.is_weak);

    return json({ ok: true, ai_used: aiUsed, chapters: outChapters, weak_chapters: weakChapters });
  } catch (e) {
    console.error("compute-analytics error:", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});

// ── LLM insight call ────────────────────────────────────────────────────────
async function fetchInsights(
  examType: string,
  records: Array<{
    chapter_id: string; chapter_name: string; subject_id: string;
    score: number; correct: number; wrong: number; unanswered: number;
    avg_time: number; error_pattern: string; improvement: number | null;
  }>,
): Promise<Map<string, {
  error_type?: string; weakness_reasoning?: string;
  recommended_action?: string; priority_score?: number;
}>> {
  const exam = examType.toUpperCase();
  const prompt =
`You are an expert ${exam} coach analysing one student's test. For each chapter below decide:
- error_type: one of "silly", "conceptual", "calculation", "mixed", or "none" (none = no notable errors).
- weakness_reasoning: ONE short sentence (max ~18 words) on why this chapter is weak/strong, grounded in the numbers.
- recommended_action: ONE short, concrete next step for the student.
- priority_score: integer 0-100 = how urgently to drill this chapter, weighing ${exam} weightage, the score, and the trend (improvement_from_last_test). Higher = more urgent. Strong chapters near 0.

Rank weak chapters so the highest-weightage, lowest-score ones get the highest priority_score.

Chapters (JSON):
${JSON.stringify(records.map((r) => ({
    chapter_id: r.chapter_id,
    chapter_name: r.chapter_name,
    subject_id: r.subject_id,
    score_percentage: r.score,
    correct: r.correct,
    wrong: r.wrong,
    unanswered: r.unanswered,
    avg_time_per_question_sec: r.avg_time,
    heuristic_error_pattern: r.error_pattern,
    improvement_from_last_test: r.improvement,
  })))}

Return ONLY JSON of the form:
{"chapters":[{"chapter_id":"...","error_type":"...","weakness_reasoning":"...","recommended_action":"...","priority_score":0}]}`;

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.3, responseMimeType: "application/json" },
    }),
  });
  if (!resp.ok) {
    throw new Error(`gemini ${resp.status}: ${await resp.text()}`);
  }
  const data = await resp.json();
  const text: string =
    data?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("") ?? "";
  const parsed = JSON.parse(text);
  const map = new Map<string, {
    error_type?: string; weakness_reasoning?: string;
    recommended_action?: string; priority_score?: number;
  }>();
  for (const c of (parsed?.chapters ?? [])) {
    if (!c?.chapter_id) continue;
    map.set(c.chapter_id, {
      error_type: c.error_type,
      weakness_reasoning: c.weakness_reasoning,
      recommended_action: c.recommended_action,
      priority_score: typeof c.priority_score === "number"
        ? Math.max(0, Math.min(100, Math.round(c.priority_score)))
        : undefined,
    });
  }
  return map;
}

function fallbackAction(
  r: { chapter_name: string; score: number; error_pattern: string },
  isWeak: boolean,
): string {
  if (!isWeak) return `Keep ${r.chapter_name} sharp with a quick mixed set.`;
  switch (r.error_pattern) {
    case "silly":
      return `Slow down on ${r.chapter_name} — re-read each question; your errors look careless.`;
    case "calculation":
      return `Drill timed numericals in ${r.chapter_name} to cut calculation slips.`;
    default:
      return `Relearn the core concepts of ${r.chapter_name}, then practise easy→medium questions.`;
  }
}
