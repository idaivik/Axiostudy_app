import '../../test/domain/test_models.dart';
import '../domain/analytics_models.dart';
import 'weakness_detector.dart';
import 'recommendation_engine.dart';
import 'analytics_repository.dart';

/// The main AI/Analytics Engine orchestrator.
///
/// After a test is submitted, this engine:
/// 1. Grades all answers (correct/wrong)
/// 2. Computes per-topic, per-chapter, per-subject, per-difficulty breakdowns
/// 3. Runs weakness detection (weighted scoring model)
/// 4. Generates personalized recommendations
/// 5. Updates score history and study streak
/// 6. Persists everything to Supabase
class AnalyticsEngine {
  final AnalyticsRepository _repository;
  final WeaknessDetector _weaknessDetector;
  final RecommendationEngine _recommendationEngine;

  AnalyticsEngine(this._repository)
      : _weaknessDetector = WeaknessDetector(),
        _recommendationEngine = RecommendationEngine();

  /// Process a completed test attempt and generate full analytics.
  ///
  /// This is the main entry point — call after test submission.
  Future<AttemptAnalyticsResult> processAttempt({
    required TestAttempt attempt,
    required List<Question> questions,
    required String testName,
  }) async {
    // ── Step 1: Grade answers ──
    final gradedAnswers = <String, bool>{};
    final timePerQuestion = <String, int>{};

    for (final q in questions) {
      final userAnswer = attempt.answers[q.id];
      if (userAnswer == null || !userAnswer.isAnswered) {
        gradedAnswers[q.id] = false;
      } else {
        gradedAnswers[q.id] =
            _evaluateAnswer(q, userAnswer.selectedAnswer!);
      }
      timePerQuestion[q.id] = userAnswer?.timeTaken.inSeconds ?? 0;
    }

    // ── Step 2: Compute score breakdown ──
    int totalCorrect = 0;
    int totalWrong = 0;
    int totalUnanswered = 0;

    for (final q in questions) {
      final userAnswer = attempt.answers[q.id];
      if (userAnswer == null || !userAnswer.isAnswered) {
        totalUnanswered++;
      } else if (gradedAnswers[q.id] == true) {
        totalCorrect++;
      } else {
        totalWrong++;
      }
    }

    final totalQuestions = questions.length;
    final accuracy =
        totalQuestions > 0 ? totalCorrect / totalQuestions : 0.0;

    // ── Step 3: Time analysis ──
    final allTimes =
        timePerQuestion.values.where((t) => t > 0).toList();
    final totalTimeSeconds = allTimes.fold(0, (a, b) => a + b);
    final avgTimePerQuestion =
        allTimes.isEmpty ? 0.0 : totalTimeSeconds / allTimes.length;
    final fastestQuestionSeconds =
        allTimes.isEmpty ? null : allTimes.reduce((a, b) => a < b ? a : b);
    final slowestQuestionSeconds =
        allTimes.isEmpty ? null : allTimes.reduce((a, b) => a > b ? a : b);

    // ── Step 4: Subject breakdown ──
    final subjectBreakdown = _computeSubjectBreakdown(
      questions,
      gradedAnswers,
      timePerQuestion,
    );

    // ── Step 5: Chapter breakdown ──
    final chapterBreakdown = _computeChapterBreakdown(
      questions,
      gradedAnswers,
    );

    // ── Step 6: Difficulty breakdown ──
    final difficultyBreakdown = _computeDifficultyBreakdown(
      questions,
      gradedAnswers,
    );

    // ── Step 7: Weakness detection ──
    final existingPerformance =
        await _repository.getTopicPerformanceMap(attempt.userId);

    final weaknessResult = _weaknessDetector.detect(
      gradedAnswers: gradedAnswers,
      questions: questions,
      existingPerformance: existingPerformance,
      timePerQuestion: timePerQuestion,
    );

    // ── Step 8: Generate recommendations ──
    // Merge existing performance with updated performance from this attempt
    final mergedPerformance = {
      ...existingPerformance,
      ...weaknessResult.updatedPerformance,
    };

    final recommendations = _recommendationEngine.generate(
      weakTopics: weaknessResult.weakTopics,
      strongTopics: weaknessResult.strongTopics,
      allTopicPerformance: mergedPerformance,
    );

    // ── Step 9: Build the analytics result ──
    final result = AttemptAnalyticsResult(
      attemptId: attempt.id,
      userId: attempt.userId,
      testId: attempt.testId,
      totalCorrect: totalCorrect,
      totalWrong: totalWrong,
      totalUnanswered: totalUnanswered,
      accuracy: accuracy,
      totalTimeSeconds: totalTimeSeconds,
      avgTimePerQuestion: avgTimePerQuestion,
      fastestQuestionSeconds: fastestQuestionSeconds,
      slowestQuestionSeconds: slowestQuestionSeconds,
      subjectBreakdown: subjectBreakdown,
      chapterBreakdown: chapterBreakdown,
      difficultyBreakdown: difficultyBreakdown,
      weakTopics: weaknessResult.weakTopics,
      strongTopics: weaknessResult.strongTopics,
      recommendations: recommendations,
      computedAt: DateTime.now(),
    );

    // ── Step 10: Persist everything ──
    await _persistResults(
      result: result,
      attempt: attempt,
      testName: testName,
      gradedAnswers: gradedAnswers,
      updatedPerformance: weaknessResult.updatedPerformance,
      recommendations: recommendations,
      subjectBreakdown: subjectBreakdown,
    );

    return result;
  }

