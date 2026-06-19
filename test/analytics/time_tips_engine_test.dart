import 'package:flutter_test/flutter_test.dart';
import 'package:axiostudy_app/features/analytics/domain/analytics_models.dart';
import 'package:axiostudy_app/features/analytics/domain/time_tips_engine.dart';
import 'package:axiostudy_app/shared/models/enums.dart';

/// Deterministic-rules coverage for the Bucket 2 Feature 1 pacing engine
/// (BILLING_BUCKET2_BUILD_PROMPT.md §5). No network — pure function.

SubjectBreakdown _subject({
  required String id,
  required String name,
  required int total,
  required int correct,
  required int timeSeconds,
}) =>
    SubjectBreakdown(
      subjectId: id,
      subjectName: name,
      correct: correct,
      total: total,
      accuracy: total > 0 ? correct / total : 0,
      timeSeconds: timeSeconds,
    );

DifficultyBreakdown _difficulty(String d, int total, int correct) =>
    DifficultyBreakdown(
      difficulty: d,
      correct: correct,
      total: total,
      accuracy: total > 0 ? correct / total : 0,
    );

AttemptAnalyticsResult _analytics({
  int correct = 0,
  int wrong = 0,
  int unanswered = 0,
  double avgTimePerQuestion = 144,
  Map<String, SubjectBreakdown> subjects = const {},
  Map<String, DifficultyBreakdown> difficulties = const {},
}) {
  final total = correct + wrong + unanswered;
  return AttemptAnalyticsResult(
    attemptId: 'a1',
    userId: 'u1',
    testId: 't1',
    totalCorrect: correct,
    totalWrong: wrong,
    totalUnanswered: unanswered,
    accuracy: (correct + wrong) > 0 ? correct / (correct + wrong) : 0,
    totalTimeSeconds: (avgTimePerQuestion * total).round(),
    avgTimePerQuestion: avgTimePerQuestion,
    subjectBreakdown: subjects,
    chapterBreakdown: const {},
    difficultyBreakdown: difficulties,
    weakTopics: const [],
    strongTopics: const [],
    recommendations: const [],
    computedAt: DateTime(2026, 6, 19),
  );
}

bool _has(List<TimeTip> tips, TimeTipKind kind) =>
    tips.any((t) => t.kind == kind);

void main() {
  final jee = IdealTimeConfig.forExam(ExamType.jee); // base 144s
  final neet = IdealTimeConfig.forExam(ExamType.neet); // base 60s

  group('rushed-but-wrong → slow down', () {
    test('a rushed, low-scoring subject yields a rushedWrong tip', () {
      final tips = TimeTipsEngine.compute(
        analytics: _analytics(
          correct: 3,
          wrong: 7,
          avgTimePerQuestion: 40,
          // Physics: 10 Q in 400s = 40s/q (< 144*0.6) at 30% → rushed-wrong.
          subjects: {
            'physics':
                _subject(id: 'physics', name: 'Physics', total: 10, correct: 3, timeSeconds: 400),
          },
          difficulties: {'medium': _difficulty('medium', 10, 3)},
        ),
        ideal: jee,
      );
      expect(_has(tips, TimeTipKind.rushedWrong), isTrue);
      // It must read as a pacing instruction, not a study instruction.
      final tip = tips.firstWhere((t) => t.kind == TimeTipKind.rushedWrong);
      expect(tip.message.toLowerCase(), contains('slow down'));
    });
  });

  group('slow-but-right → speed up', () {
    test('an accurate but slow subject yields a slowButRight tip', () {
      final tips = TimeTipsEngine.compute(
        analytics: _analytics(
          correct: 8,
          wrong: 2,
          avgTimePerQuestion: 240,
          // Chemistry: 10 Q in 2400s = 240s/q (> 144*1.5) at 80% → slow-but-right.
          subjects: {
            'chemistry': _subject(
                id: 'chemistry', name: 'Chemistry', total: 10, correct: 8, timeSeconds: 2400),
          },
          difficulties: {'medium': _difficulty('medium', 10, 8)},
        ),
        ideal: jee,
      );
      expect(_has(tips, TimeTipKind.slowButRight), isTrue);
    });
  });

  group('unanswered → pacing/budget tip', () {
    test('unanswered questions yield an unanswered tip (NEET)', () {
      final tips = TimeTipsEngine.compute(
        analytics: _analytics(
          correct: 6,
          wrong: 2,
          unanswered: 4,
          avgTimePerQuestion: 60,
          subjects: {
            'physics':
                _subject(id: 'physics', name: 'Physics', total: 12, correct: 6, timeSeconds: 720),
          },
          difficulties: {'medium': _difficulty('medium', 12, 6)},
        ),
        ideal: neet,
      );
      expect(_has(tips, TimeTipKind.unanswered), isTrue);
    });

    test('unanswered tip fires even when the exam (ideal) is unknown', () {
      final tips = TimeTipsEngine.compute(
        analytics: _analytics(correct: 4, wrong: 2, unanswered: 3, avgTimePerQuestion: 90),
        ideal: null, // unknown exam
      );
      expect(_has(tips, TimeTipKind.unanswered), isTrue);
      // …but no pacing tip can be derived without a reference.
      expect(_has(tips, TimeTipKind.rushedWrong), isFalse);
      expect(_has(tips, TimeTipKind.slowButRight), isFalse);
    });
  });

  group('small samples are suppressed (no over-claiming)', () {
    test('a sub-minimum total produces no tips at all', () {
      final tips = TimeTipsEngine.compute(
        analytics: _analytics(
          correct: 1,
          wrong: 2,
          avgTimePerQuestion: 30,
          subjects: {
            'physics':
                _subject(id: 'physics', name: 'Physics', total: 3, correct: 1, timeSeconds: 90),
          },
        ),
        ideal: jee,
      );
      expect(tips, isEmpty);
    });

    test('a subject below the per-subject minimum gets no subject tip', () {
      final tips = TimeTipsEngine.compute(
        analytics: _analytics(
          correct: 4,
          wrong: 5,
          avgTimePerQuestion: 144, // neutral overall pace
          subjects: {
            // Physics is rushed+wrong but only 3 Q → suppressed.
            'physics':
                _subject(id: 'physics', name: 'Physics', total: 3, correct: 0, timeSeconds: 90),
            // Chemistry is neutral (6 Q, ~144s/q, 67%) → no tip.
            'chemistry': _subject(
                id: 'chemistry', name: 'Chemistry', total: 6, correct: 4, timeSeconds: 864),
          },
          difficulties: {'medium': _difficulty('medium', 9, 4)},
        ),
        ideal: jee,
      );
      expect(_has(tips, TimeTipKind.rushedWrong), isFalse);
    });
  });

  group('ranking & cap', () {
    test('never returns more than maxTips, most-severe first', () {
      final tips = TimeTipsEngine.compute(
        analytics: _analytics(
          correct: 5,
          wrong: 10,
          unanswered: 5,
          avgTimePerQuestion: 40,
          subjects: {
            'physics':
                _subject(id: 'physics', name: 'Physics', total: 10, correct: 1, timeSeconds: 300),
            'chemistry': _subject(
                id: 'chemistry', name: 'Chemistry', total: 10, correct: 9, timeSeconds: 2400),
          },
          difficulties: {'medium': _difficulty('medium', 20, 5)},
        ),
        ideal: jee,
        maxTips: 3,
      );
      expect(tips.length, lessThanOrEqualTo(3));
      for (var i = 1; i < tips.length; i++) {
        expect(tips[i - 1].severity, greaterThanOrEqualTo(tips[i].severity));
      }
    });
  });
}
