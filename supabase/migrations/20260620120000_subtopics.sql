-- Subtopic taxonomy + per-subtopic practice grouping, plus a DB-backed class
-- level on chapters (previously Dart-derived in chapter_grade.dart).
--
-- ADDITIVE / idempotent. Adds one new table, one nullable column on `questions`,
-- and one column on `chapters` (backfilled). Touches no existing question data.
-- Applied to the live project (nxtfbyvacunsiytlsfkl) via the Supabase MCP on
-- 2026-06-20.

-- 1. Subtopic level under topics. Denormalize chapter_id/subject_id the same way
--    `questions` already does, so subtopic lookups don't need joins.
create table if not exists public.subtopics (
  id          text primary key,
  name        text not null,
  topic_id    text not null references public.topics(id) on delete cascade,
  chapter_id  text,
  subject_id  text,
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists subtopics_topic_idx on public.subtopics (topic_id, sort_order);

-- 2. Tag questions to a subtopic. Nullable: existing topic-only questions stay
--    valid and simply don't appear under a subtopic until tagged.
alter table public.questions
  add column if not exists subtopic_id text references public.subtopics(id);
create index if not exists questions_subtopic_lookup_idx
  on public.questions (subtopic_id, difficulty, status);

-- 3. Class level on chapters (single source of truth for the Class 11/12 toggle).
alter table public.chapters
  add column if not exists class_level text;

-- Backfill from the previously hardcoded Dart set. Every other chapter defaults
-- to Class 11 (the existing safe default in chapter_grade.dart).
update public.chapters set class_level = 'class12'
 where id in (
   'ph11','ph12','ph13','ph14','ph15','ph16','ph17','ph18','ph19','ph20',
   'ch08','ch10','ch11','ch14','ch15','ch16','ch17','ch18','ch19','ch20',
   'ma03','ma09','ma10','ma11','ma12','ma13','ma14','ma15',
   'bi17','bi18','bi19','bi20'
 );
update public.chapters set class_level = 'class11' where class_level is null;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'chapters_class_level_chk') then
    alter table public.chapters
      add constraint chapters_class_level_chk check (class_level in ('class11','class12'));
  end if;
end $$;
