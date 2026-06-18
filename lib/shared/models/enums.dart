import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Question difficulty levels.
enum Difficulty {
  easy,
  medium,
  hard;

  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }
}

/// Supported question formats.
enum QuestionType {
  mcq,
  numerical;

  String get label {
    switch (this) {
      case QuestionType.mcq:
        return 'Multiple Choice';
      case QuestionType.numerical:
        return 'Numerical';
    }
  }
}

/// Types of tests available.
enum TestType {
  diagnostic,
  practice,
  mock;

  String get label {
    switch (this) {
      case TestType.diagnostic:
        return 'Diagnostic Test';
      case TestType.practice:
        return 'Practice Test';
      case TestType.mock:
        return 'Mock Test';
    }
  }
}

/// Status of a test attempt.
enum TestAttemptStatus {
  inProgress,
  submitted,
  analyzed,
}

/// Target competitive exam the student is preparing for.
/// Persisted to `profiles.exam_type` as the lowercase enum name ('jee' | 'neet').
enum ExamType {
  jee,
  neet;

  String get label {
    switch (this) {
      case ExamType.jee:
        return 'JEE';
      case ExamType.neet:
        return 'NEET';
    }
  }

  String get fullName {
    switch (this) {
      case ExamType.jee:
        return 'Joint Entrance Examination';
      case ExamType.neet:
        return 'National Eligibility cum Entrance Test';
    }
  }

  String get tagline {
    switch (this) {
      case ExamType.jee:
        return 'Engineering • Physics, Chemistry, Maths';
      case ExamType.neet:
        return 'Medical • Physics, Chemistry, Biology';
    }
  }

  /// Subjects covered by this exam.
  List<SubjectType> get subjects {
    switch (this) {
      case ExamType.jee:
        return const [
          SubjectType.physics,
          SubjectType.chemistry,
          SubjectType.mathematics,
        ];
      case ExamType.neet:
        return const [
          SubjectType.physics,
          SubjectType.chemistry,
          SubjectType.biology,
        ];
    }
  }

  static ExamType? fromName(String? name) {
    switch (name) {
      case 'jee':
        return ExamType.jee;
      case 'neet':
        return ExamType.neet;
      default:
        return null;
    }
  }
}

/// Lifecycle of the recurring mandate / trial. Mirrors
/// `profiles.subscription_status` (see migration comments).
enum SubscriptionStatus {
  none,
  trialing,
  active,
  cancelled,
  pastDue;

  /// Value persisted to the DB (`past_due` for [pastDue], lowercase name otherwise).
  String get dbValue => this == SubscriptionStatus.pastDue ? 'past_due' : name;

  /// True while the user still has access (trial running or billing live).
  bool get isEntitled =>
      this == SubscriptionStatus.trialing || this == SubscriptionStatus.active;

  /// Human-readable status for the profile / subscription-management UI.
  String get label {
    switch (this) {
      case SubscriptionStatus.none:
        return 'Not subscribed';
      case SubscriptionStatus.trialing:
        return 'Free trial';
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.pastDue:
        return 'Payment issue';
    }
  }

  static SubscriptionStatus fromDb(String? value) {
    switch (value) {
      case 'trialing':
        return SubscriptionStatus.trialing;
      case 'active':
        return SubscriptionStatus.active;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      default:
        return SubscriptionStatus.none;
    }
  }
}

/// Subscription plan tiers. Two paid tiers only — **Basic** and **Pro**.
///
/// [free] is **not a sold tier**: it is the internal "no active entitlement →
/// paywall" sentinel and grants nothing (see `entitlements.dart`'s empty
/// capability set). The store sells `axio_basic` (→ [basic]) and
/// `axio_premium` (→ [pro], bridged in the RevenueCat webhook).
enum SubscriptionTier {
  free,
  basic,
  pro;

  String get label {
    switch (this) {
      case SubscriptionTier.free:
        return 'No plan';
      case SubscriptionTier.basic:
        return 'Basic';
      case SubscriptionTier.pro:
        return 'Pro';
    }
  }

  String get price {
    switch (this) {
      case SubscriptionTier.free:
        return '—';
      case SubscriptionTier.basic:
        return '₹199/month';
      case SubscriptionTier.pro:
        return '₹399/month';
    }
  }
}

/// Main subjects for JEE/NEET.
enum SubjectType {
  physics,
  chemistry,
  mathematics,
  biology;

  String get label {
    switch (this) {
      case SubjectType.physics:
        return 'Physics';
      case SubjectType.chemistry:
        return 'Chemistry';
      case SubjectType.mathematics:
        return 'Mathematics';
      case SubjectType.biology:
        return 'Biology';
    }
  }

  /// Professional icon for the subject (Lucide icons).
  IconData get iconData {
    switch (this) {
      case SubjectType.physics:
        return LucideIcons.atom;
      case SubjectType.chemistry:
        return LucideIcons.flaskConical;
      case SubjectType.mathematics:
        return LucideIcons.sigma;
      case SubjectType.biology:
        return LucideIcons.microscope;
    }
  }

  /// Legacy string getter — kept for backward compatibility.
  /// New code should use [iconData] instead.
  @Deprecated('Use iconData instead')
  String get icon {
    switch (this) {
      case SubjectType.physics:
        return 'atom';
      case SubjectType.chemistry:
        return 'flask';
      case SubjectType.mathematics:
        return 'sigma';
      case SubjectType.biology:
        return 'microscope';
    }
  }
}

/// How strong a student is in a topic.
enum TopicStrength {
  weak,
  moderate,
  strong;

  String get label {
    switch (this) {
      case TopicStrength.weak:
        return 'Needs Practice';
      case TopicStrength.moderate:
        return 'In Progress';
      case TopicStrength.strong:
        return 'Mastered';
    }
  }
}

/// Answer status for question grid coloring.
enum AnswerStatus {
  unanswered,
  answered,
  markedForReview,
  current,
}
