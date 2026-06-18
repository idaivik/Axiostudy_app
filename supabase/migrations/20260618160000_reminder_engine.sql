-- Feature 1 — Reminder engine, data foundation
-- (BILLING_BUCKET1_BUILD_PROMPT.md §3). ONE engine, channeled by tier: Basic =
-- rule-based reminders, Pro = spaced-repetition on the SAME engine.
--
-- This migration is JUST the schema (no Firebase, no copy decisions). The
-- `send-reminders` edge engine + the client FCM wiring land after the Firebase
-- project + copy/tone are confirmed (the ‼️ ask-first gate). Defaults here are
-- the ones the spec fixes: notifications ON, quiet 22:00–08:00, max 1/day.
-- ADDITIVE / idempotent.

-- ── user_devices — one row per device install; upsert on token refresh ────────
-- Keyed by the FCM token (a token identifies one install and belongs to the
-- currently-signed-in user). Logout deletes the row; a new login upserts and
-- reassigns user_id. The engine deletes tokens FCM reports as unregistered.
create table if not exists public.user_devices (
  fcm_token   text primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  platform    text not null,                 -- 'android' | 'ios'
  updated_at  timestamptz not null default now()
);
create index if not exists user_devices_user_idx on public.user_devices (user_id);

-- ── notification_prefs — per-user controls (quiet hours + frequency cap) ──────
-- timezone is the user's IANA zone (e.g. 'Asia/Kolkata') so the engine applies
-- quiet hours + "once per local day" correctly; null → fall back to UTC.
create table if not exists public.notification_prefs (
  user_id      uuid primary key references public.profiles(id) on delete cascade,
  enabled      boolean not null default true,
  quiet_start  time    not null default '22:00',
  quiet_end    time    not null default '08:00',
  max_per_day  int     not null default 1,
  timezone     text,
  updated_at   timestamptz not null default now()
);

-- ── reminder_schedule — the engine writes due items; the sender reads them ────
-- kind ∈ rule-based ('decay' | 'weakness' | 'streak') + 'spaced_rep' (Pro).
-- sent_at guards against double-sends.
create table if not exists public.reminder_schedule (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  topic_id    text,
  chapter_id  text,
  due_at      timestamptz not null,
  kind        text not null,
  title       text,
  body        text,
  sent_at     timestamptz,
  created_at  timestamptz not null default now()
);
-- Hot path for the sender: this user's pending, now-due items.
create index if not exists reminder_schedule_due_idx
  on public.reminder_schedule (user_id, due_at) where sent_at is null;

-- ── topic_review_state — SM-2 spaced-repetition state (Pro branch) ────────────
-- Per (user, topic) interval curve. The Pro engine widens `interval_days` as a
-- topic is mastered (reps↑, ease↑) → smarter due dates; Basic ignores this.
create table if not exists public.topic_review_state (
  user_id          uuid not null references public.profiles(id) on delete cascade,
  topic_id         text not null,
  interval_days    int     not null default 1,
  ease             numeric not null default 2.5,   -- SM-2 ease factor
  reps             int     not null default 0,
  last_reviewed_at timestamptz,
  next_due_at      timestamptz,
  primary key (user_id, topic_id)
);
create index if not exists topic_review_state_due_idx
  on public.topic_review_state (user_id, next_due_at);

-- ── RLS ───────────────────────────────────────────────────────────────────────
-- user_devices + notification_prefs are user-owned: the client manages its own
-- rows. reminder_schedule + topic_review_state are engine-written (service role,
-- which bypasses RLS) and only READABLE by their owner.
alter table public.user_devices       enable row level security;
alter table public.notification_prefs enable row level security;
alter table public.reminder_schedule  enable row level security;
alter table public.topic_review_state enable row level security;

drop policy if exists "user_devices owner" on public.user_devices;
create policy "user_devices owner" on public.user_devices
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "notification_prefs owner" on public.notification_prefs;
create policy "notification_prefs owner" on public.notification_prefs
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "reminder_schedule readable" on public.reminder_schedule;
create policy "reminder_schedule readable" on public.reminder_schedule
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "topic_review_state readable" on public.topic_review_state;
create policy "topic_review_state readable" on public.topic_review_state
  for select to authenticated using (auth.uid() = user_id);
