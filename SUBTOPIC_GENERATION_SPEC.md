# Subtopic Question-Generation Spec (CONSTANT — paste into every session)

This is **File A**. It never changes between sessions. It defines *what* and *how* we
generate. Each session you also paste **File B** (`SUBTOPIC_SESSION_NN.md`), which says
*which* topics to do that session. Generate only what File B lists; obey this spec exactly.

> Live Supabase project: `nxtfbyvacunsiytlsfkl`. Branch: `feat/analytics-ai-coach`
> (the subtopic drill-down UI is ported here). The app reads subtopics + their questions
> directly from the `subtopics` and `questions` tables under RLS, so seeded rows appear
> immediately.

---

## 1. Goal & hierarchy

Fill in subtopic practice content so the drill-down stops dead-ending at "No subtopics yet."

Hierarchy: **subject → class → chapter → topic → subtopic**. Questions attach at the
**subtopic** level. Every topic gets **exactly 2 subtopics**; every subtopic gets
**15 questions = 5 easy + 5 medium + 5 hard**. So **30 questions per topic**.

> NOTE: ch01, ch02 and ch03t1 were authored earlier at the OLD volume (30 Q/subtopic).
> Leave them as-is. Everything from ch03t2 onward uses the new **15 Q/subtopic** rule.

## 2. The app's read path (why the rules below are non-negotiable)

- `getSubtopics(topicId)` lists `subtopics` rows where `topic_id = <topic>`, ordered by `sort_order`.
- `subtopicTests(subtopicId)` selects `questions` where `subtopic_id = <subtopic> AND status='active'`,
  then chunks them: every 5 easy + 5 medium + 5 hard forms one "Practice Test". With 5/5/5 each
  subtopic yields exactly **one** clean 15-question test.
