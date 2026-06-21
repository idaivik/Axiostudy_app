import '../../subscription/domain/meter_outcome.dart';

/// Result of the `coach-overview` edge call (Plan B). The account-level sibling
/// of [NarrativeResult]: it couples the metered Pro [narrative] with the
/// DETERMINISTIC focus (`focus*`) that is returned to every user — free or Pro,
/// entitled or locked — so the "#1 focus → Practice" action always works.
class CoachOverview {
  final MeterOutcome outcome;

  /// The Pro coach paragraph. Null/empty when locked, capped, errored, or
  /// before the first test.
  final String? narrative;

  /// True when the paragraph came from the source_hash cache (no meter spent).
  final bool cached;

  /// Weakest chapter — the practice-launch target. Null on a first run (no
  /// weak chapters tracked yet).
  final String? focusChapterId;

  /// Weakest topic within [focusChapterId] (best-effort; may be null).
  final String? focusTopicId;

  /// Chapter mastery for [focusChapterId], 0–100 (higher = stronger).
  final double? focusAccuracy;

  const CoachOverview({
    required this.outcome,
    this.narrative,
    this.cached = false,
    this.focusChapterId,
    this.focusTopicId,
    this.focusAccuracy,
  });

  /// There is a deterministic focus to act on (drives the free Practice footer).
  bool get hasFocus => focusChapterId != null && focusChapterId!.isNotEmpty;

  /// The Pro narrative is present and allowed.
  bool get hasNarrative =>
      outcome.ok && narrative != null && narrative!.isNotEmpty;

  factory CoachOverview.fromJson(Map<String, dynamic> j) => CoachOverview(
        outcome: MeterOutcome.fromJson(j),
        narrative: (j['narrative'] as String?)?.trim(),
        cached: j['cached'] == true,
        focusChapterId: (j['focus_chapter_id'] as String?),
        focusTopicId: (j['focus_topic_id'] as String?),
        focusAccuracy: (j['focus_accuracy'] as num?)?.toDouble(),
      );

  /// A transient/unknown failure (network, unexpected body). No focus available.
  static const CoachOverview error =
      CoachOverview(outcome: MeterOutcome(MeterStatus.error));
}
