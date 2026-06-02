/// Domain models for the AI/Analytics Engine.
///
/// These represent computed analytics outputs that power the
/// Results, Analytics, and Home screens.

/// Full analytics breakdown for a single test attempt.
class AttemptAnalyticsResult {
  final String attemptId;
  final String userId;
  final String testId;

  // Score breakdown
  final int totalCorrect;
  final int totalWrong;
  final int totalUnanswered;
  final double accuracy; // 0.0–1.0

  // Time analysis
  final int totalTimeSeconds;
  final double avgTimePerQuestion;
  final int? fastestQuestionSeconds;
  final int? slowestQuestionSeconds;

  // Breakdowns
  final Map<String, SubjectBreakdown> subjectBreakdown;
  final Map<String, ChapterBreakdown> chapterBreakdown;
  final Map<String, DifficultyBreakdown> difficultyBreakdown;

  // Detected patterns
  final List<TopicInsight> weakTopics;
  final List<TopicInsight> strongTopics;

  // Generated recommendations
  final List<Recommendation> recommendations;

  final DateTime computedAt;

  const AttemptAnalyticsResult({
    required this.attemptId,
    required this.userId,
    required this.testId,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalUnanswered,
    required this.accuracy,
    required this.totalTimeSeconds,
    required this.avgTimePerQuestion,
    this.fastestQuestionSeconds,
    this.slowestQuestionSeconds,
    required this.subjectBreakdown,
    required this.chapterBreakdown,
    required this.difficultyBreakdown,
    required this.weakTopics,
    required this.strongTopics,
    required this.recommendations,
    required this.computedAt,
  });

