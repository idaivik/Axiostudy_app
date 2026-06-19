-- Bucket 3A · Feature 2 — AI study notes, paced to the student (Pro, 60/mo)
-- (BILLING_BUCKET3A_BUILD_PROMPT.md §2). Meter: ai_note (already seeded Pro 60 in
-- 20260617120000_usage_meters.sql — NO meter change here).
--
-- The cache IS the cost control: a note is generated ONCE per (user, topic) and
-- stored; re-opening reads the stored row and spends no meter. Regenerating is an
-- explicit user action that overwrites the row and spends one ai_note. The
-- generate-notes edge fn enforces all of that (cache-first, then consume_meter).
--
-- ADDITIVE / idempotent.

create table if not exists public.study_notes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  topic_id    text not null,
  chapter_id  text,
  subject_id  text,
  topic_name  text,
  -- Pitched at the student's mastery: 'foundational' | 'intermediate' | 'advanced'.
  level       text not null default 'intermediate',
  -- Structured note: { concept, key_points[], common_mistakes[], formulas[] }.
  content     jsonb not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, topic_id)              -- one cached note per topic; regenerate overwrites
);

create index if not exists study_notes_user_idx on public.study_notes (user_id);

comment on table public.study_notes is
  'Cached AI study notes (Bucket 3A · Feature 2, meter ai_note). One row per '
  '(user, topic): generated once, re-read for free, regeneration overwrites.';

-- ── RLS: owner-readable; writes are service-role only (the edge fn) ───────────
-- No insert/update policy is granted, so a client can read its cached notes but
-- only the metered generate-notes function (service role) can write them.
alter table public.study_notes enable row level security;

drop policy if exists "study_notes readable" on public.study_notes;
create policy "study_notes readable" on public.study_notes
  for select to authenticated using (auth.uid() = user_id);
