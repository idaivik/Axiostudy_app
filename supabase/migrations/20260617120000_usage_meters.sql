-- Billing keystone (BILLING_PRICING_AND_TIERS_PLAN.md §5.5, §9 step 5).
--
-- Replaces the single credit pool (20260613110000_question_generation.sql) with
-- PER-METER buckets. The old design treated pro/premium/professional as
-- effectively UNLIMITED (`remaining: null`, no cap) — the single most expensive
-- bug in the billing model (an uncapped Pro user costs ~₹320/mo in AI vs the
-- ~₹65 budgeted). This makes every AI cost surface a real, server-enforced cap.
--
-- Two paid tiers only: `basic` / `pro`. `free` is the internal "no active
-- entitlement → paywall" sentinel and blocks every meter (no_entitlement).
--
-- Reason codes returned by consume_meter (the edge functions branch on these):
--   ok:true                     → allowed; `remaining` left this cycle
--   reason:'no_entitlement'     → free / lapsed, OR tier lacks this meter (fail-closed)
--   reason:'trial_ai_locked'    → inside the 7-day trial; every ai_* meter is hard-locked
--   reason:'cap_reached'        → monthly cap hit (soft for ai_questions → bank fallback)

-- ── Config: tier → meter → monthly cap (seeded from §5.4) ───────────────────
-- A (plan, meter_key) row that DOES NOT EXIST means "tier not entitled to this
-- meter" → consume_meter fails closed with no_entitlement. Pro meters that
-- "draw from ai_questions" (ai_small_test, ai_practice) intentionally have no
-- pro row — those surfaces meter ai_questions directly.
create table if not exists public.meter_limits (
  plan        text not null,                 -- 'basic' | 'pro'
  meter_key   text not null,
  limit_total int  not null,
  primary key (plan, meter_key)
);

comment on table public.meter_limits is
  'Tier→meter→monthly cap config (BILLING_PRICING_AND_TIERS_PLAN.md §5.4). '
  'A missing (plan, meter_key) row = tier not entitled to that meter.';

insert into public.meter_limits (plan, meter_key, limit_total) values
  -- ai_questions: net-new generation (practice + mock gap-fill). Pro = 600 SOFT
  -- (the edge fn falls back to bank, not a wall). Basic = 100/mo ≈ 4 weekly
  -- small tests (15Q) + 1 practice (45Q); tune this knob to taste.
  ('basic', 'ai_questions',            100),
  ('pro',   'ai_questions',            600),
  ('basic', 'ai_full_mock',              1),
  ('pro',   'ai_full_mock',              8),
  ('basic', 'ai_roadmap',                2),
  ('pro',   'ai_roadmap',                8),
  ('basic', 'question_breakdown',       40),
  ('pro',   'question_breakdown',      200),
  ('pro',   'ai_analysis_narrative',    60),
  ('pro',   'ai_note',                  60),
  ('pro',   'formula_sheet',            20),
  ('basic', 'ai_small_test',             4),
  ('basic', 'ai_practice',               1)
on conflict (plan, meter_key) do update set limit_total = excluded.limit_total;

-- ── Per-user usage counters (one row per user × meter) ──────────────────────
create table if not exists public.usage_meters (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  meter_key   text not null,
  used        int  not null default 0,
  limit_total int  not null,            -- snapshot of the cap; refreshed on reset
  resets_at   timestamptz,
  primary key (user_id, meter_key)
);

comment on table public.usage_meters is
  'Per-user × per-meter usage. Rows are lazily seeded by consume_meter from '
  'meter_limits and reset monthly via resets_at.';

