-- AI Weakness-Detection Engine — Phase 2: probation → active/retired lifecycle.
--
-- Usage-feedback-only vetting (no second LLM self-check). Generated questions
-- enter as `probation`; these functions move them to `active` or `retired` from
-- real usage signal (served accuracy + explicit thumbs). compute-analytics calls
-- record_question_served() for every AI question answered in a submitted test.

-- Served-accuracy signal (called server-side from compute-analytics).
create or replace function public.record_question_served(p_qid text, p_correct boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.questions
     set times_served  = times_served + 1,
         times_correct = times_correct + (case when p_correct then 1 else 0 end)
   where id = p_qid;

  -- Auto-retire a probation question that's clearly broken (served enough,
  -- nobody gets it right → likely wrong key / impossible).
  update public.questions
     set status = 'retired'
   where id = p_qid and status = 'probation'
     and times_served >= 8 and times_correct = 0;

  -- Auto-promote a probation question with a healthy, non-degenerate accuracy.
  update public.questions
     set status = 'active', is_verified = true
   where id = p_qid and status = 'probation'
     and times_served >= 8
     and (times_correct::numeric / nullif(times_served, 0)) between 0.2 and 0.95;
end; $$;

-- Explicit thumbs up/down (called from the client when a student rates a question).
create or replace function public.record_question_feedback(p_qid text, p_up boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.questions
     set thumbs_up   = thumbs_up   + (case when p_up then 1 else 0 end),
         thumbs_down = thumbs_down + (case when p_up then 0 else 1 end)
   where id = p_qid;

  -- Strong positive signal promotes; strong negative retires (probation only).
  update public.questions
     set status = 'active', is_verified = true
   where id = p_qid and status = 'probation'
     and thumbs_up >= 3 and thumbs_up >= thumbs_down * 2;

  update public.questions
     set status = 'retired'
   where id = p_qid and status = 'probation'
     and thumbs_down >= 3 and thumbs_down > thumbs_up;
end; $$;

grant execute on function public.record_question_served(text, boolean)   to authenticated, service_role;
grant execute on function public.record_question_feedback(text, boolean)  to authenticated, service_role;
