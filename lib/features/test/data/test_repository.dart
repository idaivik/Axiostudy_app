import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/test_models.dart';
import '../../../shared/models/enums.dart';
import '../../analytics/data/analytics_engine.dart';
import '../../analytics/domain/analytics_models.dart';

/// Repository for test operations against Supabase.
class TestRepository {
  final SupabaseClient _client;

  TestRepository(this._client);

  /// Fetch available tests (without questions), ready for the Mock Tests list.
  ///
  /// - [examType] (`'jee'`/`'neet'`): keeps only tests for that exam plus any
  ///   `'both'` test. Pass null (not yet onboarded) to get everything.
  /// - Tests with **no linked questions** are dropped: an empty test cannot be
  ///   run (the runner would have nothing to show) and is almost always stale
  ///   seed data, e.g. the legacy `test_diag_001` duplicate. The dynamic
  ///   `adaptive_practice` test also has no fixed questions, so it is excluded
  ///   here too — it is launched from its own entry point, never this list.
  Future<List<Test>> getTests({String? examType}) async {
    final data = await _client.from('tests').select().order('created_at');

    // One round-trip for the question counts, tallied client-side.
    final links = await _client.from('test_questions').select('test_id');
    final counts = <String, int>{};
    for (final row in links) {
      final id = row['test_id'] as String?;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }

    return data
        .map((json) => Test.fromJson(json))
        .where((t) => (counts[t.id] ?? 0) > 0 && t.matchesExam(examType))
        .toList();
  }

  /// Fetch a single test with all its questions (joined via test_questions).
  Future<Test> getTestWithQuestions(String testId) async {
    // Get the test metadata
    final testData = await _client
        .from('tests')
        .select()
        .eq('id', testId)
        .single();

    // Get question IDs in order
    final testQuestions = await _client
        .from('test_questions')
        .select('question_id, question_order')
        .eq('test_id', testId)
        .order('question_order');

    final questionIds = testQuestions
        .map((tq) => tq['question_id'] as String)
        .toList();

    // Fetch the actual questions
    List<Question> questions = [];
    if (questionIds.isNotEmpty) {
      final questionsData = await _client
          .from('questions')
          .select()
          .inFilter('id', questionIds);

      // Build a map for ordering
      final questionMap = <String, Question>{};
      for (final q in questionsData) {
        final question = Question.fromJson(q);
        questionMap[question.id] = question;
      }

      // Return in the correct order
      questions = questionIds
          .where((id) => questionMap.containsKey(id))
          .map((id) => questionMap[id]!)
          .toList();
    }

    return Test.fromJson(testData, questions: questions);
  }

  /// Create a new test attempt. For subtopic "Practice Test N" sessions, pass
  /// [subtopicId] + [testIndex] so the attempt is tagged for roadmap
  /// auto-completion (null for mock/adaptive/diagnostic attempts).
  Future<TestAttempt> createAttempt({
    required String userId,
    required String testId,
    required int totalMarks,
    String? subtopicId,
    int? testIndex,
  }) async {
    final id = 'attempt_${const Uuid().v4().substring(0, 8)}';
    final attempt = TestAttempt(
      id: id,
      userId: userId,
      testId: testId,
      startTime: DateTime.now(),
      totalMarks: totalMarks,
      status: TestAttemptStatus.inProgress,
      subtopicId: subtopicId,
      testIndex: testIndex,
    );

    await _client.from('test_attempts').insert(attempt.toJson());
    return attempt;
  }

  /// Submit a completed test attempt — saves answers and updates attempt.
  Future<void> submitAttempt(TestAttempt attempt) async {
    // Update the attempt record
    await _client
        .from('test_attempts')
        .update({
          'end_time': attempt.endTime?.toIso8601String(),
          'score': attempt.score,
          'total_marks': attempt.totalMarks,
          'status': 'submitted',
        })
        .eq('id', attempt.id);

    // Insert all answers
    if (attempt.answers.isNotEmpty) {
      final answersJson = attempt.answers.values
          .map((a) => a.toJson(attempt.id))
          .toList();
      await _client.from('user_answers').upsert(answersJson);
    }
  }

  /// Submit a test attempt AND run the AI analytics engine.
  ///
  /// This is the primary method to use — it persists the attempt,
  /// then processes it through the analytics pipeline (weakness detection,
  /// recommendations, score history, streak, profile stats).
  ///
  /// Returns the computed analytics result.
  Future<AttemptAnalyticsResult?> submitAndAnalyze({
    required TestAttempt attempt,
    required List<Question> questions,
    required String testName,
    required AnalyticsEngine analyticsEngine,
  }) async {
    // 1. Submit the attempt (persist answers + update status)
    await submitAttempt(attempt);

    // 2. Run the local analytics engine.
    //    This stays primary for the legacy tables (attempt_analytics,
    //    topic_performance, score_history, streak, recommendations, profile)
    //    AND is the offline/failure fallback per the hybrid design.
    try {
      final result = await analyticsEngine.processAttempt(
        attempt: attempt,
        questions: questions,
        testName: testName,
      );

      // 3. Mark attempt as analyzed
      await _client
          .from('test_attempts')
          .update({'status': 'analyzed'})
          .eq('id', attempt.id);

      // 4. Additive server-side layer: chapter-level analytics + the one
      //    gated AI insight call (compute-analytics edge function). Writes
      //    chapter_analytics + user_weak_chapters and caches the grade summary
      //    on the attempt. Never blocks submission — on any failure the local
      //    result above already stands.
      await runServerAnalytics(attempt.id);

      return result;
    } catch (e) {
      // Analytics failure should not block test submission
      // The attempt is already saved — analytics can be retried
      // ignore: avoid_print
      print('Analytics engine error: $e');
      return null;
    }
  }

  /// Invoke the `compute-analytics` edge function for [attemptId].
  ///
  /// Returns the parsed insight payload (`{ ok, ai_used, chapters, ... }`) on
  /// success, or `null` if the function is unavailable or errors — the caller
  /// must treat this as best-effort and never let it block the user.
  Future<Map<String, dynamic>?> runServerAnalytics(String attemptId) async {
    try {
      final res = await _client.functions.invoke(
        'compute-analytics',
        body: {'attempt_id': attemptId},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (e) {
      // Edge function not deployed / network / AI error — degrade silently.
      // ignore: avoid_print
      print('compute-analytics edge function unavailable: $e');
      return null;
    }
  }

  /// Fetch a completed test attempt with its answers.
  Future<TestAttempt> getAttemptWithAnswers(String attemptId) async {
    final attemptData = await _client
        .from('test_attempts')
        .select()
        .eq('id', attemptId)
        .single();

    final answersData = await _client
        .from('user_answers')
        .select()
        .eq('attempt_id', attemptId);

    final answers = <String, UserAnswer>{};
    for (final a in answersData) {
      final answer = UserAnswer.fromJson(a);
      answers[answer.questionId] = answer;
    }

    return TestAttempt.fromJson(attemptData, answers: answers);
  }

  /// Get all attempts by a user.
  Future<List<TestAttempt>> getUserAttempts(String userId) async {
    final data = await _client
        .from('test_attempts')
        .select()
        .eq('user_id', userId)
        .order('start_time', ascending: false);

    return data.map((json) => TestAttempt.fromJson(json)).toList();
  }
}

