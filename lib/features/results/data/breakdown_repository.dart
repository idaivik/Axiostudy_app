import 'package:supabase_flutter/supabase_flutter.dart';

import '../../subscription/domain/meter_outcome.dart';
import '../../test/domain/test_models.dart';
import '../domain/question_breakdown.dart';

/// Data layer for Feature 2 (templated question breakdown). Pure reads from the
/// existing pool + topic_performance — NO AI, ₹0 to run. The only metered call is
/// [unlockBreakdown], which routes through the safe `consume_meter_self` wrapper.
class BreakdownRepository {
  final SupabaseClient _client;
  BreakdownRepository(this._client);

  static const String breakdownMeter = 'question_breakdown';

  /// The answered-wrong questions for an attempt, each enriched with its stored
  /// explanation image, chapter name, and the student's topic accuracy (for the
  /// templated stat line). Returns [] on any error — the section just hides.
  Future<List<QuestionBreakdown>> fetchWrongAnswers(String attemptId) async {
    try {
      final answers = await _client
          .from('user_answers')
          .select('question_id, selected_answer, is_correct')
          .eq('attempt_id', attemptId);
      if (answers.isEmpty) return [];

      final byQuestion = <String, Map<String, dynamic>>{
        for (final a in answers) a['question_id'] as String: a,
      };

      // `*` so a not-yet-applied explanation_image_url column can't break the read.
      final questionRows = await _client
          .from('questions')
          .select()
          .inFilter('id', byQuestion.keys.toList());

      // Topic standing for the stat line (one fetch, mapped by topic_id).
      final userId = _client.auth.currentUser?.id;
      final topicAccuracy = <String, double>{};
      if (userId != null) {
        final perf = await _client
            .from('topic_performance')
            .select('topic_id, accuracy')
            .eq('user_id', userId);
        for (final r in perf) {
          topicAccuracy[r['topic_id'] as String] =
              (r['accuracy'] as num?)?.toDouble() ?? 0;
        }
      }

      final wrong = <QuestionBreakdown>[];
      for (final row in questionRows) {
        final q = Question.fromJson(row);
        final ans = byQuestion[q.id];
        final selected = (ans?['selected_answer'] as String?)?.trim();
        if (selected == null || selected.isEmpty) continue; // skip unanswered

        final isCorrect = ans?['is_correct'] as bool?;
        final wrongByValue =
            selected.toLowerCase() != q.correctAnswer.trim().toLowerCase();
        final isWrong = isCorrect == null ? wrongByValue : !isCorrect;
        if (!isWrong) continue;

        wrong.add(QuestionBreakdown(
          question: q,
          selectedAnswer: selected,
          explanationImageUrl: row['explanation_image_url'] as String?,
          topicAccuracy: topicAccuracy[q.topicId],
          // chapterName is filled by the provider from chapterNamesProvider.
        ));
      }
      return wrong;
    } catch (_) {
      return [];
    }
  }

  /// Meter one breakdown open against the caller's own account. trial users are
  /// NOT locked here (question_breakdown isn't an ai_ meter). Never throws.
  Future<MeterOutcome> unlockBreakdown() async {
    try {
      final res = await _client.rpc('consume_meter_self', params: {
        'p_meter': breakdownMeter,
        'p_amount': 1,
      });
      if (res is Map) return MeterOutcome.fromJson(Map<String, dynamic>.from(res));
      return const MeterOutcome(MeterStatus.error);
    } catch (_) {
      return const MeterOutcome(MeterStatus.error);
    }
  }
}
