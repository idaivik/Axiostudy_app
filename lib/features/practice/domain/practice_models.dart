import '../../test/domain/test_models.dart';

/// A difficulty window over `questions.difficulty_level` (1–9), with the coarse
/// `easy|medium|hard` label used for generation + copy.
class DifficultyBand {
  final int lo;
  final int hi;
  final String label;
  const DifficultyBand({required this.lo, required this.hi, required this.label});
}

/// One named practice test within a subtopic ("Practice Test 1", "Practice
/// Test 2"…). Full tests are 10 easy + 10 medium + 10 hard; once the full
/// 10/10/10 sets are exhausted the leftover questions form a final, smaller
/// test (e.g. 30, 30, 17). See PracticeRepository.subtopicTests.
class SubtopicTest {
  final int index; // 1-based
  final int questionCount;
  final int easyCount;
  final int mediumCount;
  final int hardCount;

  const SubtopicTest({
    required this.index,
    required this.questionCount,
    required this.easyCount,
    required this.mediumCount,
    required this.hardCount,
  });

  String get name => 'Practice Test $index';

  /// A remainder test that isn't a full 10/10/10 set yet.
  bool get isPartial => questionCount < 30;
}

/// Where the questions in a [GenerationResult] came from (see generate-questions).
/// `pool`/`bank` are served from the existing question pool at ₹0 and are
/// indistinguishable to the student; `ai` means net-new generation happened.
enum GenerationSource { ai, pool, bank, none }

/// Result of an AI question request (generate-questions fn). With per-meter
/// billing there is no longer a "wall" for active paid tiers: they either get
/// `ai`/`pool` questions or a silent `bank` fallback (all `ok:true`, HTTP 200).
/// `ok:false` now means exactly one of two things — see [isTrialLocked] /
/// [isNoEntitlement] (HTTP 402) — or a transient generation error.
class GenerationResult {
  final bool ok;
  final List<Question> questions;
  // Reasons: cap_reached | trial_ai_locked | no_entitlement | generation_empty | error
  // (legacy: free_plan_no_generation | monthly_cap_reached | no_credit)
  final String? reason;
  final int? remaining; // meter credits left this cycle (null = not metered, e.g. pool)
  final GenerationSource source;

  const GenerationResult({
    required this.ok,
    this.questions = const [],
    this.reason,
    this.remaining,
    this.source = GenerationSource.none,
  });

  factory GenerationResult.fromJson(Map<String, dynamic> j) {
    return GenerationResult(
      ok: j['ok'] == true,
      questions: (j['questions'] as List?)
              ?.map((e) => Question.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reason: j['reason'] as String?,
      remaining: j['remaining'] as int?,
      source: switch (j['source'] as String?) {
        'ai' => GenerationSource.ai,
        'pool' => GenerationSource.pool,
        'bank' => GenerationSource.bank,
        _ => GenerationSource.none,
      },
    );
  }

  /// 7-day-trial AI hard-lock — render the "unlocks when your trial converts"
  /// state, NOT the paywall (the user is already paying).
  bool get isTrialLocked => reason == 'trial_ai_locked';

  /// No active entitlement (lapsed / never subscribed) — open the paywall.
  /// Folds in the legacy `free_plan_no_generation` reason.
  bool get isNoEntitlement =>
      reason == 'no_entitlement' || reason == 'free_plan_no_generation';

  /// Friendly, user-facing explanation for a failed generation.
  String get message {
    switch (reason) {
      case 'trial_ai_locked':
        return 'AI generation unlocks when your free trial converts. Your other tools are live now.';
      case 'no_entitlement':
      case 'free_plan_no_generation':
        return 'Custom AI questions are a paid feature. Upgrade to generate fresh questions.';
      case 'cap_reached':
      case 'monthly_cap_reached':
        return "You've used all your AI generations this month — serving from the question bank instead.";
      case 'generation_empty':
        return "Couldn't craft good questions just now — please try again.";
      default:
        return 'Question generation is unavailable right now. Try again later.';
    }
  }
}
