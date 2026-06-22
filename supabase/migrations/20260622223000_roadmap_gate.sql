-- Read-only gates for the customized-roadmap generation flow.
-- Neither function writes or spends an LLM — they only let the app decide what to
-- show BEFORE the (deferred) AI generation path exists:
--   1. roadmap_readiness()   — has the student practiced enough for a detailed plan?
--   2. meter_status(p_meter)  — peek a usage meter WITHOUT consuming it, for the
--      "X of Y generations left this month" counter shown before tapping Generate.
-- Both are SECURITY DEFINER but strictly scoped to auth.uid(), so a caller only
-- ever sees their own data.

-- ── 1. roadmap_readiness ──────────────────────────────────────────────────────
-- "Enough data" = >=10 passing (>60%) subtopic-practice attempts spanning >=3
-- distinct chapters. Mocks/adaptive sets (null subtopic_id) don't count. Also
-- projects a predicted-ready date from the last 14 days' practice rate so the UI
-- can tell the student roughly when to come back; the client caches this so it
-- isn't recomputed on every tap. No LLM involved — this runs today.
create or replace function public.roadmap_readiness()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_pass      int  := 0;   -- total passing practice attempts
  v_chapters  int  := 0;   -- distinct chapters among them
  v_recent    int  := 0;   -- passing attempts in the last 14 days
  v_need      int;
  v_rate      numeric;
  v_ready     boolean;
  v_predicted date := null;
  c_min_tests    constant int := 10;
  c_min_chapters constant int := 3;
begin
  if v_uid is null then
    return jsonb_build_object('ready', false, 'distinct_chapters', 0,
      'passing_tests', 0, 'min_tests', c_min_tests,
      'min_chapters', c_min_chapters, 'predicted_ready_date', null);
  end if;

  with passed as (
    select s.chapter_id, ta.created_at
    from public.test_attempts ta
    join public.subtopics s on s.id = ta.subtopic_id
    where ta.user_id = v_uid
      and ta.subtopic_id is not null
      and ta.status = 'completed'
      and ta.total_marks > 0
      and ta.score::numeric / ta.total_marks > 0.6
  )
  select count(*), count(distinct chapter_id),
         count(*) filter (where created_at > now() - interval '14 days')
    into v_pass, v_chapters, v_recent
    from passed;

  v_ready := v_pass >= c_min_tests and v_chapters >= c_min_chapters;

  -- Project a return date only when there's recent momentum to extrapolate from;
  -- otherwise leave it null and the UI shows a plain "keep practising".
  if not v_ready and v_recent > 0 then
    v_need := greatest(c_min_tests - v_pass, (c_min_chapters - v_chapters) * 3);
    if v_need > 0 then
      v_rate := v_recent / 14.0;                         -- passing tests per day
      v_predicted := current_date + least(ceil(v_need / v_rate)::int, 365);
    end if;
  end if;

  return jsonb_build_object(
    'ready', v_ready,
    'distinct_chapters', v_chapters,
    'passing_tests', v_pass,
    'min_tests', c_min_tests,
    'min_chapters', c_min_chapters,
    'predicted_ready_date', v_predicted
  );
end;
$$;

grant execute on function public.roadmap_readiness() to authenticated;

-- ── 2. meter_status ───────────────────────────────────────────────────────────
-- Read-only twin of consume_meter: same plan resolution + trial/cap rules, but it
-- never increments `used`. Returns plan/limit/used/remaining/resets_at so the
-- client can render the counter and reuse the existing MeterOutcome reason codes.
create or replace function public.meter_status(p_meter text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_tier   text;
  v_status text;
  v_expiry timestamptz;
  v_plan   text;
  v_limit  int;
  v_used   int := 0;
  v_resets timestamptz;
  v_is_ai  boolean := left(p_meter, 3) = 'ai_';
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'no_entitlement', 'plan', 'free');
  end if;

  select subscription_tier, subscription_status, subscription_expiry
    into v_tier, v_status, v_expiry
    from public.profiles where id = v_uid;

  if v_status in ('trialing', 'active')
     or (v_status in ('cancelled', 'past_due') and v_expiry is not null and v_expiry > now()) then
    v_plan := case
                when v_tier in ('pro', 'premium', 'professional') then 'pro'
                when v_tier = 'basic' then 'basic'
                else 'free'
              end;
  else
    v_plan := 'free';
  end if;

  if v_plan = 'free' then
    return jsonb_build_object('ok', false, 'reason', 'no_entitlement', 'plan', 'free');
  end if;

  select limit_total into v_limit
    from public.meter_limits where plan = v_plan and meter_key = p_meter;
  if v_limit is null then
    return jsonb_build_object('ok', false, 'reason', 'no_entitlement', 'plan', v_plan);
  end if;

  -- Current usage; an elapsed cycle reads as already reset (used 0) without writing.
  select used, resets_at into v_used, v_resets
    from public.usage_meters
    where user_id = v_uid and meter_key = p_meter;
  if not found or (v_resets is not null and v_resets < now()) then
    v_used := 0;
    v_resets := date_trunc('month', now()) + interval '1 month';
  end if;

  if v_status = 'trialing' and v_is_ai then
    return jsonb_build_object('ok', false, 'reason', 'trial_ai_locked', 'plan', v_plan,
      'limit', v_limit, 'used', v_used, 'remaining', greatest(0, v_limit - v_used),
      'resets_at', v_resets);
  end if;

  return jsonb_build_object(
    'ok', (v_limit - v_used) > 0,
    'reason', case when (v_limit - v_used) > 0 then null else 'cap_reached' end,
    'plan', v_plan,
    'limit', v_limit,
    'used', v_used,
    'remaining', greatest(0, v_limit - v_used),
    'resets_at', v_resets
  );
end;
$$;

grant execute on function public.meter_status(text) to authenticated;
