import '../../auth/domain/user_model.dart';

/// The gated steps a freshly-created account must clear, in order, before it
/// "officially enters the app". Derived purely from the persisted profile so
/// the router can enforce the funnel even across app restarts.
enum OnboardingStep {
  /// Pick target exam (JEE / NEET) — `profiles.exam_type` is null.
  exam,

  /// Hard paywall — no active trial/subscription yet.
  paywall,

  /// AI profiling — entitled but `onboarding_completed` is false.
  profiling,

  /// Funnel complete — full app access.
  done,
}

extension OnboardingStepRoute on OnboardingStep {
  String get route {
    switch (this) {
      case OnboardingStep.exam:
        return '/onboarding/exam';
      case OnboardingStep.paywall:
        return '/paywall';
      case OnboardingStep.profiling:
        return '/onboarding/profiling';
      case OnboardingStep.done:
        return '/';
    }
  }
}

/// Routes that belong to the signup funnel (used by the router to keep entitled
/// users out of onboarding screens and vice-versa).
const Set<String> kOnboardingRoutes = {
  '/onboarding/exam',
  '/paywall',
  '/onboarding/profiling',
};

/// The funnel routes in forward order (exam → paywall → profiling). The router
/// uses the ordering to permit BACKWARD navigation to an earlier *pre-payment*
/// step (so the back gesture can walk paywall → exam) while still blocking any
/// skip ahead to a step the user hasn't reached.
const List<String> kFunnelOrder = [
  '/onboarding/exam',
  '/paywall',
  '/onboarding/profiling',
];

/// Resolves the next gate from the profile.
///
/// Brand-new accounts run the funnel in order: exam target → paywall/trial → AI
/// profiling → done. (Completing profiling is what flips `onboarding_completed`
/// to true.)
///
/// The paid-access gate is enforced on **every** user, not just new ones: an
/// already-onboarded account whose subscription has lapsed
/// (`!user.hasActiveAccess` — e.g. `subscription_status = 'none'`, or a
/// cancelled/past-due period that has elapsed) is sent back to the paywall (a
/// soft re-paywall) until they re-subscribe or restore. A still-entitled
/// returning user — including one who cancelled but is inside their paid period —
/// goes straight to `done` and is never bounced. The order matters: the
/// entitlement check sits before the `onboarding_completed` check so lapses
/// re-lock the app, while a re-subscribe doesn't drag an onboarded user back
/// through profiling.
OnboardingStep onboardingStepFor(UserModel user) {
  if (user.examType == null) return OnboardingStep.exam;
  if (!user.hasActiveAccess) return OnboardingStep.paywall;
  if (!user.onboardingCompleted) return OnboardingStep.profiling;
  return OnboardingStep.done;
}
