import 'package:flutter_test/flutter_test.dart';
import 'package:axiostudy_app/features/roadmap/data/roadmap_planner.dart';
import 'package:axiostudy_app/features/roadmap/data/roadmap_seed_data.dart';
import 'package:axiostudy_app/features/roadmap/domain/roadmap_models.dart';

void main() {
  const planner = RoadmapPlanner();
  final now = DateTime(2026, 6, 13);

  SyllabusSequence seq() => SyllabusSequence(
        coachingId: 'test',
        entries: const [
          SyllabusEntry(position: 0, subjectId: 'physics', chapterId: 'c0', chapterName: 'Ch0'),
          SyllabusEntry(position: 1, subjectId: 'physics', chapterId: 'c1', chapterName: 'Ch1'),
          SyllabusEntry(position: 2, subjectId: 'chemistry', chapterId: 'c2', chapterName: 'Ch2'),
          SyllabusEntry(position: 3, subjectId: 'maths', chapterId: 'c3', chapterName: 'Ch3'),
        ],
      );

  group('RoadmapPlanner.generate', () {
    test('current chapter is a learn item that starts today', () {
      final enrollment = StudentEnrollment(coachingId: 'test', currentPosition: 1);
      final roadmap = planner.generate(
        sequence: seq(),
        enrollment: enrollment,
        now: now,
      );

      final learnCurrent = roadmap.items.firstWhere(
        (i) => i.type == RoadmapItemType.learn && i.chapterId == 'c1',
      );
      expect(learnCurrent.status, RoadmapItemStatus.current);
      expect(learnCurrent.scheduledStart, now);
    });

    test('future chapters become upcoming learn items in order', () {
      final enrollment = StudentEnrollment(coachingId: 'test', currentPosition: 1);
      final roadmap = planner.generate(sequence: seq(), enrollment: enrollment, now: now);

      final learns = roadmap.items
          .where((i) => i.type == RoadmapItemType.learn)
          .toList();
      // current (c1) + future (c2, c3)
      expect(learns.map((e) => e.chapterId), containsAll(['c1', 'c2', 'c3']));
      expect(learns.where((e) => e.chapterId == 'c0'), isEmpty);

      // Each subsequent learn starts after the previous ends.
      final c2 = learns.firstWhere((e) => e.chapterId == 'c2');
      final c3 = learns.firstWhere((e) => e.chapterId == 'c3');
      expect(c3.scheduledStart.isAfter(c2.scheduledEnd) ||
          c3.scheduledStart.isAtSameMomentAs(c2.scheduledEnd.add(const Duration(days: 1))),
          isTrue);
    });

    test('already-taught chapters become revise items; weak ones also get practice', () {
      final enrollment = StudentEnrollment(coachingId: 'test', currentPosition: 2);
      final roadmap = planner.generate(
        sequence: seq(),
        enrollment: enrollment,
        chapterStrength: {'c0': 0.2, 'c1': 0.9}, // c0 weak, c1 strong
        now: now,
      );

      final revises = roadmap.items.where((i) => i.type == RoadmapItemType.revise);
      expect(revises.map((e) => e.chapterId).toSet(), {'c0', 'c1'});

      final practices = roadmap.items.where((i) => i.type == RoadmapItemType.practice);
      expect(practices.map((e) => e.chapterId).toList(), ['c0']); // only the weak one
    });

    test('schedules ramping full-syllabus mocks before the exam', () {
      final enrollment = StudentEnrollment(
        coachingId: 'test',
        currentPosition: 0,
        examDate: now.add(const Duration(days: 40)),
      );
      final roadmap = planner.generate(sequence: seq(), enrollment: enrollment, now: now);

      final mocks = roadmap.items.where((i) => i.type == RoadmapItemType.mock).toList();
      expect(mocks, isNotEmpty);
      for (final m in mocks) {
        expect(m.scheduledStart.isBefore(enrollment.examDate!), isTrue);
      }
    });

    test('no mocks when no exam date is set', () {
      final enrollment = StudentEnrollment(coachingId: 'test', currentPosition: 0);
      final roadmap = planner.generate(sequence: seq(), enrollment: enrollment, now: now);
      expect(roadmap.items.where((i) => i.type == RoadmapItemType.mock), isEmpty);
    });

    test('closer exam date compresses the per-chapter learn window', () {
      final near = planner.generate(
        sequence: seq(),
        enrollment: StudentEnrollment(
            coachingId: 'test', examDate: now.add(const Duration(days: 30))),
        now: now,
      );
      final far = planner.generate(
        sequence: seq(),
        enrollment: StudentEnrollment(
            coachingId: 'test', examDate: now.add(const Duration(days: 300))),
        now: now,
      );

      int window(Roadmap r) {
        final learn = r.items.firstWhere((i) => i.type == RoadmapItemType.learn);
        return learn.scheduledEnd.difference(learn.scheduledStart).inDays;
      }

      expect(window(near), lessThan(window(far)));
    });

    test('item IDs are stable across regeneration (so completion persists)', () {
      final enrollment = StudentEnrollment(coachingId: 'test', currentPosition: 2);
      final a = planner.generate(sequence: seq(), enrollment: enrollment, now: now);
      final b = planner.generate(sequence: seq(), enrollment: enrollment, now: now);
      expect(a.items.map((e) => e.id).toList(), b.items.map((e) => e.id).toList());
    });

    test('empty sequence yields an empty roadmap', () {
      final roadmap = planner.generate(
        sequence: const SyllabusSequence(coachingId: 'x', entries: []),
        enrollment: StudentEnrollment(coachingId: 'x'),
        now: now,
      );
      expect(roadmap.items, isEmpty);
    });

    test('items are globally sorted by scheduled start', () {
      final roadmap = planner.generate(
        sequence: seq(),
        enrollment: StudentEnrollment(
          coachingId: 'test',
          currentPosition: 2,
          examDate: now.add(const Duration(days: 45)),
        ),
        chapterStrength: {'c0': 0.2},
        now: now,
      );
      for (var i = 1; i < roadmap.items.length; i++) {
        expect(
          roadmap.items[i].scheduledStart
              .isBefore(roadmap.items[i - 1].scheduledStart),
          isFalse,
        );
      }
    });
  });

  group('Roadmap getters', () {
    test('completionFraction reflects done items', () {
      final enrollment = StudentEnrollment(coachingId: 'test', currentPosition: 1);
      final roadmap = planner.generate(sequence: seq(), enrollment: enrollment, now: now);
      expect(roadmap.completionFraction, 0.0);

      final marked = Roadmap(
        items: [
          roadmap.items.first.copyWith(status: RoadmapItemStatus.done),
          ...roadmap.items.skip(1),
        ],
        generatedAt: now,
      );
      expect(marked.completionFraction, greaterThan(0.0));
    });
  });

  group('RoadmapSeedData', () {
    test('every coaching produces a non-empty sequence', () {
      for (final c in RoadmapSeedData.institutes) {
        final s = RoadmapSeedData.sequenceFor(c.id);
        expect(s.entries, isNotEmpty, reason: '${c.id} sequence should not be empty');
        // positions are 0..n-1 contiguous
        for (var i = 0; i < s.entries.length; i++) {
          expect(s.entries[i].position, i);
        }
      }
    });

    test('unknown coaching falls back to a usable sequence', () {
      final s = RoadmapSeedData.sequenceFor('does-not-exist');
      expect(s.entries, isNotEmpty);
    });
  });
}
