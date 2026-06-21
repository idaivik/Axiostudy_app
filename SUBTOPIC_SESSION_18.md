# File B — Session B1 (bio: bi01, bi02, bi03, bi04)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 10 topics below (20 subtopics,
**300 questions**), per spec, then stop. `subject_id` = `bio` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 10 topics in
> this File B (Session B1). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 10 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `bi01t1` | Taxonomy & Nomenclature | class11 | `bi01t1s1` · Taxonomic Hierarchy & Categories | `bi01t1s2` · Binomial Nomenclature & Rules | `axai_bi01_001`–`030` |
| `bi01t2` | Five Kingdom Classification | class11 | `bi01t2s1` · Kingdoms Monera & Protista | `bi01t2s2` · Kingdoms Fungi, Plantae & Animalia | `axai_bi01_031`–`060` |
| `bi01t3` | Viruses, Viroids & Lichens | class11 | `bi01t3s1` · Viruses & Viroids | `bi01t3s2` · Lichens & Mycoplasma | `axai_bi01_061`–`090` |
| `bi02t1` | Algae, Bryophytes & Pteridophytes | class11 | `bi02t1s1` · Algae & Their Classes | `bi02t1s2` · Bryophytes & Pteridophytes | `axai_bi02_001`–`030` |
| `bi02t2` | Gymnosperms & Angiosperms | class11 | `bi02t2s1` · Gymnosperms | `bi02t2s2` · Angiosperms & Life Cycles | `axai_bi02_031`–`060` |
| `bi03t1` | Non-Chordates: Porifera to Echinodermata | class11 | `bi03t1s1` · Porifera to Aschelminthes | `bi03t1s2` · Annelida to Echinodermata | `axai_bi03_001`–`030` |
| `bi03t2` | Chordates: Fishes to Mammals | class11 | `bi03t2s1` · Protochordates & Fishes | `bi03t2s2` · Amphibians, Reptiles, Birds & Mammals | `axai_bi03_031`–`060` |
| `bi04t1` | Root, Stem & Leaf Morphology | class11 | `bi04t1s1` · Root & Stem Modifications | `bi04t1s2` · Leaf & Phyllotaxy | `axai_bi04_001`–`030` |
| `bi04t2` | Flower, Fruit & Seed Structure | class11 | `bi04t2s1` · Flower & Inflorescence | `bi04t2s2` · Fruit & Seed Structure | `axai_bi04_031`–`060` |
| `bi04t3` | Anatomy: Tissues & Secondary Growth | class11 | `bi04t3s1` · Plant Tissues & Tissue Systems | `bi04t3s2` · Secondary Growth | `axai_bi04_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 10 files applied; verify query returns `5/5/5` for all 20 subtopics. Next: B2 (`SUBTOPIC_SESSION_19.md`).
