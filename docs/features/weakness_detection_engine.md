# AI Weakness-Detection & Adaptive Practice Engine — Implementation TODO

> Status: **Phases 0–4 implemented** (2026-06-13). Backend live; Flutter side
> compiles clean + tests pass. Remaining polish noted inline (pgvector dedup,
> coverage view, broad probation trickle, per-question `visited_count` capture).
> Interim LLM: **Gemini** (`gemini-2.5-flash`) stands in for Claude Haiku until
> the Anthropic budget lands — the edge function's request/response seam is
> provider-agnostic, so swapping back to Claude is a localized change.
> Goal: turn the current client-side, rule-based weakness detection into a
> server-side, Claude-powered **adaptive practice loop** — every test feeds a
> persistent per-chapter weakness profile, Claude explains the weaknesses and
> prioritises them, and the student is funnelled into targeted practice whose
> difficulty adapts until each weak chapter is mastered.

## Why this wins
We already have the measurement layer (`AnalyticsEngine`, `WeaknessDetector`,
`topic_performance`, `recommendations`, `score_history`). Today it all runs in the
Flutter client with a fixed weighted formula. This feature (a) moves the heavy
analysis server-side so it can use Claude's reasoning over JEE/NEET weightage +
historical trend + error type, and (b) closes the loop into **adaptive practice**
that keeps a student on a weak chapter, ramping difficulty, until `weakness_score`
clears — then auto-promotes the chapter and surfaces the next weakness.

## How the AI fits
Claude runs in exactly **two gated places** — everything else is free SQL / Dart:
- **Insight call (per test):** given per-chapter scores, time patterns, error
  signals and historical trend, Claude returns ranked weak chapters, error-type
  classification, priority topics, and a `recommended_action` string.
- **Question generation (on-demand, paid):** when a student asks for custom
  questions on a weak chapter, Claude generates them. Generated questions are
  **stored back into the shared pool** and reused for level-matched students, so
  one paid generation benefits the whole base.

Default practice ("more questions like this", "next topic") is **retrieval from the
existing question pool via plain SQL — no LLM, zero marginal cost.**

---

## Cost model
- **Baseline:** 1 Claude (Haiku) insight call per submitted test. Retrieval,
  adaptive loop, and push notifications cost $0.
- **On-demand:** generation only — paid + metered through `user_credits`, so AI
  spend scales with revenue, not usage.

## Tiering (no free tier)
| Plan | Price | Receive AI questions (SQL retrieval) | Trigger generation |
| --- | --- | --- | --- |
| Basic | ₹199/mo | unlimited | capped/month via `credits_total` |
| Pro | ₹299/mo | unlimited | effectively unlimited |
| Pro 7-day trial | — | unlimited | Pro-level (metered to deter abuse) |
| `free` / lapsed (DB state) | — | original 2000 questions only | ❌ |

`user_credits` already has `plan` + `credits_total`/`credits_used` + monthly
`resets_at` — Basic's generation cap refills each billing cycle.

---

## Decisions resolved (at kickoff)
- [x] **Compute location:** Hybrid — port analytics to edge functions, keep the
      Dart engine (`AnalyticsEngine`/`WeaknessDetector`/`RecommendationEngine`) as an
      offline/failure fallback. Not a full rip-out.
- [x] **v1 scope:** server analytics + Claude insights · AI question
      retrieval+generation · adaptive loop + Recovery Tracker · simple local push.
- [x] **AI question strategy:** retrieval-first (SQL); generation is the only Claude
      call in the practice path; generated questions re-enter a shared pool.
- [x] **Pool-entry vetting:** usage-feedback-only (no second Claude self-check) +
      a free, code-only structural check + short **probation** to limit blast radius.
