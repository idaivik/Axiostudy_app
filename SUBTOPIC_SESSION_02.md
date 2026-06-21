# File B — Session C2 (chem: ch06, ch07, ch08)

Paste with `SUBTOPIC_GENERATION_SPEC.md`. Generate exactly the 9 topics below (18 subtopics,
**270 questions**), per spec, then stop. `subject_id` = `chem` for every row.

**Kickoff prompt:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate subtopic taxonomy + questions for the 9 topics in
> this File B (Session C2). One migration file per topic, 2 subtopics × 15 Q (5E/5M/5H), exact ids
> below, status active, `on conflict do nothing`. Apply via Supabase MCP; verify each topic 5/5/5
> per subtopic. Don't commit. Don't go past these 9 topics.

| topic_id | topic name | class | s1 (id · name) | s2 (id · name) | question id range |
|---|---|---|---|---|---|
| `ch06t1` | Chemical Equilibrium & Le Chatelier | class11 | `ch06t1s1` · Equilibrium Constant (Kc, Kp) | `ch06t1s2` · Le Chatelier's Principle & Shifts | `axai_ch06_001`–`030` |
| `ch06t2` | Ionic Equilibrium, pH & Buffers | class11 | `ch06t2s1` · Acids, Bases & pH | `ch06t2s2` · Buffers & Common-Ion Effect | `axai_ch06_031`–`060` |
| `ch06t3` | Solubility Product & Salt Hydrolysis | class11 | `ch06t3s1` · Solubility Product (Ksp) | `ch06t3s2` · Salt Hydrolysis & pH of Salts | `axai_ch06_061`–`090` |
| `ch07t1` | Oxidation States & Redox Balancing | class11 | `ch07t1s1` · Oxidation Number Rules | `ch07t1s2` · Balancing Redox Reactions | `axai_ch07_001`–`030` |
| `ch07t2` | Electrochemical Cells & EMF | class11 | `ch07t2s1` · Galvanic Cells & Electrode Potential | `ch07t2s2` · Nernst Equation & EMF | `axai_ch07_031`–`060` |
| `ch07t3` | Electrolysis & Faraday's Laws | class11 | `ch07t3s1` · Electrolysis & Products | `ch07t3s2` · Faraday's Laws & Conductance | `axai_ch07_061`–`090` |
| `ch08t1` | Rate Laws & Order of Reactions | class12 | `ch08t1s1` · Rate, Order & Molecularity | `ch08t1s2` · Integrated Rate Equations & Half-Life | `axai_ch08_001`–`030` |
| `ch08t2` | Arrhenius Equation & Activation Energy | class12 | `ch08t2s1` · Arrhenius Equation & Temperature | `ch08t2s2` · Activation Energy & Collision Theory | `axai_ch08_031`–`060` |
| `ch08t3` | Adsorption, Colloids & Catalysis | class12 | `ch08t3s1` · Adsorption & Catalysis | `ch08t3s2` · Colloids & Their Properties | `axai_ch08_061`–`090` |

**Id split per topic** (spec §3): s1 = first 15 of the block, s2 = next 15; within each, 5 easy → 5 medium → 5 hard.
**Done when:** 9 files applied; verify query returns `5/5/5` for all 18 subtopics. Next: C3 (`SUBTOPIC_SESSION_03.md`).
