import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../../shared/models/enums.dart';
import '../domain/test_models.dart';
import 'test_repository.dart';

/// Provides the TestRepository instance.
final testRepositoryProvider = Provider<TestRepository>((ref) {
  return TestRepository(ref.watch(supabaseClientProvider));
});

/// Fetches the tests available to the current user, filtered to their exam
/// (JEE vs NEET). A `'both'` test is shown to everyone; a not-yet-onboarded
/// user (no exam) sees all tests.
final testsProvider = FutureProvider<List<Test>>((ref) async {
  final repo = ref.watch(testRepositoryProvider);
  final user = await ref.watch(currentUserProvider.future);
  return repo.getTests(examType: user?.examType?.name);
});

/// Fetches a single test with questions by ID.
final testWithQuestionsProvider = FutureProvider.family<Test, String>((ref, testId) async {
  final repo = ref.watch(testRepositoryProvider);
  return await repo.getTestWithQuestions(testId);
});

/// All of the current user's *finished* attempts (submitted or analyzed),
/// newest first. Drives the "Completed" split of the Mock Tests tab and the
/// "Past Attempted Tests" analytics widget.
final userAttemptsProvider = FutureProvider<List<TestAttempt>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(testRepositoryProvider);
  final all = await repo.getUserAttempts(userId);
  return all
      .where((a) => a.status != TestAttemptStatus.inProgress)
      .toList();
});

/// Map of `test_id → latest finished attempt`. Because [userAttemptsProvider]
/// is newest-first, the first attempt seen per test is the most recent one.
final lastAttemptByTestProvider =
    FutureProvider<Map<String, TestAttempt>>((ref) async {
  final attempts = await ref.watch(userAttemptsProvider.future);
  final map = <String, TestAttempt>{};
  for (final a in attempts) {
    map.putIfAbsent(a.testId, () => a);
  }
  return map;
});

/// Map of `test_id → display name`, covering **every** test (including ones
/// hidden from the exam-filtered list, e.g. adaptive practice) so attempt
/// history can always resolve a human-readable title.
final testNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('tests').select('id, name');
  return {
    for (final row in data)
      row['id'] as String: (row['name'] as String?) ?? 'Test',
  };
});