- [x] **Tiers:** Basic ₹199 (capped generation) / Pro ₹299 + 7-day trial (full).
- [x] **LLM key:** Anthropic deferred for budget; using a **Gemini** key as a
      server-side Supabase secret (`GEMINI_API_KEY`) for now. Note: on the current
      key `gemini-2.0-flash` reports free-tier `limit: 0`, so the function defaults
      to `gemini-2.5-flash` (override via the `GEMINI_MODEL` secret).
- [ ] **Basic monthly generation cap:** pick a number (e.g. 20/mo).
- [ ] Confirm DB `free` plan = lapsed/pre-subscription users (original questions only).

## Deferred (not in v1)
- Peer-comparison percentile (needs many users; ~2 today).
- `pgvector` embeddings for semantic "similar question" + generation dedup — **fast-follow.**
- Full FCM/Firebase push (only if server-triggered / cross-device is later needed).

---

## Phase 0 — Foundations ✅ DONE (migration `20260613100000_weakness_engine.sql`, applied live)
- [x] LLM API key → Supabase secret (`GEMINI_API_KEY`, server-side only — never in
      the Flutter client; same seam as the roadmap feature). Anthropic later.
- [x] One **additive** migration (touched none of the existing data):
  - [x] `test_attempts`: add `total_correct`, `total_wrong`, `total_unanswered`,
        `time_taken_seconds`
  - [x] `user_answers`: add `visited_count int default 0` (flowchart needs it; not
        captured today)
  - [x] new `chapter_analytics` table — the flowchart's **ANALYTICS** node
        (+ `unanswered_count`, `error_pattern`, and AI columns
        `weakness_reasoning, recommended_action, priority_score`)
  - [x] new `user_weak_chapters` table — the flowchart's **USER_WEAK_TOPICS**
        (chapter-level). `weakness_score` is a 0–100 **mastery** score (higher =
        stronger; status weak<50 / improving / strong>75), so the adaptive loop's
        ">75 → strong" promotion reads naturally.
  - [x] `questions`: add `is_ai_generated`, `is_verified`,
        `status (probation/active/retired)`, `generated_by_model`,
        `times_served`, `times_correct`, `thumbs_up`, `thumbs_down`
        (+ `questions_pool_lookup_idx` for the Phase 2 retrieval hot path)
  - [x] RLS policies for the two new user-owned tables (owner-only; 0 ERROR advisories)

## Phase 1 — Server analytics + AI insights (the core) ✅ DONE
- [x] `compute-analytics` edge function (Deno/TS, deployed v2, JWT-gated): ports
      grading + chapter/time breakdowns from `analytics_engine.dart` + the weighted
      scoring from `weakness_detector.dart`, scoped to the chapter level
- [x] Writes per-chapter rows to `chapter_analytics`; upserts `user_weak_chapters`
      with a blended 0–100 `weakness_score` (0.6 current + 0.4 prior); computes
      `improvement_from_last_test` from the most recent prior chapter row
- [x] Error-pattern classification v1 (silly / conceptual / calculation) — heuristic
      from time + `visited_count` + correctness, refined/overridden by the LLM call
- [x] **One LLM (Gemini 2.5-flash) call** → insight JSON: per-chapter error type,
      `weakness_reasoning`, `recommended_action`, `priority_score`; written back to
      `chapter_analytics`. Degrades gracefully to heuristics if the LLM is down.
- [x] Hybrid wiring: `TestRepository.submitAndAnalyze` runs the local engine (legacy
      tables + offline fallback) **then** invokes the edge function as the additive
      server-side AI layer (`runServerAnalytics`); edge failure never blocks submit
- [x] Dart data layer for the new tables: `ChapterInsight` / `WeakChapter` models,
      repo reads (`getChapterInsightsForAttempt`, `getWeakChapters`,
      `getTopWeakChapters`, `getChapterHistory`) + Riverpod providers
- [x] Results screen surfaces the per-chapter AI insights (`_ChapterInsightsCard`
      — reasoning, recommended_action, error type, priority, trend); the Dart
      `RecommendationEngine` card is now a **fallback** shown only when no AI
      insights exist. Analytics screen gained a **Weak Chapters** card.

