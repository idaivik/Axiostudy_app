import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/revision_models.dart';
import '../domain/spaced_repetition.dart';
import 'revision_repository.dart';

final revisionRepositoryProvider = Provider<RevisionRepository>((ref) {
  return RevisionRepository(ref.watch(supabaseClientProvider));
});

/// The student's current spaced-repetition revision plan (Pro · Feature 1).
/// `keepAlive` so the screen's rebuilds (scroll, animations) don't re-query;
/// the controller invalidates it after a "mark reviewed".
final revisionPlanProvider = FutureProvider<RevisionPlan>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return RevisionPlan.empty;
  return ref.watch(revisionRepositoryProvider).loadPlan(userId);
});

/// Imperative surface for the UI: advance a topic's curve, then re-plan.
final revisionControllerProvider = Provider<RevisionController>((ref) {
  return RevisionController(ref);
});

class RevisionController {
  RevisionController(this._ref);
  final Ref _ref;

  /// Mark a topic reviewed (good recall → longer gap; a lapse shortens it),
  /// then invalidate the plan so "Due today" / "Upcoming" re-sort. Returns the
  /// new curve state (null on failure).
  Future<SrsState?> markReviewed(String topicId, {int quality = 5}) async {
    final state = await _ref
        .read(revisionRepositoryProvider)
        .markReviewed(topicId, quality: quality);
    if (state != null) _ref.invalidate(revisionPlanProvider);
    return state;
  }
}
