import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/analytics_models.dart';
import '../domain/chapter_insight_models.dart';

/// Repository for reading/writing analytics data to Supabase.
class AnalyticsRepository {
  final SupabaseClient _client;

  AnalyticsRepository(this._client);

  // ─── Chapter Analytics (server weakness engine, Phase 1) ───

  /// Per-chapter AI-enriched insights for a single attempt.
  Future<List<ChapterInsight>> getChapterInsightsForAttempt(
      String attemptId) async {
    final data = await _client
        .from('chapter_analytics')
        .select()
        .eq('attempt_id', attemptId)
        .order('priority_score', ascending: false);
    return data
        .map((json) => ChapterInsight.fromJson(json))
        .toList();
  }

  /// Full chapter-analytics history for a chapter (drives the Recovery
  /// Tracker — before/after over time).
  Future<List<ChapterInsight>> getChapterHistory({
    required String userId,
    required String chapterId,
  }) async {
    final data = await _client
        .from('chapter_analytics')
        .select()
        .eq('user_id', userId)
        .eq('chapter_id', chapterId)
        .order('computed_at', ascending: true);
    return data
        .map((json) => ChapterInsight.fromJson(json))
        .toList();
  }

  /// Persistent per-chapter mastery rows for a user.
  Future<List<WeakChapter>> getWeakChapters(String userId) async {
    final data = await _client
        .from('user_weak_chapters')
        .select()
        .eq('user_id', userId)
        .order('weakness_score', ascending: true);
    return data
        .map((json) => WeakChapter.fromJson(json))
        .toList();
  }

  /// Top weak chapters (status='weak'), weakest first — the adaptive loop's
  /// practice queue (Phase 3).
  Future<List<WeakChapter>> getTopWeakChapters(
    String userId, {
    int limit = 3,
  }) async {
    final data = await _client
        .from('user_weak_chapters')
        .select()
        .eq('user_id', userId)
        .eq('status', 'weak')
        .order('weakness_score', ascending: true)
        .limit(limit);
    return data
        .map((json) => WeakChapter.fromJson(json))
        .toList();
  }

