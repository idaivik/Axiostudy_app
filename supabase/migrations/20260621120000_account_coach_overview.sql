-- Plan B — Persistent AI coach (account-level Overview card).
--
-- A single, account-level "where do I stand & why" cache, the Overview-tab
-- counterpart to the per-attempt `attempt_analytics.ai_narrative`
-- (20260618130000_ai_narrative.sql). One row per user:
--   • narrative      — the cheap-model coach paragraph (Pro, metered ONCE per
--                      source change; reuses the `ai_analysis_narrative` meter —
--                      no new meter is introduced).
--   • focus_*        — the DETERMINISTIC "#1 focus → Practice" target (weakest
--                      `user_weak_chapters` row + its weakest topic). Computed
--                      server-side and returned to EVERY user, free or Pro.
--   • source_hash    — fingerprint of (latest attempt + weak-chapter mastery).
--                      The edge function returns the cached narrative WITHOUT
--                      spending a meter while this is unchanged, so re-opening
--                      Overview never re-bills.
--
-- ADDITIVE / idempotent. Writes happen only via the service-role edge function
-- (`coach-overview`); the sole RLS policy is an owner read.

create table if not exists public.account_coach_overview (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  narrative       text,
  focus_chapter_id text,
  focus_topic_id   text,
  focus_accuracy   numeric,
  source_hash     text,
  generated_at    timestamptz not null default now()
);

comment on table public.account_coach_overview is
  'Account-level AI coach cache (Plan B). narrative is Pro+metered via the '
  'shared ai_analysis_narrative meter; focus_* is the free deterministic #1 '
  'focus. source_hash gates re-generation so re-opening Overview never re-bills.';

alter table public.account_coach_overview enable row level security;

drop policy if exists "own row read" on public.account_coach_overview;
create policy "own row read" on public.account_coach_overview
  for select to authenticated using (auth.uid() = user_id);
-- No insert/update/delete policy: writes are service-role only (edge function).
