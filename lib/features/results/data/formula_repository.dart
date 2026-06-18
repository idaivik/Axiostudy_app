import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/formula.dart';

/// Reads the static [formula_bank] (Feature 4). Pure lookup, NO meter. The
/// widget keys off the result's weak chapters/topics — chapter scoping already
/// implies the exam syllabus, so no exam filter is needed here.
class FormulaRepository {
  final SupabaseClient _client;
  FormulaRepository(this._client);

  /// Formulas for any of [chapterIds] or [topicIds], most important first.
  /// Returns [] when nothing is curated (or the table isn't applied yet).
  Future<List<Formula>> fetchFormulas({
    required List<String> chapterIds,
    required List<String> topicIds,
  }) async {
    if (chapterIds.isEmpty && topicIds.isEmpty) return [];
    try {
      final ors = <String>[];
      if (chapterIds.isNotEmpty) {
        ors.add('chapter_id.in.(${chapterIds.join(',')})');
      }
      if (topicIds.isNotEmpty) {
        ors.add('topic_id.in.(${topicIds.join(',')})');
      }
      final rows = await _client
          .from('formula_bank')
          .select()
          .or(ors.join(','))
          .order('importance', ascending: false)
          .order('name', ascending: true);
      return rows.map((j) => Formula.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }
}
