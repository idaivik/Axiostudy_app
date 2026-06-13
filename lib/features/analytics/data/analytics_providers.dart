import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/analytics_models.dart';
import '../domain/chapter_insight_models.dart';
import '../domain/chart_data_models.dart';
import 'analytics_repository.dart';
import 'analytics_engine.dart';
import '../../../shared/models/enums.dart';

/// Provides the AnalyticsRepository instance.
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(supabaseClientProvider));
});

/// Provides the AnalyticsEngine instance.
final analyticsEngineProvider = Provider<AnalyticsEngine>((ref) {
  return AnalyticsEngine(ref.watch(analyticsRepositoryProvider));
});

/// Analytics for a specific attempt (by attempt ID).
final attemptAnalyticsProvider =
    FutureProvider.family<AttemptAnalyticsResult?, String>(
        (ref, attemptId) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getAttemptAnalytics(attemptId);
});

/// All topic performance for the current user.
final topicPerformanceProvider =
    FutureProvider<List<TopicPerformance>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getTopicPerformance(userId);
});

/// Weak topics for the current user (sorted by severity).
final weakTopicsProvider =
    FutureProvider<List<TopicPerformance>>((ref) async {
  final allTopics = await ref.watch(topicPerformanceProvider.future);
  return allTopics
      .where((t) => t.strength == 'weak')
      .toList()
    ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
});

/// Strong topics for the current user.
final strongTopicsProvider =
    FutureProvider<List<TopicPerformance>>((ref) async {
  final allTopics = await ref.watch(topicPerformanceProvider.future);
  return allTopics
      .where((t) => t.strength == 'strong')
      .toList()
    ..sort((a, b) => b.accuracy.compareTo(a.accuracy));
});

/// Score history for trend charts.
final scoreHistoryProvider =
    FutureProvider<List<ScoreHistoryEntry>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getScoreHistory(userId);
});

/// Study streak data.
final studyStreakProvider = FutureProvider<StudyStreak>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const StudyStreak();

  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getStudyStreak(userId);
});

/// Active recommendations for the current user.
final recommendationsProvider =
    FutureProvider<List<Recommendation>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getRecommendations(userId);
});

// ─── Chapter Insights (server weakness engine, Phase 1/3) ───

/// AI-enriched per-chapter insights for a specific attempt.
final chapterInsightsProvider =
    FutureProvider.family<List<ChapterInsight>, String>(
        (ref, attemptId) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getChapterInsightsForAttempt(attemptId);
});

/// All persistent per-chapter mastery rows for the current user.
final weakChaptersProvider =
    FutureProvider<List<WeakChapter>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getWeakChapters(userId);
});

/// Top-3 weak chapters (weakest first) — the adaptive practice queue.
final topWeakChaptersProvider =
    FutureProvider<List<WeakChapter>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getTopWeakChapters(userId, limit: 3);
});

/// Chapter-analytics history for one chapter — the Recovery Tracker source.
final chapterHistoryProvider =
    FutureProvider.family<List<ChapterInsight>, String>(
        (ref, chapterId) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getChapterHistory(userId: userId, chapterId: chapterId);
});

/// Before → after recovery per chapter (chapters seen in 2+ tests).
final recoveryTrackingProvider =
    FutureProvider<List<ChapterRecovery>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getRecoveryTracking(userId);
});

/// Subject mastery percentages — computed from topic performance.
/// Returns a map: { "physics": 0.65, "chemistry": 0.58, "mathematics": 0.72 }
final subjectMasteryProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final allTopics = await ref.watch(topicPerformanceProvider.future);
  if (allTopics.isEmpty) return {};

  final subjectGroups = <String, List<TopicPerformance>>{};
  for (final tp in allTopics) {
    subjectGroups.putIfAbsent(tp.subjectId, () => []).add(tp);
  }

  return subjectGroups.map((subjectId, topics) {
    final avgAccuracy = topics.isEmpty
        ? 0.0
        : topics.map((t) => t.accuracy).reduce((a, b) => a + b) /
            topics.length;
    return MapEntry(subjectId, avgAccuracy);
  });
});

/// Summary stats for the current user (tests taken, avg score, streak).
final userStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  final streak = await ref.watch(studyStreakProvider.future);
  final scoreHistory = await ref.watch(scoreHistoryProvider.future);

  return {
    'tests_taken': user?.testsCompleted ?? scoreHistory.length,
    'avg_score': user?.averageScore ?? 0.0,
    'current_streak': streak.currentStreak,
    'longest_streak': streak.longestStreak,
  };
});

