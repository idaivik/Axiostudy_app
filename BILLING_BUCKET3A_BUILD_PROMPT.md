# Build prompt: Bucket 3 — Part A — Pro AI coaching artifacts

> **Part 1 of 2** for Bucket 3 (the other is `BILLING_BUCKET3B_BUILD_PROMPT.md` =
> Community). Split so each fits **one implementation session** without hitting the
> message limit. **Commit after each feature** so a session cut-off never loses work.
>
> **How to use this:** open a fresh chat in this repo and paste:
> *"Read `BILLING_BUCKET3A_BUILD_PROMPT.md` and implement the three features in the
> order given, committing after each. Stop and ask me before anything in a
> **‼️ Confirm first** list. Do not change pricing, meters, or the tier matrix."*

This part is three **Pro-only** "coaching artifact" features. They share one pattern,
so build the first carefully and the next two echo it.

---

## 0. Orientation — REUSE these, do not rebuild

- **Metered cheap-model template:** [analysis-narrative/index.ts](supabase/functions/analysis-narrative/index.ts)
  already does exactly the shape every AI feature here needs: `consume_meter` **before**
  the model call, refund on failure, 402 on `trial_ai_locked`, cheap-model route. **Copy
  it** for the new edge functions below.
- **Gate+reserve+refund reference:** [generate-questions/index.ts](supabase/functions/generate-questions/index.ts).
- **Spaced-rep engine already exists:** [send-reminders/index.ts](supabase/functions/send-reminders/index.ts)
  — the tier-channeled reminder engine (Bucket 1 F1). Feature 1 below adds the
  **viewable plan surface** on top of it; it does **not** rebuild the scheduler.
- **Plan-UI pattern:** [lib/features/roadmap/](lib/features/roadmap/) (data/domain/
  presentation) — the AI roadmap. Follow its structure; see the distinction in §1.
- **Meters already seeded** in [20260617120000_usage_meters.sql](supabase/migrations/20260617120000_usage_meters.sql):
  `ai_note` (Pro 60), `formula_sheet` (Pro 20). **No `revision_plan` meter** — Feature 1
  is deterministic/₹0, so it stays unmetered.
- **Capability enum** ([entitlements.dart](lib/features/subscription/domain/entitlements.dart)):
  `advancedRevisionPlan`, `aiNotes`, `aiFormulaSheet` already exist in the Pro set —
  **no enum changes**.
- **Formula source:** the static `formula_bank` table is **Bucket 1 Feature 4**
  ([BILLING_BUCKET1_BUILD_PROMPT.md](BILLING_BUCKET1_BUILD_PROMPT.md) §6). Feature 3
  below READS it. If it doesn't exist yet, build that schema first (cross-ref) — **do
  not** let the model invent formulas.

**Migrations:** next free timestamp (e.g. `20260619…`). Never edit a committed migration.

---

## 1. Feature 1 — Spaced-repetition revision plan (Pro)

**Goal:** an **in-app, viewable** revision schedule — "revise these weak topics today /
this week," spaced on an SM-2-style curve — that the student can open and tick off.
Gate: `Feature.advancedRevisionPlan`. **No meter** (deterministic logic, ₹0).

### ‼️ Keep it distinct from the two things it's NOT (critical — avoids duplication)
- **AI roadmap** ([roadmap/](lib/features/roadmap/)) = a *forward* study plan toward the
  exam date. **Don't touch it.**
- **Reminders** ([send-reminders](supabase/functions/send-reminders/index.ts)) = the
  *push nudges*; the spaced-rep scheduling **already lives here**.
- **This feature** = the *viewable surface + review loop* over that same spaced
  schedule. Reuse the engine's schedule rows; add a screen and a "mark reviewed" action.

### Data
- Reuse the reminder schedule the engine already writes (e.g. `reminder_schedule`
  rows with `kind='spaced_rep'`). If SM-2 state isn't persisted yet, add the per-item
  fields the curve needs: `interval_days`, `ease`, `last_reviewed_at`, `due_at` on a
  `revision_items(user_id, topic_id, …)` table keyed off `topic_performance`.
- Inputs come from `topic_performance` (strength, accuracy, last-attempted).

### Logic & client
- Deterministic **SM-2**: on "mark reviewed," advance the interval (good recall →
  longer gap; lapse → reset). Keep the algorithm in one small, tested Dart/SQL unit.
- A **Revision Plan screen** (Pro-gated): "Due today," "Upcoming," each item → start a
  practice set on that topic; "mark reviewed" advances the curve. Add a home card hook.
