import 'spaced_repetition.dart';

/// One topic on the spaced-repetition revision plan (Bucket 3A · Feature 1).
///
/// Merges the persisted SM-2 curve (`topic_review_state`) with the topic's
/// performance signal (`topic_performance`). A topic the student is weak on but
/// has never reviewed has no curve row yet → it surfaces as a "new" due item
/// seeded at [SrsState.fresh].
class RevisionItem {
  final String topicId;
  final String chapterId;
  final String subjectId;
  final String displayName;

  /// Persisted curve (or [SrsState.fresh] for a never-reviewed topic).
  final SrsState srs;

  /// When this topic next falls due. Null = never reviewed → due now.
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;

  /// Topic accuracy 0–1 and strength bucket from `topic_performance` (drives
  /// the "weak first" ordering + the templated copy — no AI, no meter).
  final double accuracy;
  final String strength; // 'weak' | 'moderate' | 'strong'

  const RevisionItem({
    required this.topicId,
    required this.chapterId,
    required this.subjectId,
    required this.displayName,
    required this.srs,
    this.dueAt,
    this.lastReviewedAt,
    this.accuracy = 0,
    this.strength = 'moderate',
  });

  /// Never reviewed through the spaced-rep loop yet.
  bool get isNew => lastReviewedAt == null;

  bool get isWeak => strength == 'weak';

  /// Due when it has no scheduled date (new) or that date is today/past.
  bool isDueAsOf(DateTime now) {
    if (dueAt == null) return true;
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueAt!.year, dueAt!.month, dueAt!.day);
    return !due.isAfter(today);
  }

  Map<String, dynamic> toJson() => {
        'topic_id': topicId,
        'chapter_id': chapterId,
        'subject_id': subjectId,
        'display_name': displayName,
        'interval_days': srs.intervalDays,
        'ease': srs.ease,
        'reps': srs.reps,
        'due_at': dueAt?.toIso8601String(),
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
        'accuracy': accuracy,
        'strength': strength,
      };

  factory RevisionItem.fromJson(Map<String, dynamic> j) => RevisionItem(
        topicId: j['topic_id'] as String,
        chapterId: j['chapter_id'] as String? ?? '',
        subjectId: j['subject_id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? (j['topic_id'] as String),
        srs: SrsState(
          intervalDays: (j['interval_days'] as num?)?.toInt() ?? 1,
          ease: (j['ease'] as num?)?.toDouble() ?? 2.5,
          reps: (j['reps'] as num?)?.toInt() ?? 0,
        ),
        dueAt: _parseDate(j['due_at']),
        lastReviewedAt: _parseDate(j['last_reviewed_at']),
        accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0,
        strength: j['strength'] as String? ?? 'moderate',
      );

  static DateTime? _parseDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);
}

/// The assembled revision plan: every tracked/weak topic split into "due now"
/// and "upcoming" by the SM-2 curve.
class RevisionPlan {
  final List<RevisionItem> items;
  final DateTime generatedAt;

  const RevisionPlan({required this.items, required this.generatedAt});

  static final RevisionPlan empty =
      RevisionPlan(items: const [], generatedAt: DateTime.fromMillisecondsSinceEpoch(0));

  /// Due today — weakest (and brand-new) topics first, so the most urgent
  /// revision sits at the top.
  List<RevisionItem> get dueToday {
    final now = DateTime.now();
    final due = items.where((i) => i.isDueAsOf(now)).toList();
    due.sort((a, b) {
      // New items first, then by ascending accuracy (weakest first).
      if (a.isNew != b.isNew) return a.isNew ? -1 : 1;
      return a.accuracy.compareTo(b.accuracy);
    });
    return due;
  }

  /// Upcoming reviews, soonest due first.
  List<RevisionItem> get upcoming {
    final now = DateTime.now();
    final up = items.where((i) => !i.isDueAsOf(now)).toList();
    up.sort((a, b) => (a.dueAt ?? now).compareTo(b.dueAt ?? now));
    return up;
  }

  Map<String, dynamic> toJson() => {
        'generated_at': generatedAt.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory RevisionPlan.fromJson(Map<String, dynamic> j) => RevisionPlan(
        generatedAt:
            DateTime.tryParse(j['generated_at'] as String? ?? '') ?? DateTime.now(),
        items: ((j['items'] as List?) ?? const [])
            .map((e) => RevisionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
