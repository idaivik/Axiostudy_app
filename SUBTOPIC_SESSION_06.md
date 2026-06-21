# File B — Session P1 (phys: ph01, ph02, ph03)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `phys` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session P1). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ph01t1` | SI Units & Dimensional Analysis | class11 | `ph01t1s1` · SI Units & Base Quantities | `ph01t1s2` · Dimensional Analysis & Homogeneity | `axai_ph01_001`–`030` |
| `ph01t2` | Errors & Significant Figures | class11 | `ph01t2s1` · Types & Propagation of Errors | `ph01t2s2` · Significant Figures & Rounding | `axai_ph01_031`–`060` |
| `ph01t3` | Vernier Caliper & Screw Gauge | class11 | `ph01t3s1` · Vernier Caliper & Least Count | `ph01t3s2` · Screw Gauge & Zero Error | `axai_ph01_061`–`090` |
| `ph02t1` | Motion in a Straight Line | class11 | `ph02t1s1` · Displacement, Velocity & Acceleration | `ph02t1s2` · Equations of Motion & Graphs | `axai_ph02_001`–`030` |
| `ph02t2` | Projectile & Circular Motion | class11 | `ph02t2s1` · Projectile Motion | `ph02t2s2` · Uniform Circular Motion | `axai_ph02_031`–`060` |
| `ph02t3` | Relative Motion | class11 | `ph02t3s1` · Relative Velocity in 1D | `ph02t3s2` · Relative Velocity in 2D (River-Boat, Rain) | `axai_ph02_061`–`090` |
| `ph03t1` | Newton's Laws & Free Body Diagrams | class11 | `ph03t1s1` · Newton's Three Laws | `ph03t1s2` · Free Body Diagrams & Applications | `axai_ph03_001`–`030` |
| `ph03t2` | Friction: Static & Kinetic | class11 | `ph03t2s1` · Static & Kinetic Friction | `ph03t2s2` · Friction on Inclines & Applications | `axai_ph03_031`–`060` |
| `ph03t3` | Pulley & Constraint Motion | class11 | `ph03t3s1` · Pulley Systems & Tension | `ph03t3s2` · Constraint Relations | `axai_ph03_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: P2 (`SUBTOPIC_SESSION_07.md`).
