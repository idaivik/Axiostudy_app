import '../../../shared/models/enums.dart';

/// Data point for the Radar Chart (Subject Mastery).
class RadarDataPoint {
  final String label;
  final double value; // 0.0–1.0
  final String topicId;

  const RadarDataPoint({
    required this.label,
    required this.value,
    required this.topicId,
  });
}

/// Data point for the Scatter Plot (Speed vs. Accuracy).
class ScatterDataPoint {
  final String topicName;
  final String topicId;
  final String subjectId;
  final double accuracy;       // 0.0–1.0
  final double avgTimeSeconds; // average time per question

  const ScatterDataPoint({
    required this.topicName,
    required this.topicId,
    required this.subjectId,
    required this.accuracy,
    required this.avgTimeSeconds,
  });

  /// Quadrant classification for color coding.
  ScatterQuadrant get quadrant {
    final fast = avgTimeSeconds <= 60; // under 1 min = fast
    final accurate = accuracy >= 0.6;   // 60%+ = accurate
    if (fast && accurate) return ScatterQuadrant.mastered;
    if (!fast && accurate) return ScatterQuadrant.slowButSteady;
    if (fast && !accurate) return ScatterQuadrant.guessing;
    return ScatterQuadrant.needsReview;
  }
}

enum ScatterQuadrant {
  mastered,       // fast + accurate (top-right)
  slowButSteady,  // slow + accurate (top-left)
  guessing,       // fast + inaccurate (bottom-right)
  needsReview,    // slow + inaccurate (bottom-left)
}

/// A node in the Skill Tree (Prerequisite Diagram).
class SkillTreeNode {
  final String topicId;
  final String label;
  final String subjectId;
  final TopicStrength strength;
  final List<String> prerequisiteIds; // topic_ids this depends on
  final double accuracy;

  const SkillTreeNode({
    required this.topicId,
    required this.label,
    required this.subjectId,
    required this.strength,
    this.prerequisiteIds = const [],
    this.accuracy = 0,
  });

  /// Whether prerequisites are all mastered.
  bool get isBlocked => strength == TopicStrength.weak;
  bool get isMastered => strength == TopicStrength.strong;
}

/// A prerequisite edge from the database.
class TopicPrerequisite {
  final String topicId;
  final String chapterId;
  final String subjectId;
  final String prerequisiteTopicId;
  final String prerequisiteChapterId;
  final String prerequisiteSubjectId;

  const TopicPrerequisite({
    required this.topicId,
    required this.chapterId,
    required this.subjectId,
    required this.prerequisiteTopicId,
    required this.prerequisiteChapterId,
    required this.prerequisiteSubjectId,
  });

  factory TopicPrerequisite.fromJson(Map<String, dynamic> json) {
    return TopicPrerequisite(
      topicId: json['topic_id'] as String,
      chapterId: json['chapter_id'] as String,
      subjectId: json['subject_id'] as String,
      prerequisiteTopicId: json['prerequisite_topic_id'] as String,
      prerequisiteChapterId: json['prerequisite_chapter_id'] as String,
      prerequisiteSubjectId: json['prerequisite_subject_id'] as String,
    );
  }
}

/// Data point for the Area Line Chart (Score Trend).
class TrendDataPoint {
  final DateTime date;
  final double score; // 0–100
  final String? testName;

  const TrendDataPoint({
    required this.date,
    required this.score,
    this.testName,
  });
}
