/// Deterministic time-management ("pacing") tips engine — Bucket 2 Feature 1
/// (BILLING_BUCKET2_BUILD_PROMPT.md §2), Pro (`Feature.aiTimeTips`).
///
/// These tips are about **how the student spent time**, NOT what to study — that
/// boundary keeps them distinct from the AI narrative ("where the marks are").
/// They are derived **deterministically** (₹0) from the analytics we already
/// compute: there is no new meter and no AI call. The phrasing is plain; if the
/// `analysis-narrative` cheap-model call is ever fused in, it can rewrite these
/// strings without changing the rules below.
///
/// Pure + provider-free so it unit-tests with no network.
library;

import '../../../shared/models/enums.dart';
import 'analytics_models.dart';

/// What a tip is about — used for ranking and (optionally) iconography.
enum TimeTipKind {
  /// Raced through a section AND scored poorly → slow down.
  rushedWrong,

  /// Raced through the whole paper AND scored poorly → slow down overall.
  rushedOverall,

  /// Accurate but slow in a section → can safely speed up, banking time.
  slowButRight,

  /// Spent well over the ideal on a section (accuracy aside) → watch the clock.
  slowPace,

  /// Ran slow across the whole paper vs the ideal budget.
  slowOverall,

  /// Left questions unanswered → budget the final stretch.
  unanswered,
}

/// A single pacing tip. [severity] orders the list (higher = surfaced first).
class TimeTip {
  final TimeTipKind kind;
  final String message;
  final int severity;

  const TimeTip(this.kind, this.message, {required this.severity});
}

/// Reference "ideal seconds per question". Derived from each exam's official
/// per-question time budget (the base = a medium question), scaled by difficulty.
/// Confirmed defaults: JEE 144 s (180 min / 75 Q), NEET 60 s (180 min / 180 Q);
/// easy ×0.7, medium ×1.0, hard ×1.4. Same base for every subject in an exam.
class IdealTimeConfig {
  /// Seconds for a *medium* question (the difficulty-1.0 anchor).
  final double baseSeconds;
  final Map<Difficulty, double> difficultyMultipliers;

  const IdealTimeConfig({
    required this.baseSeconds,
    this.difficultyMultipliers = kDefaultDifficultyMultipliers,
  });

  static const Map<Difficulty, double> kDefaultDifficultyMultipliers = {
    Difficulty.easy: 0.7,
    Difficulty.medium: 1.0,
    Difficulty.hard: 1.4,
  };

  /// The ideal-time reference for [exam], or `null` when the exam is unknown
  /// (the engine then only emits exam-agnostic tips, e.g. unanswered budget).
  static IdealTimeConfig? forExam(ExamType? exam) {
    switch (exam) {
      case ExamType.jee:
        return const IdealTimeConfig(baseSeconds: 144);
      case ExamType.neet:
        return const IdealTimeConfig(baseSeconds: 60);
      case null:
        return null;
    }
  }

  double idealFor(Difficulty d) =>
      baseSeconds * (difficultyMultipliers[d] ?? 1.0);

  /// The blended ideal for a paper whose difficulty mix is [difficultyBreakdown]
  /// (weighted by question count). Falls back to [baseSeconds] when there is no
  /// difficulty data.
  double blendedIdeal(Map<String, DifficultyBreakdown> difficultyBreakdown) {
    var weighted = 0.0;
    var count = 0;
    for (final d in difficultyBreakdown.values) {
      final diff = _parseDifficulty(d.difficulty);
      weighted += idealFor(diff) * d.total;
      count += d.total;
    }
    return count > 0 ? weighted / count : baseSeconds;
  }
}

Difficulty _parseDifficulty(String s) {
  switch (s.toLowerCase()) {
    case 'easy':
      return Difficulty.easy;
    case 'hard':
      return Difficulty.hard;
    default:
      return Difficulty.medium;
  }
}

/// Computes a ranked list of pacing tips from a single attempt's analytics.
class TimeTipsEngine {
  /// Below this many questions in a subject, its pacing signal is too noisy to
  /// claim anything — suppress the subject-level tip rather than over-claim.
  static const int minQuestionsForSubjectTip = 4;

  /// Below this many questions overall, suppress all timing claims (a 3-question
  /// quiz can't tell us anything useful about pacing).
  static const int minTotalQuestions = 5;

  // Thresholds expressed as fractions of the ideal seconds-per-question.
  static const double _rushedFactor = 0.6; // faster than 60% of ideal = rushing
  static const double _slowFactor = 1.5; // slower than 150% of ideal = slow
  static const double _slowOverallFactor = 1.3;
  static const double _lowAccuracy = 0.5;
  static const double _highAccuracy = 0.7;

