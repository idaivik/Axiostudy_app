# AI Coaching-Synced Study Roadmap — Implementation TODO

> Status: **Planning only.** Not started. We implement later today.
> Goal: an AI-generated, continuously re-planned study roadmap that matches the
> sequence in which the student's **coaching institute** (Allen / Aakash / FIITJEE /
> Physics Wallah / Resonance / etc.) is teaching chapters — so in-app practice always
> lines up with "what sir taught in class this week," while still interleaving
> revision of past weak chapters and backward-planning toward the exam date.

## Why this wins
JEE/NEET students feel their app practice is disconnected from their coaching class.
No major competitor syncs to the coaching's actual chapter sequence. We already have
the measurement layer (`TopicPerformance`, strength, streaks, recommendations) — this
turns it into a forward-looking, class-aligned plan.

## How the AI fits
Claude is the **planner/re-planner**, not just a chatbot. Given (a) the coaching
syllabus sequence + the student's current position in it, (b) exam date, (c) daily
time budget, and (d) the student's weak topics from existing analytics, Claude
produces a dated, week-by-week plan that mixes:
- **Learn** — the chapter(s) currently being taught in class
- **Revise** — recent + weak chapters on a spaced-repetition cadence
- **Practice** — targeted drills on weak topics
- **Mock** — full-syllabus mocks that ramp up as the exam approaches

It re-plans automatically after each test (new weaknesses) or when the student falls behind.

---

## Decisions to make before coding (resolve at kickoff)
- [ ] **Coaching coverage:** which institutes do we seed sequences for at launch?
      (Recommend: Allen, Aakash, FIITJEE, Physics Wallah + a "Standard / NCERT" default
      + a "Custom / Self-study" manual-ordering path so no student is blocked.)
- [ ] **Sequence source:** hand-seed templates vs. let the student arrange chapters in
      onboarding. (Recommend: seed templates, allow manual reorder/override.)
- [ ] **AI boundary:** Claude generates the full schedule vs. a deterministic scheduler
      does dating/SRS and Claude only handles re-planning + rationale text.
      (Recommend: deterministic scheduler for dates/intervals, Claude for ordering
      decisions + "why this week" copy — cheaper, predictable, testable.)
- [ ] **Exam targeting:** single exam date, or support JEE Main attempt windows + NEET separately.

---

## Phase 1 — Backend / Supabase data model ✅ DONE + APPLIED
> `supabase/migrations/20260613000000_roadmap.sql`. APPLIED to the live project
> (nxtfbyvacunsiytlsfkl) on 2026-06-13: 5 new tables, RLS + policies verified,
> Standard JEE & NEET sequences seeded (60 chapters each) derived from the real
> `public.chapters` (phys/chem/math/bio · ph01..bi20). No ERROR advisories.
> App still reads sequences from the local Dart seed; DB-backed read is a follow-up.
- [x] `coaching_institutes` table (id, name, logo, exam_type)
- [x] `syllabus_sequences` table — ordered chapter list per coaching + phase/batch
      (coaching_id, phase, position, chapter_id, expected_week)
- [x] `student_enrollment` table (user_id, coaching_id, phase, batch_start_date,
      exam_date, daily_minutes, current_position)
- [x] `roadmaps` table (id, user_id, generated_at, exam_date, version)
- [x] `roadmap_items` table (id, roadmap_id, chapter_id/topic_id, type, status,
      scheduled_start, scheduled_end, priority, reason)
- [x] RLS policies (user owns their enrollment + roadmap)
- [x] Seed: institutes + the "Standard/NCERT" default sequence

## Phase 2 — Domain models (`lib/features/roadmap/domain/`) ✅ DONE
> `lib/features/roadmap/domain/roadmap_models.dart`
- [x] `CoachingInstitute`
- [x] `SyllabusSequence` / `SyllabusEntry`
- [x] `StudentEnrollment` (current position, exam date, daily budget)
- [x] `Roadmap` + `RoadmapItem` (scheduled window, status, reason)
- [x] Enums: `RoadmapItemType {learn, revise, practice, mock}`,
      `RoadmapItemStatus {upcoming, current, done, skipped, overdue}`,
      `ExamType` (phase modelled as a string on enrollment/sequence)
- [x] Reuse existing `Chapter` / `Topic` / `TopicPerformance` — do NOT duplicate

