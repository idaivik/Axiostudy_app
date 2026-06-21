# File B — Session B2 (bio: bi05, bi06, bi07, bi08)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `bio` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session B2). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `bi05t1` | Tissues & Organs in Animals | class11 | `bi05t1s1` · Epithelial & Connective Tissue | `bi05t1s2` · Muscular & Neural Tissue | `axai_bi05_001`–`030` |
| `bi05t2` | Earthworm, Cockroach & Frog | class11 | `bi05t2s1` · Earthworm & Cockroach | `bi05t2s2` · Frog: Morphology & Systems | `axai_bi05_031`–`060` |
| `bi06t1` | Cell Organelles & Membrane Structure | class11 | `bi06t1s1` · Cell Membrane & Cell Wall | `bi06t1s2` · Cell Organelles & Functions | `axai_bi06_001`–`030` |
| `bi06t2` | Mitosis & Meiosis | class11 | `bi06t2s1` · Cell Cycle & Mitosis | `bi06t2s2` · Meiosis & Significance | `axai_bi06_031`–`060` |
| `bi07t1` | Carbohydrates, Lipids & Proteins | class11 | `bi07t1s1` · Carbohydrates & Lipids | `bi07t1s2` · Proteins & Amino Acids | `axai_bi07_001`–`030` |
| `bi07t2` | Nucleic Acids & Enzyme Kinetics | class11 | `bi07t2s1` · Nucleic Acids: DNA & RNA | `bi07t2s2` · Enzymes & Their Action | `axai_bi07_031`–`060` |
| `bi08t1` | Light & Dark Reactions of Photosynthesis | class11 | `bi08t1s1` · Light Reactions & Photophosphorylation | `bi08t1s2` · Calvin Cycle & C4 Pathway | `axai_bi08_001`–`030` |
| `bi08t2` | Aerobic & Anaerobic Respiration | class11 | `bi08t2s1` · Glycolysis & Fermentation | `bi08t2s2` · Krebs Cycle & Electron Transport | `axai_bi08_031`–`060` |
| `bi08t3` | Respiratory Quotient & ATP Yield | class11 | `bi08t3s1` · Respiratory Quotient | `bi08t3s2` · ATP Yield & Amphibolic Pathway | `axai_bi08_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: B3 (`SUBTOPIC_SESSION_20.md`).
