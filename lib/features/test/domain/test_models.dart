import '../../../shared/models/enums.dart';

/// A single question in the question bank.
class Question {
  final String id;
  final String text;
  final QuestionType type;
  final List<String>? options;
  final String correctAnswer;
  final String? imageUrl;
  final String subjectId;
  final String chapterId;
  final String topicId;
  final Difficulty difficulty;
  final String? explanation;

  const Question({
    required this.id,
    required this.text,
    required this.type,
    this.options,
    required this.correctAnswer,
    this.imageUrl,
    required this.subjectId,
    required this.chapterId,
    required this.topicId,
    required this.difficulty,
    this.explanation,
  });
}

/// A test (diagnostic, practice, or mock).
class Test {
  final String id;
  final String name;
  final TestType type;
  final Duration duration;
  final int totalQuestions;
  final List<String> subjectIds;
  final List<Question> questions;

  const Test({
    required this.id,
    required this.name,
    required this.type,
    required this.duration,
    required this.totalQuestions,
    required this.subjectIds,
    required this.questions,
  });
}

/// A user's answer to a single question.
class UserAnswer {
  final String questionId;
  final String? selectedAnswer;
  final Duration timeTaken;
  final bool markedForReview;

  const UserAnswer({
    required this.questionId,
    this.selectedAnswer,
    this.timeTaken = Duration.zero,
    this.markedForReview = false,
  });

  UserAnswer copyWith({
    String? questionId,
    String? selectedAnswer,
    Duration? timeTaken,
    bool? markedForReview,
  }) {
    return UserAnswer(
      questionId: questionId ?? this.questionId,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
      timeTaken: timeTaken ?? this.timeTaken,
      markedForReview: markedForReview ?? this.markedForReview,
    );
  }

  bool get isAnswered => selectedAnswer != null && selectedAnswer!.isNotEmpty;
}

/// A complete test attempt by a user.
class TestAttempt {
  final String id;
  final String userId;
  final String testId;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, UserAnswer> answers;
  final int? score;
  final int? totalMarks;
  final TestAttemptStatus status;

  const TestAttempt({
    required this.id,
    required this.userId,
    required this.testId,
    required this.startTime,
    this.endTime,
    this.answers = const {},
    this.score,
    this.totalMarks,
    this.status = TestAttemptStatus.inProgress,
  });

  TestAttempt copyWith({
    String? id,
    String? userId,
    String? testId,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, UserAnswer>? answers,
    int? score,
    int? totalMarks,
    TestAttemptStatus? status,
  }) {
    return TestAttempt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      testId: testId ?? this.testId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      answers: answers ?? this.answers,
      score: score ?? this.score,
      totalMarks: totalMarks ?? this.totalMarks,
      status: status ?? this.status,
    );
  }

  double get scorePercentage {
    if (score == null || totalMarks == null || totalMarks == 0) return 0;
    return (score! / totalMarks!) * 100;
  }

  int get answeredCount =>
      answers.values.where((a) => a.isAnswered).length;

  int get markedForReviewCount =>
      answers.values.where((a) => a.markedForReview).length;
}
