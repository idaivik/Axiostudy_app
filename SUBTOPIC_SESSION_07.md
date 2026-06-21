# File B — Session P2 (phys: ph04, ph05, ph06)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `phys` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session P2). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ph04t1` | Work Done & Work-Energy Theorem | class11 | `ph04t1s1` · Work by Constant & Variable Force | `ph04t1s2` · Work-Energy Theorem | `axai_ph04_001`–`030` |
| `ph04t2` | Conservative Forces & Potential Energy | class11 | `ph04t2s1` · Conservative Forces & PE | `ph04t2s2` · Conservation of Mechanical Energy | `axai_ph04_031`–`060` |
| `ph04t3` | Power & Collisions | class11 | `ph04t3s1` · Power | `ph04t3s2` · Elastic & Inelastic Collisions | `axai_ph04_061`–`090` |
| `ph05t1` | Torque, Angular Momentum & MOI | class11 | `ph05t1s1` · Torque & Moment of Inertia | `ph05t1s2` · Angular Momentum & Conservation | `axai_ph05_001`–`030` |
| `ph05t2` | Rolling Motion | class11 | `ph05t2s1` · Rolling Without Slipping | `ph05t2s2` · Rolling on Inclines & Energy | `axai_ph05_031`–`060` |
| `ph05t3` | Equilibrium of Rigid Bodies | class11 | `ph05t3s1` · Centre of Mass | `ph05t3s2` · Conditions for Equilibrium | `axai_ph05_061`–`090` |
| `ph06t1` | Universal Gravitation & Kepler's Laws | class11 | `ph06t1s1` · Newton's Law of Gravitation | `ph06t1s2` · Kepler's Laws of Planetary Motion | `axai_ph06_001`–`030` |
| `ph06t2` | Gravitational Field & Potential | class11 | `ph06t2s1` · Gravitational Field & g Variation | `ph06t2s2` · Gravitational Potential & Energy | `axai_ph06_031`–`060` |
| `ph06t3` | Satellites & Escape Velocity | class11 | `ph06t3s1` · Orbital & Escape Velocity | `ph06t3s2` · Satellites & Energy | `axai_ph06_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: P3 (`SUBTOPIC_SESSION_08.md`).