## Phase 3 — AI roadmap engine (`lib/features/roadmap/data/`) ✅ DONE
> `roadmap_seed_data.dart` (coaching sequences), `roadmap_planner.dart` (pure
> scheduler), `roadmap_ai_client.dart` (AI seam + heuristic impl),
> `roadmap_repository.dart` (assembly + local persistence),
> `roadmap_providers.dart` (Riverpod wiring). `dart analyze`: clean.
- [x] `RoadmapPlanner` service: inputs (sequence, current position, exam date,
      chapter strength, daily minutes) → dated, ordered `RoadmapItem`s
- [x] Backward-planning from exam date into phases:
      learning → consolidation → full-syllabus mock prep
- [x] Spaced-repetition cadence for `revise` items (staggered; weakest-first)
- [x] AI seam (`RoadmapAiClient`) for ordering + "why this week" rationale.
      Default = offline `HeuristicRoadmapAiClient`; Claude-via-edge-function path
      documented (keeps API key server-side — no key in the client).
- [ ] Re-plan triggers: after each submitted test, and on "I'm behind" / overdue
      items → see Phase 6 (auto re-plan currently happens on every load/invalidate)
- [x] Unit-testable pure scheduling core (no network) with AI as an injectable step

## Phase 4 — Onboarding integration ✅ DONE
> `lib/features/roadmap/presentation/roadmap_setup_screen.dart`
- [x] New step: "Where are you preparing?" → pick coaching (Allen/Aakash/FIITJEE/
      PW/Standard/Custom) + exam target
- [x] Capture "which chapter is your class on now?" (current position),
      exam date + daily study-time budget
- [x] Generate the first roadmap on completion (saves enrollment → routes to /roadmap)
- [ ] Make coaching/exam-date editable later from Settings → wired in Phase 6

## Phase 5 — Roadmap UI (`lib/features/roadmap/presentation/`) ✅ DONE
> `roadmap_screen.dart` + `widgets/exam_countdown_header.dart` +
> `widgets/roadmap_item_tile.dart`. `dart analyze`: clean.
- [x] Roadmap screen: **This Week** focus block + Upcoming timeline +
      **Catch Up** (overdue) + syllabus-coverage progress bar
- [x] Exam countdown header ("23 days to go • 61% roadmap progress")
- [x] Roadmap item → launches existing practice/test flows + mark-done toggle
- [x] "Re-plan" action (app bar) + graceful "Catch Up" section for slipped items
- [ ] Entry point: bottom-nav / Home card → wired in Phase 6

## Phase 6 — Integrations with existing features ✅ DONE (core)
> `RoadmapHomeCard` added to Home; `/roadmap` + `/roadmap/setup` routes added;
> Settings → "Study Roadmap" entry. `dart analyze`: clean.
- [x] Surface today's roadmap items on Home via `RoadmapHomeCard` (countdown +
      this-week tasks + catch-up count), routes into the full roadmap
- [x] Entry points: Home card + Settings → Study Plan → Study Roadmap
- [x] Mark roadmap item done from the roadmap screen (persisted locally)
- [ ] Deep-link `practice` items into a chapter-filtered practice set
      (currently routes to /practice) — follow-up
- [ ] Hook `revise`/`practice` into SRS queue + Error Notebook (related features)
- [ ] Notifications: "Today's class topic is ready to practice"
- [ ] Mark item done → bump `StudyStreak` (currently streak is test-driven)

## Phase 7 — State, routing, tests ✅ DONE
> `roadmap_providers.dart`; routes in `app_router.dart`;
> `test/features/roadmap/roadmap_planner_test.dart` (12 tests, all passing).
- [x] Riverpod providers: enrollment, active roadmap, controller, chapter-strength
- [x] `go_router` routes (`/roadmap`, `/roadmap/setup`) + Home/Settings nav entries
- [x] Unit tests for the scheduling core (ordering, backward planning, mocks,
      revise/practice, stable IDs, seed sequences) — 12 passing
- [ ] Widget test for the Roadmap screen states — follow-up (logic core covered)

---

## Related TODOs (from feature recommendations — built alongside)
- Spaced-repetition revision queue (powers `revise` items)
- Error notebook with mistake-type tagging (powers `practice` items)
- Claude doubt solver (linked from any roadmap practice question)
