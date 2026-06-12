import 'package:flutter/material.dart';
import '../../../shared/models/enums.dart';

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

  const Chapter({
    required this.id,
    required this.name,
    required this.subjectId,
    required this.topics,
    this.completionPercentage = 0,
    this.availableQuestions = 0,
    this.strength = TopicStrength.moderate,
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
