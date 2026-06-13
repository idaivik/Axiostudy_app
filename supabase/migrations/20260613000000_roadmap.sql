-- AI Coaching-Synced Study Roadmap — schema, RLS, and seed.
--
-- Apply with the Supabase CLI (`supabase db push`) or the dashboard SQL editor.
-- The Flutter client currently persists enrollment + item status locally
-- (shared_preferences) so the feature works before this is applied; this
-- migration is the server-side path to make roadmaps multi-device + shareable.

-- ──────────────────────────────────────────────────────────────────────────
-- Reference data: coaching institutes and their chapter sequences
-- ──────────────────────────────────────────────────────────────────────────

create table if not exists public.coaching_institutes (
  id          text primary key,
  name        text not null,
  exam_type   text not null default 'jee',   -- 'jee' | 'neet' | 'both'
  logo_url    text,
  is_custom   boolean not null default false,
  created_at  timestamptz not null default now()
);

-- One row per (coaching, phase, chapter) defining the teaching order.
create table if not exists public.syllabus_sequences (
  id            uuid primary key default gen_random_uuid(),
  coaching_id   text not null references public.coaching_institutes(id) on delete cascade,
  phase         text not null default 'full',  -- e.g. 'class11', 'class12', 'dropper', 'full'
  position      int  not null,                 -- teaching order, 0-based
  subject_id    text not null,
  chapter_id    text not null,
  chapter_name  text not null,
  expected_week int,                           -- week offset from batch start
  unique (coaching_id, phase, chapter_id)
);

create index if not exists syllabus_sequences_lookup_idx
  on public.syllabus_sequences (coaching_id, phase, position);

-- ──────────────────────────────────────────────────────────────────────────
-- Per-student state: enrollment + generated roadmap
-- ──────────────────────────────────────────────────────────────────────────

create table if not exists public.student_enrollment (
  user_id          uuid primary key references auth.users(id) on delete cascade,
  coaching_id      text references public.coaching_institutes(id) on delete set null,
  phase            text not null default 'full',
  batch_start_date date,
  exam_date        date,
  daily_minutes    int  not null default 120,
  current_position int  not null default 0,   -- index into the sequence (chapter class is on)
  updated_at       timestamptz not null default now()
);

create table if not exists public.roadmaps (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  exam_date    date,
  version      int  not null default 1,
  generated_at timestamptz not null default now()
);

create index if not exists roadmaps_user_idx on public.roadmaps (user_id, generated_at desc);

create table if not exists public.roadmap_items (
  id              uuid primary key default gen_random_uuid(),
  roadmap_id      uuid not null references public.roadmaps(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  subject_id      text not null,
  chapter_id      text not null,
  topic_id        text,
  type            text not null default 'learn',     -- learn | revise | practice | mock
  status          text not null default 'upcoming',  -- upcoming | current | done | skipped | overdue
  scheduled_start date not null,
  scheduled_end   date not null,
  priority        int  not null default 0,
  reason          text,                              -- "why this, this week" (AI/heuristic copy)
  created_at      timestamptz not null default now()
);

create index if not exists roadmap_items_schedule_idx
  on public.roadmap_items (user_id, scheduled_start);

-- ──────────────────────────────────────────────────────────────────────────
-- Row Level Security
-- ──────────────────────────────────────────────────────────────────────────

alter table public.coaching_institutes enable row level security;
alter table public.syllabus_sequences  enable row level security;
alter table public.student_enrollment  enable row level security;
alter table public.roadmaps            enable row level security;
alter table public.roadmap_items       enable row level security;

-- Reference data is readable by any authenticated user.
drop policy if exists "coaching read" on public.coaching_institutes;
create policy "coaching read" on public.coaching_institutes
  for select to authenticated using (true);

drop policy if exists "syllabus read" on public.syllabus_sequences;
create policy "syllabus read" on public.syllabus_sequences
  for select to authenticated using (true);

-- A user can only touch their own enrollment / roadmap / items.
drop policy if exists "enrollment owner" on public.student_enrollment;
create policy "enrollment owner" on public.student_enrollment
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "roadmaps owner" on public.roadmaps;
create policy "roadmaps owner" on public.roadmaps
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "roadmap items owner" on public.roadmap_items;
create policy "roadmap items owner" on public.roadmap_items
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ──────────────────────────────────────────────────────────────────────────
-- Seed: institutes + Standard sequences DERIVED from the live public.chapters
-- table (real IDs: phys/chem/math/bio · ph01..bi20). JEE weaves phys/chem/math;
-- NEET weaves phys/chem/bio. Coaching-specific orderings are also maintained
-- client-side (roadmap_seed_data.dart) for offline use; keep the two in sync.
-- ──────────────────────────────────────────────────────────────────────────

insert into public.coaching_institutes (id, name, exam_type, is_custom) values
  ('standard',  'Standard (NCERT order)', 'both', false),
  ('allen',     'Allen',                  'both', false),
  ('aakash',    'Aakash',                 'both', false),
  ('fiitjee',   'FIITJEE',                'jee',  false),
  ('pw',        'Physics Wallah',         'both', false),
  ('custom',    'Self-study / Custom',    'both', true)
on conflict (id) do nothing;

-- Standard JEE sequence: round-robin phys → chem → math by chapter index.
insert into public.syllabus_sequences
  (coaching_id, phase, position, subject_id, chapter_id, chapter_name, expected_week)
select 'standard', 'jee',
       (row_number() over (order by idx, subj_rank)) - 1 as position,
       subject_id, id, name,
       (row_number() over (order by idx, subj_rank)) - 1 as expected_week
from (
  select subject_id, id, name,
         (row_number() over (partition by subject_id order by id)) - 1 as idx,
         case subject_id when 'phys' then 0 when 'chem' then 1 else 2 end as subj_rank
  from public.chapters
  where subject_id in ('phys', 'chem', 'math')
) s
on conflict (coaching_id, phase, chapter_id) do nothing;

-- Standard NEET sequence: round-robin phys → chem → bio by chapter index.
insert into public.syllabus_sequences
  (coaching_id, phase, position, subject_id, chapter_id, chapter_name, expected_week)
select 'standard', 'neet',
       (row_number() over (order by idx, subj_rank)) - 1 as position,
       subject_id, id, name,
       (row_number() over (order by idx, subj_rank)) - 1 as expected_week
from (
  select subject_id, id, name,
         (row_number() over (partition by subject_id order by id)) - 1 as idx,
         case subject_id when 'phys' then 0 when 'chem' then 1 else 2 end as subj_rank
  from public.chapters
  where subject_id in ('phys', 'chem', 'bio')
) s
on conflict (coaching_id, phase, chapter_id) do nothing;
