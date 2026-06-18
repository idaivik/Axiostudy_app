-- Feature 2 — Templated question breakdown (BILLING_BUCKET1_BUILD_PROMPT.md §4),
-- Basic (Pro via advancedBreakdown). NO AI — ₹0 to run; the meter
-- (question_breakdown, Basic 40 / Pro 200) is positioning, seeded in
-- 20260617120000_usage_meters.
--
-- Adds a per-question explanation IMAGE (a JPEG diagram + worked solution, needed
-- for Physics/Chem), a public Storage bucket to hold it, and a SAFE client-side
-- metering wrapper. ADDITIVE / idempotent.

-- ── 1. Per-question explanation image (text `explanation` already exists) ──────
-- The authored JPEG diagram. Nullable; coverage starts at ~0 and is backfilled by
-- the content track (§9). The client degrades to text-only when null.
alter table public.questions
  add column if not exists explanation_image_url text;

comment on column public.questions.explanation_image_url is
  'Public URL of the authored explanation JPEG (diagram + worked solution) for '
  'this question (Feature 2). Null = no image yet → client shows text-only.';

-- ── 2. Storage bucket for the explanation JPEGs (public-read) ─────────────────
-- Public-read: the images are low-sensitivity study aids and the breakdown is
-- already gated by tier + the question_breakdown meter. Public buckets are
-- CDN-cacheable. Authoring (writes) is service-role / dashboard only — no
-- anon/authenticated insert policy is granted below.
insert into storage.buckets (id, name, public)
values ('question-explanations', 'question-explanations', true)
on conflict (id) do update set public = excluded.public;

-- ── 3. consume_meter_self — SAFE client-side metering ─────────────────────────
-- consume_meter(p_user, …) takes the user as a PARAM (server-role callers pass
-- it). A client must never be able to meter another account, so this wrapper
-- pins the user to auth.uid(). Use it for the no-AI client-metered surfaces
-- (question_breakdown); AI surfaces still meter server-side in their edge fn.
create or replace function public.consume_meter_self(
  p_meter  text,
  p_amount int default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'no_entitlement', 'plan', 'free');
  end if;
  return public.consume_meter(v_uid, p_meter, p_amount);
end;
$$;

grant execute on function public.consume_meter_self(text, int) to authenticated;
