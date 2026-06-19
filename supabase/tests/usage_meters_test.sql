-- Server test for the metering keystone (BILLING_PRICING_AND_TIERS_PLAN.md §9 step 10).
--
-- Proves the four reason branches of consume_meter + refund_meter:
--   pro    → ai_questions capped at 600 (SOFT: cap_reached, remaining 0 — NOT unlimited)
--   basic  → ai_questions capped at 100
--   trial  → every ai_* meter returns trial_ai_locked
--   free   → no_entitlement
--
-- PREREQUISITE: the migrations must be APPLIED first (pending approval — the live
-- DB has neither 20260614140000_native_billing nor 20260617120000_usage_meters):
--   supabase db push           # or apply_migration via MCP
-- Then run, e.g.:
--   psql "$DATABASE_URL" -f supabase/tests/usage_meters_test.sql
--
-- Non-destructive: everything runs inside a transaction that ROLLS BACK at the
-- end, so the seeded test profiles + meters never persist. Any failed assertion
-- RAISEs and aborts. On success it prints "usage_meters: ALL TESTS PASSED".

begin;

-- Fixed test users (cascade-cleaned by the rollback).
insert into public.profiles (id, email, name, subscription_tier, subscription_status, created_at)
values
  ('11111111-1111-1111-1111-111111111111', 'pro@test',   'Pro',   'pro',   'active',   now()),
  ('22222222-2222-2222-2222-222222222222', 'basic@test', 'Basic', 'basic', 'active',   now()),
  ('33333333-3333-3333-3333-333333333333', 'trial@test', 'Trial', 'pro',   'trialing', now()),
  ('44444444-4444-4444-4444-444444444444', 'none@test',  'None',  'free',  'none',     now())
on conflict (id) do update
  set subscription_tier = excluded.subscription_tier,
      subscription_status = excluded.subscription_status;

do $$
declare
  pro   constant uuid := '11111111-1111-1111-1111-111111111111';
  basic constant uuid := '22222222-2222-2222-2222-222222222222';
  trial constant uuid := '33333333-3333-3333-3333-333333333333';
  none  constant uuid := '44444444-4444-4444-4444-444444444444';
  r jsonb;
  i int;
