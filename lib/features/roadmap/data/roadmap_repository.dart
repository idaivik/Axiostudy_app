import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/roadmap_models.dart';
import 'roadmap_ai_client.dart';
import 'roadmap_planner.dart';
import 'roadmap_seed_data.dart';

/// Assembles and persists the student's roadmap.
///
/// Persistence is local (shared_preferences) for now: the student's enrollment
/// and per-item completion status. Coaching sequences come from
/// [RoadmapSeedData]. The roadmap itself is regenerated deterministically each
/// load via [RoadmapPlanner], then annotated by the [RoadmapAiClient] and
/// overlaid with saved completion status. Swapping to Supabase later only means
/// replacing the two prefs methods + the AI client (see migration + ai_client docs).
class RoadmapRepository {
  RoadmapRepository({
    RoadmapPlanner? planner,
    RoadmapAiClient? aiClient,
  })  : _planner = planner ?? const RoadmapPlanner(),
        _aiClient = aiClient ?? const HeuristicRoadmapAiClient();

  final RoadmapPlanner _planner;
  final RoadmapAiClient _aiClient;

  static const _enrollmentKey = 'roadmap_enrollment';
  static const _statusKey = 'roadmap_item_status';

  List<CoachingInstitute> get institutes => RoadmapSeedData.institutes;

  Future<StudentEnrollment?> loadEnrollment() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_enrollmentKey);
    if (raw == null) return null;
    try {
      return StudentEnrollment.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveEnrollment(StudentEnrollment enrollment) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_enrollmentKey, jsonEncode(enrollment.toJson()));
  }

  /// True once the student has completed roadmap setup.
  Future<bool> hasEnrollment() async => (await loadEnrollment()) != null;

  /// Build the current roadmap for [enrollment]. [chapterStrength] maps
  /// chapterId → strength in [0,1] (from the analytics/subjects layer).
  Future<Roadmap> buildRoadmap({
    required StudentEnrollment enrollment,
    Map<String, double> chapterStrength = const {},
  }) async {
    final sequence = RoadmapSeedData.sequenceFor(
      enrollment.coachingId,
      examType: enrollment.examType,
      phase: enrollment.phase,
    );

    final draft = _planner.generate(
      sequence: sequence,
      enrollment: enrollment,
      chapterStrength: chapterStrength,
    );

    final context = RoadmapPlanContext(
      enrollment: enrollment,
      chapterStrength: chapterStrength,
      chapterNames: {for (final e in sequence.entries) e.chapterId: e.chapterName},
    );
    final annotated = await _aiClient.refine(context, draft.items);

    // Overlay saved completion/skip status.
    final overrides = await _loadStatusOverrides();
    final merged = annotated.map((item) {
      final saved = overrides[item.id];
      return saved == null ? item : item.copyWith(status: saved);
    }).toList();

    return Roadmap(
      items: merged,
      generatedAt: draft.generatedAt,
      examDate: enrollment.examDate,
    );
  }

  Future<void> setItemStatus(String itemId, RoadmapItemStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    final overrides = await _loadStatusOverrides();
    if (status == RoadmapItemStatus.upcoming || status == RoadmapItemStatus.current) {
      overrides.remove(itemId);
    } else {
      overrides[itemId] = status;
    }
    await prefs.setString(
      _statusKey,
      jsonEncode(overrides.map((k, v) => MapEntry(k, v.asString))),
    );
  }

  Future<void> resetRoadmap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enrollmentKey);
    await prefs.remove(_statusKey);
  }

  Future<Map<String, RoadmapItemStatus>> _loadStatusOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statusKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(k, RoadmapItemStatus.fromString(v as String?)),
      );
    } catch (_) {
      return {};
    }
  }
}
