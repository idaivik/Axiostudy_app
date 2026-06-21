# File B — Session M4 (math: ma10, ma11, ma12, ma13)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `math` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session M4). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ma10t1` | Vector Operations & Dot Product | class12 | `ma10t1s1` · Vector Addition & Components | `ma10t1s2` · Dot Product & Projection | `axai_ma10_001`–`030` |
| `ma10t2` | Cross Product & Scalar Triple Product | class12 | `ma10t2s1` · Cross Product & Area | `ma10t2s2` · Scalar Triple Product & Volume | `axai_ma10_031`–`060` |
| `ma11t1` | Limits & L'Hôpital's Rule | class12 | `ma11t1s1` · Evaluation of Limits | `ma11t1s2` · L'Hôpital's Rule & Indeterminate Forms | `axai_ma11_001`–`030` |
| `ma11t2` | Continuity & Differentiability | class12 | `ma11t2s1` · Continuity at a Point | `ma11t2s2` · Differentiability & Relation | `axai_ma11_031`–`060` |
| `ma12t1` | Differentiation: Rules & Chain Rule | class12 | `ma12t1s1` · Standard Derivatives & Rules | `ma12t1s2` · Chain Rule & Implicit Differentiation | `axai_ma12_001`–`030` |
| `ma12t2` | Applications: Tangents, Maxima & Minima | class12 | `ma12t2s1` · Tangents, Normals & Rate of Change | `ma12t2s2` · Maxima, Minima & Monotonicity | `axai_ma12_031`–`060` |
| `ma12t3` | Mean Value Theorems & Rolle's Theorem | class12 | `ma12t3s1` · Rolle's Theorem | `ma12t3s2` · Lagrange's Mean Value Theorem | `axai_ma12_061`–`090` |
| `ma13t1` | Standard Integrals & Substitution | class12 | `ma13t1s1` · Standard Integrals | `ma13t1s2` · Integration by Substitution | `axai_ma13_001`–`030` |
| `ma13t2` | Integration by Parts & Partial Fractions | class12 | `ma13t2s1` · Integration by Parts | `ma13t2s2` · Partial Fractions & Special Integrals | `axai_ma13_031`–`060` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: M5 (`SUBTOPIC_SESSION_17.md`).
