import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../test/domain/test_models.dart';
import '../../../shared/models/enums.dart';
import '../domain/practice_models.dart';

/// The practice engine's data layer (Phase 2/3).
///
/// Default practice is **retrieval from the existing pool via plain SQL — zero
/// LLM cost.** The single paid path (`generateQuestions`) is delegated to the
/// `generate-questions` edge function so the LLM key stays server-side.
class PracticeRepository {
  final SupabaseClient _client;
  PracticeRepository(this._client);

  /// The sentinel `tests` row every adaptive attempt references (FK target).
  static const String adaptiveTestId = 'adaptive_practice';

  // ── Difficulty bands ──────────────────────────────────────────────────────

  /// Difficulty window for a 0–100 mastery score (start easy, ramp up).
  static DifficultyBand bandForMastery(double masteryScore) {
    if (masteryScore < 35) return const DifficultyBand(lo: 1, hi: 3, label: 'easy');
    if (masteryScore <= 65) return const DifficultyBand(lo: 3, hi: 6, label: 'medium');
    return const DifficultyBand(lo: 6, hi: 8, label: 'hard');
  }

  static DifficultyBand bandForLabel(String label) {
    switch (label) {
      case 'easy':
        return const DifficultyBand(lo: 1, hi: 3, label: 'easy');
      case 'hard':
        return const DifficultyBand(lo: 6, hi: 9, label: 'hard');
      default:
        return const DifficultyBand(lo: 3, hi: 6, label: 'medium');
    }
  }

  /// Shift a difficulty label by [delta] steps (−1 easier … +1 harder).
  static String shiftDifficulty(String label, int delta) {
    const order = ['easy', 'medium', 'hard'];
    final i = order.indexOf(label);
    final next = ((i < 0 ? 1 : i) + delta).clamp(0, order.length - 1);
    return order[next];
  }

  // ── Pool retrieval (free SQL) ─────────────────────────────────────────────

