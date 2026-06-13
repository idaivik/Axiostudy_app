-- AI Weakness-Detection & Adaptive Practice Engine — Phase 0 foundations.
--
-- ADDITIVE ONLY. Adds columns to three existing tables and creates two new
-- user-owned tables. Touches none of the existing data. Safe to re-run
-- (idempotent: `add column if not exists` / `create table if not exists`).
--
-- Apply with the Supabase CLI (`supabase db push`) or the dashboard SQL editor.
-- (This was applied to the live project via the Supabase MCP on 2026-06-13.)

-- ──────────────────────────────────────────────────────────────────────────
-- 1. test_attempts: cache the grade summary so the dashboard + adaptive loop
--    don't have to re-aggregate user_answers on every read.
-- ──────────────────────────────────────────────────────────────────────────
alter table public.test_attempts
  add column if not exists total_correct      int,
  add column if not exists total_wrong        int,
  add column if not exists total_unanswered   int,
  add column if not exists time_taken_seconds int;

-- ──────────────────────────────────────────────────────────────────────────
-- 2. user_answers: how many times the student opened the question before
--    locking an answer (the flowchart's "visited" signal — drives the
--    silly/conceptual/calculation error classification). Not captured today,
--    so it defaults to 0 for historical rows.
-- ──────────────────────────────────────────────────────────────────────────
alter table public.user_answers
  add column if not exists visited_count int not null default 0;

-- ──────────────────────────────────────────────────────────────────────────
-- 3. questions: AI-generation lifecycle + usage feedback. The existing 2000
--    seed questions stay `active` / human (`is_ai_generated=false`). Newly
--    generated questions enter as `probation` and are auto-promoted/retired
--    from usage stats (Phase 2).
-- ──────────────────────────────────────────────────────────────────────────
alter table public.questions
  add column if not exists is_ai_generated   boolean not null default false,
  add column if not exists is_verified       boolean not null default false,
  add column if not exists status            text    not null default 'active', -- active | probation | retired
  add column if not exists generated_by_model text,
  add column if not exists times_served      int not null default 0,
  add column if not exists times_correct     int not null default 0,
  add column if not exists thumbs_up         int not null default 0,
  add column if not exists thumbs_down       int not null default 0;

-- Pool-retrieval hot path: weak chapter × difficulty band, only servable rows.
create index if not exists questions_pool_lookup_idx
  on public.questions (chapter_id, difficulty_level, status);

-- ──────────────────────────────────────────────────────────────────────────
-- 4. chapter_analytics — the flowchart's ANALYTICS node. One row per
--    (attempt, chapter): the computed breakdown plus the AI insight columns.
-- ──────────────────────────────────────────────────────────────────────────
create table if not exists public.chapter_analytics (
  id                          uuid primary key default gen_random_uuid(),
  user_id                     uuid not null references auth.users(id) on delete cascade,
  attempt_id                  text not null references public.test_attempts(id) on delete cascade,
  chapter_id                  text not null,
  subject_id                  text not null,
  score_percentage            numeric not null default 0,   -- 0–100
  correct_count               int     not null default 0,
  wrong_count                 int     not null default 0,
  unanswered_count            int     not null default 0,
  avg_time_per_question       numeric not null default 0,   -- seconds
  is_weak                     boolean not null default false, -- score < 50
  is_strong                   boolean not null default false, -- score > 75
  improvement_from_last_test  numeric,                        -- null = no prior data
  error_pattern               text,                           -- silly | conceptual | calculation
  -- AI insight columns (written by the compute-analytics edge function) ──
  weakness_reasoning          text,
  recommended_action          text,
  priority_score              int,                            -- AI rank, 0–100 (higher = more urgent)
  computed_at                 timestamptz not null default now(),
  unique (attempt_id, chapter_id)
);

create index if not exists chapter_analytics_user_chapter_idx
  on public.chapter_analytics (user_id, chapter_id, computed_at desc);

-- ──────────────────────────────────────────────────────────────────────────
-- 5. user_weak_chapters — the flowchart's USER_WEAK_TOPICS (chapter-level).
--    A persistent per-chapter mastery score. `weakness_score` is a 0–100
--    MASTERY score (higher = stronger; the adaptive loop promotes a chapter to
--    `strong` once it clears 75 and surfaces the next weak chapter). One row
--    per (user, chapter); updated after every attempt that touches the chapter.
-- ──────────────────────────────────────────────────────────────────────────
create table if not exists public.user_weak_chapters (
  user_id        uuid not null references auth.users(id) on delete cascade,
  chapter_id     text not null,
  subject_id     text,
  weakness_score numeric not null default 0,   -- 0–100 mastery (higher = stronger)
  attempts_count int     not null default 0,
  status         text    not null default 'weak', -- weak (<50) | improving (50–75) | strong (>75)
  last_updated   timestamptz not null default now(),
  primary key (user_id, chapter_id)
);

create index if not exists user_weak_chapters_lookup_idx
  on public.user_weak_chapters (user_id, status, weakness_score);

-- ──────────────────────────────────────────────────────────────────────────
-- Row Level Security — both new tables are user-owned.
-- ──────────────────────────────────────────────────────────────────────────
alter table public.chapter_analytics  enable row level security;
alter table public.user_weak_chapters enable row level security;

drop policy if exists "chapter_analytics owner" on public.chapter_analytics;
create policy "chapter_analytics owner" on public.chapter_analytics
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "user_weak_chapters owner" on public.user_weak_chapters;
create policy "user_weak_chapters owner" on public.user_weak_chapters
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
