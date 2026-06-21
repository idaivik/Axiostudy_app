-- Missing RLS read policy on public.subtopics.
--
-- The subtopics table shipped with row-level security ENABLED but no SELECT
-- policy. RLS-on + no-policy = deny-all for normal roles, so the app (querying
-- as `authenticated` via PostgREST) saw ZERO subtopics even though the rows
-- exist — the practice drill-down dead-ended at "No subtopics yet for this
-- topic" and the 30-question subtopic tests were unreachable. (Admin/MCP
-- connections bypass RLS, which is why the seed data looked fine there.)
--
-- This mirrors the existing "Authenticated users can read …" policies on
-- questions / topics / chapters. Server-side only; no app rebuild needed.
-- Applied to the live project (nxtfbyvacunsiytlsfkl) via the Supabase MCP on
-- 2026-06-20 (migration version 20260620151233). Idempotent.

drop policy if exists "Authenticated users can read subtopics" on public.subtopics;
create policy "Authenticated users can read subtopics"
  on public.subtopics
  for select
  to authenticated
  using (true);
