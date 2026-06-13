import '../domain/roadmap_models.dart';

/// Client-side reference data for coaching institutes and their chapter
/// teaching sequences.
///
/// Chapter catalog and IDs mirror the live `public.chapters` table
/// (phys/chem/math/bio · ph01..ph20 etc.), so roadmap items deep-link to real
/// chapters and the per-chapter strength (from `subjectsProvider`) lines up.
///
/// A sequence is built by interleaving the relevant subject streams (JEE =
/// phys/chem/math, NEET = phys/chem/bio). Coachings differ in the ORDER they
/// weave those streams — that ordering is the whole point of the feature.
///
/// Kept in sync with supabase/migrations/20260613000000_roadmap.sql, which seeds
/// the same sequences server-side by deriving them from `public.chapters`.
class RoadmapSeedData {
  RoadmapSeedData._();

  static const List<CoachingInstitute> institutes = [
    CoachingInstitute(id: 'standard', name: 'Standard (NCERT order)', examType: 'both'),
    CoachingInstitute(id: 'allen', name: 'Allen', examType: 'both'),
    CoachingInstitute(id: 'aakash', name: 'Aakash', examType: 'both'),
    CoachingInstitute(id: 'fiitjee', name: 'FIITJEE', examType: 'jee'),
    CoachingInstitute(id: 'pw', name: 'Physics Wallah', examType: 'both'),
    CoachingInstitute(id: 'custom', name: 'Self-study / Custom', examType: 'both', isCustom: true),
  ];

  static CoachingInstitute instituteById(String id) => institutes.firstWhere(
        (c) => c.id == id,
        orElse: () => institutes.first,
      );

  // ── Real chapter catalog (matches public.chapters). Names defined once. ──
  static const List<_Ch> _phys = [
    _Ch('phys', 'ph01', 'Units, Dimensions & Measurement'),
    _Ch('phys', 'ph02', 'Kinematics'),
    _Ch('phys', 'ph03', 'Laws of Motion'),
    _Ch('phys', 'ph04', 'Work, Energy & Power'),
    _Ch('phys', 'ph05', 'Rotational Motion & Moment of Inertia'),
    _Ch('phys', 'ph06', 'Gravitation'),
    _Ch('phys', 'ph07', 'Properties of Matter & Fluid Mechanics'),
    _Ch('phys', 'ph08', 'Thermodynamics & Kinetic Theory'),
    _Ch('phys', 'ph09', 'Oscillations (SHM)'),
    _Ch('phys', 'ph10', 'Waves & Sound'),
    _Ch('phys', 'ph11', 'Electrostatics'),
    _Ch('phys', 'ph12', 'Current Electricity'),
    _Ch('phys', 'ph13', 'Magnetic Effects of Current & Magnetism'),
    _Ch('phys', 'ph14', 'Electromagnetic Induction & AC Circuits'),
    _Ch('phys', 'ph15', 'Electromagnetic Waves'),
    _Ch('phys', 'ph16', 'Ray Optics & Optical Instruments'),
    _Ch('phys', 'ph17', 'Wave Optics'),
    _Ch('phys', 'ph18', 'Dual Nature of Matter & Radiation'),
    _Ch('phys', 'ph19', 'Atoms, Nuclei & Radioactivity'),
    _Ch('phys', 'ph20', 'Semiconductor Electronics & Communication'),
  ];

  static const List<_Ch> _chem = [
    _Ch('chem', 'ch01', 'Basic Concepts, Mole Concept & Stoichiometry'),
    _Ch('chem', 'ch02', 'Atomic Structure'),
    _Ch('chem', 'ch03', 'Chemical Bonding & Molecular Structure'),
    _Ch('chem', 'ch04', 'States of Matter: Gases & Liquids'),
    _Ch('chem', 'ch05', 'Chemical Thermodynamics'),
    _Ch('chem', 'ch06', 'Chemical & Ionic Equilibrium'),
    _Ch('chem', 'ch07', 'Redox Reactions & Electrochemistry'),
    _Ch('chem', 'ch08', 'Chemical Kinetics & Surface Chemistry'),
    _Ch('chem', 'ch09', 's-Block & p-Block Elements (Gr 1–2, 13–14)'),
    _Ch('chem', 'ch10', 'p-Block Elements (Gr 15–18)'),
    _Ch('chem', 'ch11', 'd & f Block Elements & Coordination Compounds'),
    _Ch('chem', 'ch12', 'Metallurgy, Hydrogen & Environmental Chemistry'),
    _Ch('chem', 'ch13', 'General Organic Chemistry & Hydrocarbons'),
    _Ch('chem', 'ch14', 'Haloalkanes, Haloarenes & Ethers'),
    _Ch('chem', 'ch15', 'Alcohols, Phenols & Carbonyl Compounds'),
    _Ch('chem', 'ch16', 'Carboxylic Acids & Nitrogen Compounds'),
    _Ch('chem', 'ch17', 'Biomolecules & Polymers'),
    _Ch('chem', 'ch18', 'Chemistry in Everyday Life'),
    _Ch('chem', 'ch19', 'Solutions & Colligative Properties'),
    _Ch('chem', 'ch20', 'Solid State & Nuclear Chemistry'),
  ];

