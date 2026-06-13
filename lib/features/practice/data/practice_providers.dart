import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../subjects/data/subjects_providers.dart';
import '../../test/domain/test_models.dart';
import 'practice_repository.dart';

/// The practice engine repository (pool retrieval, adaptive sessions, generation).
final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  return PracticeRepository(ref.watch(supabaseClientProvider));
});

/// chapterId → human chapter name (for copy across results/analytics screens).
final chapterNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final subjects = await ref.watch(subjectsProvider.future);
  return {
    for (final s in subjects)
      for (final c in s.chapters) c.id: c.name,
  };
});

/// Holds the in-memory [Test] for the active adaptive/practice session so the
/// shared test runner can pick it up after navigation (sessions aren't stored
/// in the `tests` table — they're assembled on the fly).
final activePracticeTestProvider = StateProvider<Test?>((ref) => null);
