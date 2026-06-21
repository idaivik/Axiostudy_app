# File B — Session P6 (phys: ph16, ph17, ph18)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 7 topics below (14 subtopics,
**210 questions**), per spec, then stop. `subject_id` = `phys` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 7 topics in
> this File B (Session P6). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 7 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ph16t1` | Reflection & Refraction at Surfaces | class12 | `ph16t1s1` · Reflection & Spherical Mirrors | `ph16t1s2` · Refraction & Total Internal Reflection | `axai_ph16_001`–`030` |
| `ph16t2` | Lenses & Mirrors | class12 | `ph16t2s1` · Lens Formula & Magnification | `ph16t2s2` · Lens & Mirror Combinations | `axai_ph16_031`–`060` |
| `ph16t3` | Optical Instruments: Microscope & Telescope | class12 | `ph16t3s1` · Microscopes | `ph16t3s2` · Telescopes & Magnifying Power | `axai_ph16_061`–`090` |
| `ph17t1` | Interference & Young's Double Slit | class12 | `ph17t1s1` · Huygens' Principle & Coherence | `ph17t1s2` · Young's Double-Slit Experiment | `axai_ph17_001`–`030` |
| `ph17t2` | Diffraction & Polarisation | class12 | `ph17t2s1` · Single-Slit Diffraction | `ph17t2s2` · Polarisation & Malus' Law | `axai_ph17_031`–`060` |
| `ph18t1` | Photoelectric Effect & de Broglie Wave | class12 | `ph18t1s1` · Photoelectric Effect & Einstein's Equation | `ph18t1s2` · de Broglie Wavelength & Matter Waves | `axai_ph18_001`–`030` |
| `ph18t2` | X-rays & Compton Effect | class12 | `ph18t2s1` · Production & Spectra of X-rays | `ph18t2s2` · Compton Effect & Photon Momentum | `axai_ph18_031`–`060` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 7 files applied; verify query returns `5/5/5` for all 14 subtopics. Next: P7 (`SUBTOPIC_SESSION_12.md`).
