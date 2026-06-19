import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/feature_request.dart';
import 'feedback_repository.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(ref.watch(supabaseClientProvider));
});

/// The feature-voting board for the current user (counts + has_voted baked in).
/// autoDispose so it refetches fresh each time the screen is opened.
final featureRequestsProvider =
    FutureProvider.autoDispose<List<FeatureRequest>>((ref) async {
  return ref.watch(feedbackRepositoryProvider).getFeatureRequests();
});