- Optional light AI phrasing is **not** worth a meter here — keep copy templated.

### Acceptance
- A weak, stale topic appears in "Due today"; reviewing it pushes its next due date out
  on the curve; a lapse shortens it. Basic sees the locked upsell. Works without network
  (reads local/cached schedule).

### Gotchas
- Don't fork a second scheduler — read the engine's rows.
- SM-2 params need sane defaults; make the interval function pure + unit-tested.
- "Mark reviewed" must persist or the curve resets every open.

---

## 2. Feature 2 — AI notes, paced to the student (Pro, 60/mo)

**Goal:** AI-written study notes for a topic, **pitched at the student's level** (their
accuracy/weakness on it). Meter: `ai_note` (Pro 60). Gate: `Feature.aiNotes`. Net-new
(no existing notes feature).

### Server
- New edge function `generate-notes`, **copied from `analysis-narrative`**: gate
  `consume_meter(p_user, 'ai_note')` **before** the cheap-model call; `trial_ai_locked`
  → 402; refund on model failure.
- Input: `topic_id` + the student's performance on it (depth/level signal). Output:
  structured notes (concept → key points → common mistakes), paced to that level.

### Cache (this is the cost control)
- `study_notes(id, user_id, topic_id, content, level, created_at)`. Generate once and
  **store**; re-opening reads the stored note (no second meter). Regenerating on demand
  is what spends a meter — make that an explicit user action.

### Client
- Entry from a weak topic / topic detail; Pro-gated; locked + trial states from the
  shared helper. Reuse the math/markdown rendering chosen for the formula widget.

### Acceptance
- Generating a note for a weak topic spends one `ai_note`; re-opening it spends none;
  the 61st generation in a month is capped. Basic sees the upsell. Trial → locked.

### Gotchas
- Without the store-and-reuse cache, this re-bills on every open — cache is mandatory.
- Bound the output length (cost + readability). Ground the note in the topic, not the
  whole syllabus.

---

## 3. Feature 3 — AI formula sheet, importance-marked (Pro, 20/mo)

**Goal:** a generated, importance-ordered formula sheet for the student's weak
topics — **assembled from the static `formula_bank`**, with the model only *ordering,
grouping, and annotating* ("when to use"). Meter: `formula_sheet` (Pro 20). Gate:
`Feature.aiFormulaSheet`.

### ‼️ Confirm first
- That `formula_bank` (Bucket 1 F4) exists and has content for the target exam. If
  empty/missing, this feature has nothing to assemble — build/seed the bank first.

### Server
- New edge function `generate-formula-sheet`, again **copied from `analysis-narrative`**:
  gate `consume_meter(p_user, 'formula_sheet')`; read the `formula_bank` rows for the
  student's weak `topic_id`s; pass **only those rows** to the cheap model to order,
  group, mark importance, and add a one-line usage note.
- **Hard rule: the model must NOT invent formulas.** Every formula on the sheet must
  trace to a `formula_bank` row (a wrong formula for a JEE/NEET student is worse than
  none). Prompt + a post-check that output formulas exist in the input set.

### Cache & client
- Store the assembled sheet (`formula_sheets(id, user_id, scope, content, created_at)`);
  re-open reads it (no re-bill). Pro-gated screen; optional share/export.

### Acceptance
- A Pro student with weak Rotational Motion + Thermodynamics gets a sheet built **only**
  from bank rows for those topics, important first; re-open spends no meter; 21st/month
  is capped; Basic upsell; trial locked.

### Gotchas
- Bank coverage gaps → fewer formulas, never invented ones.
- Same math-rendering decision as Bucket 1 F4 (LaTeX engine vs pre-rendered image).

---

## 4. Build order, tests, scope
1. **Feature 1** first — no new AI infra, just reuses the engine + adds a surface.
2. **Feature 2** — establishes the `generate-notes` copy of the narrative template.
3. **Feature 3** — same template; depends on `formula_bank`.
**Commit after each.**

**Tests** (mirror existing): extend
[test/subscription/entitlements_test.dart](test/subscription/entitlements_test.dart)
(Pro can each / Basic cannot); a pure SM-2 interval unit test; a SQL test that `ai_note`
caps Pro at 60 and `formula_sheet` at 20 and both return `trial_ai_locked` during trial;
a `generate-formula-sheet` test asserting **no formula is returned that wasn't in the
bank input**.

**Out of scope:** the `formula_bank` content authoring; any new meter for the revision
plan; pricing/cap/matrix changes; Community (that's Part B).
