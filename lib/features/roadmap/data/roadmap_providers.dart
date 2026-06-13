import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/enums.dart';
import '../../subjects/data/subjects_providers.dart';
import '../../subjects/domain/subject_models.dart';
import '../domain/roadmap_models.dart';
import 'roadmap_repository.dart';

/// Roadmap repository (local persistence + planner + AI annotation).
final roadmapRepositoryProvider = Provider<RoadmapRepository>((ref) {
  return RoadmapRepository();
});

/// chapterId → strength in [0,1], derived from the existing subjects/analytics
/// data. Higher = stronger. Used to prioritise revision/practice.
final chapterStrengthProvider = FutureProvider<Map<String, double>>((ref) async {
  final subjects = await ref.watch(subjectsProvider.future);
  final map = <String, double>{};
  for (final subject in subjects) {
    for (final chapter in subject.chapters) {
      map[chapter.id] = _strengthValue(chapter);
    }
  }
  return map;
});

/// The student's saved enrollment, or null if setup hasn't been done.
final enrollmentProvider = FutureProvider<StudentEnrollment?>((ref) async {
  return ref.watch(roadmapRepositoryProvider).loadEnrollment();
});

/// Whether the roadmap setup flow still needs to run.
final needsRoadmapSetupProvider = Provider<bool>((ref) {
  final enrollment = ref.watch(enrollmentProvider);
  return enrollment.whenOrNull(data: (e) => e == null) ?? false;
});

/// The fully-assembled roadmap (null until the student has an enrollment).
final roadmapProvider = FutureProvider<Roadmap?>((ref) async {
  final repo = ref.watch(roadmapRepositoryProvider);
  final enrollment = await ref.watch(enrollmentProvider.future);
  if (enrollment == null) return null;

  final strength = await ref.watch(chapterStrengthProvider.future);
  return repo.buildRoadmap(enrollment: enrollment, chapterStrength: strength);
});

/// Convenience: the controller used by UI to mutate roadmap state.
final roadmapControllerProvider = Provider<RoadmapController>((ref) {
  return RoadmapController(ref);
});

/// Thin imperative surface over the repository that invalidates the relevant
/// providers so the UI re-plans after a change.
class RoadmapController {
  RoadmapController(this._ref);
  final Ref _ref;

  RoadmapRepository get _repo => _ref.read(roadmapRepositoryProvider);

  Future<void> saveEnrollment(StudentEnrollment enrollment) async {
    await _repo.saveEnrollment(enrollment);
    _ref.invalidate(enrollmentProvider);
    _ref.invalidate(roadmapProvider);
  }

  Future<void> setItemStatus(String itemId, RoadmapItemStatus status) async {
    await _repo.setItemStatus(itemId, status);
    _ref.invalidate(roadmapProvider);
  }

  Future<void> markDone(RoadmapItem item) =>
      setItemStatus(item.id, RoadmapItemStatus.done);

  Future<void> reset() async {
    await _repo.resetRoadmap();
    _ref.invalidate(enrollmentProvider);
    _ref.invalidate(roadmapProvider);
  }
}

double _strengthValue(Chapter chapter) {
  // Prefer the continuous completion signal; fall back to the strength bucket.
  if (chapter.completionPercentage > 0) {
    return chapter.completionPercentage.clamp(0.0, 1.0);
  }
  switch (chapter.strength) {
    case TopicStrength.weak:
      return 0.3;
    case TopicStrength.moderate:
      return 0.6;
    case TopicStrength.strong:
      return 0.85;
  }
}
