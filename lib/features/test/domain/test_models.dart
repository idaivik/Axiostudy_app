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

  /// Create from Supabase `questions` row.
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      text: json['text'] as String,
      type: json['type'] == 'mcq' ? QuestionType.mcq : QuestionType.numerical,
      options: json['options'] != null
          ? (json['options'] as List).map((e) => e.toString()).toList()
          : null,
      correctAnswer: json['correct_answer'] as String,
      imageUrl: json['image_url'] as String?,
      subjectId: json['subject_id'] as String,
      chapterId: json['chapter_id'] as String,
      topicId: json['topic_id'] as String,
      difficulty: _parseDifficulty(json['difficulty'] as String),
      explanation: json['explanation'] as String?,
    );
  }

  static Difficulty _parseDifficulty(String d) {
    switch (d) {
      case 'easy':
        return Difficulty.easy;
      case 'medium':
        return Difficulty.medium;
      case 'hard':
        return Difficulty.hard;
      default:
        return Difficulty.medium;
    }
  }
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

  /// Target exam this test belongs to: `'jee'`, `'neet'`, or `'both'`
  /// (mirrors `tests.exam_type`). Drives the JEE/NEET separation in the
  /// Mock Tests list — a `'both'` test is shown to every student.
  final String examType;

  /// For an on-the-fly subtopic "Practice Test N" session: the subtopic it
  /// drills and the 1-based test index. Null for mock/diagnostic/adaptive
  /// sessions. Carried onto the [TestAttempt] so the roadmap can auto-complete
  /// a chapter once every subtopic clears enough passing tests.
  final String? subtopicId;
  final int? testIndex;

  const Test({
    required this.id,
    required this.name,
    required this.type,
    required this.duration,
    required this.totalQuestions,
    required this.subjectIds,
    required this.questions,
    this.examType = 'both',
    this.subtopicId,
    this.testIndex,
  });

  /// Whether this test should be shown to a student preparing for [userExam]
  /// (whose `name` is `'jee'`/`'neet'`). A `'both'` test always matches; a null
  /// exam (not yet onboarded) sees everything.
  bool matchesExam(String? userExam) =>
      userExam == null || examType == 'both' || examType == userExam;

  /// Create from Supabase `tests` row.
  /// Questions must be joined or provided separately.
  factory Test.fromJson(Map<String, dynamic> json, {List<Question>? questions}) {
    return Test(
      id: json['id'] as String,
      name: json['name'] as String,
      type: _parseTestType(json['type'] as String),
      duration: Duration(minutes: json['duration_minutes'] as int? ?? 60),
      totalQuestions: json['total_questions'] as int? ?? 0,
      subjectIds: json['subject_ids'] != null
          ? (json['subject_ids'] as List).map((e) => e.toString()).toList()
          : [],
      examType: (json['exam_type'] as String?) ?? 'both',
      questions: questions ?? [],
    );
  }

  static TestType _parseTestType(String t) {
    switch (t) {
      case 'diagnostic':
        return TestType.diagnostic;
      case 'practice':
        return TestType.practice;
      case 'mock':
        return TestType.mock;
      default:
        return TestType.practice;
    }
  }
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

  /// Create from Supabase `user_answers` row.
  factory UserAnswer.fromJson(Map<String, dynamic> json) {
    return UserAnswer(
      questionId: json['question_id'] as String,
      selectedAnswer: json['selected_answer'] as String?,
      timeTaken: Duration(seconds: json['time_taken_seconds'] as int? ?? 0),
      markedForReview: json['marked_for_review'] as bool? ?? false,
    );
  }

  /// Convert to JSON for Supabase insert.
  Map<String, dynamic> toJson(String attemptId) {
    return {
      'attempt_id': attemptId,
      'question_id': questionId,
      'selected_answer': selectedAnswer,
      'time_taken_seconds': timeTaken.inSeconds,
      'marked_for_review': markedForReview,
    };
  }

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

  /// Subtopic + 1-based test index this attempt drilled, when it was launched
  /// as a subtopic "Practice Test N" (null otherwise). Drives roadmap
  /// auto-completion via `roadmap_chapter_progress()`.
  final String? subtopicId;
  final int? testIndex;

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
    this.subtopicId,
    this.testIndex,
  });

  /// Create from Supabase `test_attempts` row.
  /// Answers must be loaded separately and merged.
  factory TestAttempt.fromJson(Map<String, dynamic> json, {Map<String, UserAnswer>? answers}) {
    return TestAttempt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      testId: json['test_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      score: json['score'] as int?,
      totalMarks: json['total_marks'] as int?,
      status: _parseStatus(json['status'] as String?),
      subtopicId: json['subtopic_id'] as String?,
      testIndex: json['test_index'] as int?,
      answers: answers ?? {},
    );
  }

  /// Convert to JSON for Supabase insert. The subtopic columns are only emitted
  /// for subtopic tests, so mock/adaptive inserts stay schema-compatible.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'test_id': testId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'score': score,
      'total_marks': totalMarks,
      'status': _statusToString(status),
      if (subtopicId != null) 'subtopic_id': subtopicId,
      if (testIndex != null) 'test_index': testIndex,
    };
  }

  static TestAttemptStatus _parseStatus(String? s) {
    switch (s) {
      case 'in_progress':
        return TestAttemptStatus.inProgress;
      case 'submitted':
        return TestAttemptStatus.submitted;
      case 'analyzed':
        return TestAttemptStatus.analyzed;
      default:
        return TestAttemptStatus.inProgress;
    }
  }

  static String _statusToString(TestAttemptStatus status) {
    switch (status) {
      case TestAttemptStatus.inProgress:
        return 'in_progress';
      case TestAttemptStatus.submitted:
        return 'submitted';
      case TestAttemptStatus.analyzed:
        return 'analyzed';
    }
  }

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
    String? subtopicId,
    int? testIndex,
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
      subtopicId: subtopicId ?? this.subtopicId,
      testIndex: testIndex ?? this.testIndex,
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
