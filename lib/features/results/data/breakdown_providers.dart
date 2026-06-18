import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../practice/data/practice_providers.dart';
import '../domain/question_breakdown.dart';
import 'breakdown_repository.dart';

/// Feature 2 data layer.
final breakdownRepositoryProvider = Provider<BreakdownRepository>((ref) {
  return BreakdownRepository(ref.watch(supabaseClientProvider));
});

/// Answered-wrong questions for an attempt, enriched with chapter names for the
/// templated stat line. Drives the "Review your mistakes" section.
final wrongAnswersProvider =
    FutureProvider.family<List<QuestionBreakdown>, String>((ref, attemptId) async {
  final repo = ref.watch(breakdownRepositoryProvider);
  final wrong = await repo.fetchWrongAnswers(attemptId);
  final names = ref.watch(chapterNamesProvider).valueOrNull ?? const {};
  return [
    for (final b in wrong) b.copyWith(chapterName: names[b.question.chapterId]),
  ];
});

/// Question IDs whose breakdown the user already unlocked THIS session, so
/// re-opening the same one doesn't spend the meter again. In-memory only.
final unlockedBreakdownsProvider =
    NotifierProvider<UnlockedBreakdowns, Set<String>>(UnlockedBreakdowns.new);

class UnlockedBreakdowns extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool contains(String questionId) => state.contains(questionId);

  void markUnlocked(String questionId) {
    if (state.contains(questionId)) return;
    state = {...state, questionId};
  }
}
