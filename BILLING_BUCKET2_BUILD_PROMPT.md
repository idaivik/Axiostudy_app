# Build prompt: Bucket 2 — "small net-new" tier features

> **How to use this:** open a fresh chat in this repo and paste:
> *"Read `BILLING_BUCKET2_BUILD_PROMPT.md` and implement the two features in the
> order given. Stop and ask me before anything in the **‼️ Confirm first** lists.
> Do not change pricing, meters, or the tier matrix — those are locked elsewhere."*
>
> The new chat has the whole repo, so this doc points at files instead of repeating
> them. The product choices here are **recommended defaults** — two forks are flagged
> ‼️; if the user hasn't overridden them, build the default.

---

## 0. Orientation — read these first (already built, do not rebuild)

- **Product source of truth:** [BILLING_PRICING_AND_TIERS_PLAN.md](BILLING_PRICING_AND_TIERS_PLAN.md)
  §4 (matrix) — both features are **Pro-only**, **not metered** (no cost row in §5.4).
- **Capability model:** [entitlements.dart](lib/features/subscription/domain/entitlements.dart)
  — enum entries already exist: `aiTimeTips`, `prioritySupport` (the latter bundles
  *support + feature voting + early access*). Both already in the Pro set; **no enum
  changes needed**.
- **Client gate:** [feature_gate.dart](lib/features/subscription/presentation/feature_gate.dart)
  — `FeatureGate(feature: …, child: …)`.
- **Where surfaces go:**
  - Settings tiles live in [settings_screen.dart](lib/features/profile/presentation/settings_screen.dart)
    (existing `_SettingsTile` pattern: icon / label / subtitle / onTap — copy it).
  - The subscription state / "Pro" surface is the `_SubscriptionSheet` in
    [profile_screen.dart](lib/features/profile/presentation/profile_screen.dart).
- **Timing data already computed:** [analytics_models.dart](lib/features/analytics/domain/analytics_models.dart)
  `AttemptAnalyticsResult` has `avgTimePerQuestion`, `fastestQuestionSeconds`,
  `slowestQuestionSeconds`, per-subject `timeSeconds`, `totalUnanswered`;
  `TopicPerformance` has `avgTimeSeconds`. Feature 1 needs **no new analytics**.
- **AI plumbing:** edge functions share [_shared/gemini.ts](supabase/functions/_shared/gemini.ts);
  the cheap-model route (`GEMINI_CHEAP_MODEL`) is introduced in **Bucket 1 §2.1**
  ([BILLING_BUCKET1_BUILD_PROMPT.md](BILLING_BUCKET1_BUILD_PROMPT.md)).

**Migrations:** add new files with the next free timestamp (e.g. `20260619…`). Never
edit a committed migration.

---

## 1. Locked decisions (recommended defaults — build these unless the user overrode)

1. **Time-management tips are computed, not generated.** Derive them
   **deterministically** from the timing data above (₹0). For the "AI-fused" phrasing,
   **reuse the analysis-narrative call** (Bucket 1 Feature 3) — same cheap-model
   request returns `{narrative, timeTips[]}`. **No new meter.** If the narrative
   feature isn't built yet, ship the deterministic tips with plain phrasing.
2. **Support + voting are in-house** — small Supabase tables + simple screens. **No
   third-party SaaS** (Canny / Intercom) by default: no recurring cost, full control,
   fits the current stage. (Alternative flagged in §3 if the user prefers buy.)
3. **Neither feature is AI-metered.** Both are pure Pro gating via `FeatureGate`.

---

## 2. Feature 1 — AI-fused time-management tips (Pro)

**Goal:** a Pro card on the results screen with 2–4 pacing tips derived from how the
student *spent time*, distinct from the narrative (which covers *what to study*).
Gate: `Feature.aiTimeTips`.

### Keep the boundary with the narrative (avoids double-building)
- **Narrative (Bucket 1 F3):** "where the marks are / what to revise."
- **Time tips (here):** "pacing & speed" only — e.g. *"You spent 2.1 min/question on
  Physics vs ~1.3 ideal,"* *"You rushed Organic (avg 22s) and scored 38% — slow
  down,"* *"8 questions left unanswered — budget the last 20 min,"* *"Accuracy drops
  after Q40 — stamina."*

### How to build
- A small **deterministic** `TimeTipsEngine` (client or in `compute-analytics`) that
  takes `AttemptAnalyticsResult` + `TopicPerformance` and emits a ranked list of tips
  from fixed rules (rushed-but-wrong, slow-but-right, unanswered budget, fade-late).
- **"Ideal time" needs a reference.** Use a small static config of ideal seconds per
  (subject × difficulty) — ‼️ **confirm the reference numbers with the user** (or
  derive from the exam's per-question time budget: JEE 180 min / 75 Q ≈ 144 s; NEET
  180 min / 180 Q ≈ 60 s). Don't invent silently.
