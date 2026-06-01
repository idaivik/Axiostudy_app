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

/// Subscription plan tiers.
enum SubscriptionTier {
  free,
  basic,
  premium,
  professional;

  String get label {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free Trial';
      case SubscriptionTier.basic:
        return 'Basic';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.professional:
        return 'Professional';
    }
  }

  String get price {
    switch (this) {
      case SubscriptionTier.free:
        return '₹0/month';
      case SubscriptionTier.basic:
        return '₹199/month';
      case SubscriptionTier.premium:
        return '₹299/month';
      case SubscriptionTier.professional:
        return '₹1,999/month';
    }
  }
}

/// Three main subjects for JEE/NEET.
enum SubjectType {
  physics,
  chemistry,
  mathematics;

  String get label {
    switch (this) {
      case SubjectType.physics:
        return 'Physics';
      case SubjectType.chemistry:
        return 'Chemistry';
      case SubjectType.mathematics:
        return 'Mathematics';
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
