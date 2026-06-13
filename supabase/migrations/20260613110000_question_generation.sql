-- AI Weakness-Detection Engine — Phase 2: question-generation credit metering.
--
-- One atomic, race-safe RPC the `generate-questions` edge function calls before
-- spending an LLM generation. Tiers (per docs/features/weakness_detection_engine.md):
--   free / lapsed → no generation
--   basic (₹199)  → capped per billing cycle via user_credits.credits_total
--   pro / premium / professional (+ trial) → effectively unlimited (still metered)
--
-- `user_credits` already has plan + credits_total/used + monthly resets_at; this
-- only adds the function + a refund helper. Additive; touches no data.

create or replace function public.consume_generation_credit(p_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rec public.user_credits%rowtype;
  v_remaining int;
begin
  -- Lock (or lazily create) the caller's credit row.
  select * into rec from public.user_credits where user_id = p_user for update;
  if not found then
    insert into public.user_credits (user_id) values (p_user)
      on conflict (user_id) do nothing;
    select * into rec from public.user_credits where user_id = p_user for update;
  end if;

  -- Roll over the monthly cap when the billing cycle has elapsed.
  if rec.resets_at is not null and rec.resets_at < now() then
    update public.user_credits
       set credits_used = 0,
           resets_at = date_trunc('month', now()) + interval '1 month'
     where user_id = p_user
     returning * into rec;
  end if;

  if rec.plan = 'free' then
    return jsonb_build_object('ok', false, 'reason', 'free_plan_no_generation', 'plan', rec.plan);
  end if;

  -- Unlimited tiers: meter usage but never block.
  if rec.plan in ('pro', 'premium', 'professional') then
    update public.user_credits set credits_used = credits_used + 1 where user_id = p_user;
    return jsonb_build_object('ok', true, 'plan', rec.plan, 'remaining', null);
  end if;

  -- Capped tiers (basic and anything else paid): enforce credits_total.
  if rec.credits_used >= rec.credits_total then
    return jsonb_build_object('ok', false, 'reason', 'monthly_cap_reached', 'plan', rec.plan,
                              'credits_total', rec.credits_total, 'credits_used', rec.credits_used);
  end if;
  update public.user_credits set credits_used = credits_used + 1 where user_id = p_user
    returning credits_total - credits_used into v_remaining;
  return jsonb_build_object('ok', true, 'plan', rec.plan, 'remaining', v_remaining);
end;
$$;

-- Refund a consumed credit when a generation produced nothing usable.
create or replace function public.refund_generation_credit(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.user_credits
     set credits_used = greatest(0, credits_used - 1)
   where user_id = p_user;
end;
$$;

grant execute on function public.consume_generation_credit(uuid) to authenticated, service_role;
grant execute on function public.refund_generation_credit(uuid)  to authenticated, service_role;
