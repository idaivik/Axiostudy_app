import 'package:flutter/material.dart';
import '../../../shared/models/enums.dart';
import 'chapter_grade.dart';

/// A subject (Physics, Chemistry, Mathematics).
class Subject {
  final String id;
  final SubjectType type;
  final List<Chapter> chapters;
  final double completionPercentage;
  final int totalQuestions;

  const Subject({
    required this.id,
    required this.type,
    required this.chapters,
    this.completionPercentage = 0,
    this.totalQuestions = 0,
  });

  String get name => type.label;
  IconData get iconData => type.iconData;

  /// Create from Supabase `subjects` row.
  /// Chapters must be joined or provided separately.
  factory Subject.fromJson(Map<String, dynamic> json, {List<Chapter>? chapters}) {
    return Subject(
      id: json['id'] as String,
      type: _parseSubjectType(json['type'] as String),
      totalQuestions: json['total_questions'] as int? ?? 0,
      chapters: chapters ?? [],
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  static SubjectType _parseSubjectType(String type) {
    switch (type) {
      case 'physics':
        return SubjectType.physics;
      case 'chemistry':
        return SubjectType.chemistry;
      case 'mathematics':
        return SubjectType.mathematics;
      case 'biology':
        return SubjectType.biology;
      default:
        return SubjectType.physics;
    }
  }
}

/// A chapter within a subject.
class Chapter {
  final String id;
  final String name;
  final String subjectId;
  final List<Topic> topics;
  final double completionPercentage;
  final int availableQuestions;
  final TopicStrength strength;

  /// Which school class (11/12) this chapter belongs to. Sourced from
  /// `chapters.class_level`, falling back to the id-derived mapping.
  final ClassLevel classLevel;

  const Chapter({
    required this.id,
    required this.name,
    required this.subjectId,
    required this.topics,
    this.completionPercentage = 0,
    this.availableQuestions = 0,
    this.strength = TopicStrength.moderate,
    this.classLevel = ClassLevel.class11,
  });

  /// Create from Supabase `chapters` row.
  factory Chapter.fromJson(Map<String, dynamic> json, {List<Topic>? topics, double? completionPercentage, TopicStrength? strength}) {
    return Chapter(
      id: json['id'] as String,
      name: json['name'] as String,
      subjectId: json['subject_id'] as String,
      availableQuestions: json['available_questions'] as int? ?? 0,
      topics: topics ?? [],
      completionPercentage: completionPercentage ?? 0,
      strength: strength ?? TopicStrength.moderate,
      classLevel: classLevelFromDb(json['class_level'] as String?, json['id'] as String),
    );
  }
}

/// A topic within a chapter.
class Topic {
  final String id;
  final String name;
  final String chapterId;
  final double completionPercentage;
  final TopicStrength strength;
  final int availableQuestions;

  const Topic({
    required this.id,
    required this.name,
    required this.chapterId,
    this.completionPercentage = 0,
    this.strength = TopicStrength.moderate,
    this.availableQuestions = 0,
  });

  /// Create from Supabase `topics` row.
  factory Topic.fromJson(Map<String, dynamic> json, {double? completionPercentage, TopicStrength? strength}) {
    return Topic(
      id: json['id'] as String,
      name: json['name'] as String,
      chapterId: json['chapter_id'] as String,
      availableQuestions: json['available_questions'] as int? ?? 0,
      completionPercentage: completionPercentage ?? 0,
      strength: strength ?? TopicStrength.moderate,
    );
  }

  static TopicStrength parseStrength(String? s) {
    switch (s) {
      case 'weak':
        return TopicStrength.weak;
      case 'strong':
        return TopicStrength.strong;
      default:
        return TopicStrength.moderate;
    }
  }
}

/// A subtopic within a topic — the level practice tests are grouped under.
/// Questions carry `subtopic_id`; each subtopic's questions are chunked into
/// named "Practice Test N" sets (see PracticeRepository.subtopicTests).
class Subtopic {
  final String id;
  final String name;
  final String topicId;
  final String? chapterId;
  final String? subjectId;

  /// Counts of `active`/servable questions tagged to this subtopic, by
  /// difficulty — merged in from an aggregate over `questions`. These drive how
  /// many "Practice Test N" sets the subtopic yields.
  final int easyCount;
  final int mediumCount;
  final int hardCount;

  const Subtopic({
    required this.id,
    required this.name,
    required this.topicId,
    this.chapterId,
    this.subjectId,
    this.easyCount = 0,
    this.mediumCount = 0,
    this.hardCount = 0,
  });

  int get questionCount => easyCount + mediumCount + hardCount;

  /// Create from a Supabase `subtopics` row. Difficulty counts are merged in
  /// separately from an aggregate over `questions`.
  factory Subtopic.fromJson(
    Map<String, dynamic> json, {
    int easyCount = 0,
    int mediumCount = 0,
    int hardCount = 0,
  }) {
    return Subtopic(
      id: json['id'] as String,
      name: json['name'] as String,
      topicId: json['topic_id'] as String,
      chapterId: json['chapter_id'] as String?,
      subjectId: json['subject_id'] as String?,
      easyCount: easyCount,
      mediumCount: mediumCount,
      hardCount: hardCount,
    );
  }
}