// ─── Chart-Specific Providers ───

/// Radar Chart data: aggregates topic performance into sub-topic axes.
/// Returns up to 6 data points grouped by strongest/weakest topics.
final radarChartDataProvider =
    FutureProvider<List<RadarDataPoint>>((ref) async {
  final allTopics = await ref.watch(topicPerformanceProvider.future);
  if (allTopics.isEmpty) return [];

  // Take up to 6 topics sorted by total questions (most practiced)
  final sorted = [...allTopics]
    ..sort((a, b) => b.totalQuestions.compareTo(a.totalQuestions));
  final top = sorted.take(6).toList();

  return top.map((t) {
    final label = _topicDisplayName(t.topicId);
    return RadarDataPoint(
      label: label,
      value: t.accuracy.clamp(0.0, 1.0),
      topicId: t.topicId,
    );
  }).toList();
});

/// Scatter Plot data: maps topic performance to (time, accuracy) pairs.
final scatterPlotDataProvider =
    FutureProvider<List<ScatterDataPoint>>((ref) async {
  final allTopics = await ref.watch(topicPerformanceProvider.future);
  if (allTopics.isEmpty) return [];

  return allTopics
      .where((t) => t.totalQuestions > 0 && t.avgTimeSeconds > 0)
      .map((t) => ScatterDataPoint(
            topicName: _topicDisplayName(t.topicId),
            topicId: t.topicId,
            subjectId: t.subjectId,
            accuracy: t.accuracy.clamp(0.0, 1.0),
            avgTimeSeconds: t.avgTimeSeconds,
          ))
      .toList();
});

/// Skill Tree data: fetches prerequisites from DB and merges with topic strength.
final skillTreeDataProvider =
    FutureProvider.family<List<SkillTreeNode>, String>(
        (ref, subjectId) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;

  // Fetch prerequisites from DB
  List<TopicPrerequisite> prerequisites = [];
  try {
    final data = await client
        .from('topic_prerequisites')
        .select()
        .eq('subject_id', subjectId);
    prerequisites =
        (data as List).map((e) => TopicPrerequisite.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    // Table might not exist yet
  }

  if (prerequisites.isEmpty) return [];

  // Get all unique topic IDs
  final allTopicIds = <String>{};
  for (final p in prerequisites) {
    allTopicIds.add(p.topicId);
    allTopicIds.add(p.prerequisiteTopicId);
  }

  // Fetch topic performance for strength
  final performanceMap = <String, TopicPerformance>{};
  if (userId != null) {
    final allPerf = await ref.watch(topicPerformanceProvider.future);
    for (final tp in allPerf) {
      performanceMap[tp.topicId] = tp;
    }
  }

  // Build prerequisite lookup
  final prereqMap = <String, List<String>>{};
  for (final p in prerequisites) {
    prereqMap.putIfAbsent(p.topicId, () => []).add(p.prerequisiteTopicId);
  }

  // Build nodes
  return allTopicIds.map((topicId) {
    final perf = performanceMap[topicId];
    final strength = perf != null
        ? _parseStrength(perf.strength)
        : TopicStrength.weak;

    return SkillTreeNode(
      topicId: topicId,
      label: _topicDisplayName(topicId),
      subjectId: subjectId,
      strength: strength,
      prerequisiteIds: prereqMap[topicId] ?? [],
      accuracy: perf?.accuracy ?? 0.0,
    );
  }).toList();
});

/// Area Line Chart data: converts score history to TrendDataPoints.
final areaLineChartDataProvider =
    FutureProvider<List<TrendDataPoint>>((ref) async {
  final history = await ref.watch(scoreHistoryProvider.future);
  if (history.isEmpty) return [];

  return history.map((h) => TrendDataPoint(
    date: h.completedAt,
    score: h.scorePercentage.clamp(0, 100),
    testName: h.testName,
  )).toList();
});

// ─── Helpers ───

String _topicDisplayName(String topicId) {
  final parts = topicId.split('_');
  if (parts.length >= 3) {
    return parts.sublist(2).map((s) {
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1);
    }).join(' ');
  }
  if (parts.length >= 2) {
    return parts.sublist(1).map((s) {
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1);
    }).join(' ');
  }
  return topicId;
}

TopicStrength _parseStrength(String s) {
  switch (s) {
    case 'strong': return TopicStrength.strong;
    case 'moderate': return TopicStrength.moderate;
    case 'weak': return TopicStrength.weak;
    default: return TopicStrength.moderate;
  }
}

