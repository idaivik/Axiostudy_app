/// One curated formula from `formula_bank` (Feature 4). Static reference content
/// — no AI. `formulaTex` is LaTeX (rendered with flutter_math_fork); `imageUrl`
/// is an optional pre-rendered fallback.
class Formula {
  final String id;
  final String exam;
  final String subjectId;
  final String chapterId;
  final String? topicId;
  final String name;
  final String formulaTex;
  final int importance;
  final String? note;
  final String? imageUrl;

  const Formula({
    required this.id,
    required this.exam,
    required this.subjectId,
    required this.chapterId,
    this.topicId,
    required this.name,
    required this.formulaTex,
    this.importance = 1,
    this.note,
    this.imageUrl,
  });

  /// "Marked important" → drives ordering + the badge.
  bool get isImportant => importance >= 3;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  factory Formula.fromJson(Map<String, dynamic> json) => Formula(
        id: json['id'] as String,
        exam: json['exam'] as String? ?? 'both',
        subjectId: json['subject_id'] as String? ?? '',
        chapterId: json['chapter_id'] as String? ?? '',
        topicId: json['topic_id'] as String?,
        name: json['name'] as String? ?? '',
        formulaTex: json['formula_tex'] as String? ?? '',
        importance: json['importance'] as int? ?? 1,
        note: json['note'] as String?,
        imageUrl: json['image_url'] as String?,
      );
}
