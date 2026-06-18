# Build prompt: Bucket 1 — "finish the half-built" tier features

> **How to use this:** open a fresh chat in this repo and paste:
> *"Read `BILLING_BUCKET1_BUILD_PROMPT.md` and implement the four features in the
> order given. Stop and ask me before anything in the **‼️ Ask first** lists
> (Firebase project, content authoring). Do not change pricing, meters, or the
> tier matrix — those are locked elsewhere."*
>
> The new chat has the whole repo, so this doc points at files instead of
> repeating them. Everything here is **decided** — don't re-litigate the product
> choices, just build them.

---

## 0. Orientation — read these first (already built, do not rebuild)

- **Product source of truth:** [BILLING_PRICING_AND_TIERS_PLAN.md](BILLING_PRICING_AND_TIERS_PLAN.md)
  §4 (feature matrix), §5.4 (meter caps), §6 (model routing). [BILLING_TIER_GATING_PLAN.md](BILLING_TIER_GATING_PLAN.md) §2 (gating architecture).
- **Capability model:** [entitlements.dart](lib/features/subscription/domain/entitlements.dart)
  — the `Feature` enum + `kTierCapabilities` + `UserModel.can()`. The four features
  below already have enum entries: `revisionReminders`, `advancedRevisionPlan`,
  `basicQuestionBreakdown`, `advancedBreakdown`, `aiAnalysisNarrative`, `aiFormulaSheet`.
- **Client gate:** [feature_gate.dart](lib/features/subscription/presentation/feature_gate.dart)
  — wrap gated surfaces in `FeatureGate(feature: …, child: …)`.
- **Metering (server, the keystone):** [20260617120000_usage_meters.sql](supabase/migrations/20260617120000_usage_meters.sql)
  — `consume_meter(p_user, p_meter, p_amount)` and `refund_meter(...)`. Meter rows
  already seeded: `ai_analysis_narrative` (Pro 60), `question_breakdown`
  (Basic 40 / Pro 200), `formula_sheet` (Pro 20), `ai_note` (Pro 60). Reason codes:
  `no_entitlement`, `trial_ai_locked`, `cap_reached`.
- **Edge functions:** [generate-questions](supabase/functions/generate-questions/index.ts),
  [compute-analytics](supabase/functions/compute-analytics/index.ts) — both already
  read `GEMINI_MODEL` from env. The analytics output model is
  [analytics_models.dart](lib/features/analytics/domain/analytics_models.dart)
  (`AttemptAnalyticsResult` already holds weak/strong topics, all breakdowns, timing).
- **Notifications today:** [notification_service.dart](lib/core/notifications/notification_service.dart)
  — **local-only**, one hard-coded rule. Being replaced/extended in Feature 1.

**Migrations:** add new files with the next free timestamp (e.g. `20260618…`). Never
edit a committed migration. **Edge function changes** ship via redeploy.

---

## 1. Locked decisions (from the planning chat — do not change)

1. **Notifications → Firebase Cloud Messaging (server push).** Build **one reminder
   engine**; **channel it by tier** — Basic gets rule-based reminders, Pro gets the
   spaced-repetition variant on the same engine.
2. **Question breakdown stores text *and* an image.** A stored text explanation
   plus a **JPEG** (diagram for the question + worked solution, needed for Physics/
   Chem). Schema must hold an image URL per question.
3. **AI analysis narrative → build it.** Cheap-model paragraph over the existing
   analytics. This also forces wiring the cheap-model route (shared infra).
4. **Formulas → static per-topic formula bank (option c).** A curated `formula_bank`
   table; both the "formulas to learn" widget *and* the Phase-2 formula sheet read
   from it. **No AI extraction of formulas** (a wrong formula is worse than none).

---

## 2. Shared infra to build FIRST (everything below leans on it)

### 2.1 Cheap-model routing (unblocks Features 3, and later notes/tips)
- Add a `GEMINI_CHEAP_MODEL` env var (default `gemini-2.5-flash-lite`) to the edge
  functions, alongside the existing `GEMINI_MODEL`. Keep correctness-critical
  generation on `GEMINI_MODEL`; route narrative/breakdown/formula text to the cheap one.
- Centralize the model pick in one small helper so future surfaces (notes, tips)
  reuse it. See [BILLING_PRICING_AND_TIERS_PLAN.md](BILLING_PRICING_AND_TIERS_PLAN.md) §6.