  /// Before → after recovery per chapter, from the full chapter_analytics
  /// history. Only chapters seen in 2+ tests (so a delta exists).
  Future<List<ChapterRecovery>> getRecoveryTracking(String userId) async {
    final data = await _client
        .from('chapter_analytics')
        .select('chapter_id, subject_id, score_percentage, computed_at')
        .eq('user_id', userId)
        .order('computed_at', ascending: true);

    final byChapter = <String, List<Map<String, dynamic>>>{};
    for (final row in data) {
      byChapter.putIfAbsent(row['chapter_id'] as String, () => []).add(row);
    }

    final result = <ChapterRecovery>[];
    byChapter.forEach((chapterId, rows) {
      if (rows.length < 2) return;
      result.add(ChapterRecovery(
        chapterId: chapterId,
        subjectId: rows.first['subject_id'] as String?,
        firstScore: (rows.first['score_percentage'] as num?)?.toDouble() ?? 0,
        lastScore: (rows.last['score_percentage'] as num?)?.toDouble() ?? 0,
        attempts: rows.length,
      ));
    });

    // Biggest movers first.
    result.sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));
    return result;
  }

  // ─── Attempt Analytics ───

  /// Save the full analytics for a completed attempt.
  Future<void> saveAttemptAnalytics(AttemptAnalyticsResult result) async {
    await _client.from('attempt_analytics').upsert(result.toJson());
  }

  /// Fetch analytics for a specific attempt.
  Future<AttemptAnalyticsResult?> getAttemptAnalytics(
      String attemptId) async {
    try {
      final data = await _client
          .from('attempt_analytics')
          .select()
          .eq('attempt_id', attemptId)
          .single();
      return AttemptAnalyticsResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // ─── Topic Performance ───

  /// Get all topic performance entries for a user.
  Future<List<TopicPerformance>> getTopicPerformance(
      String userId) async {
    final data = await _client
        .from('topic_performance')
        .select()
        .eq('user_id', userId);
    return data
        .map((json) => TopicPerformance.fromJson(json))
        .toList();
  }

  /// Get topic performance as a map keyed by topic_id.
  Future<Map<String, TopicPerformance>> getTopicPerformanceMap(
      String userId) async {
    final list = await getTopicPerformance(userId);
    return {for (final tp in list) tp.topicId: tp};
  }

  /// Insert or update a topic performance entry.
  Future<void> upsertTopicPerformance({
    required String userId,
    required TopicPerformance performance,
  }) async {
    await _client.from('topic_performance').upsert({
      'user_id': userId,
      ...performance.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── Score History ───

  /// Get score history for trend charts.
  Future<List<ScoreHistoryEntry>> getScoreHistory(String userId) async {
    final data = await _client
        .from('score_history')
        .select()
        .eq('user_id', userId)
        .order('completed_at', ascending: true);
    return data
        .map((json) => ScoreHistoryEntry.fromJson(json))
        .toList();
  }

  /// Add a new score history entry.
  Future<void> addScoreHistoryEntry({
    required String userId,
    required ScoreHistoryEntry entry,
  }) async {
    await _client.from('score_history').insert({
      'user_id': userId,
      ...entry.toJson(),
    });
  }

  // ─── Study Streak ───

  /// Get the study streak for a user.
  Future<StudyStreak> getStudyStreak(String userId) async {
    try {
      final data = await _client
          .from('study_streaks')
          .select()
          .eq('user_id', userId)
          .single();
      return StudyStreak.fromJson(data);
    } catch (_) {
      return const StudyStreak();
    }
  }

  /// Update the study streak after a test completion.
  Future<void> updateStreak(String userId) async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T').first;

    // Get existing streak data
    StudyStreak existing;
    try {
      final data = await _client
          .from('study_streaks')
          .select()
          .eq('user_id', userId)
          .single();
      existing = StudyStreak.fromJson(data);
    } catch (_) {
      existing = const StudyStreak();
    }

    // Calculate new streak
    int newStreak = existing.currentStreak;
    final lastDate = existing.lastStudyDate;

    if (lastDate == null) {
      newStreak = 1;
    } else {
      final lastDateOnly =
          DateTime(lastDate.year, lastDate.month, lastDate.day);
      final todayOnly = DateTime(today.year, today.month, today.day);
      final diff = todayOnly.difference(lastDateOnly).inDays;

      if (diff == 0) {
        // Same day — streak unchanged
      } else if (diff == 1) {
        // Consecutive day — increment
        newStreak++;
      } else {
        // Gap — reset to 1
        newStreak = 1;
      }
    }

    final newLongest = newStreak > existing.longestStreak
        ? newStreak
        : existing.longestStreak;

    // Update recent activity (last 30 days)
    final activity = List<DayActivity>.from(existing.recentActivity);
    final todayActivity = activity.where(
      (a) => a.date.toIso8601String().split('T').first == todayStr,
    );
    if (todayActivity.isNotEmpty) {
      // Increment today's count
      final idx = activity.indexOf(todayActivity.first);
      activity[idx] = DayActivity(
        date: today,
        testsTaken: todayActivity.first.testsTaken + 1,
      );
    } else {
      activity.add(DayActivity(date: today, testsTaken: 1));
    }

    // Keep only last 30 days
    final cutoff = today.subtract(const Duration(days: 30));
    activity.removeWhere((a) => a.date.isBefore(cutoff));

    final updated = StudyStreak(
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastStudyDate: today,
      recentActivity: activity,
    );

    await _client.from('study_streaks').upsert({
      'user_id': userId,
      ...updated.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── Recommendations ───

  /// Get active recommendations for a user.
  Future<List<Recommendation>> getRecommendations(
      String userId) async {
    final data = await _client
        .from('recommendations')
        .select()
        .eq('user_id', userId)
        .eq('is_dismissed', false)
        .order('priority', ascending: false)
        .limit(10);
    return data
        .map((json) => Recommendation.fromJson(json))
        .toList();
  }

  /// Replace all recommendations for a user with new ones.
  Future<void> replaceRecommendations({
    required String userId,
    required List<Recommendation> recommendations,
  }) async {
    // Mark existing as dismissed
    await _client
        .from('recommendations')
        .update({'is_dismissed': true})
        .eq('user_id', userId)
        .eq('is_dismissed', false);

    // Insert new ones
    if (recommendations.isNotEmpty) {
      final rows = recommendations.map((r) => {
            'user_id': userId,
            ...r.toJson(),
          }).toList();
      await _client.from('recommendations').insert(rows);
    }
  }

  // ─── Answer Correctness ───

  /// Update user_answers with the is_correct flag after grading.
  Future<void> updateAnswerCorrectness({
    required String attemptId,
    required Map<String, bool> gradedAnswers,
  }) async {
    for (final entry in gradedAnswers.entries) {
      await _client
          .from('user_answers')
          .update({'is_correct': entry.value})
          .eq('attempt_id', attemptId)
          .eq('question_id', entry.key);
    }
  }

  // ─── Profile Stats ───

  /// Recompute and update aggregate stats on the profiles table.
  Future<void> updateProfileStats(String userId) async {
    // Count completed attempts
    final attempts = await _client
        .from('test_attempts')
        .select('id, score, total_marks')
        .eq('user_id', userId)
        .eq('status', 'submitted');

    final testsCompleted = attempts.length;

    // Average score
    double avgScore = 0;
    if (attempts.isNotEmpty) {
      double totalPct = 0;
      for (final a in attempts) {
        final score = a['score'] as int? ?? 0;
        final total = a['total_marks'] as int? ?? 1;
        totalPct += (total > 0 ? (score / total) * 100 : 0);
      }
      avgScore = totalPct / attempts.length;
    }

    // Get streak
    final streak = await getStudyStreak(userId);

    // Count topics mastered (strong)
    final strongTopics = await _client
        .from('topic_performance')
        .select('topic_id')
        .eq('user_id', userId)
        .eq('strength', 'strong');
    final topicsMastered = strongTopics.length;

    // Update profile
    await _client.from('profiles').update({
      'tests_completed': testsCompleted,
      'average_score': avgScore,
      'current_streak': streak.currentStreak,
      'topics_mastered': topicsMastered,
    }).eq('id', userId);
  }
}
