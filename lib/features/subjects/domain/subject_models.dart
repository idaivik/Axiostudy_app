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
  String get icon => type.icon;
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
}