  /// Returns up to [maxTips] tips, most important first. [ideal] may be null
  /// (unknown exam) → only exam-agnostic tips (unanswered budget) are produced.
  static List<TimeTip> compute({
    required AttemptAnalyticsResult analytics,
    IdealTimeConfig? ideal,
    int maxTips = 4,
  }) {
    final tips = <TimeTip>[];
    final totalQ = analytics.totalCorrect +
        analytics.totalWrong +
        analytics.totalUnanswered;
    if (totalQ < minTotalQuestions) return const [];

    // ── 1. Unanswered budget (exam-agnostic) ──────────────────────────────────
    if (analytics.totalUnanswered > 0) {
      final n = analytics.totalUnanswered;
      final estSecs = analytics.avgTimePerQuestion > 0
          ? analytics.avgTimePerQuestion * n
          : 0;
      final estMin = (estSecs / 60).ceil();
      final msg = estMin > 0
          ? '$n question${n == 1 ? '' : 's'} left unanswered — about $estMin min of marks on the table. '
              'Budget the final stretch so every question gets an attempt.'
          : '$n question${n == 1 ? '' : 's'} left unanswered — pace yourself so every question gets an attempt.';
      tips.add(TimeTip(TimeTipKind.unanswered, msg, severity: 80 + n));
    }

    if (ideal != null) {
      // ── 2. Overall pace vs the blended ideal ────────────────────────────────
      final answered = analytics.totalCorrect + analytics.totalWrong;
      final blended = ideal.blendedIdeal(analytics.difficultyBreakdown);
      final avg = analytics.avgTimePerQuestion;
      if (answered >= minTotalQuestions && avg > 0 && blended > 0) {
        if (avg < blended * _rushedFactor && analytics.accuracy < _lowAccuracy) {
          tips.add(TimeTip(
            TimeTipKind.rushedOverall,
            'You raced the whole paper (~${_fmt(avg)}/question vs ~${_fmt(blended)} ideal) '
            'and landed at ${(analytics.accuracy * 100).round()}%. Slowing down should lift your score.',
            severity: 90,
          ));
        } else if (avg > blended * _slowOverallFactor) {
          tips.add(TimeTip(
            TimeTipKind.slowOverall,
            'Overall you averaged ~${_fmt(avg)}/question vs ~${_fmt(blended)} ideal. '
            'Triage the hard ones early and move on so the clock never beats you.',
            severity: 55,
          ));
        }
      }

      // ── 3. Per-subject pacing ───────────────────────────────────────────────
      // Sorted by subjectId for deterministic output.
      final subjects = analytics.subjectBreakdown.values.toList()
        ..sort((a, b) => a.subjectId.compareTo(b.subjectId));
      for (final s in subjects) {
        if (s.total < minQuestionsForSubjectTip || s.timeSeconds <= 0) continue;
        final subjAvg = s.timeSeconds / s.total;
        final base = ideal.baseSeconds;
        final accPct = (s.accuracy * 100).round();

        if (subjAvg < base * _rushedFactor && s.accuracy < _lowAccuracy) {
          tips.add(TimeTip(
            TimeTipKind.rushedWrong,
            'You rushed ${s.subjectName} (~${_fmt(subjAvg)}/question vs ~${_fmt(base)} ideal) '
            'and scored $accPct%. Slow down and read each question fully.',
            severity: 100,
          ));
        } else if (subjAvg > base * _slowFactor && s.accuracy >= _highAccuracy) {
          tips.add(TimeTip(
            TimeTipKind.slowButRight,
            "You're accurate in ${s.subjectName} ($accPct%) but slow "
            '(~${_fmt(subjAvg)}/question vs ~${_fmt(base)} ideal). '
            'Speeding up here banks time for tougher sections.',
            severity: 60,
          ));
        } else if (subjAvg > base * _slowFactor) {
          tips.add(TimeTip(
            TimeTipKind.slowPace,
            'You spent ~${_fmt(subjAvg)}/question on ${s.subjectName} vs ~${_fmt(base)} ideal — '
            'keep an eye on the clock in this section.',
            severity: 50,
          ));
        }
      }
    }

    // Rank by severity (stable: ties keep insertion order) and cap.
    final indexed = tips.asMap().entries.toList()
      ..sort((a, b) {
        final c = b.value.severity.compareTo(a.value.severity);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).take(maxTips).toList();
  }

  /// "2.4 min" for ≥60 s, "22s" otherwise.
  static String _fmt(num seconds) {
    if (seconds >= 60) return '${(seconds / 60).toStringAsFixed(1)} min';
    return '${seconds.round()}s';
  }
}
