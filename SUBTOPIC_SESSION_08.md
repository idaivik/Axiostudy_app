# File B — Session P3 (phys: ph07, ph08, ph09)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `phys` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session P3). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ph07t1` | Elasticity & Surface Tension | class11 | `ph07t1s1` · Stress, Strain & Moduli | `ph07t1s2` · Surface Tension & Capillarity | `axai_ph07_001`–`030` |
| `ph07t2` | Fluid Statics: Pressure & Buoyancy | class11 | `ph07t2s1` · Pressure in Fluids | `ph07t2s2` · Buoyancy & Archimedes' Principle | `axai_ph07_031`–`060` |
| `ph07t3` | Fluid Dynamics: Bernoulli & Viscosity | class11 | `ph07t3s1` · Continuity & Bernoulli's Theorem | `ph07t3s2` · Viscosity & Stokes' Law | `axai_ph07_061`–`090` |
| `ph08t1` | Zeroth & First Law of Thermodynamics | class11 | `ph08t1s1` · Heat, Temperature & Zeroth Law | `ph08t1s2` · First Law & Thermodynamic Processes | `axai_ph08_001`–`030` |
| `ph08t2` | Second Law, Entropy & Heat Engines | class11 | `ph08t2s1` · Second Law & Entropy | `ph08t2s2` · Heat Engines, Refrigerators & Carnot | `axai_ph08_031`–`060` |
| `ph08t3` | Kinetic Theory & Maxwell Distribution | class11 | `ph08t3s1` · Kinetic Theory & Gas Pressure | `ph08t3s2` · Molecular Speeds & Degrees of Freedom | `axai_ph08_061`–`090` |
| `ph09t1` | SHM: Equations & Energy | class11 | `ph09t1s1` · SHM Equations & Phase | `ph09t1s2` · Energy in SHM | `axai_ph09_001`–`030` |
| `ph09t2` | Spring-Mass & Pendulum Systems | class11 | `ph09t2s1` · Spring-Mass Oscillators | `ph09t2s2` · Simple & Physical Pendulums | `axai_ph09_031`–`060` |
| `ph09t3` | Damped & Forced Oscillations | class11 | `ph09t3s1` · Damped Oscillations | `ph09t3s2` · Forced Oscillations & Resonance | `axai_ph09_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: P4 (`SUBTOPIC_SESSION_09.md`).