-- ── consume_meter: the one atomic, race-safe gate every paid AI surface calls ─
create or replace function public.consume_meter(
  p_user  uuid,
  p_meter text,
  p_amount int default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier    text;
  v_status  text;
  v_expiry  timestamptz;
  v_plan    text;                 -- effective plan: 'basic' | 'pro' | 'free'
  v_amount  int := greatest(1, coalesce(p_amount, 1));
  v_limit   int;
  v_used    int;
  v_resets  timestamptz;
  v_is_ai   boolean := left(p_meter, 3) = 'ai_';
begin
  -- 1. Effective entitlement (mirrors UserModel.hasActiveAccess).
  select subscription_tier, subscription_status, subscription_expiry
    into v_tier, v_status, v_expiry
    from public.profiles where id = p_user;

  if v_status in ('trialing', 'active')
     or (v_status in ('cancelled', 'past_due')
         and v_expiry is not null and v_expiry > now()) then
    -- Normalize tier (legacy premium/professional rows → consolidated pro).
    v_plan := case
                when v_tier in ('pro', 'premium', 'professional') then 'pro'
                when v_tier = 'basic' then 'basic'
                else 'free'
              end;
  else
    v_plan := 'free';
  end if;

  -- 2. No entitlement → paywall.
  if v_plan = 'free' then
    return jsonb_build_object('ok', false, 'reason', 'no_entitlement', 'plan', 'free');
  end if;

  -- 3. Trial AI hard-lock: inside the 7-day trial, every ai_* meter is locked.
  --    Keyed on status='trialing' so it applies to BOTH monthly and annual trials.
  if v_status = 'trialing' and v_is_ai then
    return jsonb_build_object('ok', false, 'reason', 'trial_ai_locked', 'plan', v_plan);
  end if;

  -- 4. Cap config. A missing row = this tier isn't entitled to this meter.
  select limit_total into v_limit
    from public.meter_limits where plan = v_plan and meter_key = p_meter;
  if v_limit is null then
    return jsonb_build_object('ok', false, 'reason', 'no_entitlement', 'plan', v_plan);
  end if;

  -- 5. Lock (or lazily seed) the user's meter row.
  select used, resets_at into v_used, v_resets
    from public.usage_meters
    where user_id = p_user and meter_key = p_meter
    for update;
  if not found then
    insert into public.usage_meters (user_id, meter_key, used, limit_total, resets_at)
    values (p_user, p_meter, 0, v_limit,
            date_trunc('month', now()) + interval '1 month')
    on conflict (user_id, meter_key) do nothing;
    select used, resets_at into v_used, v_resets
      from public.usage_meters
      where user_id = p_user and meter_key = p_meter
      for update;
  end if;

  -- 6. Monthly reset — also refreshes the snapshotted cap from config.
  if v_resets is not null and v_resets < now() then
    update public.usage_meters
       set used = 0,
           limit_total = v_limit,
           resets_at = date_trunc('month', now()) + interval '1 month'
     where user_id = p_user and meter_key = p_meter
     returning used into v_used;
  end if;

  -- 7. Enforce the cap (soft and hard share this path; the edge fn decides what
  --    cap_reached means per meter — ai_questions → bank fallback, others → wall).
  if v_used + v_amount > v_limit then
    return jsonb_build_object('ok', false, 'reason', 'cap_reached',
                              'plan', v_plan, 'remaining', greatest(0, v_limit - v_used));
  end if;

  -- 8. Atomic increment.
  update public.usage_meters
     set used = used + v_amount
   where user_id = p_user and meter_key = p_meter
   returning used into v_used;

  return jsonb_build_object('ok', true, 'plan', v_plan, 'remaining', v_limit - v_used);
end;
$$;

-- ── refund_meter: give back credits a generation didn't actually spend ──────
-- Per-amount so the edge fn refunds only the questions it failed to produce
-- (mirrors the old refund_generation_credit pattern).
create or replace function public.refund_meter(
  p_user  uuid,
  p_meter text,
  p_amount int default 1
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.usage_meters
     set used = greatest(0, used - greatest(1, coalesce(p_amount, 1)))
   where user_id = p_user and meter_key = p_meter;
end;
$$;

grant execute on function public.consume_meter(uuid, text, int) to authenticated, service_role;
grant execute on function public.refund_meter(uuid, text, int)  to authenticated, service_role;

-- ── Retire the single-pool RPCs (replaced by the per-meter design above) ────
-- DEFERRED: the live `generate-questions` edge fn (v8) STILL calls
-- consume_generation_credit / refund_generation_credit. Dropping them here would
-- break question generation immediately. Re-enable these drops only in a
-- follow-up migration that ships ALONGSIDE a generate-questions redeploy moving
-- it onto consume_meter('ai_questions'). Until then the two pools coexist (the
-- per-meter design gates the new AI surfaces; the legacy pool gates generation).
-- drop function if exists public.consume_generation_credit(uuid);
-- drop function if exists public.refund_generation_credit(uuid);