begin
  -- ── Pro: 600 ok, 601st soft-capped ──
  for i in 1..600 loop
    r := public.consume_meter(pro, 'ai_questions', 1);
    if not (r->>'ok')::boolean then
      raise exception 'pro consume #% should succeed, got %', i, r;
    end if;
  end loop;
  if (r->>'remaining')::int <> 0 then
    raise exception 'pro remaining after 600 should be 0, got %', r;
  end if;

  r := public.consume_meter(pro, 'ai_questions', 1);
  if (r->>'ok')::boolean then raise exception 'pro 601 should fail, got %', r; end if;
  if r->>'reason' <> 'cap_reached' then raise exception 'pro 601 reason should be cap_reached, got %', r; end if;
  if r->>'remaining' is null then raise exception 'pro cap_reached must NOT be unlimited (remaining null), got %', r; end if;
  if (r->>'remaining')::int <> 0 then raise exception 'pro cap_reached remaining should be 0, got %', r; end if;

  -- refund_meter gives back room for exactly one more.
  perform public.refund_meter(pro, 'ai_questions', 1);
  r := public.consume_meter(pro, 'ai_questions', 1);
  if not (r->>'ok')::boolean then raise exception 'pro should succeed after refund, got %', r; end if;

  -- ── Basic: capped at 100 ──
  for i in 1..100 loop
    r := public.consume_meter(basic, 'ai_questions', 1);
    if not (r->>'ok')::boolean then
      raise exception 'basic consume #% should succeed, got %', i, r;
    end if;
  end loop;
  r := public.consume_meter(basic, 'ai_questions', 1);
  if (r->>'ok')::boolean then raise exception 'basic 101 should fail, got %', r; end if;
  if r->>'reason' <> 'cap_reached' then raise exception 'basic 101 reason should be cap_reached, got %', r; end if;

  -- Basic is NOT entitled to a Pro-only meter → no_entitlement (fail-closed).
  r := public.consume_meter(basic, 'ai_analysis_narrative', 1);
  if (r->>'ok')::boolean then raise exception 'basic narrative should fail, got %', r; end if;
  if r->>'reason' <> 'no_entitlement' then raise exception 'basic narrative reason should be no_entitlement, got %', r; end if;

  -- ── Trial: every ai_* meter hard-locked ──
  r := public.consume_meter(trial, 'ai_questions', 1);
  if (r->>'ok')::boolean then raise exception 'trial ai_questions should fail, got %', r; end if;
  if r->>'reason' <> 'trial_ai_locked' then raise exception 'trial reason should be trial_ai_locked, got %', r; end if;
  -- Non-ai meter during trial is NOT AI-locked (it hits the normal cap path).
  r := public.consume_meter(trial, 'question_breakdown', 1);
  if r->>'reason' = 'trial_ai_locked' then raise exception 'non-ai meter should not be trial-locked, got %', r; end if;

  -- ── Free / lapsed: no entitlement ──
  r := public.consume_meter(none, 'ai_questions', 1);
  if (r->>'ok')::boolean then raise exception 'free ai_questions should fail, got %', r; end if;
  if r->>'reason' <> 'no_entitlement' then raise exception 'free reason should be no_entitlement, got %', r; end if;

  -- ── Feature 3: ai_analysis_narrative (Pro 60) — BILLING_BUCKET1 §8 ──
  -- Pro: 60 ok, 61st soft-capped.
  for i in 1..60 loop
    r := public.consume_meter(pro, 'ai_analysis_narrative', 1);
    if not (r->>'ok')::boolean then
      raise exception 'pro narrative #% should succeed, got %', i, r;
    end if;
  end loop;
  if (r->>'remaining')::int <> 0 then
    raise exception 'pro narrative remaining after 60 should be 0, got %', r;
  end if;
  r := public.consume_meter(pro, 'ai_analysis_narrative', 1);
  if (r->>'ok')::boolean then raise exception 'pro narrative 61 should fail, got %', r; end if;
  if r->>'reason' <> 'cap_reached' then raise exception 'pro narrative 61 reason should be cap_reached, got %', r; end if;

  -- Trial: ai_analysis_narrative is an ai_ meter → hard-locked.
  r := public.consume_meter(trial, 'ai_analysis_narrative', 1);
  if (r->>'ok')::boolean then raise exception 'trial narrative should fail, got %', r; end if;
  if r->>'reason' <> 'trial_ai_locked' then raise exception 'trial narrative reason should be trial_ai_locked, got %', r; end if;

  -- (Basic→ai_analysis_narrative no_entitlement is already asserted above.)

  -- ── Feature 2: question_breakdown (Basic 40 / Pro 200) — BILLING_BUCKET1 §8 ──
  -- NOTE: 'trial' already consumed 1 question_breakdown above (non-ai meter is
  -- NOT trial-locked), but that's a different user from basic/pro below.
  for i in 1..40 loop
    r := public.consume_meter(basic, 'question_breakdown', 1);
    if not (r->>'ok')::boolean then
      raise exception 'basic breakdown #% should succeed, got %', i, r;
    end if;
  end loop;
  r := public.consume_meter(basic, 'question_breakdown', 1);
  if (r->>'ok')::boolean then raise exception 'basic breakdown 41 should fail, got %', r; end if;
  if r->>'reason' <> 'cap_reached' then raise exception 'basic breakdown 41 reason should be cap_reached, got %', r; end if;

  for i in 1..200 loop
    r := public.consume_meter(pro, 'question_breakdown', 1);
    if not (r->>'ok')::boolean then
      raise exception 'pro breakdown #% should succeed, got %', i, r;
    end if;
  end loop;
  r := public.consume_meter(pro, 'question_breakdown', 1);
  if (r->>'ok')::boolean then raise exception 'pro breakdown 201 should fail, got %', r; end if;
  if r->>'reason' <> 'cap_reached' then raise exception 'pro breakdown 201 reason should be cap_reached, got %', r; end if;

  -- ── Bucket 3A · Feature 2: ai_note (Pro 60) — BILLING_BUCKET3A §2 ──
  -- Pro: 60 ok, 61st soft-capped.
  for i in 1..60 loop
    r := public.consume_meter(pro, 'ai_note', 1);
    if not (r->>'ok')::boolean then
      raise exception 'pro ai_note #% should succeed, got %', i, r;
    end if;
  end loop;
  if (r->>'remaining')::int <> 0 then
    raise exception 'pro ai_note remaining after 60 should be 0, got %', r;
  end if;
  r := public.consume_meter(pro, 'ai_note', 1);
  if (r->>'ok')::boolean then raise exception 'pro ai_note 61 should fail, got %', r; end if;
  if r->>'reason' <> 'cap_reached' then raise exception 'pro ai_note 61 reason should be cap_reached, got %', r; end if;

  -- Trial: ai_note is an ai_ meter → hard-locked (NOTE the formula_sheet meter
  -- has NO ai_ prefix, so its trial lock is enforced in the edge function, not
  -- here — see generate-formula-sheet when Feature 3 lands).
  r := public.consume_meter(trial, 'ai_note', 1);
  if (r->>'ok')::boolean then raise exception 'trial ai_note should fail, got %', r; end if;
  if r->>'reason' <> 'trial_ai_locked' then raise exception 'trial ai_note reason should be trial_ai_locked, got %', r; end if;

  -- Basic: not entitled to a Pro-only meter → no_entitlement (fail-closed).
  r := public.consume_meter(basic, 'ai_note', 1);
  if (r->>'ok')::boolean then raise exception 'basic ai_note should fail, got %', r; end if;
  if r->>'reason' <> 'no_entitlement' then raise exception 'basic ai_note reason should be no_entitlement, got %', r; end if;

  -- Notes CACHING (second open spends no meter) is enforced in the generate-notes
  -- edge fn (it returns the stored study_notes row BEFORE consume_meter), so it
  -- can't be exercised from pure SQL — same as the narrative cache below.

  -- Narrative CACHING (second open spends no meter) is enforced in the
  -- analysis-narrative edge fn (it returns the cached attempt_analytics.ai_narrative
  -- BEFORE calling consume_meter), so it can't be exercised from pure SQL here —
  -- the meter never sees the second open. Covered by the edge fn's cache check.

  raise notice 'usage_meters: ALL TESTS PASSED';
end $$;

rollback;
