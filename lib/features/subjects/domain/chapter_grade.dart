/// Which school class a chapter is taught in. Drives the Practice → chapter
/// list "Class 11 / Class 12" toggle so the two classes are no longer mixed.
enum ClassLevel {
  class11,
  class12;

  String get label => this == ClassLevel.class11 ? 'Class 11' : 'Class 12';
}

/// Chapter IDs (live DB: `ph01..bi20`) that belong to **Class 12**. Every other
/// chapter is treated as Class 11 — the safe default, so any chapter not listed
/// here (e.g. content added later) still shows up rather than vanishing.
///
/// Within a class, chapters keep their existing `id` order, which the app
/// already treats as NCERT/book order (see the roadmap syllabus seed in
/// `20260613000000_roadmap.sql`).
///
/// A handful of chapters consolidate topics from both classes; each is filed
/// under the class of its leading NCERT topic:
///   • ch07 "Redox Reactions & Electrochemistry"          → Class 11 (Redox)
///   • ch12 "Metallurgy, Hydrogen & Environmental Chem."   → Class 11 (Hydrogen/Env)
///   • ma06 "Trigonometry & Inverse Trigonometric Funcs."  → Class 11 (Trigonometry)
///   • ma11 "Limits, Continuity & Differentiability"       → Class 12 (bulk is Class 12)
///   • ma17 "Mathematical Reasoning & Linear Programming"  → Class 11 (Reasoning)
const Set<String> _class12ChapterIds = {
  // Physics — Electrostatics onward.
  'ph11', 'ph12', 'ph13', 'ph14', 'ph15',
  'ph16', 'ph17', 'ph18', 'ph19', 'ph20',
  // Chemistry.
  'ch08', 'ch10', 'ch11', 'ch14', 'ch15',
  'ch16', 'ch17', 'ch18', 'ch19', 'ch20',
  // Mathematics.
  'ma03', 'ma09', 'ma10', 'ma11', 'ma12', 'ma13', 'ma14', 'ma15',
  // Biology — Reproduction onward.
  'bi17', 'bi18', 'bi19', 'bi20',
};

/// The class a chapter is taught in, derived from its [chapterId].
ClassLevel chapterClassLevel(String chapterId) =>
    _class12ChapterIds.contains(chapterId)
        ? ClassLevel.class12
        : ClassLevel.class11;
