# File B — Session P7 (phys: ph19, ph20)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 6 topics below (12 subtopics,
**180 questions**), per spec, then stop. `subject_id` = `phys` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 6 topics in
> this File B (Session P7). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 6 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ph19t1` | Bohr Model & Hydrogen Spectrum | class12 | `ph19t1s1` · Bohr Model & Energy Levels | `ph19t1s2` · Hydrogen Spectral Series | `axai_ph19_001`–`030` |
| `ph19t2` | Nuclear Reactions, Fission & Fusion | class12 | `ph19t2s1` · Nuclear Structure & Binding Energy | `ph19t2s2` · Fission, Fusion & Q-value | `axai_ph19_031`–`060` |
| `ph19t3` | Radioactive Decay & Half-Life | class12 | `ph19t3s1` · Radioactive Decay & Laws | `ph19t3s2` · Half-Life & Activity | `axai_ph19_061`–`090` |
| `ph20t1` | p-n Junction & Semiconductor Devices | class12 | `ph20t1s1` · Semiconductors & p-n Junction | `ph20t1s2` · Diodes, Rectifiers & Transistors | `axai_ph20_001`–`030` |
| `ph20t2` | Logic Gates & Digital Electronics | class12 | `ph20t2s1` · Basic Logic Gates | `ph20t2s2` · Universal Gates & Boolean Logic | `axai_ph20_031`–`060` |
| `ph20t3` | Modulation & Communication Systems | class12 | `ph20t3s1` · Communication System Blocks | `ph20t3s2` · Modulation Techniques (AM/FM) | `axai_ph20_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 6 files applied; verify query returns `5/5/5` for all 12 subtopics. Next: M1 (`SUBTOPIC_SESSION_13.md`).