### 2.2 Trial / entitlement handling in the client (reused by 3 & gated reads)
Any AI surface must handle the three `consume_meter` outcomes the server returns:
`no_entitlement` / `trial_ai_locked` → 402 (show locked "unlocks when your trial
converts"); `cap_reached` → feature-specific; `ok` → render. Build one small client
helper to map these to UI states so each feature isn't re-inventing it.

---

## 3. Feature 1 — Reminder engine on Firebase (one engine, tier-channeled)

**This is the biggest of the four (real external setup). Treat as its own milestone.**

**Goal:** replace the single local nudge with a server-driven reminder engine that
pushes via FCM. Basic = rule-based reminders; Pro = spaced-repetition schedule.

**‼️ Ask first:**
- Firebase project + app registration (need `google-services.json` for Android,
  `GoogleService-Info.plist` + an **APNs auth key** for iOS). Do not create the
  Firebase project without the user.
- Confirm copy/tone and the default frequency cap.

### Data
- `user_devices(user_id, fcm_token, platform, updated_at)` — one row per device;
  upsert on token refresh.
- `notification_prefs(user_id, enabled bool, quiet_start, quiet_end, max_per_day)`
  — defaults: enabled, quiet 22:00–08:00, max 1/day.
- `reminder_schedule(user_id, topic_id, due_at, kind, sent_at)` — the engine writes
  due items here; the sender reads it. `kind` ∈ rule-based kinds + `spaced_rep`.

### Server (the engine)
- **One scheduler** (pg_cron → edge function `send-reminders`, run daily) that, per
  user with `enabled`:
  - reads `topic_performance` (last-attempted dates, weakness), streak data;
  - **Basic** branch: rule-based — decay ("not revised in N days"), weakness ("3 weak
    chapters waiting"), streak nudge;
  - **Pro** branch: same data, **spaced-repetition** scheduling (SM-2-style interval
    curve) → smarter due dates. This is the `advancedRevisionPlan` Pro surface; it
    shares the engine, not a parallel system.
  - branch is chosen by `subscription_tier` (read like `consume_meter` does);
  - respects `notification_prefs` (quiet hours, `max_per_day`), then pushes via the
    **FCM HTTP v1 API** (service-account auth) to the user's `user_devices` tokens.

### Client
- Add `firebase_core` + `firebase_messaging`. Register token on login → upsert
  `user_devices`; refresh on token rotation; clear on logout.
- Keep `flutter_local_notifications` for the immediate on-device nudge (post-test);
  FCM handles the away-from-app reminders.
- Settings screen: toggle + quiet hours (writes `notification_prefs`).
- Permission UX: request at a sensible moment (not cold on launch).

### Acceptance
- Basic user with a stale weak topic gets exactly one rule-based push next run,
  never more than `max_per_day`, never in quiet hours.
- Pro user gets spaced-rep-timed pushes (intervals widen as a topic is mastered).
- Token refresh / logout keeps `user_devices` correct. Disabling prefs silences all.

### Gotchas
- **iOS is the hard part** — APNs key, capabilities, background modes.
- **Spam = death:** if users mute the OS channel you lose it permanently — the
  frequency cap + quiet hours are not optional.
- Time zones (store user tz or schedule in UTC with a per-user offset).
- Don't double-send: mark `reminder_schedule.sent_at`.

---

## 4. Feature 2 — Templated question breakdown (text + image), Basic

**Goal:** on results, tapping a wrong question shows the stored explanation (text **and**
a JPEG diagram) plus templated stats. **No AI — ₹0 to run.** Meter: `question_breakdown`
(Basic 40). Gate: `Feature.basicQuestionBreakdown`.

**‼️ Ask first:** who authors the explanation JPEGs and is there a backlog/pipeline?
The schema lands now; **content authoring is a separate track** — flag coverage gaps.

### Data
- `questions` already has `explanation text?`. **Add `explanation_image_url text?`**
  (new migration). Store the image in a Supabase **Storage bucket**
  `question-explanations` (public-read or signed-URL — confirm with user).
- (If per-question authoring is heavy, allow the image to live at chapter/topic level
  as a fallback — but per-question is the target.)

### Client
- Results screen: wrong-question → breakdown card:
  - correct answer, the stored `explanation` text,
  - the `explanation_image_url` rendered as a **zoomable image** (Physics/Chem
    diagrams), with a graceful empty state when null,
  - templated stat line: "Medium · Rotational Motion · you're at 45% in this topic"
    (pull from `topic_performance` / the attempt analytics).
- Meter the open via `consume_meter('question_breakdown')`; show remaining; on
  `cap_reached`, upsell to Pro (whose cap is 200).

### Acceptance
- Wrong question with an image shows text + zoomable diagram; without an image shows
  text-only cleanly. Basic hits the 40 cap → upsell; Pro (Feature 4) doesn't.

### Gotchas
- `explanation` is **nullable** and image coverage starts at ~0 — the feature is only
  as good as the content backfill. Surface coverage to the user before promising it.
- **Open question (raise to user):** the 40/mo cap is *positioning*, not cost (this is
  free to run). Keep it only if you want the Pro upsell pressure; otherwise drop it.
- Image size/caching — cache locally; keep JPEGs reasonably compressed.

---

## 5. Feature 3 — AI analysis narrative, Pro (the cleanest win)

**Goal:** a 2–3 sentence AI coach paragraph above the existing charts, generated from
the analytics we already compute. Meter: `ai_analysis_narrative` (Pro 60). Gate:
`Feature.aiAnalysisNarrative`.

### Server
- New edge function `analysis-narrative` (or extend `compute-analytics`): input =
  the already-computed `AttemptAnalyticsResult` summary (weak/strong topics, subject/
  difficulty accuracy, timing); call the **cheap model** (§2.1); return a short
  "where to target for max marks / least time" paragraph.
- Gate with `consume_meter(p_user, 'ai_analysis_narrative')` **before** the model
  call. Handle `trial_ai_locked` → 402. On model failure, `refund_meter`.

### Cache (don't re-bill on re-open)
- Add `ai_narrative text` + `ai_narrative_at timestamptz` to the
  `attempt_analytics` row. Generate once per attempt; re-opening reads the cache.

### Client
- Pro-only card above the charts on the results screen, wrapped in
  `FeatureGate(feature: aiAnalysisNarrative)`. Render the locked/trial states from the
  §2.2 helper.

### Acceptance
- Pro sees a relevant paragraph once; re-opening the same result does **not** spend a
  second meter. Basic sees the locked upsell. Trial user sees "unlocks when your trial
  converts". Cost ≈ ₹0.15 × 60 ≈ negligible.

### Gotchas
- The **cheap-model route (§2.1) must exist first** — this feature is the reason to
  build it.
- Prompt must be grounded only in the supplied numbers (no invented topics).

---

## 6. Feature 4 — "Formulas to learn" widget + static formula bank, Pro

**Goal:** for the weak topics / wrong questions in a result, show the formulas the
student should learn, importance-marked, read from a **curated static bank**. Pro
surface; rides on the advanced-breakdown gate (`Feature.advancedBreakdown`). The
bank is also the source for the Phase-2 `aiFormulaSheet` — build it once here.

**‼️ Ask first:** who curates the formula bank content, and the exam scope
(JEE / NEET) for the first pass. Schema + widget land now; **content is a track**.

### Data
- `formula_bank(id, exam, subject_id, chapter_id, topic_id, name, formula_tex,
  importance int, note text?, image_url text?)` — keyed so a topic maps to its
  formulas. `importance` drives the "marked important" ordering. `formula_tex` holds
  LaTeX (render decision below).
- Seed a starter set for a few high-value chapters as a content sample (not the whole
  syllabus — that's the content track).

### Client
- "Formulas to learn" widget on the Pro results/breakdown surface: takes the result's
  weak `topic_id`s → looks up `formula_bank` → lists formulas, important ones first.
- **Math rendering decision (raise to user):** LaTeX needs a render package
  (`flutter_math_fork` or similar). Confirm the dependency, or store pre-rendered
  images in `image_url` and skip the math engine.
- This is a **static lookup → no meter** on the widget itself (₹0). The metered
  `formula_sheet` (20/mo) is the Phase-2 *generated* sheet, not this widget.

### Acceptance
- A Pro result with weak Rotational Motion shows that chapter's formulas, important
  first. Pieces also queryable by the future formula-sheet feature. Basic doesn't see it.

### Gotchas
- **Coverage:** an un-curated topic shows nothing — empty state + don't crash.
- Keep `formula_bank` the **single** formula source (Feature 4 widget *and* P2 sheet)
  so they never disagree.
- Math rendering can be fiddly cross-platform — the `image_url` fallback de-risks it.

---

## 7. Build order & milestones

1. **Shared infra (§2):** cheap-model route + the entitlement/trial client helper.
2. **Feature 3 (narrative):** smallest, proves the cheap-model route end to end.
3. **Feature 2 (breakdown text+image):** schema + storage bucket + results card.
4. **Feature 4 (formula bank + widget):** schema + sample content + widget; reuse the
   breakdown surface from #3.
5. **Feature 1 (Firebase reminders):** its own milestone — most external setup; do it
   last (or in parallel by someone handling the Firebase/APNs side).

Ship 2–4 behind their `FeatureGate`s as soon as each is done; they don't block each other.

## 8. Tests (mirror the existing patterns)
- Extend [test/subscription/entitlements_test.dart](test/subscription/entitlements_test.dart):
  Basic `can(basicQuestionBreakdown)` / Pro `can(aiAnalysisNarrative)` / Pro
  `can(advancedBreakdown)` true; Basic false for the Pro ones.
- Extend [supabase/tests/usage_meters_test.sql](supabase/tests/usage_meters_test.sql):
  `ai_analysis_narrative` blocks Basic (`no_entitlement`), caps Pro at 60, and returns
  `trial_ai_locked` during trial; `question_breakdown` caps Basic at 40 / Pro at 200.
- Narrative caching: second open of the same attempt does not increment the meter.

## 9. Out of scope here (don't build)
- The actual JPEG explanation content and the formula-bank content (separate tracks).
- The Phase-2 *generated* formula sheet, AI notes, time-management tips — later buckets.
- Any pricing / meter-cap / tier-matrix change.
