# File B — Session M5 (math: ma14, ma15, ma16, ma17)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `math` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session M5). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ma14t1` | Definite Integration & Properties | class12 | `ma14t1s1` · Definite Integrals & Evaluation | `ma14t1s2` · Properties of Definite Integrals | `axai_ma14_001`–`030` |
| `ma14t2` | Area Under Curves | class12 | `ma14t2s1` · Area Bounded by a Curve & Axis | `ma14t2s2` · Area Between Two Curves | `axai_ma14_031`–`060` |
| `ma15t1` | Formation & Solution of ODEs | class12 | `ma15t1s1` · Order, Degree & Formation | `ma15t1s2` · Variable Separable Equations | `axai_ma15_001`–`030` |
| `ma15t2` | Linear & Homogeneous Differential Equations | class12 | `ma15t2s1` · Homogeneous Equations | `ma15t2s2` · Linear First-Order Equations | `axai_ma15_031`–`060` |
| `ma16t1` | Classical & Conditional Probability | class11 | `ma16t1s1` · Classical Probability & Events | `ma16t1s2` · Conditional Probability & Independence | `axai_ma16_001`–`030` |
| `ma16t2` | Bayes' Theorem & Random Variables | class11 | `ma16t2s1` · Total Probability & Bayes' Theorem | `ma16t2s2` · Random Variables & Distributions | `axai_ma16_031`–`060` |
| `ma16t3` | Mean, Variance & Distributions | class11 | `ma16t3s1` · Mean & Variance | `ma16t3s2` · Binomial Distribution | `axai_ma16_061`–`090` |
| `ma17t1` | Statements, Connectives & Truth Tables | class11 | `ma17t1s1` · Statements & Logical Connectives | `ma17t1s2` · Truth Tables & Validity | `axai_ma17_001`–`030` |
| `ma17t2` | Linear Programming: Graphical Method | class11 | `ma17t2s1` · Formulation & Constraints | `ma17t2s2` · Graphical Solution & Optimisation | `axai_ma17_031`–`060` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: B1 (`SUBTOPIC_SESSION_18.md`).
