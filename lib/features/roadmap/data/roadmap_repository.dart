import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../subscription/domain/meter_outcome.dart';
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
    SupabaseClient? client,
  })  : _planner = planner ?? const RoadmapPlanner(),
        _aiClient = aiClient ?? const HeuristicRoadmapAiClient(),
        _client = client;

  final RoadmapPlanner _planner;
  final RoadmapAiClient _aiClient;

  /// Null in tests / offline: persistence then falls back to local prefs only.
  final SupabaseClient? _client;

  static const _enrollmentKey = 'roadmap_enrollment';
  static const _statusKey = 'roadmap_item_status';
  static const _readinessKey = 'roadmap_readiness_cache';
  static const _enrollmentTable = 'student_enrollment';

  List<CoachingInstitute> get institutes => RoadmapSeedData.institutes;

  /// Loads the enrollment, preferring the server row when signed in (so study
  /// hours / exam track set on another device follow the student), and falling
  /// back to the local mirror when offline or signed out.
  Future<StudentEnrollment?> loadEnrollment() async {
    final user = _client?.auth.currentUser;
    if (_client != null && user != null) {
      try {
        final row = await _client
            .from(_enrollmentTable)
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        if (row != null) {
          final enrollment = StudentEnrollment.fromJson(row);
          await _cacheEnrollment(enrollment); // keep the local mirror fresh
          return enrollment;
        }
      } catch (_) {
        // Network / RLS hiccup → fall through to the local copy.
      }
    }
    return _loadLocalEnrollment();
  }

  Future<void> saveEnrollment(StudentEnrollment enrollment) async {
    await _cacheEnrollment(enrollment);
    final user = _client?.auth.currentUser;
    if (_client != null && user != null) {
      try {
        await _client.from(_enrollmentTable).upsert({
          'user_id': user.id,
          ...enrollment.toJson(),
        });
      } catch (_) {
        // Offline write-through is best-effort; the local mirror still has it.
      }
    }
  }

  Future<StudentEnrollment?> _loadLocalEnrollment() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_enrollmentKey);
    if (raw == null) return null;
    try {
      return StudentEnrollment.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheEnrollment(StudentEnrollment enrollment) async {
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
    ChapterAutoCompletion autoCompletion = ChapterAutoCompletion.empty,
  }) async {
    final sequence = RoadmapSeedData.sequenceFor(
      enrollment.coachingId,
      examType: enrollment.examType,
      phase: enrollment.phase,
    );

    // Baseline is deliberately uniform — same plan for everyone with the same
    // exam track + study hours (no per-student strength weighting). Pace-tuning
    // by performance is the job of the (deferred) AI path, which receives the
    // real strength map via [RoadmapPlanContext] below.
    final draft = _planner.generate(
      sequence: sequence,
      enrollment: enrollment,
      chapterStrength: const {},
    );

    final context = RoadmapPlanContext(
      enrollment: enrollment,
      chapterStrength: chapterStrength,
      chapterNames: {for (final e in sequence.entries) e.chapterId: e.chapterName},
    );
    final annotated = await _aiClient.refine(context, draft.items);

    // Resolve each item's status: an explicit manual override always wins;
    // otherwise a chapter that's cleared the subtopic-test bar for this item's
    // type auto-completes; otherwise the planned status stands.
    final overrides = await _loadStatusOverrides();
    final merged = annotated.map((item) {
      final saved = overrides[item.id];
      if (saved != null) return item.copyWith(status: saved);
      if (autoCompletion.isDone(item.type, item.chapterId)) {
        return item.copyWith(status: RoadmapItemStatus.done);
      }
      return item;
    }).toList();

    return Roadmap(
      items: merged,
      generatedAt: draft.generatedAt,
      examDate: enrollment.examDate,
    );
  }

  /// Whether the student has enough practice data for a detailed, pace-tuned
  /// roadmap. Cached for [RoadmapReadiness.isStale]'s window so tapping
  /// "Generate" repeatedly doesn't re-query; [force] (a manual refresh) skips
  /// the cache. Degrades to "not ready" when signed out / offline.
  Future<RoadmapReadiness> fetchReadiness({bool force = false}) async {
    final user = _client?.auth.currentUser;
    if (_client == null || user == null) return RoadmapReadiness.notReady();

    final cached = await _loadCachedReadiness();
    if (!force && cached != null && !cached.isStale) return cached;

    try {
      final res = await _client.rpc('roadmap_readiness');
      final readiness =
          RoadmapReadiness.fromJson((res as Map).cast<String, dynamic>());
      await _saveCachedReadiness(readiness);
      return readiness;
    } catch (_) {
      return cached ?? RoadmapReadiness.notReady();
    }
  }

  /// Read-only peek at a usage meter (no consumption) for the "generations left"
  /// counter. Returns a no-entitlement outcome when signed out.
  Future<MeterOutcome> fetchMeterStatus(String meter) async {
    final user = _client?.auth.currentUser;
    if (_client == null || user == null) {
      return const MeterOutcome(MeterStatus.noEntitlement, plan: 'free');
    }
    try {
      final res = await _client.rpc('meter_status', params: {'p_meter': meter});
      return MeterOutcome.fromJson((res as Map).cast<String, dynamic>());
    } catch (_) {
      return const MeterOutcome(MeterStatus.error);
    }
  }

  Future<RoadmapReadiness?> _loadCachedReadiness() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_readinessKey);
    if (raw == null) return null;
    try {
      return RoadmapReadiness.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCachedReadiness(RoadmapReadiness readiness) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readinessKey, jsonEncode(readiness.toJson()));
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
    await prefs.remove(_readinessKey);
    final user = _client?.auth.currentUser;
    if (_client != null && user != null) {
      try {
        await _client.from(_enrollmentTable).delete().eq('user_id', user.id);
      } catch (_) {
        // Best-effort; the local mirror is already cleared.
      }
    }
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
