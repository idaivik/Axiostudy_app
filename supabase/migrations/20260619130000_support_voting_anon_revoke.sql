-- Bucket 2 follow-up: lock get_feature_requests() to signed-in users only.
--
-- The board RPC is SECURITY DEFINER. Supabase's default privileges grant EXECUTE
-- to BOTH `anon` and `authenticated`, so the prior migration's
-- `revoke all ... from public` left `anon` still able to call it via
-- /rest/v1/rpc/get_feature_requests (security advisor lint 0028). The board is
-- an in-app, Pro-gated surface — a signed-out caller has no reason to read it.
-- Idempotent.
revoke execute on function public.get_feature_requests() from anon;
