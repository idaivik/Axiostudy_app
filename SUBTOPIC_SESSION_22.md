# File B — Session B5 (bio: bi18, bi19, bi20) — FINAL SESSION

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `bio` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session B5). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `bi18t1` | Male & Female Reproductive Systems | class12 | `bi18t1s1` · Male Reproductive System | `bi18t1s2` · Female Reproductive System & Cycle | `axai_bi18_001`–`030` |
| `bi18t2` | Gametogenesis, Fertilisation & Embryology | class12 | `bi18t2s1` · Spermatogenesis & Oogenesis | `bi18t2s2` · Fertilisation, Implantation & Development | `axai_bi18_031`–`060` |
| `bi18t3` | Contraception, Infertility & STDs | class12 | `bi18t3s1` · Contraception & Birth Control | `bi18t3s2` · Infertility, ART & STDs | `axai_bi18_061`–`090` |
| `bi19t1` | Mendelian Genetics & Chromosomal Theory | class12 | `bi19t1s1` · Mendel's Laws & Inheritance | `bi19t1s2` · Linkage, Sex Determination & Mutations | `axai_bi19_001`–`030` |
| `bi19t2` | DNA Structure, Replication & Central Dogma | class12 | `bi19t2s1` · DNA Structure & Replication | `bi19t2s2` · Transcription, Translation & Gene Regulation | `axai_bi19_031`–`060` |
| `bi19t3` | Darwinism, Neo-Darwinism & Evidence | class12 | `bi19t3s1` · Theories of Evolution | `bi19t3s2` · Evidence & Mechanisms of Evolution | `axai_bi19_061`–`090` |
| `bi20t1` | Immunity, Vaccines & Diseases | class12 | `bi20t1s1` · Immunity & Human Diseases | `bi20t1s2` · Vaccines & Immune Disorders | `axai_bi20_001`–`030` |
| `bi20t2` | Biotechnology: PCR, rDNA & Applications | class12 | `bi20t2s1` · rDNA Technology & Tools | `bi20t2s2` · PCR & Applications of Biotechnology | `axai_bi20_031`–`060` |
| `bi20t3` | Ecosystems, Biodiversity & Conservation | class12 | `bi20t3s1` · Ecosystem Structure & Energy Flow | `bi20t3s2` · Biodiversity & Conservation | `axai_bi20_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics.
**This is the last session** — on completion, all 188 remaining topics have subtopics + questions. Only
ma18/ma19/ma20 (0 topics in DB) remain, pending a topic-taxonomy pass.
