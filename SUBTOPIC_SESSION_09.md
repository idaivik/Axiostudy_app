# File B — Session P4 (phys: ph10, ph11, ph12)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `phys` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session P4). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ph10t1` | Wave Motion & Superposition | class11 | `ph10t1s1` · Travelling Waves & Wave Equation | `ph10t1s2` · Superposition & Interference | `axai_ph10_001`–`030` |
| `ph10t2` | Stationary Waves & Resonance | class11 | `ph10t2s1` · Stationary Waves in Strings | `ph10t2s2` · Waves in Air Columns & Beats | `axai_ph10_031`–`060` |
| `ph10t3` | Doppler Effect | class11 | `ph10t3s1` · Doppler Effect: Moving Source/Observer | `ph10t3s2` · Applications of Doppler Effect | `axai_ph10_061`–`090` |
| `ph11t1` | Coulomb's Law & Electric Field | class12 | `ph11t1s1` · Coulomb's Law & Force | `ph11t1s2` · Electric Field & Field Lines | `axai_ph11_001`–`030` |
| `ph11t2` | Electric Potential & Capacitance | class12 | `ph11t2s1` · Electric Potential & Energy | `ph11t2s2` · Capacitors & Combinations | `axai_ph11_031`–`060` |
| `ph11t3` | Gauss's Law & Conductors | class12 | `ph11t3s1` · Electric Flux & Gauss's Law | `ph11t3s2` · Conductors & Dielectrics | `axai_ph11_061`–`090` |
| `ph12t1` | Ohm's Law, Resistance & Kirchhoff's Laws | class12 | `ph12t1s1` · Ohm's Law & Resistance | `ph12t1s2` · Kirchhoff's Laws & Networks | `axai_ph12_001`–`030` |
| `ph12t2` | Wheatstone Bridge & Potentiometer | class12 | `ph12t2s1` · Wheatstone Bridge & Meter Bridge | `ph12t2s2` · Potentiometer & Applications | `axai_ph12_031`–`060` |
| `ph12t3` | Heating Effect & Cells in Circuits | class12 | `ph12t3s1` · Heating Effect & Electric Power | `ph12t3s2` · EMF, Internal Resistance & Cells | `axai_ph12_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: P5 (`SUBTOPIC_SESSION_10.md`).
