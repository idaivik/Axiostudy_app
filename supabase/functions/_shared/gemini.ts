// Shared Gemini model routing for the edge functions
// (BILLING_PRICING_AND_TIERS_PLAN.md §6, BILLING_BUCKET1_BUILD_PROMPT.md §2.1).
//
// ONE place decides which model a surface uses, so every consumer (question
// generation, analytics insight, narrative, future notes/tips/formula sheet)
// routes through the same two constants and the same call helper:
//
//   GEMINI_MODEL        — correctness-critical generation (question stems, answer
//                         keys). A wrong key is worse than no question, so this
//                         stays on the stronger/default model.
//   GEMINI_CHEAP_MODEL  — non-correctness narrative/breakdown/formula TEXT. ~5–6×
//                         cheaper output; used for prose that summarises numbers
//                         we already computed, never for net-new facts.
//
// Both are env-overridable without a redeploy. gemini-2.5-flash is the confirmed
// default on the current key (gemini-2.0-flash reports free-tier limit:0); the
// lite variant is the cheap default.

export const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
export const GEMINI_CHEAP_MODEL =
  Deno.env.get("GEMINI_CHEAP_MODEL") ?? "gemini-2.5-flash-lite";
export const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

/// Which model a surface should use.
///   "generate"  → correctness-critical (GEMINI_MODEL)
///   "narrative" → cheap prose over computed numbers (GEMINI_CHEAP_MODEL)
export type ModelKind = "generate" | "narrative";

/// Single source of truth for the model pick. Future cheap surfaces (notes,
/// time-tips, formula sheet) call this with "narrative" and inherit the route.
export function pickModel(kind: ModelKind): string {
  return kind === "narrative" ? GEMINI_CHEAP_MODEL : GEMINI_MODEL;
}

export interface GeminiOptions {
  /// Model id (use pickModel) — defaults to the cheap model since most shared
  /// callers are narrative/text surfaces.
  model?: string;
  temperature?: number;
  /// Ask Gemini for application/json and return the raw JSON text.
  json?: boolean;
}

/// Call Gemini's generateContent and return the concatenated text parts.
/// Throws on a non-2xx response so callers can refund a reserved meter and fail
/// closed. Mirrors the inline fetch the existing functions already use.
export async function callGemini(
  prompt: string,
  opts: GeminiOptions = {},
): Promise<string> {
  const model = opts.model ?? GEMINI_CHEAP_MODEL;
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": GEMINI_API_KEY,
    },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: opts.temperature ?? 0.3,
        ...(opts.json ? { responseMimeType: "application/json" } : {}),
      },
    }),
  });
  if (!resp.ok) {
    throw new Error(`gemini ${resp.status}: ${await resp.text()}`);
  }
  const data = await resp.json();
  return (
    data?.candidates?.[0]?.content?.parts
      ?.map((p: { text?: string }) => p.text ?? "")
      .join("") ?? ""
  );
}
