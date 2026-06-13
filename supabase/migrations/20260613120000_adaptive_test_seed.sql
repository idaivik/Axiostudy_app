-- AI Weakness-Detection Engine — Phase 3: sentinel test row for adaptive practice.
--
-- Adaptive practice sessions are assembled on the fly (retrieved/generated
-- questions), but `test_attempts.test_id` is a FK to `tests`. Rather than create
-- a throwaway `tests` row per session, all adaptive attempts reference this one
-- stable sentinel row. The attempt itself is what carries the real per-session
-- data; analytics key on attempt_id, so sharing the test row is harmless.

insert into public.tests (id, name, type, duration_minutes, total_questions, subject_ids, is_adaptive)
values ('adaptive_practice', 'AI Adaptive Practice', 'practice', 30, 0,
        array['phys','chem','math','bio'], true)
on conflict (id) do nothing;
