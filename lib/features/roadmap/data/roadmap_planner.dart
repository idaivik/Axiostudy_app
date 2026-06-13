import 'package:flutter/material.dart';
import '../domain/roadmap_models.dart';

/// Deterministic roadmap scheduler.
///
/// This is the pure, testable core (no network, no AI): given a coaching
/// sequence, the student's enrollment, and per-chapter strength, it produces a
/// dated [Roadmap]. The "why this week" copy is filled separately by a
/// [RoadmapAiClient] so this layer stays deterministic.
///
/// Strategy, planned forward from today and backward from the exam:
///  - LEARN the chapter the class is currently on, then future chapters in
///    teaching order, each in its own window.
///  - REVISE already-taught chapters on a staggered spaced cadence (weakest first).
///  - PRACTICE weak already-taught chapters with targeted drills.
///  - MOCK full-syllabus tests every two weeks in the run-up to the exam.
class RoadmapPlanner {
  const RoadmapPlanner();

  Roadmap generate({
    required SyllabusSequence sequence,
    required StudentEnrollment enrollment,
    Map<String, double> chapterStrength = const {},
    DateTime? now,
  }) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final entries = sequence.entries;
    final items = <RoadmapItem>[];

    // Per-(type,chapter) occurrence counters → stable IDs so completion status
    // survives re-planning.
    final occ = <String, int>{};
    String idFor(RoadmapItemType type, String chapterId) {
      final key = '${type.asString}-$chapterId';
      final n = occ[key] = (occ[key] ?? -1) + 1;
      return '$key-$n';
    }

    if (entries.isEmpty) {
      return Roadmap(items: items, generatedAt: now ?? DateTime.now(), examDate: enrollment.examDate);
    }

    final current = enrollment.currentPosition.clamp(0, entries.length - 1);
    final remaining = entries.length - current;
    final learnWindow = _learnWindowDays(enrollment, remaining);

    // ── LEARN: current chapter starts today, future chapters follow ──
    var cursor = today;
    for (var i = current; i < entries.length; i++) {
      final e = entries[i];
      final start = cursor;
      final end = _addDays(start, learnWindow - 1);
      items.add(RoadmapItem(
        id: idFor(RoadmapItemType.learn, e.chapterId),
        subjectId: e.subjectId,
        chapterId: e.chapterId,
        chapterName: e.chapterName,
        type: RoadmapItemType.learn,
        status: i == current ? RoadmapItemStatus.current : RoadmapItemStatus.upcoming,
        scheduledStart: start,
        scheduledEnd: end,
        priority: i == current ? 3 : 1,
      ));
      cursor = _addDays(end, 1);
    }

    // ── REVISE + PRACTICE: already-taught chapters, weakest first ──
    final taught = entries.sublist(0, current).toList()
      ..sort((a, b) => (chapterStrength[a.chapterId] ?? 0.6)
          .compareTo(chapterStrength[b.chapterId] ?? 0.6));

    var reviseCursor = today;
    for (final e in taught) {
      final strength = chapterStrength[e.chapterId] ?? 0.6;
      final isWeak = strength < 0.5;

      final rStart = reviseCursor;
      final rEnd = _addDays(rStart, 1);
      items.add(RoadmapItem(
        id: idFor(RoadmapItemType.revise, e.chapterId),
        subjectId: e.subjectId,
        chapterId: e.chapterId,
        chapterName: e.chapterName,
        type: RoadmapItemType.revise,
        scheduledStart: rStart,
        scheduledEnd: rEnd,
        priority: isWeak ? 2 : 1,
      ));
      reviseCursor = _addDays(rEnd, 2); // stagger revisions

      if (isWeak) {
        final pStart = _addDays(rStart, 3);
        items.add(RoadmapItem(
          id: idFor(RoadmapItemType.practice, e.chapterId),
          subjectId: e.subjectId,
          chapterId: e.chapterId,
          chapterName: e.chapterName,
          type: RoadmapItemType.practice,
          scheduledStart: pStart,
          scheduledEnd: _addDays(pStart, 1),
          priority: 3,
        ));
      }
    }

    // ── MOCK: full-syllabus tests in the run-up to the exam ──
    final daysToExam = enrollment.daysToExam;
    if (enrollment.examDate != null && daysToExam != null && daysToExam > 2) {
      final examDay = DateUtils.dateOnly(enrollment.examDate!);
      final mockPhase = daysToExam < 56 ? daysToExam : 56;
      var mockDay = _addDays(examDay, -mockPhase);
      if (mockDay.isBefore(today)) mockDay = today;
      while (mockDay.isBefore(_addDays(examDay, -2))) {
        items.add(RoadmapItem(
          id: idFor(RoadmapItemType.mock, 'full'),
          subjectId: 'all',
          chapterId: 'full_syllabus',
          chapterName: 'Full Syllabus Mock',
          type: RoadmapItemType.mock,
          scheduledStart: mockDay,
          scheduledEnd: _addDays(mockDay, 1),
          priority: 2,
        ));
        mockDay = _addDays(mockDay, 14);
      }
    }

    items.sort((a, b) {
      final byDate = a.scheduledStart.compareTo(b.scheduledStart);
      return byDate != 0 ? byDate : b.priority.compareTo(a.priority);
    });

    return Roadmap(
      items: items,
      generatedAt: now ?? DateTime.now(),
      examDate: enrollment.examDate,
    );
  }

  /// Days allotted per chapter: spread remaining "learning time" (≈70% of the
  /// runway to the exam, leaving the rest for revision + mocks) across the
  /// chapters left to learn. Clamped to a sane 1–3 week window.
  int _learnWindowDays(StudentEnrollment enrollment, int remainingChapters) {
    final days = enrollment.daysToExam;
    if (days == null || days <= 0 || remainingChapters <= 0) return 14;
    final learnDays = (days * 0.7).floor();
    final per = (learnDays / remainingChapters).floor();
    return per.clamp(7, 21);
  }

  DateTime _addDays(DateTime d, int n) => DateUtils.addDaysToDate(d, n);
}
