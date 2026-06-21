# File B — Session C1 (chem: ch03t2, ch03t3, ch04, ch05)

Paste this **together with `SUBTOPIC_GENERATION_SPEC.md`** to run one generation session.
Generate exactly the 7 topics below (14 subtopics, **210 questions**), following the spec.
Then stop.

**Kickoff prompt to paste:**
> Using SUBTOPIC_GENERATION_SPEC.md, generate the subtopic taxonomy + questions for the 7 topics
> in this File B (Session C1). One migration file per topic, 2 subtopics × 15 Q (5 easy/5 medium/5
> hard), exact ids below, status active, `on conflict do nothing`. Apply each via Supabase MCP and
> verify each topic reads back 5/5/5 per subtopic. Don't commit. Don't go past these 7 topics.

`subject_id` = `chem` for every row this session.

| # | topic_id | topic name | class | subtopic s1 (id · suggested name) | subtopic s2 (id · suggested name) | question id range |
|---|---|---|---|---|---|---|
| 1 | `ch03t2` | VSEPR, Hybridisation & Geometry | class11 | `ch03t2s1` · VSEPR & Molecular Geometry | `ch03t2s2` · Hybridisation & Bond Parameters | `axai_ch03_061`–`090` |
| 2 | `ch03t3` | MO Theory & Resonance | class11 | `ch03t3s1` · Molecular Orbital Theory & Bond Order | `ch03t3s2` · Resonance, Polarity & Dipole Moment | `axai_ch03_091`–`120` |
| 3 | `ch04t1` | Ideal Gas Laws & Real Gases | class11 | `ch04t1s1` · Gas Laws (Boyle, Charles, Avogadro) | `ch04t1s2` · Ideal Gas Equation & Dalton's Law | `axai_ch04_001`–`030` |
| 4 | `ch04t2` | Kinetic Molecular Theory | class11 | `ch04t2s1` · Postulates & Molecular Speeds | `ch04t2s2` · Kinetic Energy & Maxwell Distribution | `axai_ch04_031`–`060` |
| 5 | `ch04t3` | Liquefaction & Van der Waals | class11 | `ch04t3s1` · Real Gases & Van der Waals Equation | `ch04t3s2` · Critical Constants & Liquefaction | `axai_ch04_061`–`090` |
| 6 | `ch05t1` | Enthalpy, Hess's Law & Born-Haber Cycle | class11 | `ch05t1s1` · Enthalpy & Thermochemical Equations | `ch05t1s2` · Hess's Law & Born–Haber Cycle | `axai_ch05_001`–`030` |
| 7 | `ch05t2` | Entropy, Gibbs Energy & Spontaneity | class11 | `ch05t2s1` · Entropy & the Second Law | `ch05t2s2` · Gibbs Energy & Spontaneity | `axai_ch05_031`–`060` |

**Per-topic id split** (per spec §3): within each topic's 30-id block, **s1 = first 15**, **s2 = next 15**;
inside each subtopic the 5 easy ids come first, then 5 medium, then 5 hard. Example for topic 1:
- `ch03t2s1`: `axai_ch03_061`–`075` (061–065 easy, 066–070 medium, 071–075 hard)
- `ch03t2s2`: `axai_ch03_076`–`090` (076–080 easy, 081–085 medium, 086–090 hard)

**Definition of done for this session:** 7 migration files created + applied; the verify query in
spec §7 returns `5 / 5 / 5` for all 14 subtopics; `flutter analyze` unaffected (no code touched).

---

### Making the next File B
Slice the next row from the master schedule in `SUBTOPIC_GENERATION_SPEC.md` §9 (C2 = ch06, ch07,
ch08) and fill this same table: look up each topic's real name from the chapter, assign the 2
subtopic ids `<topicId>s1/s2`, pick 2 sub-theme names, and compute id ranges as 30-blocks per
chapter (topic1 `001–030`, topic2 `031–060`, topic3 `061–090`). Every chapter except ch03 starts
its questions at `001`.
