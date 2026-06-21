# File B — Session M2 (math: ma04, ma05, ma06)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 8 topics below (16 subtopics,
**240 questions**), per spec, then stop. `subject_id` = `math` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 8 topics in
> this File B (Session M2). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 8 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ma04t1` | Permutations & Fundamental Counting | class11 | `ma04t1s1` · Fundamental Principle of Counting | `ma04t1s2` · Permutations & Arrangements | `axai_ma04_001`–`030` |
| `ma04t2` | Combinations & Selection Problems | class11 | `ma04t2s1` · Combinations & Selections | `ma04t2s2` · Distribution & Grouping Problems | `axai_ma04_031`–`060` |
| `ma04t3` | Binomial Theorem & Pascal's Triangle | class11 | `ma04t3s1` · Binomial Expansion & General Term | `ma04t3s2` · Middle Term & Properties | `axai_ma04_061`–`090` |
| `ma05t1` | AP, GP & HP | class11 | `ma05t1s1` · Arithmetic Progression | `ma05t1s2` · Geometric & Harmonic Progression | `axai_ma05_001`–`030` |
| `ma05t2` | Sum of Special Series | class11 | `ma05t2s1` · Sum of Powers of Natural Numbers | `ma05t2s2` · Telescoping & Special Series | `axai_ma05_031`–`060` |
| `ma06t1` | Trigonometric Ratios & Identities | class11 | `ma06t1s1` · Trigonometric Ratios & Signs | `ma06t1s2` · Compound & Multiple Angle Identities | `axai_ma06_001`–`030` |
| `ma06t2` | Equations & Heights & Distances | class11 | `ma06t2s1` · General Solutions of Trig Equations | `ma06t2s2` · Heights & Distances | `axai_ma06_031`–`060` |
| `ma06t3` | Inverse Trigonometric Functions | class11 | `ma06t3s1` · Domains, Ranges & Principal Values | `ma06t3s2` · Properties & Identities of Inverse Trig | `axai_ma06_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 8 files applied; verify query returns `5/5/5` for all 16 subtopics. Next: M3 (`SUBTOPIC_SESSION_15.md`).
