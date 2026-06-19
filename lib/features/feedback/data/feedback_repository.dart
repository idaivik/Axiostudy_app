import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/feature_request.dart';

/// Data access for the feature-voting board (Bucket 2 §3b). Pure data — the
/// Pro gate lives in the UI (FeatureGate(prioritySupport)).
class FeedbackRepository {
  final SupabaseClient _client;
  const FeedbackRepository(this._client);

  /// The board, sorted by votes (the RPC handles counts + the caller's
  /// has_voted; see `get_feature_requests`).
  Future<List<FeatureRequest>> getFeatureRequests() async {
    final data = await _client.rpc('get_feature_requests');
    return (data as List)
        .map((e) => FeatureRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Idempotent upvote toggle. Insert is conflict-safe (the (user, request) PK
  /// guarantees at most one vote); delete removes the user's own vote.
  Future<void> setVote({
    required String requestId,
    required bool voted,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be signed in to vote.');
    }
    if (voted) {
      await _client.from('feature_votes').upsert(
        {'user_id': userId, 'request_id': requestId},
        onConflict: 'user_id,request_id',
        ignoreDuplicates: true,
      );
    } else {
      await _client
          .from('feature_votes')
          .delete()
          .eq('user_id', userId)
          .eq('request_id', requestId);
    }
  }

  /// Submit a new feature request (the "suggest a feature" form).
  Future<void> submitFeatureRequest({
    required String title,
    String? description,
  }) async {
    final trimmedDesc = description?.trim();
    await _client.from('feature_requests').insert({
      'title': title.trim(),
      if (trimmedDesc != null && trimmedDesc.isNotEmpty)
        'description': trimmedDesc,
    });
  }
}
