-- Cleanup: remove bounced / abandoned unconfirmed test accounts.
--
-- WHY: Supabase flagged a high bounce rate on this project's transactional
-- emails. Unconfirmed accounts (email_confirmed_at IS NULL) are the residue of
-- signups whose confirmation email was never acted on — typically junk/typo'd
-- test addresses that bounced. Removing them stops them from dragging the
-- bounce ratio and cleans up the user table before launch.
--
-- SAFETY: profiles.id -> auth.users(id) is ON DELETE CASCADE, and every other
-- user-scoped table cascades off profiles/auth.users, so deleting from
-- auth.users removes all dependent rows cleanly (no orphans).
--
-- HOW TO RUN: paste into the Supabase SQL Editor for project nxtfbyvacunsiytlsfkl.
-- Run STEP 1 and 2 first and eyeball the results. Only then run STEP 3.
-- This is a one-time maintenance script — do NOT add it to supabase/migrations.

-- Addresses to always keep, even if currently unconfirmed (edit as needed):
--   your own real test logins.
-- Used by the steps below via the keep_list CTE.

------------------------------------------------------------------------------
-- STEP 1 — How many would be deleted, and how old are they?
------------------------------------------------------------------------------
select
  count(*)                              as unconfirmed_total,
  min(created_at)                       as oldest,
  max(created_at)                       as newest,
  count(*) filter (where created_at < now() - interval '1 day') as older_than_1d
from auth.users
where email_confirmed_at is null
  and email not in ('daiviknnl@gmail.com', 'daiviknnl2@gmail.com', 'daiviknnl3@gmail.com');

------------------------------------------------------------------------------
-- STEP 2 — Review the actual rows (sanity-check the addresses before deleting).
--          Look for anything that is NOT a junk/test address.
------------------------------------------------------------------------------
select id, email, created_at, last_sign_in_at
from auth.users
where email_confirmed_at is null
  and created_at < now() - interval '1 day'   -- grace period for genuine new signups
  and email not in ('daiviknnl@gmail.com', 'daiviknnl2@gmail.com', 'daiviknnl3@gmail.com')
order by created_at;

------------------------------------------------------------------------------
-- STEP 3 — Delete. Cascades to profiles + all user-scoped tables.
--          Run inside a transaction so you can ROLLBACK if the count surprises
--          you. Change COMMIT -> ROLLBACK to do a dry run first.
------------------------------------------------------------------------------
begin;

delete from auth.users
where email_confirmed_at is null
  and created_at < now() - interval '1 day'
  and email not in ('daiviknnl@gmail.com', 'daiviknnl2@gmail.com', 'daiviknnl3@gmail.com');

-- Inspect the row count reported above, then:
commit;       -- or: rollback;
