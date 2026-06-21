# File B — Session C3 (chem: ch09, ch10, ch11, ch12)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `chem` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session C3). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ch09t1` | Alkali & Alkaline Earth Metals | class11 | `ch09t1s1` · Group 1: Alkali Metals | `ch09t1s2` · Group 2: Alkaline Earth Metals | `axai_ch09_001`–`030` |
| `ch09t2` | Boron & Carbon Family (Gr 13–14) | class11 | `ch09t2s1` · Group 13: Boron Family | `ch09t2s2` · Group 14: Carbon Family | `axai_ch09_031`–`060` |
| `ch10t1` | Nitrogen & Oxygen Family (Gr 15–16) | class12 | `ch10t1s1` · Group 15: Nitrogen Family | `ch10t1s2` · Group 16: Oxygen Family | `axai_ch10_001`–`030` |
| `ch10t2` | Halogen Family & Noble Gases (Gr 17–18) | class12 | `ch10t2s1` · Group 17: Halogens | `ch10t2s2` · Group 18: Noble Gases | `axai_ch10_031`–`060` |
| `ch11t1` | Transition Elements: Properties & Trends | class12 | `ch11t1s1` · d-Block Properties & Trends | `ch11t1s2` · Lanthanoids & Actinoids (f-Block) | `axai_ch11_001`–`030` |
| `ch11t2` | Coordination Compounds & IUPAC Naming | class12 | `ch11t2s1` · Werner's Theory & Ligands | `ch11t2s2` · IUPAC Nomenclature of Complexes | `axai_ch11_031`–`060` |
| `ch11t3` | VBT, CFT & Isomerism in Complexes | class12 | `ch11t3s1` · VBT & Crystal Field Theory | `ch11t3s2` · Isomerism in Coordination Compounds | `axai_ch11_061`–`090` |
| `ch12t1` | Metallurgy: Extraction & Refining | class11 | `ch12t1s1` · Concentration & Reduction of Ores | `ch12t1s2` · Refining & Thermodynamics of Extraction | `axai_ch12_001`–`030` |
| `ch12t2` | Hydrogen & its Compounds | class11 | `ch12t2s1` · Hydrogen & Hydrides | `ch12t2s2` · Water, H₂O₂ & Hard Water | `axai_ch12_031`–`060` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: C4 (`SUBTOPIC_SESSION_04.md`).
