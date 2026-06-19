-- Bucket 2 follow-up: enforce the Pro perk SERVER-SIDE for the voting board.
--
-- Submitting a feature request and casting a vote are Pro perks
-- (Feature.prioritySupport). The first migration gated these only on the client
-- (WITH CHECK true), which the security advisor flagged (lint 0024) and which
-- left a Basic/free user able to vote/submit via the raw API — contradicting the
-- "Basic cannot vote" acceptance. This moves the gate into the database so it
-- can't drift out of sync with the UI.
--
-- is_pro_active() mirrors UserModel.hasActiveAccess + the Pro tier exactly:
--   entitled  = status trialing|active, OR cancelled|past_due still inside the
--               already-paid period (subscription_expiry in the future)
--   pro tier  = subscription_tier in pro (+ legacy premium/professional, which
--               UserModel._parseTier folds into pro)
-- Keep it in sync with entitlements.dart / user_model.dart if those rules change.
--
-- ADDITIVE / idempotent. Does NOT change pricing, meters, or the tier matrix —
-- it only ENFORCES the existing matrix at the data layer.

create or replace function public.is_pro_active(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = uid
      and p.subscription_tier in ('pro', 'premium', 'professional')
      and (
        p.subscription_status in ('active', 'trialing')
        or (
          p.subscription_status in ('cancelled', 'past_due')
          and p.subscription_expiry is not null
          and p.subscription_expiry > now()
        )
      )
  );
$$;

revoke all on function public.is_pro_active(uuid) from public, anon;
grant execute on function public.is_pro_active(uuid) to authenticated;

-- feature_requests: only an active Pro may submit (read stays open to signed-in).
drop policy if exists "feature_requests insertable" on public.feature_requests;
create policy "feature_requests insertable" on public.feature_requests
  for insert to authenticated
  with check (public.is_pro_active(auth.uid()));

-- feature_votes: still strictly owner-scoped, AND only an active Pro may ADD a
-- vote. SELECT/DELETE keep the owner check WITHOUT a tier gate, so a user who
-- later lapses can still see and remove their existing votes.
drop policy if exists "feature_votes owner" on public.feature_votes;
create policy "feature_votes owner" on public.feature_votes
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and public.is_pro_active(auth.uid()));
