/// Domain models for the server-side weakness engine (Phase 1).
///
/// These mirror the `chapter_analytics` and `user_weak_chapters` tables written
/// by the `compute-analytics` edge function. The legacy topic-level models in
/// `analytics_models.dart` still power the existing screens; these add the
/// chapter-level, AI-enriched view.

/// One chapter's computed + AI-enriched analytics for a single attempt
/// (a `chapter_analytics` row).
class ChapterInsight {
  final String chapterId;
  final String subjectId;
  final String attemptId;
  final double scorePercentage; // 0–100
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final double avgTimePerQuestion; // seconds
  final bool isWeak; // score < 50
  final bool isStrong; // score > 75
  final double? improvementFromLastTest; // null = no prior data
  final String? errorPattern; // silly | conceptual | calculation | mixed
  final String? weaknessReasoning; // AI copy
  final String? recommendedAction; // AI / heuristic next step
  final int? priorityScore; // AI urgency rank, 0–100
  final DateTime computedAt;

  const ChapterInsight({
    required this.chapterId,
    required this.subjectId,
    required this.attemptId,
    required this.scorePercentage,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.avgTimePerQuestion,
    required this.isWeak,
    required this.isStrong,
    this.improvementFromLastTest,
    this.errorPattern,
    this.weaknessReasoning,
    this.recommendedAction,
    this.priorityScore,
    required this.computedAt,
  });

  factory ChapterInsight.fromJson(Map<String, dynamic> json) {
    return ChapterInsight(
      chapterId: json['chapter_id'] as String,
      subjectId: json['subject_id'] as String? ?? '',
      attemptId: json['attempt_id'] as String? ?? '',
      scorePercentage: (json['score_percentage'] as num?)?.toDouble() ?? 0,
      correctCount: json['correct_count'] as int? ?? 0,
      wrongCount: json['wrong_count'] as int? ?? 0,
      unansweredCount: json['unanswered_count'] as int? ?? 0,
      avgTimePerQuestion:
          (json['avg_time_per_question'] as num?)?.toDouble() ?? 0,
      isWeak: json['is_weak'] as bool? ?? false,
      isStrong: json['is_strong'] as bool? ?? false,
      improvementFromLastTest:
          (json['improvement_from_last_test'] as num?)?.toDouble(),
      errorPattern: json['error_pattern'] as String?,
      weaknessReasoning: json['weakness_reasoning'] as String?,
      recommendedAction: json['recommended_action'] as String?,
      priorityScore: json['priority_score'] as int?,
      computedAt: json['computed_at'] != null
          ? DateTime.parse(json['computed_at'] as String)
          : DateTime.now(),
    );
  }
}

/// A persistent per-chapter mastery row (a `user_weak_chapters` row).
///
/// [weaknessScore] is a 0–100 MASTERY score (higher = stronger). The adaptive
/// loop promotes a chapter to `strong` once it clears 75 and surfaces the next
/// weak chapter.
class WeakChapter {
  final String chapterId;
  final String? subjectId;
  final double weaknessScore; // 0–100 mastery (higher = stronger)
  final int attemptsCount;
  final String status; // weak | improving | strong
  final DateTime lastUpdated;

  const WeakChapter({
    required this.chapterId,
    this.subjectId,
    required this.weaknessScore,
    required this.attemptsCount,
    required this.status,
    required this.lastUpdated,
  });

  bool get isWeak => status == 'weak';
  bool get isStrong => status == 'strong';

  factory WeakChapter.fromJson(Map<String, dynamic> json) {
    return WeakChapter(
      chapterId: json['chapter_id'] as String,
      subjectId: json['subject_id'] as String?,
      weaknessScore: (json['weakness_score'] as num?)?.toDouble() ?? 0,
      attemptsCount: json['attempts_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'weak',
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : DateTime.now(),
    );
  }
}

/// Before → after recovery for one chapter, derived from its
/// `chapter_analytics` history. Drives the Recovery Tracker widget.
class ChapterRecovery {
  final String chapterId;
  final String? subjectId;
  final double firstScore; // earliest recorded score_percentage
  final double lastScore; // most recent score_percentage
  final int attempts; // number of analytics rows

  const ChapterRecovery({
    required this.chapterId,
    this.subjectId,
    required this.firstScore,
    required this.lastScore,
    required this.attempts,
  });

  double get delta => lastScore - firstScore;
}