- **Phrasing:** if the narrative edge fn exists, extend its cheap-model response to
  also return `timeTips` (one call, one meter — the existing `ai_analysis_narrative`).
  Otherwise render the deterministic strings directly.

### Client
- Pro-only card on the results screen under the narrative, wrapped in
  `FeatureGate(feature: aiTimeTips)`. Reuse the trial/locked states from Bucket 1 §2.2
  **only if** it goes through the AI call; the pure-deterministic path has no 402.

### Acceptance
- A result where the student rushed a weak topic shows a "slow down" tip; one with
  unanswered questions shows a pacing tip. Basic sees the locked upsell. Re-opening
  does **not** spend an extra meter (it rides the cached narrative or is ₹0).

### Gotchas
- **Overlap risk** — if tips start saying "study X," they've drifted into the
  narrative. Keep them strictly about time/pace.
- Don't add a new meter; don't make a second AI call.
- Small samples (few questions) → suppress weak tips rather than over-claim.

---

## 3. Feature 2 — Priority support + feature voting + early access (Pro)

**Goal:** three small Pro perks. **Honest caveat for the user:** these are *promises to
be staffed*, not just code — someone must actually answer priority tickets, triage
votes, and ship early-access builds.

**‼️ Confirm first:**
- **Build vs buy** (default = build in-house). If the user wants Canny/Intercom
  instead, stop — that's a different, SDK-integration build.
- **Operations:** who answers priority support, who triages votes, what "early access"
  actually ships. Don't promise an SLA the user can't keep.

Build the three sub-surfaces in this order (simplest first). Add them as
`_SettingsTile`s in [settings_screen.dart](lib/features/profile/presentation/settings_screen.dart).

### 3a. Priority support
- **Everyone can contact support; Pro gets *priority*.** Don't hard-gate the contact
  form — gate the **priority flag + "Priority" badge + faster-response copy** behind
  `FeatureGate(prioritySupport)`.
- **Data:** `support_tickets(id, user_id, tier, subject, body, status default 'open',
  priority bool, created_at)`. RLS: a user inserts/reads only their own rows.
- **Client:** "Contact support" tile → simple form → insert row with
  `priority = user.can(prioritySupport)`. (Or, even simpler v1: deep-link to a mailto
  with the tier in the subject — confirm with user which they prefer.)
- **Admin v1:** read tickets in the **Supabase dashboard** — no admin UI needed yet.

### 3b. Feature voting
- **Data:** `feature_requests(id, title, description, status default 'open',
  created_at)` and `feature_votes(user_id, request_id, created_at,
  primary key (user_id, request_id))` (one vote per user, idempotent). A view or RPC
  returns each request with its vote count.
- **Client:** a "Feature voting" screen (push route) — list sorted by votes, an
  upvote toggle, optional "suggest a feature" form. **Pro-gated** (`prioritySupport`):
  the perk is that Pro can vote/submit.
- RLS: anyone Pro can read the list + their own votes; insert/delete own votes.

### 3c. Early access
- **Data:** add `early_access bool default false` to `profiles` (opt-in).
- **Client:** an "Early access" toggle tile (Pro-gated) that flips the flag.
  Experimental features check `profiles.early_access` before showing.
- This is mostly a **flag + process** — keep it minimal; it's the hook, not a feature.

### Acceptance
- Basic: can contact support (no priority badge), cannot vote, no early-access toggle.
- Pro: ticket flagged `priority=true` with the badge; can upvote/submit feature
  requests; can opt into early access. All three tiles appear only for Pro.

### Gotchas
- **It's a commitment, not a toggle** — surfacing "priority support" you don't staff
  is worse than not having it. Confirm ops before shipping the copy.
- Vote-count `view`/RPC must be efficient (don't N+1 per row).
- Keep `early_access` a real gate some future feature reads — otherwise it's dead UI.

---

## 4. Build order & dependencies
1. **Feature 2** is fully independent (no Bucket 1 dependency) — can ship first.
2. **Feature 1** ideally lands *after* Bucket 1 Feature 3 (narrative) so it reuses that
   AI call; but it can ship **deterministic-only** now without it.
Both are gated behind their `FeatureGate`s and don't block each other.

## 5. Tests (mirror existing patterns)
- Extend [test/subscription/entitlements_test.dart](test/subscription/entitlements_test.dart):
  Pro `can(aiTimeTips)` and `can(prioritySupport)` true; Basic both false.
- Time tips: a deterministic-rules unit test (rushed-wrong → "slow down"; unanswered →
  pacing tip; tiny sample → suppressed) — no network.
- RLS tests (if the SQL test harness covers it): a user can't read another user's
  `support_tickets`; a second vote by the same user is idempotent.

## 6. Out of scope here (don't build)
- Any admin/staff dashboard (use the Supabase dashboard for v1 tickets/votes).
- Third-party support/voting SaaS unless the user picks "buy" in §3.
- A new AI meter or a second model call for time tips.
- Pricing / meter-cap / tier-matrix changes.
