import '../../test/domain/test_models.dart';
import '../domain/analytics_models.dart';

/// Detects weak and strong topics from a test attempt using
/// a weighted scoring model.
///
/// Weights:
/// - Current attempt accuracy: 0.6
/// - Historical accuracy: 0.3
/// - Time penalty (above-average time = struggle): 0.1
class WeaknessDetector {
  /// Analyze questions and answers to identify weak/strong topics.
  ///
  /// [gradedAnswers] maps question ID → whether the answer is correct.
  /// [questions] is the full question list for the attempt.
  /// [existingPerformance] is the user's historical topic performance.
  WeaknessResult detect({
    required Map<String, bool> gradedAnswers,
    required List<Question> questions,
    required Map<String, TopicPerformance> existingPerformance,
    required Map<String, int> timePerQuestion,
  }) {
    // Group questions by topic
    final topicQuestions = <String, List<_TopicQuestionData>>{};

    for (final q in questions) {
      final isCorrect = gradedAnswers[q.id] ?? false;
      final timeTaken = timePerQuestion[q.id] ?? 0;

      topicQuestions.putIfAbsent(q.topicId, () => []).add(
        _TopicQuestionData(
          question: q,
          isCorrect: isCorrect,
          timeTakenSeconds: timeTaken,
        ),
      );
    }

    // Compute average time across all questions (for time penalty)
    final allTimes = timePerQuestion.values.where((t) => t > 0).toList();
    final avgTime = allTimes.isEmpty
        ? 60.0
        : allTimes.reduce((a, b) => a + b) / allTimes.length;

    // Score each topic
    final topicScores = <String, _TopicScore>{};

    for (final entry in topicQuestions.entries) {
      final topicId = entry.key;
      final items = entry.value;
      final firstQ = items.first.question;

      // Current attempt accuracy (weight: 0.6)
      final correctCount = items.where((i) => i.isCorrect).length;
      final currentAccuracy =
          items.isEmpty ? 0.0 : correctCount / items.length;

      // Historical accuracy (weight: 0.3)
      final existing = existingPerformance[topicId];
      final historicalAccuracy = existing?.accuracy ?? currentAccuracy;

      // Time penalty (weight: 0.1)
      // If avg time on this topic > overall avg, penalize
      final topicTimes =
          items.map((i) => i.timeTakenSeconds).where((t) => t > 0).toList();
      final topicAvgTime = topicTimes.isEmpty
          ? avgTime
          : topicTimes.reduce((a, b) => a + b) / topicTimes.length;
      // Normalize: 1.0 = fast (good), 0.0 = very slow (bad)
      final timeScore =
          (topicAvgTime <= avgTime) ? 1.0 : (avgTime / topicAvgTime).clamp(0.0, 1.0);

      // Weighted composite score
      final compositeScore =
          (currentAccuracy * 0.6) + (historicalAccuracy * 0.3) + (timeScore * 0.1);

      // Classify strength
      final strength = _classifyStrength(compositeScore);

      topicScores[topicId] = _TopicScore(
        topicId: topicId,
        topicName: _topicName(topicId, items),
        chapterId: firstQ.chapterId,
        chapterName: _inferChapterName(firstQ.chapterId),
        subjectId: firstQ.subjectId,
        subjectName: _inferSubjectName(firstQ.subjectId),
        accuracy: currentAccuracy,
        compositeScore: compositeScore,
        strength: strength,
        totalQuestions: items.length,
        correctAnswers: correctCount,
      );
    }

    // Sort by composite score
    final sorted = topicScores.values.toList()
      ..sort((a, b) => a.compositeScore.compareTo(b.compositeScore));

    // Weak: composite < 0.5 (or bottom topics)
    final weakTopics = sorted
        .where((t) => t.compositeScore < 0.5)
        .map((t) => t.toTopicInsight())
        .toList();

    // Strong: composite >= 0.7
    final strongTopics = sorted.reversed
        .where((t) => t.compositeScore >= 0.7)
        .map((t) => t.toTopicInsight())
        .toList();

    // Updated performance entries
    final updatedPerformance = <String, TopicPerformance>{};
    for (final entry in topicScores.entries) {
      final topicId = entry.key;
      final score = entry.value;
      final existing = existingPerformance[topicId];

      final newTotal =
          (existing?.totalQuestions ?? 0) + score.totalQuestions;
      final newCorrect =
          (existing?.correctAnswers ?? 0) + score.correctAnswers;
      final newTimeTotal = (existing?.totalTimeSeconds ?? 0) +
          topicQuestions[topicId]!
              .map((i) => i.timeTakenSeconds)
              .fold<int>(0, (a, b) => a + b);

      updatedPerformance[topicId] = TopicPerformance(
        topicId: topicId,
        chapterId: score.chapterId,
        subjectId: score.subjectId,
        totalQuestions: newTotal,
        correctAnswers: newCorrect,
        totalTimeSeconds: newTimeTotal,
        avgTimeSeconds: newTotal > 0 ? newTimeTotal / newTotal : 0,
        accuracy: newTotal > 0 ? newCorrect / newTotal : 0,
        strength: score.strength,
        lastAttemptedAt: DateTime.now(),
      );
    }

    return WeaknessResult(
      weakTopics: weakTopics,
      strongTopics: strongTopics,
      updatedPerformance: updatedPerformance,
    );
  }

  static String _classifyStrength(double score) {
    if (score < 0.4) return 'weak';
    if (score < 0.7) return 'moderate';
    return 'strong';
  }

  static String _topicName(
      String topicId, List<_TopicQuestionData> items) {
    // Derive a readable name from the topic ID
    // e.g. "ph_m_kinematics" → "Kinematics"
    final parts = topicId.split('_');
    if (parts.length >= 3) {
      return parts.sublist(2).map(_capitalize).join(' ');
    }
    return parts.last;
  }

  static String _inferChapterName(String chapterId) {
    final parts = chapterId.split('_');
    if (parts.length >= 2) {
      return parts.sublist(1).map(_capitalize).join(' ');
    }
    return chapterId;
  }

  static String _inferSubjectName(String subjectId) {
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

/// Result from the weakness detection algorithm.
class WeaknessResult {
  final List<TopicInsight> weakTopics;
  final List<TopicInsight> strongTopics;
  final Map<String, TopicPerformance> updatedPerformance;

  const WeaknessResult({
    required this.weakTopics,
    required this.strongTopics,
    required this.updatedPerformance,
  });
}

class _TopicQuestionData {
  final Question question;
  final bool isCorrect;
  final int timeTakenSeconds;

  const _TopicQuestionData({
    required this.question,
    required this.isCorrect,
    required this.timeTakenSeconds,
  });
}

class _TopicScore {
  final String topicId;
  final String topicName;
  final String chapterId;
  final String chapterName;
  final String subjectId;
  final String subjectName;
  final double accuracy;
  final double compositeScore;
  final String strength;
  final int totalQuestions;
  final int correctAnswers;

  const _TopicScore({
    required this.topicId,
    required this.topicName,
    required this.chapterId,
    required this.chapterName,
    required this.subjectId,
    required this.subjectName,
    required this.accuracy,
    required this.compositeScore,
    required this.strength,
    required this.totalQuestions,
    required this.correctAnswers,
  });

  TopicInsight toTopicInsight() => TopicInsight(
        topicId: topicId,
        topicName: topicName,
        chapterId: chapterId,
        chapterName: chapterName,
        subjectId: subjectId,
        subjectName: subjectName,
        accuracy: accuracy,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
      );
}
