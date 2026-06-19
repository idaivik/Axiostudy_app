-- Server test for the feature-voting board (BILLING_BUCKET2_BUILD_PROMPT.md §5).
--
-- Proves:
--   • the (user, request) PK makes a repeat vote idempotent (no double-count);
--   • get_feature_requests() returns ACCURATE counts (aggregates ALL voters via
--     SECURITY DEFINER) and the CALLER's own has_voted (via auth.uid());
--   • feature_votes RLS isolates voters — a user reads only their OWN votes;
--   • is_pro_active() (the server-side Pro gate on submit/vote) mirrors
--     hasActiveAccess + Pro tier — pro+active ✓, basic ✗, lapsed-pro ✗.
--
-- PREREQUISITE: the migration must be APPLIED first, and the Supabase roles
-- (authenticated) + their default grants must exist (true on any Supabase DB):
--   supabase db push           # or apply_migration via MCP
-- Then run:
--   psql "$DATABASE_URL" -f supabase/tests/feature_voting_test.sql
--
-- Non-destructive: everything runs inside a transaction that ROLLS BACK, so the
-- seeded rows never persist. Any failed assertion RAISEs and aborts. On success
-- it prints "feature_voting: ALL TESTS PASSED".

begin;

-- Fixed test users + requests (cascade-cleaned by the rollback).
insert into public.profiles (id, email, name, subscription_tier, subscription_status, subscription_expiry, created_at)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a@test', 'A', 'pro',   'active',    null,                   now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@test', 'B', 'pro',   'active',    null,                   now()),
  -- C = Basic (active): not entitled to the Pro perk.
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'c@test', 'C', 'basic', 'active',    null,                   now()),
  -- D = Pro but lapsed (cancelled, paid period already elapsed): no access.
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'd@test', 'D', 'pro',   'cancelled', now() - interval '1 day', now())
on conflict (id) do update
  set subscription_tier = excluded.subscription_tier,
      subscription_status = excluded.subscription_status,
      subscription_expiry = excluded.subscription_expiry;

insert into public.feature_requests (id, title)
values
  ('11111111-0000-0000-0000-000000000001', 'Offline mock tests'),
  ('11111111-0000-0000-0000-000000000002', 'Dark mode');

do $$
declare
  a   constant uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  b   constant uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  c   constant uuid := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  d   constant uuid := 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  rq1 constant uuid := '11111111-0000-0000-0000-000000000001';
  rq2 constant uuid := '11111111-0000-0000-0000-000000000002';
  n   int;
  r   record;
begin
  -- ── Server-side Pro gate: is_pro_active mirrors hasActiveAccess + Pro tier ──
  if not public.is_pro_active(a) then
    raise exception 'A (pro+active) should be pro_active';
  end if;
  if public.is_pro_active(c) then
    raise exception 'C (basic) must NOT be pro_active';
  end if;
  if public.is_pro_active(d) then
    raise exception 'D (lapsed pro, expiry in the past) must NOT be pro_active';
  end if;

  -- ── Votes (as table owner — RLS bypassed for the seed) ──
  -- A votes rq1 + rq2; B votes rq1.
  insert into public.feature_votes (user_id, request_id) values
    (a, rq1), (a, rq2), (b, rq1);

  -- ── Idempotency: a repeat vote is a no-op (PK), not a double-count ──
  insert into public.feature_votes (user_id, request_id)
    values (a, rq1)
  on conflict (user_id, request_id) do nothing;

  select count(*) into n from public.feature_votes where request_id = rq1;
  if n <> 2 then
    raise exception 'rq1 should have exactly 2 votes after a repeat vote, got %', n;
  end if;

  -- ── get_feature_requests() counts (caller = A) ──
  perform set_config('request.jwt.claims',
    json_build_object('sub', a::text, 'role', 'authenticated')::text, true);

  for r in select * from public.get_feature_requests() loop
    if r.id = rq1 then
      if r.vote_count <> 2 then raise exception 'rq1 count should be 2, got %', r.vote_count; end if;
      if not r.has_voted then raise exception 'A should have voted rq1'; end if;
    elsif r.id = rq2 then
      if r.vote_count <> 1 then raise exception 'rq2 count should be 1, got %', r.vote_count; end if;
      if not r.has_voted then raise exception 'A should have voted rq2'; end if;
    end if;
  end loop;

  -- has_voted is per-caller: B did NOT vote rq2.
  perform set_config('request.jwt.claims',
    json_build_object('sub', b::text, 'role', 'authenticated')::text, true);
  select has_voted into n from public.get_feature_requests() where id = rq2;
  if n is not null and n::boolean then
    raise exception 'B must not show has_voted for rq2';
  end if;

  -- ── RLS isolation: under the authenticated role, a user sees only own votes ──
  -- As A → 2 own votes.
  perform set_config('request.jwt.claims',
    json_build_object('sub', a::text, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into n from public.feature_votes;
  if n <> 2 then raise exception 'A should see only its 2 votes under RLS, got %', n; end if;

  -- As B → 1 own vote (cannot see A's).
  perform set_config('request.jwt.claims',
    json_build_object('sub', b::text, 'role', 'authenticated')::text, true);
  select count(*) into n from public.feature_votes;
  if n <> 1 then raise exception 'B should see only its 1 vote under RLS, got %', n; end if;

  -- Restore the superuser role for the rollback.
  perform set_config('role', 'none', true);

  raise notice 'feature_voting: ALL TESTS PASSED';
end $$;

rollback;
