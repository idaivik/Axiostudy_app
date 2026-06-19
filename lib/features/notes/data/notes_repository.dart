import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/note_result.dart';

/// Fetches (or generates-and-caches) AI study notes via the `generate-notes`
/// edge function (Feature 2). The server caches per (user, topic), so opening a
/// note a second time returns the stored copy without spending a meter;
/// [regenerate] is the explicit user action that overwrites it and spends one
/// ai_note. Never throws — maps every outcome (incl. 402 trial-lock / paywall)
/// to a [NoteResult].
class NotesRepository {
  final SupabaseClient _client;
  NotesRepository(this._client);

  Future<NoteResult> getNote({
    required String topicId,
    String? topicName,
    String? chapterId,
    String? subjectId,
    bool regenerate = false,
  }) async {
    try {
      final res = await _client.functions.invoke('generate-notes', body: {
        'topic_id': topicId,
        if (topicName != null && topicName.isNotEmpty) 'topic_name': topicName,
        if (chapterId != null && chapterId.isNotEmpty) 'chapter_id': chapterId,
        if (subjectId != null && subjectId.isNotEmpty) 'subject_id': subjectId,
        if (regenerate) 'regenerate': true,
      });
      final data = res.data;
      if (data is Map<String, dynamic>) return NoteResult.fromJson(data);
      return NoteResult.error;
    } on FunctionException catch (e) {
      // Non-2xx (402 trial_ai_locked / no_entitlement) arrives here with the body.
      final details = e.details;
      if (details is Map<String, dynamic>) return NoteResult.fromJson(details);
      return NoteResult.error;
    } catch (_) {
      return NoteResult.error;
    }
  }
}