  /// Grade a single answer against the correct answer.
  bool _evaluateAnswer(Question question, String selectedAnswer) {
    final correct = question.correctAnswer.trim().toLowerCase();
    final selected = selectedAnswer.trim().toLowerCase();
    return correct == selected;
  }

  /// Compute per-subject breakdown.
  Map<String, SubjectBreakdown> _computeSubjectBreakdown(
    List<Question> questions,
    Map<String, bool> gradedAnswers,
    Map<String, int> timePerQuestion,
  ) {
    final map = <String, _MutableBreakdown>{};

    for (final q in questions) {
      final entry = map.putIfAbsent(
        q.subjectId,
        () => _MutableBreakdown(id: q.subjectId),
      );
      entry.total++;
      entry.timeSeconds += timePerQuestion[q.id] ?? 0;
      if (gradedAnswers[q.id] == true) entry.correct++;
    }

    return map.map((k, v) => MapEntry(
          k,
          SubjectBreakdown(
            subjectId: k,
            subjectName: _subjectName(k),
            correct: v.correct,
            total: v.total,
            accuracy: v.total > 0 ? v.correct / v.total : 0,
            timeSeconds: v.timeSeconds,
          ),
        ));
  }

  /// Compute per-chapter breakdown.
  Map<String, ChapterBreakdown> _computeChapterBreakdown(
    List<Question> questions,
    Map<String, bool> gradedAnswers,
  ) {
    final map = <String, _MutableBreakdown>{};

    for (final q in questions) {
      final entry = map.putIfAbsent(
        q.chapterId,
        () => _MutableBreakdown(id: q.chapterId, parentId: q.subjectId),
      );
      entry.total++;
      if (gradedAnswers[q.id] == true) entry.correct++;
    }

    return map.map((k, v) => MapEntry(
          k,
          ChapterBreakdown(
            chapterId: k,
            chapterName: _chapterName(k),
            subjectId: v.parentId ?? '',
            correct: v.correct,
            total: v.total,
            accuracy: v.total > 0 ? v.correct / v.total : 0,
          ),
        ));
  }

  /// Compute per-difficulty breakdown.
  Map<String, DifficultyBreakdown> _computeDifficultyBreakdown(
    List<Question> questions,
    Map<String, bool> gradedAnswers,
  ) {
    final map = <String, _MutableBreakdown>{};

    for (final q in questions) {
      final diffStr = q.difficulty.name;
      final entry = map.putIfAbsent(
        diffStr,
        () => _MutableBreakdown(id: diffStr),
      );
      entry.total++;
      if (gradedAnswers[q.id] == true) entry.correct++;
    }

    return map.map((k, v) => MapEntry(
          k,
          DifficultyBreakdown(
            difficulty: k,
            correct: v.correct,
            total: v.total,
            accuracy: v.total > 0 ? v.correct / v.total : 0,
          ),
        ));
  }

  /// Persist all computed analytics to Supabase.
  Future<void> _persistResults({
    required AttemptAnalyticsResult result,
    required TestAttempt attempt,
    required String testName,
    required Map<String, bool> gradedAnswers,
    required Map<String, TopicPerformance> updatedPerformance,
    required List<Recommendation> recommendations,
    required Map<String, SubjectBreakdown> subjectBreakdown,
  }) async {
    // 1. Save attempt analytics
    await _repository.saveAttemptAnalytics(result);

    // 2. Update user_answers with is_correct flag
    await _repository.updateAnswerCorrectness(
      attemptId: attempt.id,
      gradedAnswers: gradedAnswers,
    );

    // 3. Upsert topic performance
    for (final perf in updatedPerformance.values) {
      await _repository.upsertTopicPerformance(
        userId: attempt.userId,
        performance: perf,
      );
    }

    // 4. Add score history entry
    final subjectScores = subjectBreakdown.map(
      (k, v) => MapEntry(k, v.accuracy * 100),
    );
    await _repository.addScoreHistoryEntry(
      userId: attempt.userId,
      entry: ScoreHistoryEntry(
        attemptId: attempt.id,
        testId: attempt.testId,
        testName: testName,
        scorePercentage: result.scorePercentage,
        subjectScores: subjectScores,
        completedAt: attempt.endTime ?? DateTime.now(),
      ),
    );

    // 5. Update study streak
    await _repository.updateStreak(attempt.userId);

    // 6. Save recommendations (clear old, insert new)
    await _repository.replaceRecommendations(
      userId: attempt.userId,
      recommendations: recommendations,
    );

    // 7. Update profile aggregate stats
    await _repository.updateProfileStats(attempt.userId);
  }

  static String _subjectName(String id) {
    switch (id) {
      case 'physics':
        return 'Physics';
      case 'chemistry':
        return 'Chemistry';
      case 'mathematics':
        return 'Mathematics';
      default:
        return id;
    }
  }

  static String _chapterName(String id) {
    final parts = id.split('_');
    if (parts.length >= 2) {
      return parts.sublist(1).map((s) {
        if (s.isEmpty) return s;
        return s[0].toUpperCase() + s.substring(1);
      }).join(' ');
    }
    return id;
  }
}

/// Mutable accumulator for computing breakdowns.
class _MutableBreakdown {
  final String id;
  final String? parentId;
  int correct = 0;
  int total = 0;
  int timeSeconds = 0;

  _MutableBreakdown({required this.id, this.parentId});
}