  static const List<_Ch> _math = [
    _Ch('math', 'ma01', 'Sets, Relations & Functions'),
    _Ch('math', 'ma02', 'Complex Numbers & Quadratic Equations'),
    _Ch('math', 'ma03', 'Matrices & Determinants'),
    _Ch('math', 'ma04', 'Permutations, Combinations & Binomial Theorem'),
    _Ch('math', 'ma05', 'Sequences & Series'),
    _Ch('math', 'ma06', 'Trigonometry & Inverse Trigonometric Functions'),
    _Ch('math', 'ma07', 'Straight Lines & Pair of Lines'),
    _Ch('math', 'ma08', 'Circles & Conic Sections'),
    _Ch('math', 'ma09', 'Three Dimensional Geometry'),
    _Ch('math', 'ma10', 'Vector Algebra'),
    _Ch('math', 'ma11', 'Limits, Continuity & Differentiability'),
    _Ch('math', 'ma12', 'Differentiation & Applications of Derivatives'),
    _Ch('math', 'ma13', 'Indefinite Integration'),
    _Ch('math', 'ma14', 'Definite Integration & Area Under Curves'),
    _Ch('math', 'ma15', 'Differential Equations'),
    _Ch('math', 'ma16', 'Probability & Statistics'),
    _Ch('math', 'ma17', 'Mathematical Reasoning & Linear Programming'),
    _Ch('math', 'ma18', 'Coordinate Geometry — Miscellaneous'),
    _Ch('math', 'ma19', 'Number Theory & Miscellaneous Algebra'),
    _Ch('math', 'ma20', 'Statics & Dynamics (JEE Mains level)'),
  ];

  static const List<_Ch> _bio = [
    _Ch('bio', 'bi01', 'The Living World & Biological Classification'),
    _Ch('bio', 'bi02', 'Plant Kingdom'),
    _Ch('bio', 'bi03', 'Animal Kingdom'),
    _Ch('bio', 'bi04', 'Morphology & Anatomy of Flowering Plants'),
    _Ch('bio', 'bi05', 'Structural Organisation in Animals'),
    _Ch('bio', 'bi06', 'Cell: Structure, Function & Cell Division'),
    _Ch('bio', 'bi07', 'Biomolecules & Enzymes'),
    _Ch('bio', 'bi08', 'Photosynthesis & Respiration in Plants'),
    _Ch('bio', 'bi09', 'Plant Growth, Development & Mineral Nutrition'),
    _Ch('bio', 'bi10', 'Digestion & Absorption'),
    _Ch('bio', 'bi11', 'Breathing & Exchange of Gases'),
    _Ch('bio', 'bi12', 'Body Fluids & Circulation'),
    _Ch('bio', 'bi13', 'Excretory Products & Osmoregulation'),
    _Ch('bio', 'bi14', 'Locomotion & Movement'),
    _Ch('bio', 'bi15', 'Neural Control, Coordination & Sense Organs'),
    _Ch('bio', 'bi16', 'Chemical Coordination & Integration'),
    _Ch('bio', 'bi17', 'Reproduction in Organisms & Plants'),
    _Ch('bio', 'bi18', 'Human Reproduction & Reproductive Health'),
    _Ch('bio', 'bi19', 'Genetics, Molecular Biology & Evolution'),
    _Ch('bio', 'bi20', 'Human Health, Disease, Biotechnology & Ecology'),
  ];

  /// How each coaching weaves the subject streams. Roles: 'phys', 'chem',
  /// 'third' (= math for JEE, bio for NEET). The order is the per-cycle pickup
  /// order, which is what differentiates one coaching's plan from another.
  static const Map<String, List<String>> _subjectOrder = {
    'standard': ['phys', 'chem', 'third'],
    'allen': ['phys', 'third', 'chem'], // Allen front-loads physics + maths
    'aakash': ['chem', 'third', 'phys'], // Aakash (NEET-leaning) leads with chem
    'fiitjee': ['third', 'phys', 'chem'], // FIITJEE is maths-heavy up front
    'pw': ['phys', 'chem', 'third'],
    'custom': ['phys', 'chem', 'third'],
  };

  /// Build the [SyllabusSequence] for a coaching + exam target by round-robin
  /// interleaving the relevant subject streams in the coaching's order.
  static SyllabusSequence sequenceFor(
    String coachingId, {
    ExamType examType = ExamType.jee,
    String phase = 'full',
  }) {
    final third = examType == ExamType.neet ? _bio : _math;
    final streams = <String, List<_Ch>>{'phys': _phys, 'chem': _chem, 'third': third};
    final order = _subjectOrder[coachingId] ?? _subjectOrder['standard']!;
    final maxLen = streams.values.map((s) => s.length).reduce((a, b) => a > b ? a : b);

    final entries = <SyllabusEntry>[];
    var pos = 0;
    for (var i = 0; i < maxLen; i++) {
      for (final key in order) {
        final stream = streams[key]!;
        if (i >= stream.length) continue;
        final c = stream[i];
        entries.add(SyllabusEntry(
          position: pos,
          subjectId: c.subjectId,
          chapterId: c.chapterId,
          chapterName: c.chapterName,
          expectedWeek: pos, // ≈1 chapter/week; the planner re-dates from the exam
        ));
        pos++;
      }
    }
    return SyllabusSequence(coachingId: coachingId, phase: phase, entries: entries);
  }
}

class _Ch {
  final String subjectId;
  final String chapterId;
  final String chapterName;
  const _Ch(this.subjectId, this.chapterId, this.chapterName);
}
