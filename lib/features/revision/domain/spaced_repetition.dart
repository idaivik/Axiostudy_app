/// Pure SM-2 spaced-repetition curve (Bucket 3A · Feature 1).
///
/// This is the CANONICAL spec for the revision plan's interval math. The
/// server-side advance lives in the `mark_topic_reviewed` RPC
/// (20260619150000_revision_plan.sql) and MUST mirror this function exactly —
/// the RPC persists the curve, this drives the unit test + the client's
/// "next review in ~N days" preview. No I/O, no clock: deterministic and
/// trivially testable.
///
/// Textbook SM-2: a self-rated recall quality `q` in 0..5.
///   q < 3  → lapse: the repetition restarts (reps→0, interval→1 day).
///   q >= 3 → advance: I(1)=1, I(2)=6, then round(prevInterval * ease) days.
/// The ease factor is nudged every review (and floored at 1.3) so well-recalled
/// topics stretch out faster and shaky ones stay tight.
class SrsState {
  /// Days until the next review after this advance.
  final int intervalDays;

  /// SM-2 ease factor (>= 1.3).
  final double ease;

  /// Successful repetitions in a row (0 right after a lapse).
  final int reps;

  const SrsState({
    required this.intervalDays,
    required this.ease,
    required this.reps,
  });

  /// A never-reviewed topic: due now, default ease, no reps yet.
  static const SrsState fresh = SrsState(intervalDays: 1, ease: 2.5, reps: 0);
}

class SpacedRepetition {
  const SpacedRepetition._();

  /// Lowest ease SM-2 allows — keeps a chronically-missed topic from collapsing
  /// to a degenerate (negative/zero) interval.
  static const double minEase = 1.3;

  /// A self-rating of 3 is the lapse boundary: below it, the topic restarts.
  static const int lapseThreshold = 3;

  /// Advance [prev] by a review rated [quality] (0..5, clamped). Pure: same
  /// inputs → same [SrsState], every time. Mirrors `mark_topic_reviewed`.
  static SrsState advance(SrsState prev, int quality) {
    final q = quality.clamp(0, 5);

    // Ease is nudged on every review, recalled or lapsed (classic SM-2).
    final ease =
        (prev.ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))).clamp(minEase, double.infinity);

    if (q < lapseThreshold) {
      // Lapse → restart the repetition with the shortest interval.
      return SrsState(intervalDays: 1, ease: ease.toDouble(), reps: 0);
    }

    final reps = prev.reps + 1;
    final interval = switch (reps) {
      1 => 1,
      2 => 6,
      _ => (prev.intervalDays * ease).round().clamp(1, 1 << 30),
    };
    return SrsState(intervalDays: interval, ease: ease.toDouble(), reps: reps);
  }

  /// Days from now until the next review if [prev] is rated [quality] — the
  /// client-side preview that matches what the RPC will persist.
  static int nextIntervalDays(SrsState prev, int quality) =>
      advance(prev, quality).intervalDays;
}
