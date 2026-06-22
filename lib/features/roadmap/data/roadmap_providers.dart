import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/models/enums.dart';
import '../../subjects/data/subjects_providers.dart';
import '../../subjects/domain/subject_models.dart';
import '../../subscription/domain/meter_outcome.dart';
import '../domain/roadmap_models.dart';
import 'roadmap_repository.dart';

/// Roadmap repository (Supabase + local persistence + planner + AI annotation).
final roadmapRepositoryProvider = Provider<RoadmapRepository>((ref) {
  return RoadmapRepository(client: ref.watch(supabaseClientProvider));
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

/// Chapters the student has auto-completed via subtopic tests, per row type.
/// Driven server-side by the `roadmap_chapter_progress()` RPC (only attempts
/// scoring >60% count). Degrades to [ChapterAutoCompletion.empty] when signed
/// out or if the RPC is unavailable — the roadmap then relies on manual checks.
final chapterAutoCompletionProvider =
    FutureProvider<ChapterAutoCompletion>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client.auth.currentUser == null) return ChapterAutoCompletion.empty;
  try {
    final rows = await client.rpc('roadmap_chapter_progress') as List;
    final map = <String, Set<RoadmapItemType>>{};
    for (final r in rows) {
      final chapterId = r['chapter_id'] as String?;
      if (chapterId == null) continue;
      final types = <RoadmapItemType>{
        if (r['learn_done'] == true) RoadmapItemType.learn,
        if (r['revise_done'] == true) RoadmapItemType.revise,
        if (r['practice_done'] == true) RoadmapItemType.practice,
      };
      if (types.isNotEmpty) map[chapterId] = types;
    }
    return ChapterAutoCompletion(map);
  } catch (_) {
    return ChapterAutoCompletion.empty;
  }
});

/// The fully-assembled roadmap (null until the student has an enrollment).
final roadmapProvider = FutureProvider<Roadmap?>((ref) async {
  final repo = ref.watch(roadmapRepositoryProvider);
  final enrollment = await ref.watch(enrollmentProvider.future);
  if (enrollment == null) return null;

  final strength = await ref.watch(chapterStrengthProvider.future);
  final autoCompletion = await ref.watch(chapterAutoCompletionProvider.future);
  return repo.buildRoadmap(
    enrollment: enrollment,
    chapterStrength: strength,
    autoCompletion: autoCompletion,
  );
});

/// Whether the student has practiced enough for a detailed, pace-tuned roadmap
/// (+ a projected ready date). Cached server-side verdict; see [fetchReadiness].
final roadmapReadinessProvider = FutureProvider<RoadmapReadiness>((ref) async {
  return ref.watch(roadmapRepositoryProvider).fetchReadiness();
});

/// Read-only peek at the `ai_roadmap` meter (Basic 2/mo, Pro 8/mo) for the
/// "generations left this month" counter — does not consume a credit.
final roadmapMeterProvider = FutureProvider<MeterOutcome>((ref) async {
  return ref.watch(roadmapRepositoryProvider).fetchMeterStatus('ai_roadmap');
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

  /// Force a fresh readiness check (bypasses the daily cooldown), then refresh
  /// the provider so the gate UI re-reads the new verdict.
  Future<void> refreshReadiness() async {
    await _repo.fetchReadiness(force: true);
    _ref.invalidate(roadmapReadinessProvider);
  }

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
