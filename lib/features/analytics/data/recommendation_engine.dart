import '../domain/analytics_models.dart';

/// Generates prioritized study recommendations based on
/// weakness detection output and historical performance.
///
/// Recommendation types:
/// - weak_topic_drill: Targeted practice on topics below 40% accuracy
/// - revision: Topics not attempted in 7+ days
/// - challenge: Harder questions on strong topics
/// - chapter_test: Full chapter coverage when enough topics are moderate+
class RecommendationEngine {
  /// Generate recommendations from the latest weakness analysis
  /// and historical topic performance.
  List<Recommendation> generate({
    required List<TopicInsight> weakTopics,
    required List<TopicInsight> strongTopics,
    required Map<String, TopicPerformance> allTopicPerformance,
  }) {
    final recommendations = <Recommendation>[];
    var priority = 100;

    // 1. Weak topic drills (highest priority)
    for (final topic in weakTopics.take(3)) {
      recommendations.add(Recommendation(
        type: 'weak_topic_drill',
        title: '${topic.topicName} Drill',
        subtitle:
            '${_questionCount(topic.accuracy)} targeted questions • ${topic.subjectName}',
        topicId: topic.topicId,
        chapterId: topic.chapterId,
        subjectId: topic.subjectId,
        priority: priority--,
        reason:
            'Your accuracy on ${topic.topicName} is ${topic.scorePercentage}% — below the 50% threshold',
      ));
    }

    // 2. Revision suggestions (topics not attempted in 7+ days)
    final now = DateTime.now();
    final staleTopics = allTopicPerformance.entries
        .where((e) {
          final lastAttempt = e.value.lastAttemptedAt;
          if (lastAttempt == null) return false;
          return now.difference(lastAttempt).inDays >= 7;
        })
        .where((e) => e.value.strength != 'weak') // weak topics already covered
        .toList()
      ..sort((a, b) {
        // Prioritize topics with more questions answered (more to lose)
        return b.value.totalQuestions.compareTo(a.value.totalQuestions);
      });

    for (final entry in staleTopics.take(2)) {
      final perf = entry.value;
      final daysSince =
          now.difference(perf.lastAttemptedAt!).inDays;
      recommendations.add(Recommendation(
        type: 'revision',
        title: 'Revise: ${_topicDisplayName(perf.topicId)}',
        subtitle:
            'Last practiced $daysSince days ago • ${_subjectDisplayName(perf.subjectId)}',
        topicId: perf.topicId,
        chapterId: perf.chapterId,
        subjectId: perf.subjectId,
        priority: priority--,
        reason:
            'You haven\'t practiced this topic in $daysSince days — revision prevents forgetting',
      ));
    }

    // 3. Challenge tests for strong topics (push growth)
    for (final topic in strongTopics.take(1)) {
      recommendations.add(Recommendation(
        type: 'challenge',
        title: '${topic.topicName} Challenge',
        subtitle:
            'Hard questions • ${topic.subjectName}',
        topicId: topic.topicId,
        chapterId: topic.chapterId,
        subjectId: topic.subjectId,
        priority: priority--,
        reason:
            'You\'re strong in ${topic.topicName} (${topic.scorePercentage}%) — try harder questions to push further',
      ));
    }

    // 4. Chapter tests (when multiple topics in a chapter are moderate+)
    final chapterTopics = <String, List<TopicPerformance>>{};
    for (final perf in allTopicPerformance.values) {
      chapterTopics.putIfAbsent(perf.chapterId, () => []).add(perf);
    }

    for (final entry in chapterTopics.entries) {
      final topics = entry.value;
      if (topics.length < 2) continue;

      final moderateOrStrong = topics
          .where((t) => t.strength == 'moderate' || t.strength == 'strong')
          .length;
      final ratio =
          topics.isEmpty ? 0.0 : moderateOrStrong / topics.length;

      if (ratio >= 0.5) {
        recommendations.add(Recommendation(
          type: 'chapter_test',
          title: 'Full Chapter Test — ${_chapterDisplayName(entry.key)}',
          subtitle:
              '${topics.length * 10} questions • ${_subjectDisplayName(topics.first.subjectId)}',
          chapterId: entry.key,
          subjectId: topics.first.subjectId,
          priority: priority--,
          reason:
              'You\'ve covered ${moderateOrStrong}/${topics.length} topics — ready for a full chapter assessment',
        ));
      }
    }

    // Sort by priority (highest first)
    recommendations.sort((a, b) => b.priority.compareTo(a.priority));

    return recommendations;
  }

  /// Suggest question count based on weakness severity.
  int _questionCount(double accuracy) {
    if (accuracy < 0.2) return 25;
    if (accuracy < 0.4) return 20;
    return 15;
  }

  static String _topicDisplayName(String topicId) {
    final parts = topicId.split('_');
    if (parts.length >= 3) {
      return parts.sublist(2).map(_capitalize).join(' ');
    }
    return _capitalize(parts.last);
  }

  static String _chapterDisplayName(String chapterId) {
    final parts = chapterId.split('_');
    if (parts.length >= 2) {
      return parts.sublist(1).map(_capitalize).join(' ');
    }
    return _capitalize(chapterId);
  }

  static String _subjectDisplayName(String subjectId) {
    switch (subjectId) {
      case 'physics':
        return 'Physics';
      case 'chemistry':
        return 'Chemistry';
      case 'mathematics':
        return 'Mathematics';
      default:
        return _capitalize(subjectId);
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
