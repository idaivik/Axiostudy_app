import '../../test/domain/test_models.dart';

/// A difficulty window over `questions.difficulty_level` (1–9), with the coarse
/// `easy|medium|hard` label used for generation + copy.
class DifficultyBand {
  final int lo;
  final int hi;
  final String label;
  const DifficultyBand({required this.lo, required this.hi, required this.label});
}

/// Result of a paid AI question-generation request (generate-questions fn).
class GenerationResult {
  final bool ok;
  final List<Question> questions;
  final String? reason; // free_plan_no_generation | monthly_cap_reached | generation_empty | error
  final int? remaining; // credits left this cycle (null = unlimited tier)

  const GenerationResult({
    required this.ok,
    this.questions = const [],
    this.reason,
    this.remaining,
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
    );
  }

  /// Friendly, user-facing explanation for a failed generation.
  String get message {
    switch (reason) {
      case 'free_plan_no_generation':
        return 'Custom AI questions are a paid feature. Upgrade to generate fresh questions.';
      case 'monthly_cap_reached':
        return "You've used all your AI generations this month. They refill next cycle.";
      case 'generation_empty':
        return "Couldn't craft good questions just now — please try again.";
      default:
        return 'Question generation is unavailable right now. Try again later.';
    }
  }
}
