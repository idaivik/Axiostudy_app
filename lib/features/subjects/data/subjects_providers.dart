import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/subject_models.dart';
import 'subjects_repository.dart';

/// Provides the SubjectsRepository instance.
final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  return SubjectsRepository(ref.watch(supabaseClientProvider));
});

/// Fetches the subjects relevant to the student's exam, with user progress
/// merged in. JEE students see Physics/Chemistry/Mathematics (no Biology);
/// NEET students see Physics/Chemistry/Biology (no Mathematics). When the exam
/// isn't known yet (e.g. guest mode, pre-onboarding) all subjects are returned.
final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  final repo = ref.watch(subjectsRepositoryProvider);
  final user = ref.watch(currentUserProvider).valueOrNull;

  final subjects = await repo.getSubjects(userId: user?.id);

  final examType = user?.examType;
  if (examType == null) return subjects;
  final allowed = examType.subjects.toSet();
  return subjects.where((s) => allowed.contains(s.type)).toList();
});
