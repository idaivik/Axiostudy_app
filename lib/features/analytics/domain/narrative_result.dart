import '../../subscription/domain/meter_outcome.dart';

/// Result of the `analysis-narrative` edge call (Feature 3). Couples the metered
/// [outcome] with the generated [narrative] so the UI can render the paragraph
/// on `ok` and the §2.2 locked/cap states otherwise.
class NarrativeResult {
  final MeterOutcome outcome;
  final String? narrative;

  /// True when the paragraph came from the attempt's cache (no meter spent).
  final bool cached;

  const NarrativeResult({
    required this.outcome,
    this.narrative,
    this.cached = false,
  });

  factory NarrativeResult.fromJson(Map<String, dynamic> j) => NarrativeResult(
        outcome: MeterOutcome.fromJson(j),
        narrative: (j['narrative'] as String?)?.trim(),
        cached: j['cached'] == true,
      );

  /// A transient/unknown failure (network, unexpected body).
  static const NarrativeResult error =
      NarrativeResult(outcome: MeterOutcome(MeterStatus.error));
}
