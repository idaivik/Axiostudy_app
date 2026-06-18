import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../analytics/data/analytics_providers.dart';
import '../domain/formula.dart';
import 'formula_repository.dart';

final formulaRepositoryProvider = Provider<FormulaRepository>((ref) {
  return FormulaRepository(ref.watch(supabaseClientProvider));
});

/// "Formulas to learn" for an attempt (Feature 4): looks up the formula bank by
/// the result's weak chapters (from the AI chapter insights) and weak topics
/// (from attempt analytics), important first. Empty when nothing is curated.
final formulasToLearnProvider =
    FutureProvider.family<List<Formula>, String>((ref, attemptId) async {
  final insights =
      ref.watch(chapterInsightsProvider(attemptId)).valueOrNull ?? const [];
  final analytics = ref.watch(attemptAnalyticsProvider(attemptId)).valueOrNull;

  final chapterIds = <String>{
    for (final i in insights)
      if (i.isWeak) i.chapterId,
    for (final t in analytics?.weakTopics ?? const []) t.chapterId,
  }..removeWhere((e) => e.isEmpty);

  final topicIds = <String>{
    for (final t in analytics?.weakTopics ?? const []) t.topicId,
  }..removeWhere((e) => e.isEmpty);

  if (chapterIds.isEmpty && topicIds.isEmpty) return const [];
  return ref.watch(formulaRepositoryProvider).fetchFormulas(
        chapterIds: chapterIds.toList(),
        topicIds: topicIds.toList(),
      );
});