  /// Create from Supabase `attempt_analytics` row.
  factory AttemptAnalyticsResult.fromJson(Map<String, dynamic> json) {
    return AttemptAnalyticsResult(
      attemptId: json['attempt_id'] as String,
      userId: json['user_id'] as String,
      testId: json['test_id'] as String,
      totalCorrect: json['total_correct'] as int? ?? 0,
      totalWrong: json['total_wrong'] as int? ?? 0,
      totalUnanswered: json['total_unanswered'] as int? ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      totalTimeSeconds: json['total_time_seconds'] as int? ?? 0,
      avgTimePerQuestion:
          (json['avg_time_per_question'] as num?)?.toDouble() ?? 0,
      fastestQuestionSeconds: json['fastest_question_seconds'] as int?,
      slowestQuestionSeconds: json['slowest_question_seconds'] as int?,
      subjectBreakdown: _parseSubjectBreakdown(json['subject_breakdown']),
      chapterBreakdown: _parseChapterBreakdown(json['chapter_breakdown']),
      difficultyBreakdown:
          _parseDifficultyBreakdown(json['difficulty_breakdown']),
      weakTopics: _parseTopicInsights(json['weak_topics']),
      strongTopics: _parseTopicInsights(json['strong_topics']),
      recommendations: _parseRecommendations(json['recommendations']),
      computedAt: json['computed_at'] != null
          ? DateTime.parse(json['computed_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to JSON for Supabase insert.
  Map<String, dynamic> toJson() {
    return {
      'attempt_id': attemptId,
      'user_id': userId,
      'test_id': testId,
      'total_correct': totalCorrect,
      'total_wrong': totalWrong,
      'total_unanswered': totalUnanswered,
      'accuracy': accuracy,
      'total_time_seconds': totalTimeSeconds,
      'avg_time_per_question': avgTimePerQuestion,
      'fastest_question_seconds': fastestQuestionSeconds,
      'slowest_question_seconds': slowestQuestionSeconds,
      'subject_breakdown': subjectBreakdown.map(
        (k, v) => MapEntry(k, v.toJson()),
      ),
      'chapter_breakdown': chapterBreakdown.map(
        (k, v) => MapEntry(k, v.toJson()),
      ),
      'difficulty_breakdown': difficultyBreakdown.map(
        (k, v) => MapEntry(k, v.toJson()),
      ),
      'weak_topics': weakTopics.map((t) => t.toJson()).toList(),
      'strong_topics': strongTopics.map((t) => t.toJson()).toList(),
      'recommendations': recommendations.map((r) => r.toJson()).toList(),
      'computed_at': computedAt.toIso8601String(),
    };
  }

  double get scorePercentage {
    final total = totalCorrect + totalWrong + totalUnanswered;
    if (total == 0) return 0;
    return (totalCorrect / total) * 100;
  }

  static Map<String, SubjectBreakdown> _parseSubjectBreakdown(dynamic data) {
    if (data == null || data is! Map) return {};
    return (data as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, SubjectBreakdown.fromJson(v as Map<String, dynamic>)),
    );
  }

  static Map<String, ChapterBreakdown> _parseChapterBreakdown(dynamic data) {
    if (data == null || data is! Map) return {};
    return (data as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, ChapterBreakdown.fromJson(v as Map<String, dynamic>)),
    );
  }

  static Map<String, DifficultyBreakdown> _parseDifficultyBreakdown(
      dynamic data) {
    if (data == null || data is! Map) return {};
    return (data as Map<String, dynamic>).map(
      (k, v) =>
          MapEntry(k, DifficultyBreakdown.fromJson(v as Map<String, dynamic>)),
    );
  }

  static List<TopicInsight> _parseTopicInsights(dynamic data) {
    if (data == null || data is! List) return [];
    return (data as List)
        .map((e) => TopicInsight.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Recommendation> _parseRecommendations(dynamic data) {
    if (data == null || data is! List) return [];
    return (data as List)
        .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Per-subject accuracy breakdown.
class SubjectBreakdown {
  final String subjectId;
  final String subjectName;
  final int correct;
  final int total;
  final double accuracy;
  final int timeSeconds;

  const SubjectBreakdown({
    required this.subjectId,
    required this.subjectName,
    required this.correct,
    required this.total,
    required this.accuracy,
    this.timeSeconds = 0,
  });

  factory SubjectBreakdown.fromJson(Map<String, dynamic> json) {
    final correct = json['correct'] as int? ?? 0;
    final total = json['total'] as int? ?? 0;
    return SubjectBreakdown(
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      correct: correct,
      total: total,
      accuracy: (json['accuracy'] as num?)?.toDouble() ??
          (total > 0 ? correct / total : 0),
      timeSeconds: json['time_seconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'subject_name': subjectName,
        'correct': correct,
        'total': total,
        'accuracy': accuracy,
        'time_seconds': timeSeconds,
      };
}

/// Per-chapter accuracy breakdown.
class ChapterBreakdown {
  final String chapterId;
  final String chapterName;
  final String subjectId;
  final int correct;
  final int total;
  final double accuracy;

  const ChapterBreakdown({
    required this.chapterId,
    required this.chapterName,
    required this.subjectId,
    required this.correct,
    required this.total,
    required this.accuracy,
  });

  factory ChapterBreakdown.fromJson(Map<String, dynamic> json) {
    final correct = json['correct'] as int? ?? 0;
    final total = json['total'] as int? ?? 0;
    return ChapterBreakdown(
      chapterId: json['chapter_id'] as String? ?? '',
      chapterName: json['chapter_name'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      correct: correct,
      total: total,
      accuracy: (json['accuracy'] as num?)?.toDouble() ??
          (total > 0 ? correct / total : 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'chapter_id': chapterId,
        'chapter_name': chapterName,
        'subject_id': subjectId,
        'correct': correct,
        'total': total,
        'accuracy': accuracy,
      };
}

/// Per-difficulty accuracy breakdown.
class DifficultyBreakdown {
  final String difficulty;
  final int correct;
  final int total;
  final double accuracy;

  const DifficultyBreakdown({
    required this.difficulty,
    required this.correct,
    required this.total,
    required this.accuracy,
  });

  factory DifficultyBreakdown.fromJson(Map<String, dynamic> json) {
    final correct = json['correct'] as int? ?? 0;
    final total = json['total'] as int? ?? 0;
    return DifficultyBreakdown(
      difficulty: json['difficulty'] as String? ?? 'medium',
      correct: correct,
      total: total,
      accuracy: (json['accuracy'] as num?)?.toDouble() ??
          (total > 0 ? correct / total : 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty,
        'correct': correct,
        'total': total,
        'accuracy': accuracy,
      };
}

/// A detected weak or strong topic with score.
class TopicInsight {
  final String topicId;
  final String topicName;
  final String chapterId;
  final String chapterName;
  final String subjectId;
  final String subjectName;
  final double accuracy; // 0.0–1.0
  final int totalQuestions;
  final int correctAnswers;

  const TopicInsight({
    required this.topicId,
    required this.topicName,
    required this.chapterId,
    required this.chapterName,
    required this.subjectId,
    required this.subjectName,
    required this.accuracy,
    required this.totalQuestions,
    required this.correctAnswers,
  });

  int get scorePercentage => (accuracy * 100).round();

  factory TopicInsight.fromJson(Map<String, dynamic> json) {
    return TopicInsight(
      topicId: json['topic_id'] as String? ?? '',
      topicName: json['topic_name'] as String? ?? '',
      chapterId: json['chapter_id'] as String? ?? '',
      chapterName: json['chapter_name'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      correctAnswers: json['correct_answers'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'topic_id': topicId,
        'topic_name': topicName,
        'chapter_id': chapterId,
        'chapter_name': chapterName,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'accuracy': accuracy,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
      };
}

/// Aggregated topic-level performance (persisted in topic_performance table).
class TopicPerformance {
  final String topicId;
  final String chapterId;
  final String subjectId;
  final int totalQuestions;
  final int correctAnswers;
  final int totalTimeSeconds;
  final double avgTimeSeconds;
  final double accuracy;
  final String strength; // 'weak', 'moderate', 'strong'
  final DateTime? lastAttemptedAt;

  const TopicPerformance({
    required this.topicId,
    required this.chapterId,
    required this.subjectId,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalTimeSeconds,
    required this.avgTimeSeconds,
    required this.accuracy,
    required this.strength,
    this.lastAttemptedAt,
  });

  factory TopicPerformance.fromJson(Map<String, dynamic> json) {
    return TopicPerformance(
      topicId: json['topic_id'] as String,
      chapterId: json['chapter_id'] as String,
      subjectId: json['subject_id'] as String,
      totalQuestions: json['total_questions'] as int? ?? 0,
      correctAnswers: json['correct_answers'] as int? ?? 0,
      totalTimeSeconds: json['total_time_seconds'] as int? ?? 0,
      avgTimeSeconds:
          (json['avg_time_seconds'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      strength: json['strength'] as String? ?? 'moderate',
      lastAttemptedAt: json['last_attempted_at'] != null
          ? DateTime.parse(json['last_attempted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'topic_id': topicId,
        'chapter_id': chapterId,
        'subject_id': subjectId,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'total_time_seconds': totalTimeSeconds,
        'avg_time_seconds': avgTimeSeconds,
        'accuracy': accuracy,
        'strength': strength,
        'last_attempted_at': lastAttemptedAt?.toIso8601String(),
      };
}

/// A personalized study recommendation.
class Recommendation {
  final String? id;
  final String type; // 'weak_topic_drill', 'revision', 'challenge', 'chapter_test'
  final String title;
  final String? subtitle;
  final String? topicId;
  final String? chapterId;
  final String? subjectId;
  final int priority;
  final String? reason;
  final bool isDismissed;

  const Recommendation({
    this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.topicId,
    this.chapterId,
    this.subjectId,
    this.priority = 0,
    this.reason,
    this.isDismissed = false,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] as String?,
      type: json['type'] as String? ?? 'weak_topic_drill',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      topicId: json['topic_id'] as String?,
      chapterId: json['chapter_id'] as String?,
      subjectId: json['subject_id'] as String?,
      priority: json['priority'] as int? ?? 0,
      reason: json['reason'] as String?,
      isDismissed: json['is_dismissed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'topic_id': topicId,
        'chapter_id': chapterId,
        'subject_id': subjectId,
        'priority': priority,
        'reason': reason,
        'is_dismissed': isDismissed,
      };
}

/// A single score history entry for trend charts.
class ScoreHistoryEntry {
  final String attemptId;
  final String testId;
  final String? testName;
  final double scorePercentage;
  final Map<String, double> subjectScores;
  final DateTime completedAt;

  const ScoreHistoryEntry({
    required this.attemptId,
    required this.testId,
    this.testName,
    required this.scorePercentage,
    this.subjectScores = const {},
    required this.completedAt,
  });

  factory ScoreHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScoreHistoryEntry(
      attemptId: json['attempt_id'] as String,
      testId: json['test_id'] as String,
      testName: json['test_name'] as String?,
      scorePercentage:
          (json['score_percentage'] as num?)?.toDouble() ?? 0,
      subjectScores: _parseSubjectScores(json['subject_scores']),
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'attempt_id': attemptId,
        'test_id': testId,
        'test_name': testName,
        'score_percentage': scorePercentage,
        'subject_scores': subjectScores,
        'completed_at': completedAt.toIso8601String(),
      };

  static Map<String, double> _parseSubjectScores(dynamic data) {
    if (data == null || data is! Map) return {};
    return (data as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
  }
}

/// Study streak data.
class StudyStreak {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastStudyDate;
  final List<DayActivity> recentActivity; // last 30 days

  const StudyStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastStudyDate,
    this.recentActivity = const [],
  });

  factory StudyStreak.fromJson(Map<String, dynamic> json) {
    return StudyStreak(
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastStudyDate: json['last_study_date'] != null
          ? DateTime.parse(json['last_study_date'] as String)
          : null,
      recentActivity: _parseActivity(json['streak_history']),
    );
  }

  Map<String, dynamic> toJson() => {
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_study_date': lastStudyDate?.toIso8601String().split('T').first,
        'streak_history':
            recentActivity.map((a) => a.toJson()).toList(),
      };

  static List<DayActivity> _parseActivity(dynamic data) {
    if (data == null || data is! List) return [];
    return (data as List)
        .map((e) => DayActivity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Activity for a single day (used in streak_history).
class DayActivity {
  final DateTime date;
  final int testsTaken;

  const DayActivity({required this.date, required this.testsTaken});

  factory DayActivity.fromJson(Map<String, dynamic> json) {
    return DayActivity(
      date: DateTime.parse(json['date'] as String),
      testsTaken: json['tests_taken'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().split('T').first,
        'tests_taken': testsTaken,
      };
}