- Therefore every question MUST set BOTH `topic_id` AND `subtopic_id`, and MUST be `status='active'`
  (the column default is `active`, so just don't override it). A question with a null `subtopic_id`
  or `status='probation'` is invisible to the feature.

## 3. ID scheme (must be collision-free)

- **Subtopic id:** `<topicId>s1` and `<topicId>s2` (e.g. `ch04t1s1`, `ph01t2s2`).
- **Question id:** `axai_<chapterId>_NNN`, zero-padded 3 digits (e.g. `axai_ch04_001`, `axai_ph01_031`).
- **Per-chapter numbering:** each topic owns a 30-id block in topic order:
  topic1 → `001–030`, topic2 → `031–060`, topic3 → `061–090`.
  Within a topic's block: **s1 = first 15** (`…01–15`), **s2 = next 15** (`…16–30`).
  Within each subtopic's 15: the 5 easy first, then 5 medium, then 5 hard.
  - ⚠️ **ch03 is the one exception:** ch03t1 already consumed `axai_ch03_001–060`, so
    ch03t2 = `061–090`, ch03t3 = `091–120`. (File B always states the exact range — trust it.)
- File B gives you the exact id range and subtopic ids for every topic. Never improvise ids.

## 4. Subtopic naming rule

Split the topic into **2 coherent sub-themes** that a teacher would recognise, in teaching
order. Keep names short (2–5 words), Title Case, no trailing punctuation. Examples:
- `ch04t1` "Ideal Gas Laws & Real Gases" → s1 "Gas Laws (Boyle, Charles, Avogadro)", s2 "Ideal Gas Equation & Dalton's Law"
- `ph01t1` "SI Units & Dimensional Analysis" → s1 "SI Units & Base Quantities", s2 "Dimensional Analysis & Homogeneity"
File B suggests the two names per topic; you may refine them, but keep 2 per topic.

## 5. Exact migration format

**One migration file per topic.** File name: `supabase/migrations/<UTCstamp>_<topicId>_<slug>.sql`
(e.g. `20260621140000_ch03t2_vsepr_hybridisation.sql`). Stamps must be increasing; bump the
time component per file within a session.

Each file is exactly two statements — the subtopics insert, then the questions insert:

```sql
-- ch04t1 "Ideal Gas Laws & Real Gases" — 2 subtopics + 30 questions (5E/5M/5H each).
insert into public.subtopics (id, name, topic_id, chapter_id, subject_id, sort_order) values
  ('ch04t1s1', 'Gas Laws (Boyle, Charles, Avogadro)', 'ch04t1', 'ch04', 'chem', 1),
  ('ch04t1s2', 'Ideal Gas Equation & Dalton''s Law',  'ch04t1', 'ch04', 'chem', 2)
on conflict (id) do nothing;

insert into public.questions
  (id, text, type, options, correct_answer, difficulty, difficulty_level, exam_type, explanation, subject_id, chapter_id, topic_id, subtopic_id)
values
('axai_ch04_001', 'At constant temperature, the volume of a fixed mass of gas is …', 'mcq', '["directly proportional to pressure","inversely proportional to pressure","independent of pressure","proportional to the square of pressure"]', 'inversely proportional to pressure', 'easy', 2, 'both', 'Boyle''s law: at constant T, V ∝ 1/P for a fixed mass of gas.', 'chem', 'ch04', 'ch04t1', 'ch04t1s1'),
-- … 14 more rows for ch04t1s1 (5E total, then 5M, then 5H) …
-- … then 15 rows for ch04t1s2 …
on conflict (id) do nothing;
```

### Column rules
| column | rule |
|---|---|
| `id` | `axai_<chapterId>_NNN`, exact range from File B. |
| `text` | The question stem. End with a colon or question mark. |
| `type` | Always `'mcq'`. |
| `options` | A JSON **array string** of **exactly 4** distinct option strings: `'["a","b","c","d"]'`. |
| `correct_answer` | Must be **character-for-character identical** to one of the 4 option strings. |
| `difficulty` | One of `'easy'`, `'medium'`, `'hard'`. 5 of each per subtopic. |
| `difficulty_level` | Integer fineness: easy 1–3, medium 4–6, hard 6–8. |
| `exam_type` | `'both'` (default), or `'jee'` / `'neet'` when a question is clearly one exam's style. |
| `explanation` | One concise sentence stating why the answer is correct. |
| `subject_id` | `phys` / `chem` / `math` / `bio` (from File B). |
| `chapter_id` / `topic_id` / `subtopic_id` | Exact ids from File B. **All three required.** |

Do **not** include `status` (defaults to `active`). Always end each insert with
`on conflict (id) do nothing;` so re-running is safe.

## 6. Accuracy & style rules (this is exam content — correctness is the priority)

1. Verify every answer yourself before writing it. Exactly **one** option is correct; the other
   three must be plausible but wrong (common misconceptions make the best distractors).
2. No ambiguous stems, no "both A and B", no trick wording. NCERT / JEE-Mains / NEET level.
3. Use correct SI units and standard symbols. Unicode sub/superscripts are fine (e.g. `H₂O`, `cm³`, `10⁻¹⁹`).
4. **Escape single quotes by doubling them** in SQL (`Boyle's` → `Boyle''s`, `Hess's` → `Hess''s`).
5. Spread the 5 within a difficulty across the sub-theme (don't ask the same fact 5 ways).
6. Keep explanations to one line — they render in the review screen.

## 7. Per-session workflow

1. Read File B for the session's topic list, subtopic ids, names and id ranges.
2. For each topic, write its migration file under `supabase/migrations/` (section 5 format).
3. Apply each via the Supabase MCP `apply_migration` (name = `<topicId>_<slug>`), or hand the
   files to the user to `supabase db push`.
4. **Verify** each topic with this query (expect two rows, each `5 / 5 / 5`):
   ```sql
   select s.id, s.sort_order,
     count(q.*) filter (where q.status='active' and q.difficulty='easy')   as easy,
     count(q.*) filter (where q.status='active' and q.difficulty='medium') as medium,
     count(q.*) filter (where q.status='active' and q.difficulty='hard')   as hard
   from subtopics s left join questions q on q.subtopic_id = s.id
   where s.topic_id = '<topicId>' group by s.id, s.sort_order order by s.sort_order;
   ```
5. Do NOT commit unless the user asks. Stop at the topics File B lists — don't run ahead.

## 8. Budget (why a session is ~9 topics)

~300 tokens/question all-in (write + apply + reasoning) → ~270 questions (9 topics) fits comfortably
under a 150k session with headroom. Calculation-heavy physics/math sessions are capped at ~7–8 topics.

## 9. Master schedule (22 sessions, 188 topics, 5,640 questions)

Each row is one session = one File B. Chapters kept intact within a session where possible.

| Session | Subj | Chapters (topics) | #Topics | #Qs |
|---|---|---|---|---|
| C1 | chem | ch03(t2,t3), ch04, ch05 | 7 | 210 |
| C2 | chem | ch06, ch07, ch08 | 9 | 270 |
| C3 | chem | ch09, ch10, ch11, ch12 | 9 | 270 |
| C4 | chem | ch13, ch14, ch15, ch16 | 9 | 270 |
| C5 | chem | ch17, ch18, ch19, ch20 | 7 | 210 |
| P1 | phys | ph01, ph02, ph03 | 9 | 270 |
| P2 | phys | ph04, ph05, ph06 | 9 | 270 |
| P3 | phys | ph07, ph08, ph09 | 9 | 270 |
| P4 | phys | ph10, ph11, ph12 | 9 | 270 |
| P5 | phys | ph13, ph14, ph15 | 8 | 240 |
| P6 | phys | ph16, ph17, ph18 | 7 | 210 |
| P7 | phys | ph19, ph20 | 6 | 180 |
| M1 | math | ma01, ma02, ma03 | 9 | 270 |
| M2 | math | ma04, ma05, ma06 | 8 | 240 |
| M3 | math | ma07, ma08, ma09 | 8 | 240 |
| M4 | math | ma10, ma11, ma12, ma13 | 9 | 270 |
| M5 | math | ma14, ma15, ma16, ma17 | 9 | 270 |
| B1 | bio | bi01, bi02, bi03, bi04 | 10 | 300 |
| B2 | bio | bi05, bi06, bi07, bi08 | 9 | 270 |
| B3 | bio | bi09, bi10, bi11, bi12 | 9 | 270 |
| B4 | bio | bi13, bi14, bi15, bi16, bi17 | 10 | 300 |
| B5 | bio | bi18, bi19, bi20 | 9 | 270 |

> ma18 / ma19 / ma20 have **0 topics** in the DB, so they are intentionally excluded — they need
> a topic taxonomy first (separate task). Order is chem → phys → math → bio; you may reorder by
> subject, but keep a chapter's topics together.
