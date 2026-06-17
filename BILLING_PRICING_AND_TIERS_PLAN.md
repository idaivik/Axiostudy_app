# Plan: Pricing, Packaging & Tier Features (implementation spec)

> Status: **DECIDED — ready to implement in a fresh chat.** This is the filled-in
> answer to [BILLING_TIER_GATING_PLAN.md](BILLING_TIER_GATING_PLAN.md) §4 (feature
> matrix) and §6 (open decisions). Read that doc first for the **gating
> architecture** (`entitlements.dart`, `FeatureGate`, server enforcement,
> upgrade-mode paywall) — this doc does not repeat it; it supplies the pricing,
> the per-tier feature assignment, the metering caps, the AI-model routing, and
> the build phasing.
>
> Currency assumption throughout: **₹84 / USD**. Net-revenue figures strip a
> **15% store cut** (one platform per user — Apple Small Business / Google Play
> sub rate) and **18% GST** (the conservative "GST is not yours" case).

---

## 1. The decision in one paragraph

Two tiers — **Basic ₹199/mo** (diagnosis: charts + light, capped AI), **Pro ₹399/mo**
(prescription + treatment: AI interpretation, generation, and the net-new AI
artifacts). **No free tier** — acquisition runs through a **7-day trial on the annual
plans, with AI hard-locked until the trial converts** (anti-abuse: nobody burns 600 AI
questions then cancels). The product story is a **diagnosis → prescription ladder**:
Basic shows you *where* you're weak, Pro tells you *what to do* and *does it for you*.
Annual front-loads a year of cash and kills churn. High profit comes from four levers,
in order of impact: **(1) push annual, (2) keep Basic's AI light + capped, (3) cap Pro
generation at 600 questions/mo with a silent bank fallback, (4) route low-stakes AI to
a cheap model.** Basic clears ~73% margin and Pro monthly ~77%; the annuals
(Basic ₹2,199 / Pro ₹4,399, ~8% off 12×) hold **~71% / ~75%**.

---

## 2. Pricing & packaging

| Tier | Monthly | Annual | Annual = /mo | Net/mo (monthly) | Net/mo (annual) |
| --- | --- | --- | --- | --- | --- |
| **Basic** | ₹199 | **₹2,199** (~8% off 12×) | ₹183 | ₹143 | ₹132 |
| **Pro** | ₹399 | **₹4,399** (~8% off 12×) | ₹367 | ₹287 | ₹264 |

Annual carries the **exact same features and limits as monthly** (your decision —
billing period never changes capabilities; see §4). Net = `gross × 0.85 / 1.18`
(15% store cut + 18% GST).

> ✅ **Annual contribution now healthy and well-ordered** (net − AI at capped max usage):
> - **Basic annual (₹2,199):** net ₹1,584 − AI ₹456 = **₹1,128/yr**
> - **Pro annual (₹4,399):** net ₹3,169 − AI ₹780 = **₹2,389/yr**
>
> Pro annual now contributes **₹1,261/yr more** than Basic annual — the earlier
> inversion (where Pro annual trailed Basic) is fixed. Both annuals are modest **~8%
> discounts** off 12×monthly, so annual's pull is commitment-lock plus a light saving,
> not a deep "hero" discount; if you want annual to *drive conversion*, discount harder.

- **7-day trial:** annual plans only, **AI hard-locked** for the 7 days, then
  auto-converts to the locked year (AI unlocks on conversion). Monthly has no trial.
- **No free tier.** The trial is the *only* try-before-buy now — and it auto-charges a
  full year on day 8. ⚠️ With free gone, consider also offering the trial on monthly
  (or a short genuinely-free taste) or top-of-funnel friction will rise.

---

## 3. Store products & RevenueCat entitlements

Replaces the 2-product setup. **Product IDs are permanent — reconcile against what
already exists in Play Console / App Store Connect before creating.**

| Product ID | Price | RevenueCat package | Entitlement |
| --- | --- | --- | --- |
| `axio_basic_monthly` | ₹199 | monthly | `basic` |
| `axio_basic_yearly` | ₹2,199 | annual | `basic` |
| `axio_pro_monthly` | ₹399 | monthly | `pro` |
| `axio_pro_yearly` | ₹4,399 | annual | `pro` |

- **Retire `axio_premium_monthly` (₹299).** Wrong on both id and price now. Its
  comment is hard-coded in [20260614140000_native_billing.sql](supabase/migrations/20260614140000_native_billing.sql)
  (`store_product_id` example) and the webhook tier mapping (`*premium*` → premium).
  Remap `*premium*` → `pro` in the webhook and update [BILLING_GO_LIVE.md](BILLING_GO_LIVE.md) §1.
