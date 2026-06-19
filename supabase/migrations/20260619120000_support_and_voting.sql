-- Bucket 2 — Feature 2: feature voting + early-access opt-in
-- (BILLING_BUCKET2_BUILD_PROMPT.md §3). Build-in-house (not Canny/Intercom).
--
-- Priority support is delivered as a mailto deep-link (confirmed with the user),
-- so there is NO support_tickets table — replies are handled in the support
-- inbox, with the tier/priority flag carried in the email subject. This migration
-- therefore covers only the voting board + the early-access flag.
--
-- GATING: "only Pro can vote/submit/early-access" is enforced client-side via
-- FeatureGate(prioritySupport) — the app's gating model (see feature_gate.dart:
-- "client gating is UX only"). These rows carry no money/meter cost, so the DB
-- RLS just scopes ownership + guarantees idempotency; it deliberately does not
-- re-implement the tier/lapse predicate. NOT metered, NOT a tier-matrix change.
--
-- ADDITIVE / idempotent. Never edits a committed migration.

-- ── profiles.early_access — opt-in flag a future experimental feature reads ────
alter table public.profiles
  add column if not exists early_access boolean not null default false;
comment on column public.profiles.early_access is
  'Opt-in (Pro perk): when true, experimental / early-access features may be '
  'shown to this user. A real gate future features must read — see §3c.';

-- ── feature_requests — the voting board ───────────────────────────────────────
-- status ∈ open | planned | shipped | closed. 'closed' rows drop off the board.
create table if not exists public.feature_requests (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  description text,
  status      text not null default 'open',
  created_at  timestamptz not null default now()
);

-- ── feature_votes — one vote per (user, request); the PK makes it idempotent ───
create table if not exists public.feature_votes (
  user_id    uuid not null references public.profiles(id)         on delete cascade,
  request_id uuid not null references public.feature_requests(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, request_id)
);
-- Hot path for the vote-count aggregate.
create index if not exists feature_votes_request_idx
  on public.feature_votes (request_id);

-- ── RLS ───────────────────────────────────────────────────────────────────────
-- feature_requests : any signed-in user may read the board + insert a suggestion
--                    (the Pro-only perk is the client gate, above).
-- feature_votes    : strictly owner-scoped, so who-voted-for-what stays private
--                    and a user can only add/remove their OWN vote.
alter table public.feature_requests enable row level security;
alter table public.feature_votes    enable row level security;

drop policy if exists "feature_requests readable" on public.feature_requests;
create policy "feature_requests readable" on public.feature_requests
  for select to authenticated using (true);

drop policy if exists "feature_requests insertable" on public.feature_requests;
create policy "feature_requests insertable" on public.feature_requests
  for insert to authenticated with check (true);

drop policy if exists "feature_votes owner" on public.feature_votes;
create policy "feature_votes owner" on public.feature_votes
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── get_feature_requests() — board + ACCURATE counts + caller's has_voted ──────
-- SECURITY DEFINER so count() aggregates EVERY user's votes (owner-scoped RLS
-- would otherwise let each caller see only their own row, undercounting to ≤1).
-- It returns aggregate counts only — never voter identities — so privacy holds.
-- has_voted is the calling user's own flag: auth.uid() reads the request JWT
-- claim, which stays the caller's even inside a definer function. One grouped
-- aggregate join → no N+1.
create or replace function public.get_feature_requests()
returns table (
  id          uuid,
  title       text,
  description text,
  status      text,
  created_at  timestamptz,
  vote_count  int,
  has_voted   boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.title,
    r.description,
    r.status,
    r.created_at,
    coalesce(vc.cnt, 0)::int as vote_count,
    exists (
      select 1
      from public.feature_votes v
      where v.request_id = r.id
        and v.user_id = auth.uid()
    ) as has_voted
  from public.feature_requests r
  left join (
    select request_id, count(*) as cnt
    from public.feature_votes
    group by request_id
  ) vc on vc.request_id = r.id
  where r.status <> 'closed'
  order by vote_count desc, r.created_at desc;
$$;

-- Only signed-in users may call it (it leaks nothing beyond the board itself).
revoke all on function public.get_feature_requests() from public;
grant execute on function public.get_feature_requests() to authenticated;

-- ── Starter content — so the board isn't empty on first open ──────────────────
-- Fixed ids + ON CONFLICT DO NOTHING keep this idempotent and non-destructive
-- (re-running never duplicates or clobbers edits made later in the dashboard).
insert into public.feature_requests (id, title, description) values
  ('f0000000-0000-4000-8000-000000000001',
   'Offline practice mode',
   'Download tests and practise without an internet connection.'),
  ('f0000000-0000-4000-8000-000000000002',
   'Previous-year question papers',
   'Full PYQ sets for JEE/NEET, browsable by year and subject.'),
  ('f0000000-0000-4000-8000-000000000003',
   'Dark mode',
   'A dark theme for late-night study sessions.'),
  ('f0000000-0000-4000-8000-000000000004',
   'Custom mock-test builder',
   'Pick the chapters, question count and timing for your own mock.'),
  ('f0000000-0000-4000-8000-000000000005',
   'Downloadable formula sheets (PDF)',
   'Export curated per-chapter formula sheets to revise offline.')
on conflict (id) do nothing;
