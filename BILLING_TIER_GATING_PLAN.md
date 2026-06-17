# Plan: Tier gating (Basic vs Premium/Pro) — §9.3

> Status: **PLAN ONLY — not implemented.** Waiting on the per-tier feature list
> (coming in a separate chat). This document is the architecture + the matrix to
> fill in; once the matrix is filled, implementation is mechanical.

---

## 1. Current state (verified)

- `subscriptionTier` (`free` / `basic` / `premium` / `professional`) is **display
  only**. It is read in exactly three non-model places — the profile label, the
  profile "Manage Subscription" subtitle, and the paywall's selected-plan state —
  and **gates nothing**. A Basic subscriber and a Premium subscriber have
  identical access to every feature.
- The only access gate that exists is the **paywall on lapse/signup**
  (`onboardingStepFor` → `hasActiveAccess`), which is binary: in or out. It does
  not distinguish tiers.
- The paywall (`payment_models.dart`) **sells two tiers**: Basic ₹199, Premium
  ₹299 — but advertises Premium-only features ("Unlimited AI question generation",
  "AI-driven coaching roadmap", "Priority full-length mock tests", "Deep
  chapter-level insights") that are not actually withheld from Basic.

### Tier set — DECIDED (2026-06-17, repriced — see BILLING_PRICING_AND_TIERS_PLAN.md §1–2)
Two paid tiers, each billed **monthly or annually**. **No free tier:**

| Tier | Monthly | Annual | Annual vs 12×monthly |
| --- | --- | --- | --- |
| **Basic** | ₹199/mo | ₹2,199/yr | ~8% off (12× = ₹2,388) |
| **Pro** | ₹399/mo | ₹4,399/yr | ~8% off (12× = ₹4,788) |

No third tier, **no free tier**. The current code's **`premium`** tier becomes
**`pro`** (price ₹299 → ₹399); a **Basic/Pro annual** option is new. Annual carries the
**same features/limits as monthly** at a modest ~8% discount — margins ~71% (Basic) /
~75% (Pro), with Pro annual contributing well above Basic (pricing plan §2/§7).

**Code + store impact this implies (build phase — NOT done yet):**
- Consolidate `SubscriptionTier` to two paid values — rename `premium` → `pro`, drop
  the unused `professional`; keep `free` **only** as the internal "no active
  entitlement → paywall" sentinel (not a sold tier, grants nothing).
- **4 store products + RevenueCat packages** instead of 2:
  `axio_basic_monthly` (₹199), `axio_basic_yearly` (₹2,199),
  `axio_pro_monthly` (₹399), `axio_pro_yearly` (₹4,399).
  ⚠️ Product ids are **permanent** — reconcile against what you already created in
  Play Console. The old plan's `axio_premium_monthly` @ ₹299 is now wrong on both
  **id and price**; `BILLING_GO_LIVE.md` §1 and the webhook tier mapping
  (`*premium*` → premium) must be updated to `pro` in the same change.
- Paywall needs a **monthly/annual toggle**. Entitlements stay **tier-level**
  (`basic` / `pro`), independent of billing period, so gating never inspects the
  period — capabilities attach to the tier.
- **7-day trial = annual only, AI hard-locked** for the duration (then auto-converts
  and AI unlocks). Resolved — pricing plan §10.

---

## 2. Architecture — one capability model, three enforcement layers

### 2a. Central capability map (single source of truth)
New file `lib/features/subscription/domain/entitlements.dart`:

```dart
/// Gateable capabilities. Add one entry per feature we sell differently by tier.
enum Feature {
  adaptivePractice,
  diagnosticTest,
  dailyStudyPlan,
  progressAnalytics,
  aiQuestionGeneration,   // costs money per call → MUST also be enforced server-side
  coachingRoadmap,
  fullLengthMockTests,
  deepChapterInsights,
  // …extend from the filled-in matrix.
}

/// Which capabilities each tier unlocks. Pro is a superset of Basic.
/// (`pro` = the renamed `premium` enum value — see §1 store/code impact.)
const Map<SubscriptionTier, Set<Feature>> kTierCapabilities = {
  SubscriptionTier.free: {},          // NOT a sold tier — "no entitlement" sentinel; grants nothing
  SubscriptionTier.basic: { /* from matrix — pricing plan §4 */ },
  SubscriptionTier.pro:   { /* Basic ∪ pro-only — pricing plan §4 */ },
};

extension Entitlements on UserModel {
  bool can(Feature f) =>
      hasActiveAccess && (kTierCapabilities[subscriptionTier]?.contains(f) ?? false);
}
```

`hasActiveAccess` (added in §9.2) is ANDed in, so a lapsed user `can()` nothing —
tier gating and the lapse gate compose for free.

### 2b. Client enforcement (UX)
At each gated surface, branch on `user.can(Feature.x)`:
- **Hard gate** (feature absent for tier): replace the entry point with a locked
  state + "Upgrade to unlock" CTA → opens the paywall in **upgrade mode** (see 2d).
- **Soft gate** (metered, e.g. N free AI generations): allow, show remaining, then
  upsell.

A small reusable `FeatureGate` widget (`child` vs `locked` builder) keeps call
sites one-liners and consistent.

### 2c. Server enforcement (the part that actually matters for paid compute)
Client checks are **bypassable** — anything that costs us money or unlocks real
value must be re-checked server-side. Concretely:
- `supabase/functions/generate-questions` → read the caller's `profiles.subscription_tier`
  (+ status) and reject/limit if the tier lacks `aiQuestionGeneration`. There is
  already a `question_generation_credits` migration to build the metering on.
- Anything roadmap-AI (`roadmap_ai_client.dart` → its edge function, if it calls one)
  → same check.
- Consider an RLS policy / RPC guard for premium-only data reads.

### 2d. Paywall "upgrade mode"
Today the paywall is signup-only (hard gate, full-screen). Add an entry path so an
in-app upgrade CTA can open it to **change tier** (Basic→Premium) without it being
a funnel gate. Minimal: a parameter/flag on `PaywallScreen` that (i) preselects the
upsell tier, (ii) shows a close affordance, (iii) on success just refreshes and
pops rather than running `_enterApp()`'s onboarding routing.

---

## 3. Surfaces to gate (file pointers — assign each to a tier via the matrix)

| Capability | Where it lives | Gate type (likely) |
| --- | --- | --- |
| AI question generation | `lib/features/practice/data/practice_repository.dart`, `results_screen.dart`, edge fn `generate-questions` | metered or Pro-only; **server-enforced** |
| Coaching roadmap | `lib/features/roadmap/**` (home card `roadmap_home_card.dart`, `roadmap_screen.dart`, `roadmap_providers.dart`, `roadmap_ai_client.dart`) | Pro-only (hard) |
| Full-length mock tests | `lib/features/practice/presentation/practice_screen.dart`, `lib/features/test/**` | Pro-only (hard) |
| Deep chapter insights | `lib/features/analytics/**` | Pro-only (hard) |
| Adaptive practice / diagnostic / daily plan / basic analytics | practice, test, home, analytics | Basic+ (the floor) |

---

## 4. Matrix to fill in (from the other chat)

Mark ✅ = included, ❌ = locked (→ upsell), or a number for metered limits.
Billing period (monthly/annual) does **not** change features — only the tier does.

| Feature | Basic (₹199/mo · ₹2,199/yr) | Pro (₹399/mo · ₹4,399/yr) |
| --- | --- | --- |
| Adaptive practice | | |
| Diagnostic + weakness detection | | |
| Daily study plan | | |
| Progress analytics (basic) | | |
| AI question generation | | |
| Coaching-synced roadmap | | |
| Full-length mock tests | | |
| Deep chapter-level insights | | |
| _…add rows as needed_ | | |

---

## 5. Implementation order (once the matrix lands)

1. **Rename `premium` → `pro`** across `SubscriptionTier`, `TrialPlan`, store
   **product ids**, RevenueCat **entitlements**, and the webhook tier mapping
   (`*premium*` → `*pro*`); add the **annual** products/packages and a
   monthly/annual paywall toggle (§1). Update `BILLING_GO_LIVE.md` §1 to match.
2. Add `entitlements.dart` (`Feature`, `kTierCapabilities`, `UserModel.can`).
3. Build `FeatureGate` widget + the upgrade-mode paywall entry (2d).
4. Gate each surface in §3 (hard gates first, metered ones second).
5. **Server-enforce** AI generation (and any other paid-compute) in the edge
   function(s) — do not ship client-only gating for those.
6. Sync the paywall copy so each tier's advertised features match what it unlocks.
7. Tests: one per tier asserting `can()` matches the matrix; a server test that a
   Basic token is rejected by `generate-questions` if Basic lacks it.

---

## 6. Open decisions — RESOLVED (see BILLING_PRICING_AND_TIERS_PLAN.md §10)
- **Feature matrix:** filled in — pricing plan §4. Per-meter caps — pricing plan §5.4.
- **Trial:** 7-day, **annual only, AI hard-locked** until it converts. No free tier.
- **Downgrade (Pro→Basic at period end):** Pro artifacts go **read-only — kept, not
  deleted**.
- **Pricing:** Basic ₹2,199/yr, Pro ₹4,399/yr (~8% off 12×) — the earlier Pro-annual
  inversion is resolved; both hold healthy margins (pricing plan §2/§7).
