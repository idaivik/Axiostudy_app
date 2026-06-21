# File B — Session C4 (chem: ch13, ch14, ch15, ch16)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `chem` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session C4). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ch13t1` | IUPAC, Isomerism & Reaction Mechanisms | class11 | `ch13t1s1` · IUPAC Nomenclature & Isomerism | `ch13t1s2` · Electronic Effects & Reaction Intermediates | `axai_ch13_001`–`030` |
| `ch13t2` | Alkanes, Alkenes & Alkynes | class11 | `ch13t2s1` · Alkanes & Free-Radical Substitution | `ch13t2s2` · Alkenes & Alkynes: Addition Reactions | `axai_ch13_031`–`060` |
| `ch13t3` | Arenes & Aromatic Substitution | class11 | `ch13t3s1` · Aromaticity & Benzene Structure | `ch13t3s2` · Electrophilic Aromatic Substitution | `axai_ch13_061`–`090` |
| `ch14t1` | Haloalkanes: SN1, SN2 & Elimination | class12 | `ch14t1s1` · Nucleophilic Substitution (SN1/SN2) | `ch14t1s2` · Elimination Reactions & Stability | `axai_ch14_001`–`030` |
| `ch14t2` | Haloarenes & Ethers: Reactions | class12 | `ch14t2s1` · Haloarenes: Preparation & Reactions | `ch14t2s2` · Ethers: Preparation & Cleavage | `axai_ch14_031`–`060` |
| `ch15t1` | Alcohols & Phenols: Reactions | class12 | `ch15t1s1` · Alcohols: Preparation & Reactions | `ch15t1s2` · Phenols: Acidity & Reactions | `axai_ch15_001`–`030` |
| `ch15t2` | Aldehydes & Ketones: Reactions | class12 | `ch15t2s1` · Nucleophilic Addition to Carbonyls | `ch15t2s2` · Aldol, Cannizzaro & Oxidation | `axai_ch15_031`–`060` |
| `ch16t1` | Carboxylic Acids & Derivatives | class12 | `ch16t1s1` · Carboxylic Acids: Acidity & Preparation | `ch16t1s2` · Acid Derivatives & Reactions | `axai_ch16_001`–`030` |
| `ch16t2` | Amines & Diazonium Salts | class12 | `ch16t2s1` · Amines: Basicity & Preparation | `ch16t2s2` · Diazonium Salts & Their Reactions | `axai_ch16_031`–`060` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: C5 (`SUBTOPIC_SESSION_05.md`).