- Entitlements are **tier-level** (`basic` / `pro`), independent of billing period —
  gating never inspects monthly-vs-annual.
- Paywall needs a **monthly/annual toggle** with annual pre-selected and "Save X%"
  badge (annual is the hero). Files: [paywall_screen.dart](lib/features/subscription/presentation/paywall_screen.dart),
  [payment_models.dart](lib/features/subscription/domain/payment_models.dart).

---

## 4. Feature matrix (fills BILLING_TIER_GATING_PLAN.md §4)

✅ = included · ❌ = locked (→ upsell) · number = monthly metered cap · **bold caps =
cost-bearing, server-enforced**. **Annual = identical to monthly** (same features, same
caps). During the **7-day trial**, every AI row (✅ or number) is **hard-locked** with
an "unlocks when your trial converts" state — only the non-AI rows are live.

| Capability | Basic ₹199 | Pro ₹399 | Built? |
| --- | :---: | :---: | :---: |
| Diagnostic test (from bank) | ✅ unlimited | ✅ | ✅ built |
| Adaptive tests from question bank | ✅ unlimited | ✅ | ✅ built |
| **Basic analysis — ALL charts** (mistakes, strength meter, spider grid, weak topics, score trend, speed-vs-accuracy) | ✅ **full** | ✅ | ✅ built |
| Community | ✅ | ✅ | ❌ **build** |
| Basic roadmap (NOT coaching-synced) | **2/mo** | — | ✅ built |
| Revision reminders (rule-based notifications) | ✅ | — | ⚠️ partial |
| Limited AI test gen | 1 small/wk · 1 mock/mo · 1 practice/mo | — | ✅ built |
| Personalized practice (from bank) | ✅ | ✅ | ✅ built |
| Basic question breakdown (templated) | **40/mo** | — | ⚠️ partial |
| AI-generated adaptive questions | ❌ | ✅ | ✅ built |
| **Full AI practice sessions** | ❌ | ✅ **600 Q/mo (soft → bank)** | ✅ built |
| AI narrative on analysis (how to avoid mistakes, where to target for max marks / min time) | ❌ | ✅ **60/mo** | ⚠️ engine built, narrative new |
| AI roadmaps (best-for-you + coaching-synced) | ❌ | ✅ **8/mo** | ✅ built |
| Advanced breakdown + "formulas to learn" widget | ❌ | ✅ **200/mo** | ⚠️ build widget |
| AI-fused time-management tips | ❌ | ✅ | ❌ **build** |
| Priority support + feature voting + early access | ❌ | ✅ | ❌ **build** |
| Advanced spaced-repetition revision plan | ❌ | ✅ | ❌ **PHASE 2** |
| AI notes (paced to student) | ❌ | ✅ **60/mo** | ❌ **PHASE 2** |
| AI formula sheet (importance-marked) | ❌ | ✅ **20/mo** | ❌ **PHASE 2** |

**Two deliberate edits to the original feature list:**
- "1:1 developer access" → reframed as **priority support + feature voting + early
  access** (scalable, not shareable, ties to the Phase-2 rollout).
- Nothing is "unlimited." **Full AI practice = 600/mo soft cap** (see §5).

**The price-justification line:** Basic *sees* the data (charts cost ₹0 to render);
Pro gets the AI coach that *interprets* it, *generates* the practice, and (Phase 2)
*writes* the notes / formula sheet / revision plan.

---

## 5. Metering & caps (the margin engine)

### 5.1 Two cost centers, not one
- **Flash question-generation** (the only thing that must stay on the accurate model
  for correctness): ₹0.108 per generated question. This is the **600/mo Pro cap**.
- **Cheap-model everything-else** (notes, narrative, breakdowns, formula sheets,
  roadmaps, tips): routed to Flash-Lite / GPT-4o-mini, ~₹20–25/mo total even at
  generous caps.

### 5.2 The "Full AI practice" cap — 600 questions/mo, SOFT
- Session size: **15 Q (~15 min) or 30 Q (~30 min)**, student picks.
- Limit: **600 net-new AI-generated questions / month** — market as *"a fresh
  adaptive session every day."*
- **Soft cap, not a hard block.** On reaching 600, do **not** lock the user out —
  fall back silently to **adaptive practice from the question bank** (unlimited, ₹0).
  The student never hits a wall; they just stop getting *net-new* AI questions.
