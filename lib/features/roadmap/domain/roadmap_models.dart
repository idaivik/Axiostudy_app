import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

/// Domain models for the AI Coaching-Synced Study Roadmap.
///
/// A [SyllabusSequence] is the ordered list of chapters a coaching institute
/// teaches. A [StudentEnrollment] records which coaching/phase the student is
/// in, their exam date, and where their class currently is. The planner turns
/// those into a [Roadmap] — a dated list of [RoadmapItem]s.

/// What a roadmap item asks the student to do.
enum RoadmapItemType {
  /// The chapter currently being taught in class — learn it now.
  learn,

  /// Spaced revision of a previously-covered (often weak) chapter.
  revise,

  /// Targeted drilling of a weak topic/chapter.
  practice,

  /// A full-syllabus mock test (ramps up near the exam).
  mock;

  String get label {
    switch (this) {
      case RoadmapItemType.learn:
        return 'Learn';
      case RoadmapItemType.revise:
        return 'Revise';
      case RoadmapItemType.practice:
        return 'Practice';
      case RoadmapItemType.mock:
        return 'Mock Test';
    }
  }

  IconData get iconData {
    switch (this) {
      case RoadmapItemType.learn:
        return LucideIcons.bookOpen;
      case RoadmapItemType.revise:
        return LucideIcons.repeat;
      case RoadmapItemType.practice:
        return LucideIcons.target;
      case RoadmapItemType.mock:
        return LucideIcons.fileText;
    }
  }

  Color get color {
    switch (this) {
      case RoadmapItemType.learn:
        return AppColors.primary;
      case RoadmapItemType.revise:
        return AppColors.chemistry;
      case RoadmapItemType.practice:
        return AppColors.warning;
      case RoadmapItemType.mock:
        return AppColors.physics;
    }
  }

  static RoadmapItemType fromString(String? s) {
    switch (s) {
      case 'revise':
        return RoadmapItemType.revise;
      case 'practice':
        return RoadmapItemType.practice;
      case 'mock':
        return RoadmapItemType.mock;
      default:
        return RoadmapItemType.learn;
    }
  }

  String get asString => name;
}

/// Progress state of a roadmap item.
enum RoadmapItemStatus {
  upcoming,
  current,
  done,
  skipped,
  overdue;

  String get label {
    switch (this) {
      case RoadmapItemStatus.upcoming:
        return 'Upcoming';
      case RoadmapItemStatus.current:
        return 'This Week';
      case RoadmapItemStatus.done:
        return 'Done';
      case RoadmapItemStatus.skipped:
        return 'Skipped';
      case RoadmapItemStatus.overdue:
        return 'Overdue';
    }
  }

  static RoadmapItemStatus fromString(String? s) {
    switch (s) {
      case 'current':
        return RoadmapItemStatus.current;
      case 'done':
        return RoadmapItemStatus.done;
      case 'skipped':
        return RoadmapItemStatus.skipped;
      case 'overdue':
        return RoadmapItemStatus.overdue;
      default:
        return RoadmapItemStatus.upcoming;
    }
  }

  String get asString => name;
}

/// Which exam the student is targeting (drives which coachings/subjects apply).
enum ExamType {
  jee,
  neet;

  String get label => this == ExamType.jee ? 'JEE' : 'NEET';

  static ExamType fromString(String? s) =>
      s == 'neet' ? ExamType.neet : ExamType.jee;

  String get asString => name;

  /// Fixed exam day for this track — JEE ≈ Jan 24, NEET ≈ May 4. Returns the
  /// next occurrence on/after [from] (today by default), rolling to next year
  /// once this year's date has passed. Hardcoded because these barely move
  /// year-to-year, so the student no longer picks a date in setup.
  DateTime nextExamDate([DateTime? from]) {
    final today = DateUtils.dateOnly(from ?? DateTime.now());
    final month = this == ExamType.neet ? 5 : 1;
    final day = this == ExamType.neet ? 4 : 24;
    var d = DateTime(today.year, month, day);
    if (d.isBefore(today)) d = DateTime(today.year + 1, month, day);
    return d;
  }
}

/// A coaching institute (or the Standard / Custom pseudo-institutes).
class CoachingInstitute {
  final String id;
  final String name;
  final String examType; // 'jee' | 'neet' | 'both'
  final bool isCustom;

  const CoachingInstitute({
    required this.id,
    required this.name,
    this.examType = 'both',
    this.isCustom = false,
  });

