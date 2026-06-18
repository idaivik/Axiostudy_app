import '../../test/domain/test_models.dart';

/// One wrong question on a results screen plus everything Feature 2 shows in its
/// breakdown card: the stored text explanation, the authored JPEG diagram, and
/// the data for the templated stat line. NO AI — all stored/computed values.
class QuestionBreakdown {
  final Question question;

  /// What the student picked (null/empty = left blank, though the mistakes list
  /// only surfaces answered-wrong questions).
  final String? selectedAnswer;

  /// Authored explanation JPEG (diagram + worked solution). Null until the
  /// content track backfills it → the card renders text-only.
  final String? explanationImageUrl;

  /// Human chapter name for the stat line (e.g. "Rotational Motion").
  final String? chapterName;

  /// The student's standing in this question's topic (0–1) from
  /// topic_performance, for "you're at 45% in this topic". Null when untracked.
  final double? topicAccuracy;

  const QuestionBreakdown({
    required this.question,
    this.selectedAnswer,
    this.explanationImageUrl,
    this.chapterName,
    this.topicAccuracy,
  });

  QuestionBreakdown copyWith({String? chapterName}) => QuestionBreakdown(
        question: question,
        selectedAnswer: selectedAnswer,
        explanationImageUrl: explanationImageUrl,
        chapterName: chapterName ?? this.chapterName,
        topicAccuracy: topicAccuracy,
      );

  bool get hasImage =>
      explanationImageUrl != null && explanationImageUrl!.trim().isNotEmpty;

  bool get hasExplanation =>
      question.explanation != null && question.explanation!.trim().isNotEmpty;

  int? get topicAccuracyPct =>
      topicAccuracy == null ? null : (topicAccuracy! * 100).round();
}
