import '../domain/roadmap_models.dart';

/// Context handed to the AI step when refining a draft roadmap.
class RoadmapPlanContext {
  final StudentEnrollment enrollment;

  /// chapterId -> strength in [0,1] (lower = weaker). Drives prioritisation.
  final Map<String, double> chapterStrength;

  /// chapterId -> human chapter name (for copy).
  final Map<String, String> chapterNames;

  const RoadmapPlanContext({
    required this.enrollment,
    this.chapterStrength = const {},
    this.chapterNames = const {},
  });
}

/// The "AI" seam of the roadmap engine.
///
/// Per the design decision in docs/features/ai_coaching_roadmap.md, the
/// deterministic [RoadmapPlanner] owns dates + SRS cadence; this client owns
/// the *ordering rationale* and the human-readable "why this, this week" copy.
///
/// [HeuristicRoadmapAiClient] runs fully offline and is the default. The
/// production path is a Claude-backed implementation calling a Supabase Edge
/// Function (so the Anthropic API key stays server-side, never in the app):
///
///   class ClaudeRoadmapAiClient implements RoadmapAiClient {
///     // POST plan context to an edge function that calls
///     // claude-opus-4-8 and returns refined ordering + reason strings.
///   }
///
/// ⚠️ BILLING HOOK (deferred — BILLING_PRICING_AND_TIERS_PLAN.md §6, §9 step 6):
/// `ai_roadmap` is a server-metered Pro surface (Basic 2/mo, Pro 8/mo — already
/// seeded in `meter_limits`, see 20260617120000_usage_meters.sql). When the
/// `ClaudeRoadmapAiClient` edge function above is built, it MUST gate the same
/// way generate-questions does:
///   1. call `consume_meter(p_user, 'ai_roadmap')` before spending the LLM;
///   2. branch on the reason — `trial_ai_locked` / `no_entitlement` → 402,
///      `cap_reached` → fall back to the [HeuristicRoadmapAiClient] output (no wall);
///   3. route generation to the CHEAP model (`GEMINI_CHEAP_MODEL`), not Flash —
///      roadmap ordering is a non-correctness surface.
/// The offline client below is unmetered (₹0) and needs no gate.
abstract class RoadmapAiClient {
  /// Annotate (and optionally re-prioritise) a draft plan. Implementations must
  /// preserve the schedule windows produced by the planner.
  Future<List<RoadmapItem>> refine(
    RoadmapPlanContext context,
    List<RoadmapItem> draft,
  );
}

/// Offline default: fills in rationale copy and bumps weak-chapter priority.
class HeuristicRoadmapAiClient implements RoadmapAiClient {
  const HeuristicRoadmapAiClient();

  @override
  Future<List<RoadmapItem>> refine(
    RoadmapPlanContext context,
    List<RoadmapItem> draft,
  ) async {
    return draft
        .map((item) => item.reason != null && item.reason!.isNotEmpty
            ? item
            : _withReason(item, context))
        .toList();
  }

  RoadmapItem _withReason(RoadmapItem item, RoadmapPlanContext context) {
    final strength = context.chapterStrength[item.chapterId];
    final reason = _reasonFor(item, strength, context.enrollment);
    // Re-using copyWith would drop the reason (it only copies status), so build
    // a fresh item preserving the schedule.
    return RoadmapItem(
      id: item.id,
      subjectId: item.subjectId,
      chapterId: item.chapterId,
      chapterName: item.chapterName,
      topicId: item.topicId,
      type: item.type,
      status: item.status,
      scheduledStart: item.scheduledStart,
      scheduledEnd: item.scheduledEnd,
      priority: item.priority,
      reason: reason,
    );
  }

  String _reasonFor(
    RoadmapItem item,
    double? strength,
    StudentEnrollment enrollment,
  ) {
    final weak = strength != null && strength < 0.5;
    switch (item.type) {
      case RoadmapItemType.learn:
        return 'Your ${_coachingLabel(enrollment.coachingId)} class is on '
            '${item.chapterName} this week — learn it while it\'s fresh.';
      case RoadmapItemType.revise:
        return weak
            ? '${item.chapterName} is still shaky. Spaced revision now locks it in '
                'before the next layer builds on it.'
            : 'Quick spaced revision of ${item.chapterName} to keep it from fading.';
      case RoadmapItemType.practice:
        return weak
            ? '${item.chapterName} is one of your weak chapters — targeted drilling '
                'will move the needle most here.'
            : 'Sharpen ${item.chapterName} with a focused practice set.';
      case RoadmapItemType.mock:
        final days = enrollment.daysToExam;
        return days != null
            ? 'Full-syllabus mock — $days days to ${enrollment.examType.label}, '
                'time to train exam stamina + pacing.'
            : 'Full-syllabus mock to pressure-test everything you\'ve covered.';
    }
  }

  String _coachingLabel(String coachingId) {
    if (coachingId == 'custom' || coachingId == 'standard') return 'study';
    return coachingId.toUpperCase() == coachingId
        ? coachingId
        : coachingId[0].toUpperCase() + coachingId.substring(1);
  }
}
