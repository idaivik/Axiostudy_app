# File B — Session B4 (bio: bi13, bi14, bi15, bi16, bi17)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 10 topics below (20 subtopics,
**300 questions**), per spec, then stop. `subject_id` = `bio` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 10 topics in
> this File B (Session B4). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 10 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `bi13t1` | Kidney: Structure & Urine Formation | class11 | `bi13t1s1` · Nephron & Kidney Structure | `bi13t1s2` · Urine Formation & Counter-Current | `axai_bi13_001`–`030` |
| `bi13t2` | Osmoregulation & Kidney Disorders | class11 | `bi13t2s1` · Regulation of Kidney Function | `bi13t2s2` · Kidney Disorders & Dialysis | `axai_bi13_031`–`060` |
| `bi14t1` | Skeletal System & Joints | class11 | `bi14t1s1` · Axial & Appendicular Skeleton | `bi14t1s2` · Joints & Skeletal Disorders | `axai_bi14_001`–`030` |
| `bi14t2` | Muscle Structure & Contraction | class11 | `bi14t2s1` · Muscle Types & Ultrastructure | `bi14t2s2` · Sliding Filament & Contraction | `axai_bi14_031`–`060` |
| `bi15t1` | Neuron, Synapse & Reflex Action | class11 | `bi15t1s1` · Neuron & Nerve Impulse | `bi15t1s2` · Synapse & Reflex Action | `axai_bi15_001`–`030` |
| `bi15t2` | Brain, Spinal Cord & Sense Organs | class11 | `bi15t2s1` · Central Nervous System | `bi15t2s2` · Eye & Ear (Sense Organs) | `axai_bi15_031`–`060` |
| `bi16t1` | Endocrine Glands & Hormones | class11 | `bi16t1s1` · Major Endocrine Glands | `bi16t1s2` · Hormones & Their Functions | `axai_bi16_001`–`030` |
| `bi16t2` | Feedback Mechanisms & Disorders | class11 | `bi16t2s1` · Hormonal Regulation & Feedback | `bi16t2s2` · Endocrine Disorders | `axai_bi16_031`–`060` |
| `bi17t1` | Asexual & Sexual Reproduction in Plants | class12 | `bi17t1s1` · Asexual Reproduction & Vegetative Propagation | `bi17t1s2` · Sexual Reproduction & Flower Structure | `axai_bi17_001`–`030` |
| `bi17t2` | Pollination, Fertilisation & Fruits | class12 | `bi17t2s1` · Pollination & Pollen-Pistil Interaction | `bi17t2s2` · Double Fertilisation, Seed & Fruit | `axai_bi17_031`–`060` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 10 files applied; verify query returns `5/5/5` for all 20 subtopics. Next: B5 (`SUBTOPIC_SESSION_22.md`).
