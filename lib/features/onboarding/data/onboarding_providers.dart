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

/// Resolves the next gate from the profile. Order matters: exam target →
/// paywall/trial → AI profiling → done.
OnboardingStep onboardingStepFor(UserModel user) {
  if (user.examType == null) return OnboardingStep.exam;
  if (!user.isEntitled) return OnboardingStep.paywall;
  if (!user.onboardingCompleted) return OnboardingStep.profiling;
  return OnboardingStep.done;
}
