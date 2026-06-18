-- Allow an authenticated user to INSERT their own profile row.
--
-- Context: `profiles` already has RLS enabled with SELECT-own and UPDATE-own
-- policies, but no INSERT policy. The `on_auth_user_created` trigger
-- (handle_new_user, SECURITY DEFINER) is the primary path that seeds a profile
-- at signup and bypasses RLS, so normal signups work without this.
--
-- This policy is the safety net for AuthRepository.getProfile's self-heal: if a
-- profile row is ever missing (trigger failure, legacy account, row deleted out
-- of band), the app can recreate it from the authenticated user instead of
-- throwing and bouncing the user back to /login. The WITH CHECK clause ensures a
-- user can only ever create a row keyed to their own auth id.
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);