- Cost at cap: ~₹65/mo on Flash → ~77% Pro margin.

### 5.3 The question-pool optimization (makes 600 feel like thousands)
Cache every generated question into a **shared pool keyed by (subject, chapter,
topic, difficulty, exam)**. A "projectile motion / medium / JEE" question generated
for one student serves hundreds. Most of what *feels* like AI practice is served from
the growing pool at ₹0; the 600 cap only meters genuinely **novel** generation. Effective
per-Pro cost drifts *down* over time. Mocks and adaptive sessions assemble from
bank + pool first, dipping into the generation budget only to fill gaps.

### 5.4 Per-meter caps (server-enforced)

Caps are **identical for monthly and annual**. During the 7-day trial all `ai_*` meters
are **hard-locked** (RPC returns `trial_ai_locked`; see §5.5).

| meter_key | Basic | Pro | Model | ≈ unit cost |
| --- | :---: | :---: | --- | --- |
| `ai_questions` (net-new gen; practice + mock gap-fill) | small/mock/practice limits below | **600/mo soft→bank** | Flash | ₹0.108/Q |
| `ai_small_test` | 4/mo (1/wk, 15 Q) | (draws from 600) | Flash/pool | ₹1.6 |
| `ai_full_mock` | 1/mo | 8/mo (bank+pool) | bank/pool | ~₹0–19 |
| `ai_practice` | 1/mo (45 Q) | (draws from 600) | Flash/pool | ₹4.9 |
| `ai_roadmap` | 2/mo | 8/mo | Flash-Lite | ₹1.1 |
| `ai_analysis_narrative` | ❌ (charts only) | 60/mo | Flash-Lite / 4o-mini | ~₹0.15 |
| `question_breakdown` | 40/mo | 200/mo | Flash-Lite / 4o-mini | ~₹0.05 |
| `ai_note` *(P2)* | ❌ | 60/mo | Flash-Lite | ~₹0.15 |
| `formula_sheet` *(P2)* | ❌ | 20/mo | Flash-Lite | ~₹0.10 |
| `revision_plan` | rule-based (₹0) | spaced-rep *(P2)* | logic + light AI | ~₹0 |

**Full-mock spec (pinned, verified against current exam patterns):** JEE Main =
**75 Q / 300 marks / 180 min**; NEET = **180 Q / 720 marks / 180 min** (the 200-item
pool with internal choice scores 180; 2025 reverted toward 180 compulsory). Assembled
bank+pool first; worst-case all-generated cost ≈ NEET 180×₹0.108 = ₹19.4, JEE
75×₹0.108 = ₹8.1. Was "90 Q JEE / ~180–200 NEET" — both corrected.

### 5.5 Schema change required (the keystone — §9 step 5)
The current RPC ([20260613110000_question_generation.sql](supabase/migrations/20260613110000_question_generation.sql))
has **one** credit pool and treats `pro`/`premium`/`professional` as **unlimited**
(`return ... 'remaining', null` without checking a cap). This is the **single most
important code change** and must become:

1. **Generalize to per-meter buckets.** Either add named counters or (cleaner) a
   `usage_meters(user_id, meter_key, used, limit_total, resets_at)` table with a new
   RPC `consume_meter(p_user, p_meter, p_amount default 1)` that lazily seeds the row
   from the tier→meter→limit config, resets monthly via `resets_at`, enforces the cap,
   increments atomically (`for update`), and returns `{ok, remaining, plan, reason}`.
   Keep `refund_generation_credit`'s pattern as `refund_meter(p_user, p_meter)`.
2. **Tiers are `basic` / `pro` only.** Drop the `premium` / `professional` branches
   (consolidated to `pro`). `free` is **no longer a sold tier** — it survives only as
   the internal "no active entitlement" sentinel and must block every `ai_*` meter.
3. **Cap Pro (soft).** `pro` enforces the `ai_questions` soft limit of 600 instead of
   `remaining: null`. On exhaustion the RPC returns `ok:false, reason:'cap_reached'`,
   and [generate-questions/index.ts](supabase/functions/generate-questions/index.ts)
   **returns bank questions** (HTTP 200, `source:'bank'`) — *not* a 402. This is a
   behavior change, not just a number: the wall disappears for Pro.
