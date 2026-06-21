# File B — Session P5 (phys: ph13, ph14, ph15)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 8 topics below (16 subtopics,
**240 questions**), per spec, then stop. `subject_id` = `phys` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 8 topics in
> this File B (Session P5). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 8 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ph13t1` | Biot-Savart Law & Ampere's Law | class12 | `ph13t1s1` · Biot-Savart Law & Field of Loops | `ph13t1s2` · Ampere's Law & Solenoids | `axai_ph13_001`–`030` |
| `ph13t2` | Force on Current & Moving Charges | class12 | `ph13t2s1` · Force on Moving Charge (Lorentz) | `ph13t2s2` · Force & Torque on Current Loops | `axai_ph13_031`–`060` |
| `ph13t3` | Magnetism & Magnetic Materials | class12 | `ph13t3s1` · Bar Magnet & Earth's Magnetism | `ph13t3s2` · Dia, Para & Ferromagnetism | `axai_ph13_061`–`090` |
| `ph14t1` | Faraday's Laws & Lenz's Law | class12 | `ph14t1s1` · Faraday's Law & Induced EMF | `ph14t1s2` · Lenz's Law & Motional EMF | `axai_ph14_001`–`030` |
| `ph14t2` | Self & Mutual Inductance | class12 | `ph14t2s1` · Self-Inductance & Energy | `ph14t2s2` · Mutual Inductance & Transformers | `axai_ph14_031`–`060` |
| `ph14t3` | AC Circuits: LCR & Resonance | class12 | `ph14t3s1` · AC, RMS & Reactance | `ph14t3s2` · LCR Circuits & Resonance | `axai_ph14_061`–`090` |
| `ph15t1` | Maxwell's Equations & EM Spectrum | class12 | `ph15t1s1` · Displacement Current & Maxwell's Equations | `ph15t1s2` · Electromagnetic Spectrum | `axai_ph15_001`–`030` |
| `ph15t2` | Properties & Applications of EM Waves | class12 | `ph15t2s1` · Nature & Properties of EM Waves | `ph15t2s2` · Applications Across the Spectrum | `axai_ph15_031`–`060` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 8 files applied; verify query returns `5/5/5` for all 16 subtopics. Next: P6 (`SUBTOPIC_SESSION_11.md`).
