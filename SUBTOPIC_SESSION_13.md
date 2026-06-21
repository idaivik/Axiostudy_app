# File B — Session M1 (math: ma01, ma02, ma03)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `math` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session M1). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ma01t1` | Sets & Operations on Sets | class11 | `ma01t1s1` · Sets & Venn Diagrams | `ma01t1s2` · Operations & Laws of Sets | `axai_ma01_001`–`030` |
| `ma01t2` | Relations: Types & Properties | class11 | `ma01t2s1` · Cartesian Product & Relations | `ma01t2s2` · Equivalence Relations & Properties | `axai_ma01_031`–`060` |
| `ma01t3` | Functions: Domain, Range & Types | class11 | `ma01t3s1` · Domain, Range & Function Types | `ma01t3s2` · Composition & Inverse Functions | `axai_ma01_061`–`090` |
| `ma02t1` | Algebra of Complex Numbers | class11 | `ma02t1s1` · Complex Number Algebra | `ma02t1s2` · Conjugate & Powers of i | `axai_ma02_001`–`030` |
| `ma02t2` | Modulus, Argument & Polar Form | class11 | `ma02t2s1` · Modulus & Argument | `ma02t2s2` · Polar Form & De Moivre's Theorem | `axai_ma02_031`–`060` |
| `ma02t3` | Quadratic Equations & Discriminant | class11 | `ma02t3s1` · Roots & Discriminant | `ma02t3s2` · Nature of Roots & Relations | `axai_ma02_061`–`090` |
| `ma03t1` | Matrix Operations & Types | class12 | `ma03t1s1` · Types of Matrices | `ma03t1s2` · Matrix Algebra & Transpose | `axai_ma03_001`–`030` |
| `ma03t2` | Determinants & Properties | class12 | `ma03t2s1` · Evaluating Determinants | `ma03t2s2` · Properties & Area Applications | `axai_ma03_031`–`060` |
| `ma03t3` | Inverse Matrix & System of Equations | class12 | `ma03t3s1` · Adjoint & Inverse | `ma03t3s2` · Solving Linear Systems (Cramer's) | `axai_ma03_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: M2 (`SUBTOPIC_SESSION_14.md`).
