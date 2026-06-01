import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/subject_models.dart';
import 'subjects_repository.dart';

/// Provides the SubjectsRepository instance.
final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  return SubjectsRepository(ref.watch(supabaseClientProvider));
});

/// Fetches all subjects with user progress merged in.
final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  final repo = ref.watch(subjectsRepositoryProvider);
  final userAsync = ref.watch(currentUserProvider);
  final userId = userAsync.whenOrNull(data: (user) => user?.id);

  return await repo.getSubjects(userId: userId);
});
