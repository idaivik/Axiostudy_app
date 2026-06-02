import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/analytics_models.dart';
import 'analytics_repository.dart';
import 'analytics_engine.dart';

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
