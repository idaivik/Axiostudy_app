-- Bucket 3A · Feature 1 — Spaced-repetition revision plan (Pro), the VIEWABLE
-- surface + review loop over the spaced schedule (BILLING_BUCKET3A_BUILD_PROMPT.md §1).
--
-- This is NOT a second scheduler. The push engine (send-reminders) already widens
-- `topic_review_state` as it nudges; this migration only adds the ONE thing the
-- viewable surface needs that the engine didn't: a client-callable "mark reviewed"
-- that advances the SM-2 curve. The table itself (interval_days, ease, reps,
-- last_reviewed_at, next_due_at) already exists (20260618160000_reminder_engine.sql)
-- and is RLS read-only to clients, so the advance MUST go through a SECURITY
-- DEFINER RPC keyed on auth.uid() (no client write policy is granted).
--
-- DETERMINISTIC / ₹0 — no meter (the spec keeps Feature 1 unmetered). The SM-2
-- math here MIRRORS the pure Dart unit `SpacedRepetition.advance`
-- (lib/features/revision/domain/spaced_repetition.dart) — keep the two in lockstep
-- (same precedent as send-reminders mirroring consume_meter's plan logic).
--
-- ADDITIVE / idempotent.

-- ── mark_topic_reviewed — advance (or seed) one topic's SM-2 curve ─────────────
-- p_quality is the student's self-rated recall 0–5 (the screen sends 5 for
-- "Got it", 2 for "Still shaky"). Textbook SM-2: q<3 lapses (reps→0, interval→1);
-- q>=3 advances (I1=1, I2=6, then round(prev*ease)). Ease floored at 1.3.
create or replace function public.mark_topic_reviewed(
  p_topic_id text,
  p_quality  int default 5
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user    uuid := auth.uid();
  v_q       int  := greatest(0, least(5, coalesce(p_quality, 5)));
  v_interval int;
  v_ease    numeric;
  v_reps    int;
  v_next    timestamptz;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'reason', 'unauthorized');
  end if;
  if coalesce(trim(p_topic_id), '') = '' then
    return jsonb_build_object('ok', false, 'reason', 'topic_required');
  end if;

  -- Current curve (defaults match a never-reviewed item).
  select interval_days, ease, reps
    into v_interval, v_ease, v_reps
    from public.topic_review_state
    where user_id = v_user and topic_id = p_topic_id
    for update;
  if not found then
    v_interval := 1; v_ease := 2.5; v_reps := 0;
  end if;

  -- SM-2 ease update (same formula whether recalled or lapsed).
  v_ease := greatest(1.3, v_ease + (0.1 - (5 - v_q) * (0.08 + (5 - v_q) * 0.02)));

  if v_q < 3 then
    -- Lapse: restart the repetition, shortest interval.
    v_reps := 0;
    v_interval := 1;
  else
    v_reps := v_reps + 1;
    v_interval := case
                    when v_reps = 1 then 1
                    when v_reps = 2 then 6
                    else greatest(1, round(v_interval * v_ease))::int
                  end;
  end if;

  v_next := now() + make_interval(days => v_interval);

  insert into public.topic_review_state
    (user_id, topic_id, interval_days, ease, reps, last_reviewed_at, next_due_at)
  values
    (v_user, p_topic_id, v_interval, v_ease, v_reps, now(), v_next)
  on conflict (user_id, topic_id) do update
    set interval_days    = excluded.interval_days,
        ease             = excluded.ease,
        reps             = excluded.reps,
        last_reviewed_at = excluded.last_reviewed_at,
        next_due_at      = excluded.next_due_at;

  return jsonb_build_object(
    'ok', true,
    'interval_days', v_interval,
    'ease', v_ease,
    'reps', v_reps,
    'next_due_at', v_next
  );
end;
$$;

grant execute on function public.mark_topic_reviewed(text, int) to authenticated, service_role;
