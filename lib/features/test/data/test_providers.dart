import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/test_models.dart';
import 'test_repository.dart';

/// Provides the TestRepository instance.
final testRepositoryProvider = Provider<TestRepository>((ref) {
  return TestRepository(ref.watch(supabaseClientProvider));
});

/// Fetches all available tests.
final testsProvider = FutureProvider<List<Test>>((ref) async {
  final repo = ref.watch(testRepositoryProvider);
  return await repo.getTests();
});

/// Fetches a single test with questions by ID.
final testWithQuestionsProvider = FutureProvider.family<Test, String>((ref, testId) async {
  final repo = ref.watch(testRepositoryProvider);
  return await repo.getTestWithQuestions(testId);
});
