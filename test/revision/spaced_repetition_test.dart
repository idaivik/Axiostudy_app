import 'package:flutter_test/flutter_test.dart';
import 'package:axiostudy_app/features/revision/domain/spaced_repetition.dart';

/// Pure SM-2 curve (Bucket 3A · Feature 1). The server `mark_topic_reviewed`
/// RPC mirrors this exactly, so these assertions also pin the persisted schedule.
void main() {
  group('SpacedRepetition.advance — good recall lengthens the gap', () {
    test('first good review → 1 day, reps 1, ease nudged up', () {
      final s = SpacedRepetition.advance(SrsState.fresh, 5);
      expect(s.intervalDays, 1);
      expect(s.reps, 1);
      expect(s.ease, closeTo(2.6, 1e-9)); // 2.5 + 0.1
    });

    test('second good review → 6 days, reps 2', () {
      var s = SpacedRepetition.advance(SrsState.fresh, 5);
      s = SpacedRepetition.advance(s, 5);
      expect(s.intervalDays, 6);
      expect(s.reps, 2);
      expect(s.ease, closeTo(2.7, 1e-9));
    });

    test('third good review → round(prev * ease), reps 3', () {
      var s = SpacedRepetition.advance(SrsState.fresh, 5); // 1d, ease 2.6
      s = SpacedRepetition.advance(s, 5); // 6d, ease 2.7
      s = SpacedRepetition.advance(s, 5); // round(6 * 2.8) = 17
      expect(s.reps, 3);
      expect(s.ease, closeTo(2.8, 1e-9));
      expect(s.intervalDays, 17);
    });

    test('q=4 holds ease steady (the SM-2 neutral grade)', () {
      final s = SpacedRepetition.advance(SrsState.fresh, 4);
      expect(s.ease, closeTo(2.5, 1e-9));
      expect(s.intervalDays, 1);
    });
  });

  group('SpacedRepetition.advance — a lapse shortens it', () {
    test('a lapse resets reps and interval to the shortest, lowers ease', () {
      // Build up a long interval first…
      var s = SpacedRepetition.advance(SrsState.fresh, 5);
      s = SpacedRepetition.advance(s, 5);
      s = SpacedRepetition.advance(s, 5);
      expect(s.intervalDays, greaterThan(6));

      final lapsed = SpacedRepetition.advance(s, 2);
      expect(lapsed.reps, 0);
      expect(lapsed.intervalDays, 1); // back to tomorrow
      expect(lapsed.ease, lessThan(s.ease)); // ease penalised
      expect(lapsed.ease, greaterThanOrEqualTo(SpacedRepetition.minEase));
    });

    test('a lapse always lands on a SHORTER gap than a good recall', () {
      final base = SpacedRepetition.advance(
          SpacedRepetition.advance(SrsState.fresh, 5), 5); // reps 2, 6d
      final good = SpacedRepetition.advance(base, 5);
      final lapse = SpacedRepetition.advance(base, 1);
      expect(lapse.intervalDays, lessThan(good.intervalDays));
    });
  });

  group('SpacedRepetition.advance — guardrails', () {
    test('ease never drops below the floor under repeated failure', () {
      var s = SrsState.fresh;
      for (var i = 0; i < 30; i++) {
        s = SpacedRepetition.advance(s, 0);
      }
      expect(s.ease, greaterThanOrEqualTo(SpacedRepetition.minEase));
      expect(s.intervalDays, greaterThanOrEqualTo(1));
    });

    test('quality is clamped to 0..5', () {
      expect(SpacedRepetition.advance(SrsState.fresh, 99).intervalDays,
          SpacedRepetition.advance(SrsState.fresh, 5).intervalDays);
      expect(SpacedRepetition.advance(SrsState.fresh, -5).reps,
          SpacedRepetition.advance(SrsState.fresh, 0).reps);
    });

    test('nextIntervalDays previews what advance would persist', () {
      expect(SpacedRepetition.nextIntervalDays(SrsState.fresh, 5),
          SpacedRepetition.advance(SrsState.fresh, 5).intervalDays);
    });
  });
}
