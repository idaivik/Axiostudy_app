// generate-notes — Bucket 3A · Feature 2 (BILLING_BUCKET3A_BUILD_PROMPT.md §2), Pro-only.
//
// AI-written study notes for ONE topic, pitched at the student's level (their
// accuracy/weakness on it). Copied from analysis-narrative — same metered
// cheap-model shape:
//   • Cache first: a stored study_notes row for (user, topic) is returned WITHOUT
//     metering — re-opening a note never spends a second credit. `regenerate:true`
//     is the explicit user action that overwrites it and spends one ai_note.
//   • Else consume_meter('ai_note') BEFORE the model call:
//       trial_ai_locked / no_entitlement → HTTP 402 (locked / paywall).
//       cap_reached                      → HTTP 200 ok:false (no fallback note).
//       ok                               → generate, cache, return.
//   • On model failure → refund_meter (a flaky model never burns a credit).
//
// The note is GROUNDED in the one topic (not the syllabus) and bounded in length.
//
// Input  (POST JSON): { topic_id, topic_name?, chapter_id?, subject_id?, regenerate? }
// Output (JSON): { ok, note?, level?, cached?, remaining?, reason?, plan? }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { callGemini, GEMINI_API_KEY, pickModel } from "../_shared/gemini.ts";

const METER = "ai_note";

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

interface NoteContent {
  concept: string;
  key_points: string[];
  common_mistakes: string[];
  formulas?: { name: string; tex: string }[];
}

// Mastery → how the note is pitched. Mirrors the strength buckets the analytics
// engine writes; defaults to 'intermediate' when we have no signal for the topic.
function levelFor(strength: string | null, accuracy: number | null): string {
  if (strength === "weak" || (accuracy !== null && accuracy < 0.4)) {
    return "foundational";
  }
  if (strength === "strong" || (accuracy !== null && accuracy >= 0.75)) {
    return "advanced";
  }
  return "intermediate";
}

const LEVEL_GUIDANCE: Record<string, string> = {
  foundational:
    "This student is WEAK here — start from the intuition, keep it simple and " +
    "concrete, and spell out the very first steps. Avoid jargon without defining it.",
  intermediate:
    "This student is OK here — reinforce the core ideas and the few high-yield " +
    "facts, and sharpen exam technique.",
  advanced:
    "This student is STRONG here — skip the basics, focus on subtleties, edge " +
    "cases, and the trickier exam traps.",
};

function clampList(v: unknown, max: number): string[] {
  if (!Array.isArray(v)) return [];
  return v
    .map((x) => (typeof x === "string" ? x.trim() : ""))
    .filter((x) => x.length > 0)
    .slice(0, max);
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
    const topicId: string | undefined = body?.topic_id;
    if (!topicId) return json({ ok: false, error: "topic_id required" }, 400);
    const regenerate = body?.regenerate === true;

    db = createClient(supabaseUrl, serviceKey);

    // ── Cache hit: never re-bill (unless the user explicitly regenerates) ──
    const { data: existing } = await db
      .from("study_notes")
      .select("content, level")
      .eq("user_id", userId)
      .eq("topic_id", topicId)
      .maybeSingle();
    if (existing && !regenerate) {
      return json({
        ok: true,
        note: existing.content,
        level: existing.level,
        cached: true,
      });
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

    // ── Exam track (tone) + this topic's mastery (level pitch) ──
    const { data: profile } = await db
      .from("profiles").select("exam_type").eq("id", userId).single();
    const exam = ((profile?.exam_type as string | null) ?? "jee").toUpperCase();

    const { data: perf } = await db
      .from("topic_performance")
      .select("accuracy, strength, chapter_id, subject_id")
      .eq("user_id", userId)
      .eq("topic_id", topicId)
      .maybeSingle();
    const accuracy = (perf?.accuracy as number | null) ?? null;
    const strength = (perf?.strength as string | null) ?? null;
    const level = levelFor(strength, accuracy);

    // ── Topic label: prefer the client's, else the topics table, else derive ──
    let topicName: string = (body?.topic_name as string | null)?.trim() || "";
    if (!topicName) {
      const { data: t } = await db
        .from("topics").select("name").eq("id", topicId).maybeSingle();
      topicName = (t?.name as string | null) ?? topicId.replaceAll("_", " ");
    }

    const prompt =
`You are an expert ${exam} tutor writing concise revision notes for ONE student on ONE topic.
Topic: "${topicName}".
${LEVEL_GUIDANCE[level]}
Stay strictly on THIS topic — do not drift into the wider syllabus. Be accurate; a wrong fact is worse than a missing one.

Return ONLY JSON with this exact shape (no markdown, no prose outside the JSON):
{
  "concept": "2-3 sentence plain-language explanation of the core idea",
  "key_points": ["3-5 short, high-yield bullet points a student should memorise"],
  "common_mistakes": ["2-4 mistakes ${exam} students typically make on this topic"],
  "formulas": [{"name": "short name", "tex": "LaTeX, no $ delimiters"}]
}
Keep each string under ~160 characters. "formulas" may be an empty array if the topic has none. Include only formulas that genuinely belong to this topic.`;

    let raw = "";
    try {
      raw = await callGemini(prompt, {
        model: pickModel("narrative"),
        temperature: 0.4,
        json: true,
      });
    } catch (e) {
      console.error("generate-notes gemini failed:", e);
    }

    let parsed: NoteContent | null = null;
    try {
      const obj = JSON.parse(raw);
      const concept = typeof obj?.concept === "string" ? obj.concept.trim() : "";
      const keyPoints = clampList(obj?.key_points, 5);
      const mistakes = clampList(obj?.common_mistakes, 4);
      const formulas = Array.isArray(obj?.formulas)
        ? obj.formulas
          .filter((f: unknown) =>
            f && typeof (f as { tex?: unknown }).tex === "string" &&
            typeof (f as { name?: unknown }).name === "string"
          )
          .slice(0, 6)
          .map((f: { name: string; tex: string }) => ({
            name: f.name.trim(),
            tex: f.tex.trim(),
          }))
        : [];
      // A usable note needs at least a concept and one key point.
      if (concept && keyPoints.length > 0) {
        parsed = { concept, key_points: keyPoints, common_mistakes: mistakes, formulas };
      }
    } catch (_) { /* fall through to refund */ }

    if (!parsed) {
      await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: 1 });
      consumed = false;
      return json({ ok: false, reason: "generation_error" }, 200);
    }

    // ── Cache so re-opening the note doesn't re-bill ──
    await db.from("study_notes").upsert({
      user_id: userId,
      topic_id: topicId,
      chapter_id: (body?.chapter_id as string | null) ??
        (perf?.chapter_id as string | null) ?? null,
      subject_id: (body?.subject_id as string | null) ??
        (perf?.subject_id as string | null) ?? null,
      topic_name: topicName,
      level,
      content: parsed,
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,topic_id" });
    consumed = false;

    return json({
      ok: true,
      note: parsed,
      level,
      cached: false,
      remaining: credit?.remaining ?? null,
    });
  } catch (e) {
    if (consumed && db && userId) {
      try {
        await db.rpc("refund_meter", { p_user: userId, p_meter: METER, p_amount: 1 });
      } catch (_) { /* noop */ }
    }
    console.error("generate-notes error:", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