4. **Trial AI lock (hard, NOT soft).** When the caller is inside the 7-day trial, the
   RPC reads trial status and returns `ok:false, reason:'trial_ai_locked'` for every
   `ai_*` meter. Unlike the Pro soft-cap, the edge function does **not** fall back to
   bank — it returns a **402** (`reason:'trial_ai_locked'`) so the client renders the
   locked "unlocks when your trial converts" state.
5. **What 402 now means.** With no free tier, the 402/403 path survives for exactly two
   cases: `trial_ai_locked` (above) and `no_entitlement` (lapsed / never-subscribed).
   Every *paid, active* tier either succeeds or soft-falls-back to bank at 200.

---

## 6. AI model routing

| Surface | Model | Why |
| --- | --- | --- |
| Question generation + answer keys | **Gemini 2.5 Flash** (current) | Correctness is non-negotiable; a wrong key is worse than no question. Small share of tokens. |
| Notes, formula sheets, analysis narrative, breakdowns, time tips, roadmaps | **Gemini 2.5 Flash-Lite or GPT-4o-mini** | ~80% of output volume; forgiving content; ~5–6× cheaper output. |
| (Optional) answer-key verification pass | Claude Haiku 4.5 | Only if accuracy complaints surface — verify generated keys, don't generate with it. |

Edge functions already read `GEMINI_MODEL` from env ([generate-questions](supabase/functions/generate-questions/index.ts),
[compute-analytics](supabase/functions/compute-analytics/index.ts)). Add a second
env/model constant (`GEMINI_CHEAP_MODEL` or an OpenAI key) and route per surface.
This drops heavy-Pro AI cost from ~₹153 → ~₹50–70/mo.

---

## 7. Profit model

Per-user monthly contribution (net revenue − AI cost at capped max usage), with
routing + caps:

| | Net/mo | AI cost/mo | Margin |
| --- | --- | --- | --- |
| Basic monthly (max usage) | ₹143 | ~₹38 | **~73%** |
| Basic annual (₹2,199) | ₹132 | ~₹38 | ~71% |
| Pro monthly (heavy, capped+routed) | ₹287 | ~₹65 | **~77%** |
| Pro annual (₹4,399) | ₹264 | ~₹65 | ~75% |
| Pro **uncapped, no routing** | ₹287 | ~₹320 | **negative** ← what §5 prevents |

Both annuals are modest **~8% discounts** off 12×monthly, so they hold healthy margins
(Basic ~71%, Pro ~75%) while still **locking a year** that beats a monthly Pro who
churns in 2–3 months (~₹556 lifetime contribution). Pro annual contributes ₹2,389/yr vs
Basic annual ₹1,128/yr — a clean, well-ordered ladder. Biggest profit lever is **mix**
(annual share × Pro share). Trade-off: at only ~8% off, annual saves the buyer little,
so it leans on lock/convenience to convert — model a blended margin at a target mix
(e.g. 75% Basic / 25% Pro, 50% annual) before launch.

---

## 8. Build phasing (so you can charge ₹399 on day one)

**Phase 1 — launch (all already built, just gate + cap):**
adaptive tests, full basic analysis (charts), AI question gen, full AI practice
(600 cap + bank fallback), AI roadmaps, basic roadmap, advanced breakdown.
Plus the gating plumbing (§9). Market the Phase-2 items as *"included, rolling out."*

**Phase 2 — retention hooks (build after launch, months 2–3):**
spaced-repetition revision plan, AI notes, AI formula sheet + "formulas to learn"
widget, community, AI-fused time tips, priority-support/feature-voting surface.
These are the churn-reducers that arrive right when monthly subscribers tend to drop.

---

## 9. Implementation order & change list (for the next chat)

Builds on BILLING_TIER_GATING_PLAN.md §5. Concrete file pointers:

1. **Consolidate `SubscriptionTier`** — [enums.dart:174](lib/shared/models/enums.dart)
   `{free, basic, premium, professional}` → `{free, basic, pro}`, where **`free` is
   the internal "no active entitlement → paywall" sentinel only — not a sold tier**
   (no free features). Update labels and every `case`. Rename `premium`→`pro` in the
   webhook tier mapping ([revenuecat-webhook](supabase/functions/revenuecat-webhook/))
   and drop `professional`.
2. **Store products + RevenueCat** — create the 4 products in §3; add `basic`/`pro`
   entitlements; wire [revenuecat.dart](lib/core/billing/revenuecat.dart); update
   [BILLING_GO_LIVE.md](BILLING_GO_LIVE.md) §1.