  factory CoachingInstitute.fromJson(Map<String, dynamic> json) {
    return CoachingInstitute(
      id: json['id'] as String,
      name: json['name'] as String,
      examType: json['exam_type'] as String? ?? 'both',
      isCustom: json['is_custom'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exam_type': examType,
        'is_custom': isCustom,
      };
}

/// A single chapter in a coaching's teaching order.
class SyllabusEntry {
  final int position;
  final String subjectId;
  final String chapterId;
  final String chapterName;
  final int? expectedWeek;

  const SyllabusEntry({
    required this.position,
    required this.subjectId,
    required this.chapterId,
    required this.chapterName,
    this.expectedWeek,
  });

  factory SyllabusEntry.fromJson(Map<String, dynamic> json) {
    return SyllabusEntry(
      position: json['position'] as int,
      subjectId: json['subject_id'] as String,
      chapterId: json['chapter_id'] as String,
      chapterName: json['chapter_name'] as String,
      expectedWeek: json['expected_week'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'position': position,
        'subject_id': subjectId,
        'chapter_id': chapterId,
        'chapter_name': chapterName,
        'expected_week': expectedWeek,
      };
}

/// The ordered chapter list for one coaching + phase.
class SyllabusSequence {
  final String coachingId;
  final String phase;
  final List<SyllabusEntry> entries;

  const SyllabusSequence({
    required this.coachingId,
    this.phase = 'full',
    required this.entries,
  });

  int get length => entries.length;
}

/// What the student told us in setup.
class StudentEnrollment {
  final String coachingId;
  final String phase;
  final ExamType examType;
  final DateTime? batchStartDate;
  final DateTime? examDate;
  final int dailyMinutes;

  /// Index into the sequence marking the chapter class is currently on.
  final int currentPosition;

  const StudentEnrollment({
    required this.coachingId,
    this.phase = 'full',
    this.examType = ExamType.jee,
    this.batchStartDate,
    this.examDate,
    this.dailyMinutes = 120,
    this.currentPosition = 0,
  });

  /// Days remaining until the exam (null if no exam date set).
  int? get daysToExam {
    if (examDate == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(examDate!).difference(today).inDays;
  }

  StudentEnrollment copyWith({
    String? coachingId,
    String? phase,
    ExamType? examType,
    DateTime? batchStartDate,
    DateTime? examDate,
    int? dailyMinutes,
    int? currentPosition,
  }) {
    return StudentEnrollment(
      coachingId: coachingId ?? this.coachingId,
      phase: phase ?? this.phase,
      examType: examType ?? this.examType,
      batchStartDate: batchStartDate ?? this.batchStartDate,
      examDate: examDate ?? this.examDate,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      currentPosition: currentPosition ?? this.currentPosition,
    );
  }

  factory StudentEnrollment.fromJson(Map<String, dynamic> json) {
    return StudentEnrollment(
      coachingId: json['coaching_id'] as String? ?? 'standard',
      phase: json['phase'] as String? ?? 'full',
      examType: ExamType.fromString(json['exam_type'] as String?),
      batchStartDate: _parseDate(json['batch_start_date']),
      examDate: _parseDate(json['exam_date']),
      dailyMinutes: json['daily_minutes'] as int? ?? 120,
      currentPosition: json['current_position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'coaching_id': coachingId,
        'phase': phase,
        'exam_type': examType.asString,
        'batch_start_date': batchStartDate?.toIso8601String().split('T').first,
        'exam_date': examDate?.toIso8601String().split('T').first,
        'daily_minutes': dailyMinutes,
        'current_position': currentPosition,
      };

  static DateTime? _parseDate(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}

/// A single scheduled task in the roadmap.
class RoadmapItem {
  final String id;
  final String subjectId;
  final String chapterId;
  final String chapterName;
  final String? topicId;
  final RoadmapItemType type;
  final RoadmapItemStatus status;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int priority;
  final String? reason;

  const RoadmapItem({
    required this.id,
    required this.subjectId,
    required this.chapterId,
    required this.chapterName,
    this.topicId,
    required this.type,
    this.status = RoadmapItemStatus.upcoming,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.priority = 0,
    this.reason,
  });

  bool get isDone => status == RoadmapItemStatus.done;

  /// True when [scheduledStart, scheduledEnd] contains today.
  bool get isThisWeek {
    final today = DateUtils.dateOnly(DateTime.now());
    return !today.isBefore(DateUtils.dateOnly(scheduledStart)) &&
        !today.isAfter(DateUtils.dateOnly(scheduledEnd));
  }

  RoadmapItem copyWith({RoadmapItemStatus? status}) {
    return RoadmapItem(
      id: id,
      subjectId: subjectId,
      chapterId: chapterId,
      chapterName: chapterName,
      topicId: topicId,
      type: type,
      status: status ?? this.status,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      priority: priority,
      reason: reason,
    );
  }

  factory RoadmapItem.fromJson(Map<String, dynamic> json) {
    return RoadmapItem(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      chapterId: json['chapter_id'] as String,
      chapterName: json['chapter_name'] as String? ?? json['chapter_id'] as String,
      topicId: json['topic_id'] as String?,
      type: RoadmapItemType.fromString(json['type'] as String?),
      status: RoadmapItemStatus.fromString(json['status'] as String?),
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
      priority: json['priority'] as int? ?? 0,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'chapter_id': chapterId,
        'chapter_name': chapterName,
        'topic_id': topicId,
        'type': type.asString,
        'status': status.asString,
        'scheduled_start': scheduledStart.toIso8601String().split('T').first,
        'scheduled_end': scheduledEnd.toIso8601String().split('T').first,
        'priority': priority,
        'reason': reason,
      };
}

/// Which roadmap rows a chapter has earned automatically from subtopic-test
/// performance (see `roadmap_chapter_progress()`). A chapter only appears here
/// once *every* one of its subtopics clears the relevant tier:
///   * [RoadmapItemType.learn]    — 3 different passing (>60%) tests per subtopic.
///   * [RoadmapItemType.revise]   — 6 passing tests per subtopic (cumulative).
///   * [RoadmapItemType.practice] — 9 passing tests per subtopic (cumulative).
class ChapterAutoCompletion {
  /// chapterId → the roadmap item types it has auto-completed.
  final Map<String, Set<RoadmapItemType>> doneTypesByChapter;

  const ChapterAutoCompletion(this.doneTypesByChapter);

  static const empty = ChapterAutoCompletion(<String, Set<RoadmapItemType>>{});

  bool isDone(RoadmapItemType type, String chapterId) =>
      doneTypesByChapter[chapterId]?.contains(type) ?? false;
}

/// Whether the student has practiced enough for the AI to build a detailed,
/// pace-tuned roadmap — and, if not, a projected date when they will. Computed
/// server-side by `roadmap_readiness()`; cached client-side so repeated
/// "Generate" taps don't re-query (a manual refresh bypasses the cache).
class RoadmapReadiness {
  final bool ready;
  final int distinctChapters;
  final int passingTests;
  final int minChapters;
  final int minTests;

  /// Projected date the student will have enough data (null when there's no
  /// recent practice to extrapolate from — the UI then shows a plain prompt).
  final DateTime? predictedReadyDate;

  /// When this verdict was computed (drives the re-check cooldown).
  final DateTime checkedAt;

  RoadmapReadiness({
    required this.ready,
    required this.distinctChapters,
    required this.passingTests,
    this.minChapters = 3,
    this.minTests = 10,
    this.predictedReadyDate,
    DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? DateTime.now();

  factory RoadmapReadiness.notReady() =>
      RoadmapReadiness(ready: false, distinctChapters: 0, passingTests: 0);

  /// Re-check at most once a day; a manual refresh forces a fresh check.
  bool get isStale =>
      DateTime.now().difference(checkedAt) > const Duration(hours: 24);

  /// 0..1 progress toward unlocking, averaging chapter breadth and test volume.
  double get progress {
    final c = (distinctChapters / minChapters).clamp(0.0, 1.0);
    final t = (passingTests / minTests).clamp(0.0, 1.0);
    return ((c + t) / 2).clamp(0.0, 1.0);
  }

  factory RoadmapReadiness.fromJson(Map<String, dynamic> j) => RoadmapReadiness(
        ready: j['ready'] == true,
        distinctChapters: (j['distinct_chapters'] as num?)?.toInt() ?? 0,
        passingTests: (j['passing_tests'] as num?)?.toInt() ?? 0,
        minChapters: (j['min_chapters'] as num?)?.toInt() ?? 3,
        minTests: (j['min_tests'] as num?)?.toInt() ?? 10,
        predictedReadyDate: _tryDate(j['predicted_ready_date']),
        checkedAt: _tryDate(j['checked_at']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'ready': ready,
        'distinct_chapters': distinctChapters,
        'passing_tests': passingTests,
        'min_chapters': minChapters,
        'min_tests': minTests,
        'predicted_ready_date':
            predictedReadyDate?.toIso8601String().split('T').first,
        'checked_at': checkedAt.toIso8601String(),
      };
}

DateTime? _tryDate(dynamic v) => v is String ? DateTime.tryParse(v) : null;

/// A generated, dated study plan.
class Roadmap {
  final List<RoadmapItem> items;
  final DateTime generatedAt;
  final DateTime? examDate;

  const Roadmap({
    required this.items,
    required this.generatedAt,
    this.examDate,
  });

  /// Items whose window contains today.
  List<RoadmapItem> get thisWeek =>
      items.where((i) => i.isThisWeek && !i.isDone).toList();

  /// Past-due items that were never completed.
  List<RoadmapItem> get overdue => items
      .where((i) =>
          !i.isDone &&
          i.status != RoadmapItemStatus.skipped &&
          DateUtils.dateOnly(i.scheduledEnd)
              .isBefore(DateUtils.dateOnly(DateTime.now())))
      .toList();

  /// Future items, soonest first.
  List<RoadmapItem> get upcoming {
    final today = DateUtils.dateOnly(DateTime.now());
    return items
        .where((i) =>
            !i.isDone &&
            DateUtils.dateOnly(i.scheduledStart).isAfter(today))
        .toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  }

  double get completionFraction {
    if (items.isEmpty) return 0;
    final done = items.where((i) => i.isDone).length;
    return done / items.length;
  }

  int? get daysToExam {
    if (examDate == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(examDate!).difference(today).inDays;
  }
}
