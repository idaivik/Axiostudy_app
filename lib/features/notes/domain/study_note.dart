/// A single formula inside an AI study note. `tex` is LaTeX (no $ delimiters),
/// rendered with flutter_math_fork — same engine as the formula bank widget.
class NoteFormula {
  final String name;
  final String tex;
  const NoteFormula({required this.name, required this.tex});

  factory NoteFormula.fromJson(Map<String, dynamic> j) => NoteFormula(
        name: j['name'] as String? ?? '',
        tex: j['tex'] as String? ?? '',
      );
}

/// Structured AI study note for one topic (Bucket 3A · Feature 2), pitched at
/// the student's mastery [level] ('foundational' | 'intermediate' | 'advanced').
class StudyNote {
  final String concept;
  final List<String> keyPoints;
  final List<String> commonMistakes;
  final List<NoteFormula> formulas;
  final String level;

  const StudyNote({
    required this.concept,
    this.keyPoints = const [],
    this.commonMistakes = const [],
    this.formulas = const [],
    this.level = 'intermediate',
  });

  /// Build from the edge function's `note` payload + the resolved `level`.
  factory StudyNote.fromContent(Map<String, dynamic> content, String? level) {
    List<String> strs(dynamic v) => (v as List?)
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    return StudyNote(
      concept: content['concept'] as String? ?? '',
      keyPoints: strs(content['key_points']),
      commonMistakes: strs(content['common_mistakes']),
      formulas: ((content['formulas'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(NoteFormula.fromJson)
          .where((f) => f.tex.isNotEmpty)
          .toList(),
      level: level ?? 'intermediate',
    );
  }

  String get levelLabel {
    switch (level) {
      case 'foundational':
        return 'Foundational — built up from the basics';
      case 'advanced':
        return 'Advanced — focused on the tricky bits';
      default:
        return 'Intermediate — core ideas + exam technique';
    }
  }
}