## Phase 2 — AI questions: retrieval + generation ✅ DONE
- [x] **Default = retrieval (SQL, free):** `PracticeRepository.retrieveFromPool`
      matches weak `chapter_id` + difficulty band (`difficulty_level`), excludes
      previously-seen IDs (`seenQuestionIds`), serves `active`-pool questions
- [x] **3 post-result options** (`_PostResultActionsCard` on Results):
  - [x] (1) practice weak chapters (adaptive session)
  - [x] (2) more questions like this → **easier / same / harder**, kept within the
        same weak chapter (`moreLikeThis`)
  - [x] (3) custom AI-generate (paid)
- [x] **Custom generate (metered via `user_credits`):** `generate-questions` edge
      function → Gemini → free **structural validation** (exactly one correct
      option, 4 distinct non-empty options, valid stem) → store as `probation` →
      usage stats (`record_question_served`) + thumbs (`record_question_feedback`)
      auto-promote to `active` / auto-retire → re-enters the shared pool. Credit
      is **refunded** if nothing usable comes back (`refund_generation_credit`).
- [x] Probation: a freshly generated question is served straight to its requester
      (returned from the function into the session). *Broad trickle = fast-follow.*
- [x] Wired the "AI-Recommended Practice" button → `buildAdaptiveSession` →
      `/practice/session` runner (was a stub → `/test-selection`)
- [ ] Optional later: "(chapter × difficulty) coverage" view (not started)

## Phase 3 — Adaptive loop + Recovery Tracker ✅ DONE
- [x] `buildAdaptiveSession` pulls top weak chapters from `user_weak_chapters`;
      difficulty band derived from `weakness_score` via `bandForMastery` (easy→hard)
- [x] Post-session re-runs `compute-analytics` (via real `submitAndAnalyze` on
      submit) → blends `weakness_score`, promotes to `strong` at >75; weakest
      chapters resurface in the next adaptive session
- [x] **Recovery Tracker** card on the analytics Overview tab (before → after over
      `chapter_analytics` history, biggest movers first)
- [x] Replaced hardcoded mock lists in `practice_screen.dart` `_TestsTab` with real
      data — **Available Tests** (`testsProvider`) + **Recent Results**
      (`scoreHistoryProvider`, with signed improvement deltas)
- Note: the whole test→submit→analyze loop is now **real** — `TestScreen` creates
  an attempt, tracks per-question time, persists answers, and runs both engines
  (was previously a stub navigating to a hardcoded `/results/attempt_001`).

## Phase 4 — Simple push notification ✅ DONE
- [x] `flutter_local_notifications` + `timezone`: `NotificationService` schedules an
      OS-level 24h reminder when a Results screen shows weak chapters; starting any
      practice session cancels it (`TestScreen._loadTest`). `POST_NOTIFICATIONS`
      added to the Android manifest. All calls are best-effort/guarded.

---

## Features superseded by this engine
- Client-side `AnalyticsEngine` **persistence path** → replaced by edge functions
  (keep a thin trigger + offline fallback).
- `RecommendationEngine` (Dart rules) **as primary** → Claude insights are primary;
  demote to fallback.
- `WeaknessDetector` (Dart) **as primary** → moves server-side; offline fallback only.
- Hardcoded mock lists in `practice_screen.dart` `_TestsTab` → real data.
- (Consistent with in-flight cleanup: `score_trends_card` / `upcoming_tests_card`
  already being removed.)

## Related
- Ties into the AI Coaching Roadmap (`docs/features/ai_coaching_roadmap.md`):
  re-plan triggers fire on each submitted test → new weaknesses feed the roadmap.
- Live chapter IDs are `phys/chem/math/bio` · `ph01..bi20` — use real IDs, not
  `mock_data.dart` (see memory: live-db-ids-differ-from-mock).
