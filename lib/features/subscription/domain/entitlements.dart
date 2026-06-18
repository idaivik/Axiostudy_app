import '../../../shared/models/enums.dart';
import '../../auth/domain/user_model.dart';

/// Gateable capabilities — one entry per feature we sell differently by tier.
///
/// Source of truth: `BILLING_PRICING_AND_TIERS_PLAN.md` §4 (feature matrix).
/// Capabilities marked `*(P2)*` are sold on Pro but not built yet (Phase 2);
/// they belong to the tier's set so `can()` is correct the day they ship.
enum Feature {
  // ─── Floor: included on BOTH paid tiers ───
  diagnosticTest,
  adaptivePractice,
  progressAnalytics, // basic analysis — ALL charts
  personalizedPractice, // from the question bank
  community,

  // ─── Basic-only: Pro has a strictly superior replacement (see note below) ───
  basicRoadmap, // NOT coaching-synced; Pro uses `aiRoadmap`
  revisionReminders, // rule-based; Pro uses `advancedRevisionPlan`
  limitedAiTestGen, // small/mock/practice caps; Pro uses `fullAiPractice`
  basicQuestionBreakdown, // templated; Pro uses `advancedBreakdown`

  // ─── Pro-only ───
  aiQuestionGeneration,
  fullAiPractice, // 600/mo soft → bank fallback
  aiAnalysisNarrative,
  aiRoadmap, // best-for-you + coaching-synced
  advancedBreakdown, // + "formulas to learn" widget
  aiTimeTips,
  prioritySupport, // support + feature voting + early access
  advancedRevisionPlan, // *(P2)* spaced repetition
  aiNotes, // *(P2)*
  aiFormulaSheet, // *(P2)*
}

/// Which capabilities each tier unlocks.
///
/// `free` is the internal "no active entitlement → paywall" sentinel — **not a
/// sold tier** — so it grants nothing.
///
/// NOTE on the Basic/Pro relationship: Pro is **not** a literal superset of
/// Basic's *set*. §4 deliberately drops four Basic-flavored rows from Pro because
/// Pro ships a superior replacement (basicRoadmap → aiRoadmap, revisionReminders
/// → advancedRevisionPlan, limitedAiTestGen → fullAiPractice, basicQuestionBreakdown
/// → advancedBreakdown). A surface that exists in both flavors must therefore check
/// the **union** of the basic + pro feature, not just the basic one.
const Map<SubscriptionTier, Set<Feature>> kTierCapabilities = {
  // No entitlement → no capabilities.
  SubscriptionTier.free: <Feature>{},

  SubscriptionTier.basic: {
    // floor
    Feature.diagnosticTest,
    Feature.adaptivePractice,
    Feature.progressAnalytics,
    Feature.personalizedPractice,
    Feature.community,
    // basic-only
    Feature.basicRoadmap,
    Feature.revisionReminders,
    Feature.limitedAiTestGen,
    Feature.basicQuestionBreakdown,
  },

  SubscriptionTier.pro: {
    // floor
    Feature.diagnosticTest,
    Feature.adaptivePractice,
    Feature.progressAnalytics,
    Feature.personalizedPractice,
    Feature.community,
    // pro-only
    Feature.aiQuestionGeneration,
    Feature.fullAiPractice,
    Feature.aiAnalysisNarrative,
    Feature.aiRoadmap,
    Feature.advancedBreakdown,
    Feature.aiTimeTips,
    Feature.prioritySupport,
    Feature.advancedRevisionPlan,
    Feature.aiNotes,
    Feature.aiFormulaSheet,
  },
};

extension Entitlements on UserModel {
  /// Whether this user may use [f]. ANDs in [hasActiveAccess] so a lapsed account
  /// (or the `free` sentinel) `can()` nothing — tier gating and the lapse gate
  /// compose for free.
  ///
  /// This is purely tier-based. The 7-day-trial AI **hard-lock** is a separate,
  /// server-enforced concern (steps 6/8): during the trial these may return true
  /// here while the edge function still returns 402 `trial_ai_locked`.
  bool can(Feature f) =>
      hasActiveAccess &&
      (kTierCapabilities[subscriptionTier]?.contains(f) ?? false);
}
