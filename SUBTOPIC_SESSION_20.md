# File B — Session B3 (bio: bi09, bi10, bi11, bi12)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `bio` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session B3). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `bi09t1` | Plant Growth Regulators & Vernalisation | class11 | `bi09t1s1` · Plant Growth Regulators | `bi09t1s2` · Photoperiodism & Vernalisation | `axai_bi09_001`–`030` |
| `bi09t2` | Mineral Nutrition & Nitrogen Fixation | class11 | `bi09t2s1` · Essential Minerals & Deficiency | `bi09t2s2` · Nitrogen Fixation & Cycle | `axai_bi09_031`–`060` |
| `bi10t1` | Digestive System & Enzymes | class11 | `bi10t1s1` · Alimentary Canal & Glands | `bi10t1s2` · Digestive Enzymes & Digestion | `axai_bi10_001`–`030` |
| `bi10t2` | Absorption & Assimilation | class11 | `bi10t2s1` · Absorption of Nutrients | `bi10t2s2` · Disorders of Digestive System | `axai_bi10_031`–`060` |
| `bi11t1` | Lungs, Breathing Mechanism & Volumes | class11 | `bi11t1s1` · Respiratory Organs & Breathing | `bi11t1s2` · Respiratory Volumes & Capacities | `axai_bi11_001`–`030` |
| `bi11t2` | Gas Transport & Respiratory Disorders | class11 | `bi11t2s1` · Transport of O₂ & CO₂ | `bi11t2s2` · Regulation & Respiratory Disorders | `axai_bi11_031`–`060` |
| `bi12t1` | Blood Composition & Coagulation | class11 | `bi12t1s1` · Blood Components & Groups | `bi12t1s2` · Coagulation & Lymph | `axai_bi12_001`–`030` |
| `bi12t2` | Heart: Structure, Cardiac Cycle & ECG | class11 | `bi12t2s1` · Heart Structure & Conduction | `bi12t2s2` · Cardiac Cycle & ECG | `axai_bi12_031`–`060` |
| `bi12t3` | Lymph & Disorders of Circulation | class11 | `bi12t3s1` · Double Circulation & Regulation | `bi12t3s2` · Disorders of Circulatory System | `axai_bi12_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: B4 (`SUBTOPIC_SESSION_21.md`).
