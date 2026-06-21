# File B — Session M3 (math: ma07, ma08, ma09)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 8 topics below (16 subtopics,
**240 questions**), per spec, then stop. `subject_id` = `math` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 8 topics in
> this File B (Session M3). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 8 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ma07t1` | Distance, Section & Slope Formulas | class11 | `ma07t1s1` · Distance & Section Formula | `ma07t1s2` · Slope & Area of Triangle | `axai_ma07_001`–`030` |
| `ma07t2` | Various Forms of Line & Angles | class11 | `ma07t2s1` · Forms of a Straight Line | `ma07t2s2` · Angle Between Lines & Distance | `axai_ma07_031`–`060` |
| `ma07t3` | Pair of Straight Lines | class11 | `ma07t3s1` · Pair of Lines Through Origin | `ma07t3s2` · General Second-Degree Pair | `axai_ma07_061`–`090` |
| `ma08t1` | Circles: Equations & Properties | class11 | `ma08t1s1` · Equation of a Circle | `ma08t1s2` · Tangents & Chords | `axai_ma08_001`–`030` |
| `ma08t2` | Parabola & Ellipse | class11 | `ma08t2s1` · Parabola | `ma08t2s2` · Ellipse | `axai_ma08_031`–`060` |
| `ma08t3` | Hyperbola | class11 | `ma08t3s1` · Standard Hyperbola & Properties | `ma08t3s2` · Asymptotes & Rectangular Hyperbola | `axai_ma08_061`–`090` |
| `ma09t1` | Direction Cosines & Lines in 3D | class12 | `ma09t1s1` · Direction Cosines & Ratios | `ma09t1s2` · Equation of a Line in 3D | `axai_ma09_001`–`030` |
| `ma09t2` | Planes & Shortest Distance | class12 | `ma09t2s1` · Equation of a Plane | `ma09t2s2` · Shortest Distance & Coplanarity | `axai_ma09_031`–`060` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 8 files applied; verify query returns `5/5/5` for all 16 subtopics. Next: M4 (`SUBTOPIC_SESSION_16.md`).