  /// Question IDs the user has already answered (so we don't re-serve them).
  Future<Set<String>> seenQuestionIds(String userId, {int limit = 500}) async {
    try {
      final data = await _client
          .from('user_answers')
          .select('question_id, test_attempts!inner(user_id)')
          .eq('test_attempts.user_id', userId)
          .limit(limit);
      return data.map((r) => r['question_id'] as String).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Retrieve `active`-pool questions matching chapters + a difficulty band,
  /// excluding already-seen IDs. Over-fetches then shuffles for variety.
  Future<List<Question>> retrieveFromPool({
    required List<String> chapterIds,
    required int loLevel,
    required int hiLevel,
    Set<String> exclude = const {},
    int limit = 10,
  }) async {
    if (chapterIds.isEmpty) return [];
    final data = await _client
        .from('questions')
        .select()
        .inFilter('chapter_id', chapterIds)
        .eq('status', 'active')
        .gte('difficulty_level', loLevel)
        .lte('difficulty_level', hiLevel)
        .limit(limit * 5);
    var qs = data.map((j) => Question.fromJson(j)).toList();
    if (exclude.isNotEmpty) {
      qs = qs.where((q) => !exclude.contains(q.id)).toList();
    }
    qs.shuffle();
    return qs.take(limit).toList();
  }

  // ── Adaptive session (Phase 3) ────────────────────────────────────────────

  /// Build a practice session from the user's top weak chapters, each at a
  /// difficulty band derived from its mastery score (weakest → easiest start).
  /// Falls back to a broad medium set when there are no weak chapters yet.
  Future<Test> buildAdaptiveSession({int perChapter = 4, int maxChapters = 3}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');

    final weakRows = await _client
        .from('user_weak_chapters')
        .select('chapter_id, subject_id, weakness_score')
        .eq('user_id', userId)
        .eq('status', 'weak')
        .order('weakness_score', ascending: true)
        .limit(maxChapters);

    final seen = await seenQuestionIds(userId);
    final questions = <Question>[];

    for (final row in weakRows) {
      final chapterId = row['chapter_id'] as String;
      final score = (row['weakness_score'] as num?)?.toDouble() ?? 0;
      final band = bandForMastery(score);
      questions.addAll(await retrieveFromPool(
        chapterIds: [chapterId],
        loLevel: band.lo,
        hiLevel: band.hi,
        exclude: seen,
        limit: perChapter,
      ));
    }

    // No weak chapters identified yet → broad medium-difficulty warm-up.
    if (questions.isEmpty) {
      final data = await _client
          .from('questions')
          .select()
          .eq('status', 'active')
          .gte('difficulty_level', 3)
          .lte('difficulty_level', 6)
          .limit(60);
      final pool = data.map((j) => Question.fromJson(j)).toList()
        ..removeWhere((q) => seen.contains(q.id))
        ..shuffle();
      questions.addAll(pool.take(perChapter * 2));
    }

    questions.shuffle();
    return _sessionTest(questions, 'AI Adaptive Practice');
  }

  /// "More questions like this" — kept within the same weak chapter, at an
  /// adjusted difficulty (−1 easier / 0 same / +1 harder).
  Future<Test> moreLikeThis({
    required String chapterId,
    required String currentDifficulty,
    required int delta,
    Set<String> exclude = const {},
    int count = 5,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final target = shiftDifficulty(currentDifficulty, delta);
    final band = bandForLabel(target);
    final seen = <String>{
      ...exclude,
      if (userId != null) ...await seenQuestionIds(userId),
    };
    final qs = await retrieveFromPool(
      chapterIds: [chapterId],
      loLevel: band.lo,
      hiLevel: band.hi,
      exclude: seen,
      limit: count,
    );
    final label = '${target[0].toUpperCase()}${target.substring(1)}';
    return _sessionTest(qs, 'Practice · $label');
  }

  Test _sessionTest(
    List<Question> questions,
    String name, {
    String? subtopicId,
    int? testIndex,
  }) {
    final mins = (questions.length * 1.5).ceil().clamp(5, 60);
    return Test(
      id: adaptiveTestId,
      name: name,
      type: TestType.practice,
      duration: Duration(minutes: mins),
      totalQuestions: questions.length,
      subjectIds: questions.map((q) => q.subjectId).toSet().toList(),
      questions: questions,
      subtopicId: subtopicId,
      testIndex: testIndex,
    );
  }

  // ── Subtopic practice tests (fixed 10/10/10 named sets) ────────────────────

  /// Questions per difficulty band in a full test.
  static const int _testBand = 10;

  /// Group a subtopic's question COUNTS into named tests. Each full test is
  /// 10 easy + 10 medium + 10 hard; once the full sets are used up the leftover
  /// questions form a final, smaller test — e.g. (E25,M30,H22) → [30, 30, 17].
  static List<SubtopicTest> testsFromCounts(int easy, int medium, int hard) {
    final full = [easy, medium, hard].reduce(min) ~/ _testBand;
    final tests = <SubtopicTest>[];
    for (var k = 0; k < full; k++) {
      tests.add(SubtopicTest(
        index: k + 1,
        questionCount: _testBand * 3,
        easyCount: _testBand,
        mediumCount: _testBand,
        hardCount: _testBand,
      ));
    }
    final remE = easy - full * _testBand;
    final remM = medium - full * _testBand;
    final remH = hard - full * _testBand;
    if (remE + remM + remH > 0) {
      tests.add(SubtopicTest(
        index: full + 1,
        questionCount: remE + remM + remH,
        easyCount: remE,
        mediumCount: remM,
        hardCount: remH,
      ));
    }
    return tests;
  }

  /// Descriptor list of the named tests available for a subtopic (counts only).
  Future<List<SubtopicTest>> subtopicTests(String subtopicId) async {
    final rows = await _client
        .from('questions')
        .select('difficulty')
        .eq('subtopic_id', subtopicId)
        .eq('status', 'active');
    var e = 0, m = 0, h = 0;
    for (final r in rows) {
      switch (r['difficulty']) {
        case 'easy':
          e++;
        case 'hard':
          h++;
        default:
          m++;
      }
    }
    return testsFromCounts(e, m, h);
  }

  /// Build the [testIndex]-th (1-based) named practice test for a subtopic — a
  /// fixed 10/10/10 set (or the smaller remainder for the last test). Unlike
  /// adaptive practice these are stable/repeatable, so already-seen questions are
  /// NOT excluded.
  Future<Test> buildSubtopicTest({
    required String subtopicId,
    required int testIndex,
    String? subtopicName,
  }) async {
    final data = await _client
        .from('questions')
        .select()
        .eq('subtopic_id', subtopicId)
        .eq('status', 'active');
    final all = data.map((j) => Question.fromJson(j)).toList();

    List<Question> band(Difficulty d) =>
        all.where((q) => q.difficulty == d).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final groups = _groupQuestions(
      band(Difficulty.easy),
      band(Difficulty.medium),
      band(Difficulty.hard),
    );

    final name = subtopicName == null
        ? 'Practice Test $testIndex'
        : '$subtopicName · Test $testIndex';
    if (testIndex < 1 || testIndex > groups.length) {
      return _sessionTest(const [], name,
          subtopicId: subtopicId, testIndex: testIndex);
    }
    return _sessionTest(groups[testIndex - 1], name,
        subtopicId: subtopicId, testIndex: testIndex);
  }

  /// Chunk difficulty-sorted question lists into tests (mirrors [testsFromCounts]).
  List<List<Question>> _groupQuestions(
    List<Question> easy,
    List<Question> medium,
    List<Question> hard,
  ) {
    final full =
        [easy.length, medium.length, hard.length].reduce(min) ~/ _testBand;
    final groups = <List<Question>>[];
    for (var k = 0; k < full; k++) {
      groups.add([
        ...easy.sublist(k * _testBand, (k + 1) * _testBand),
        ...medium.sublist(k * _testBand, (k + 1) * _testBand),
        ...hard.sublist(k * _testBand, (k + 1) * _testBand),
      ]);
    }
    final used = full * _testBand;
    final remaining = [
      ...easy.sublist(used),
      ...medium.sublist(used),
      ...hard.sublist(used),
    ];
    if (remaining.isNotEmpty) groups.add(remaining);
    return groups;
  }

  // ── Generation (the only paid path) ───────────────────────────────────────

  Future<GenerationResult> generateQuestions({
    required String chapterId,
    String difficulty = 'medium',
    int count = 3,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'generate-questions',
        body: {'chapter_id': chapterId, 'difficulty': difficulty, 'count': count},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) return GenerationResult.fromJson(data);
      return const GenerationResult(ok: false, reason: 'error');
    } on FunctionException catch (e) {
      // Non-2xx (e.g. 402 no-credit) surfaces here with the parsed body.
      final details = e.details;
      if (details is Map<String, dynamic>) return GenerationResult.fromJson(details);
      return const GenerationResult(ok: false, reason: 'error');
    } catch (_) {
      return const GenerationResult(ok: false, reason: 'error');
    }
  }

  // ── Usage feedback (probation lifecycle) ──────────────────────────────────

  /// Record an explicit thumbs up/down on a question.
  Future<void> recordFeedback(String questionId, {required bool up}) async {
    try {
      await _client.rpc('record_question_feedback',
          params: {'p_qid': questionId, 'p_up': up});
    } catch (_) {/* best-effort */}
  }

  /// Record that an AI-generated question was served + whether it was answered
  /// correctly (drives auto-promote/retire). Called after an adaptive submit.
  Future<void> recordServed(String questionId, {required bool correct}) async {
    try {
      await _client.rpc('record_question_served',
          params: {'p_qid': questionId, 'p_correct': correct});
    } catch (_) {/* best-effort */}
  }

  /// Report a bad pooled question (pool-poisoning guard, §5.3/§11). Reports are
  /// deduped per user server-side; once enough distinct students flag it the
  /// question is quarantined out of the active pool. Best-effort — a failed
  /// report never blocks the UI.
  Future<void> reportQuestion(String questionId, {String? reason}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client.rpc('report_question',
          params: {'p_user': userId, 'p_qid': questionId, 'p_reason': reason});
    } catch (_) {/* best-effort */}
  }
}
