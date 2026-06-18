-- Feature 1 — daily schedule for the send-reminders engine (§3 "One scheduler").
--
-- Enables the extensions. The actual cron.schedule call carries the project URL
-- + the REMINDERS_CRON_SECRET, which are environment-specific and secret-bearing,
-- so it is NOT hardcoded in a committed migration — run the filled-in command
-- from supabase/functions/REMINDERS_SETUP.md once, after deploying the function.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ── Template (run from the SQL editor with your values; see REMINDERS_SETUP.md) ─
-- Runs once daily at 13:30 UTC (~7pm IST — a sensible study-evening slot; the
-- per-user quiet-hours + max_per_day guards in the engine do the fine-grained
-- gating). Re-running cron.schedule with the same name replaces the job.
--
--   select cron.schedule(
--     'send-reminders-daily',
--     '30 13 * * *',
--     $$
--       select net.http_post(
--         url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-reminders',
--         headers := jsonb_build_object(
--                      'Content-Type', 'application/json',
--                      'x-reminders-secret', '<REMINDERS_CRON_SECRET>'
--                    ),
--         body    := '{}'::jsonb
--       );
--     $$
--   );
--
-- To stop it:  select cron.unschedule('send-reminders-daily');
