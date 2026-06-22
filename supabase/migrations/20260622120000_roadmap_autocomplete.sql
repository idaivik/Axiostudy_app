-- Roadmap auto-completion: link practice attempts to the subtopic + test they
-- belong to, and expose per-chapter completion tiers for the study roadmap.
--
-- A chapter's roadmap rows auto-complete from subtopic-test performance — only
-- attempts scoring > 60% count — gated cumulatively per subtopic:
--   * Learn    — every subtopic has >= 3 DIFFERENT passing tests.
--   * Revise   — every subtopic has >= 6 passing tests total (the extra 3 may
--                repeat earlier tests).
--   * Practice — every subtopic has >= 9 passing tests total.
-- "Every subtopic, no exceptions": a chapter with any uncleared subtopic — or no
-- subtopics at all — never auto-completes (it falls back to the manual checkbox).

-- 1. Tag attempts with the subtopic + 1-based test index they were launched
--    from. Null for mock / adaptive / diagnostic attempts (not subtopic tests).
alter table public.test_attempts
  add column if not exists subtopic_id text references public.subtopics(id) on delete set null,
  add column if not exists test_index  int;

create index if not exists test_attempts_user_subtopic_idx
  on public.test_attempts (user_id, subtopic_id)
  where subtopic_id is not null;

-- 2. Per-chapter completion tiers for the signed-in user. Security invoker so the
--    existing RLS (own attempts; authenticated-readable subtopics) applies.
create or replace function public.roadmap_chapter_progress()
returns table (
  chapter_id    text,
  learn_done    boolean,
  revise_done   boolean,
  practice_done boolean
)
language sql
stable
security invoker
set search_path = public
as $$
  with stats as (
    -- Every subtopic of every chapter, left-joined to THIS user's passing
    -- attempts on it (subtopics with no passing attempt keep a 0 count).
    select
      s.chapter_id,
      s.id as subtopic_id,
      count(distinct a.test_index) as distinct_passes,
      count(a.id)                  as total_passes
    from public.subtopics s
    left join public.test_attempts a
      on a.subtopic_id = s.id
     and a.user_id = auth.uid()
     and a.status in ('submitted', 'analyzed')
     and a.total_marks > 0
     and a.score * 100 > a.total_marks * 60
    group by s.chapter_id, s.id
  ),
  per_subtopic as (
    select
      chapter_id,
      distinct_passes >= 3                       as tier_learn,
      distinct_passes >= 3 and total_passes >= 6 as tier_revise,
      distinct_passes >= 3 and total_passes >= 9 as tier_practice
    from stats
  )
  select
    chapter_id,
    bool_and(tier_learn)    as learn_done,
    bool_and(tier_revise)   as revise_done,
    bool_and(tier_practice) as practice_done
  from per_subtopic
  group by chapter_id;
$$;

grant execute on function public.roadmap_chapter_progress() to authenticated;
