# File B — Session C5 (chem: ch17, ch18, ch19, ch20)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 7 topics below (14 subtopics,
**210 questions**), per spec, then stop. `subject_id` = `chem` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 7 topics in
> this File B (Session C5). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 7 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ch17t1` | Carbohydrates, Proteins & Nucleic Acids | class12 | `ch17t1s1` · Carbohydrates & Their Classification | `ch17t1s2` · Proteins, Amino Acids & Nucleic Acids | `axai_ch17_001`–`030` |
| `ch17t2` | Polymers: Natural & Synthetic | class12 | `ch17t2s1` · Classification & Types of Polymers | `ch17t2s2` · Polymerisation & Important Polymers | `axai_ch17_031`–`060` |
| `ch18t1` | Drugs, Dyes & Detergents | class12 | `ch18t1s1` · Drugs & Their Therapeutic Action | `ch18t1s2` · Soaps, Detergents & Food Chemicals | `axai_ch18_001`–`030` |
| `ch19t1` | Types of Solutions & Solubility | class12 | `ch19t1s1` · Concentration Terms | `ch19t1s2` · Solubility & Henry's Law | `axai_ch19_001`–`030` |
| `ch19t2` | Colligative Properties & Osmosis | class12 | `ch19t2s1` · Colligative Properties & Molar Mass | `ch19t2s2` · Osmosis & Abnormal Molar Mass | `axai_ch19_031`–`060` |
| `ch20t1` | Crystal Structure & Unit Cells | class12 | `ch20t1s1` · Unit Cells & Packing | `ch20t1s2` · Density & Coordination Number | `axai_ch20_001`–`030` |
| `ch20t2` | Defects & Electrical Properties of Solids | class12 | `ch20t2s1` · Crystal Defects & Imperfections | `ch20t2s2` · Electrical & Magnetic Properties | `axai_ch20_031`–`060` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Note:** ch18 has a single topic, so only `axai_ch18_001`–`030` are used.
**Done when:** 7 files applied; verify query returns `5/5/5` for all 14 subtopics. Next: P1 (`SUBTOPIC_SESSION_06.md`).