3. **`entitlements.dart`** — `Feature` enum + `kTierCapabilities` map from §4 +
   `UserModel.can()` (per BILLING_TIER_GATING_PLAN.md §2a). ANDs in `hasActiveAccess`.
4. **`FeatureGate` widget** + upgrade-mode paywall entry (BILLING_TIER_GATING_PLAN.md §2b/§2d);
   monthly/annual toggle on the paywall.
5. **Metering rewrite (keystone)** — `usage_meters` table + `consume_meter` /
   `refund_meter` RPCs replacing the single-pool `consume_generation_credit` (§5.5).
   Seed limits from the §5.4 table; add the **trial AI lock** + **Pro 600 soft-cap**
   branches; drop `premium`/`professional`.
6. **Server enforcement** — [generate-questions](supabase/functions/generate-questions/index.ts):
   call `consume_meter('ai_questions')`, implement the **Pro soft bank-fallback** (200)
   and the **trial 402 lock** (§5.5); add cheap-model routing (§6). Gate any roadmap-AI
   edge fn the same way.
7. **Question-pool cache** — table keyed by (subject, chapter, topic, difficulty,
   exam); generation writes to it; practice/mock assembly reads bank+pool first (§5.3).
8. **Trial AI lock + no-entitlement gate** — there is **no free tier**. The 7-day
   trial grants the chosen tier's non-AI features but **hard-locks every `ai_*` meter**
   (client shows "unlocks when your trial converts"; RPC returns `trial_ai_locked` →
   402). Users with no active entitlement (lapsed / pre-subscribe) hit the paywall and
   get `no_entitlement` from the RPC.
9. **Paywall copy** — each tier's advertised features must match what `can()` unlocks
   (the original paywall over-promised Premium features to Basic — see
   BILLING_TIER_GATING_PLAN.md §1).
10. **Tests** — one per tier asserting `can()` matches §4; a server test that Basic is
    capped and Pro soft-falls-back-to-bank on `ai_questions`; a downgrade test (§10).

---

## 10. Resolved open decisions (BILLING_TIER_GATING_PLAN.md §6)

- **No free tier.** Removed entirely. `free` survives only as the internal
  "no entitlement → paywall" sentinel. Acquisition = the trial (below).
- **Trial:** 7-day, **annual only**, **AI hard-locked** for the duration (every
  `ai_*` meter returns `trial_ai_locked`; client shows "unlocks when your trial
  converts"), then auto-converts to the locked year and AI unlocks. Monthly = no
  trial. ⚠️ Reconsider — with free gone, the trial is the *only* try-before-buy and it
  auto-charges a full year on day 8; a monthly trial may be needed for the funnel.
- **Downgrade (Pro → Basic at period end):** Pro-generated artifacts (AI roadmap,
  notes, formula sheet) become **read-only — kept, not deleted**. No new Pro
  generation; existing content stays viewable. Humane and avoids "I lost my notes"
  churn.
- **Mock sizes (pinned, verified):** JEE Main = **75 Q / 300 marks / 180 min**; NEET =
  **180 Q / 720 marks / 180 min** (200-item pool with internal choice scores 180). Was
  "90 Q JEE / ~180–200 NEET" — both corrected.
- **Annual = monthly limits.** Annual carries identical features/caps to monthly; no
  extended-limit buckets (your decision).
- **Meter unit:** per-feature buckets (§5.4), not a single pool, because the cost
  surfaces are heterogeneous and routed to different models.

---

## 11. Risks to watch

- **Shallow annual discount (~8%) may not move conversion.** At ₹2,199 / ₹4,399 the
  annuals save the buyer only ~₹190 / ~₹390 vs paying monthly — margins are healthy
  (~71% / ~75%) and the Pro-over-Basic ladder is well-ordered (contribution ₹2,389 vs
  ₹1,128/yr), but a thin discount leans on lock/convenience to convert. If annual share
  lags, discount harder.
- **Annual-only trial + no free tier** narrows the funnel to "commit to a year (with a
  7-day out)." Instrument trial-start → conversion from day one; if top-of-funnel
  drops, add a monthly trial.
- **Community is a build + a moderation/safety liability** for a minor-heavy audience
  (16–18). Phase 2, and budget moderation — it's not a toggle.
- **Pool poisoning:** a wrong AI-generated question cached into the shared pool serves
  many students. Add a lightweight validation/report-and-quarantine path before pool
  reuse.
- **Annual discount depth** lowers per-unit revenue; only worth it if it lifts annual
  conversion — instrument the monthly-vs-annual split from day one.
