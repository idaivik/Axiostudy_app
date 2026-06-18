-- Question-pool poisoning guard (BILLING_PRICING_AND_TIERS_PLAN.md §5.3, §11, §9 step 7).
--
-- The `questions` table already IS the shared pool keyed by
-- (subject, chapter, topic, difficulty): one paid generation serves every
-- level-matched student, so practice/mock assembly reads bank+pool first and the
-- 600/mo cap only meters genuinely novel generation (see generate-questions).
--
-- The risk that creates: a wrong AI-generated question cached into the pool
-- serves hundreds. This adds an explicit report → quarantine path so a flagged
-- question is pulled OUT of the active pool before reuse can spread it.
-- `questions.status` is plain text (active|probation|retired); 'quarantined' is
-- a new value that pool reads (status='active') exclude automatically.

create table if not exists public.question_reports (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  question_id text not null references public.questions(id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now(),
  primary key (user_id, question_id)   -- one report per user per question (dedup)
);

create index if not exists question_reports_qid_idx
  on public.question_reports (question_id);

comment on table public.question_reports is
  'Student reports of bad pooled questions. report_question() quarantines a '
  'question once distinct reporters cross the threshold.';

-- Record a report (idempotent per user) and quarantine the question once it has
-- enough distinct reporters. Mirrors the auto-retire/promote logic in
-- 20260613130000_question_lifecycle.sql (usage-feedback-driven, no second LLM).
create or replace function public.report_question(
  p_user   uuid,
  p_qid    text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count       int;
  v_quarantined boolean := false;
  -- distinct reporters needed before a question leaves the active pool.
  c_threshold   constant int := 3;
begin
  insert into public.question_reports (user_id, question_id, reason)
  values (p_user, p_qid, p_reason)
  on conflict (user_id, question_id) do update set reason = excluded.reason;

  select count(*) into v_count
    from public.question_reports where question_id = p_qid;

  if v_count >= c_threshold then
    update public.questions
       set status = 'quarantined'
     where id = p_qid and status in ('active', 'probation')
     returning true into v_quarantined;
  end if;

  return jsonb_build_object(
    'ok', true, 'reports', v_count, 'quarantined', coalesce(v_quarantined, false));
end;
$$;

grant execute on function public.report_question(uuid, text, text) to authenticated, service_role;
