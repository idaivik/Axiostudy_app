-- Feature 3 — AI analysis narrative (BILLING_BUCKET1_BUILD_PROMPT.md §5), Pro.
--
-- A 2–3 sentence "AI coach" paragraph generated once per attempt from the
-- analytics we ALREADY compute (no new facts; cheap model — §2.1). Cached on the
-- attempt's analytics row so re-opening the result never spends a second meter
-- (meter: ai_analysis_narrative, Pro 60 — seeded in 20260617120000_usage_meters).
--
-- ADDITIVE ONLY. `attempt_analytics` is a pre-existing live table; these two
-- columns are nullable so historical rows are untouched. Idempotent.

alter table public.attempt_analytics
  add column if not exists ai_narrative    text,
  add column if not exists ai_narrative_at timestamptz;

comment on column public.attempt_analytics.ai_narrative is
  'Cached cheap-model coach paragraph for this attempt (Feature 3). Generated '
  'once; re-opening the result reads this instead of re-billing the meter.';
comment on column public.attempt_analytics.ai_narrative_at is
  'When ai_narrative was generated (null = not generated yet).';
