# Plan: Deploy `revenuecat-webhook` edge function (Step 1)

> Hand this file to a fresh chat: "Read `DEPLOY_REVENUECAT_WEBHOOK.md` and execute it."
> Everything needed is below — no extra context required.

## Goal
Deploy the `revenuecat-webhook` Supabase edge function so the URL
`https://nxtfbyvacunsiytlsfkl.functions.supabase.co/revenuecat-webhook`
stops returning 404 / `NOT_FOUND`. It currently exists only locally and was never deployed.

## Facts
- **Project ref:** `nxtfbyvacunsiytlsfkl`
- **Function name:** `revenuecat-webhook` (must match exactly)
- **Source file:** `supabase/functions/revenuecat-webhook/index.ts` (already written — deploy as-is)
- **JWT:** must be deployed with **`verify_jwt: false`**. RevenueCat sends its own
  `Authorization` header (not a Supabase JWT); the function checks it against the
  `REVENUECAT_WEBHOOK_AUTH` secret internally. With JWT on, every webhook is 401'd at the gateway.

## Already done by the user (do NOT redo)
- Secret `REVENUECAT_WEBHOOK_AUTH` is set in Supabase with a random value.
- RevenueCat webhook `Authorization` header is set to that same value.

## Action — deploy via Supabase MCP
1. `Read` the file `supabase/functions/revenuecat-webhook/index.ts`.
2. Call `mcp__claude_ai_Supabase__deploy_edge_function` with:
   - `project_id`: `nxtfbyvacunsiytlsfkl`
   - `name`: `revenuecat-webhook`
   - `entrypoint_path`: `index.ts`
   - `verify_jwt`: `false`
   - `files`: `[{ name: "index.ts", content: <full contents of the source file> }]`

This deploy requires the user's authorization (an earlier attempt was auto-blocked as an
unauthorized production deploy). The user has now approved it — proceed.

### Fallback if MCP deploy is unavailable (CLI)
```bash
brew install supabase/tap/supabase
supabase link --project-ref nxtfbyvacunsiytlsfkl
supabase functions deploy revenuecat-webhook --no-verify-jwt
```

## Verify
1. Call `mcp__claude_ai_Supabase__list_edge_functions` for project `nxtfbyvacunsiytlsfkl`
   → `revenuecat-webhook` should now appear with status `ACTIVE`.
2. Auth check (run in terminal):
   ```bash
   # No header → expect 401 Unauthorized (proves it's deployed + auth works)
   curl -i -X POST https://nxtfbyvacunsiytlsfkl.functions.supabase.co/revenuecat-webhook -d '{}'

   # Correct header → expect 200 "ignored"
   curl -i -X POST https://nxtfbyvacunsiytlsfkl.functions.supabase.co/revenuecat-webhook \
     -H "Authorization: <the REVENUECAT_WEBHOOK_AUTH value>" -d '{}'
   ```
3. RevenueCat → "Send test event" should return **200**.

## Note (out of scope for Step 1, but flag it)
For real purchase events to actually update the DB, the migration
`supabase/migrations/20260614140000_native_billing.sql` must be applied to the project
(adds `subscription_*` + `store_product_id` columns to `profiles`). It is **NOT applied yet**.
TEST events return 200 without it, but a real `INITIAL_PURCHASE` webhook would 500.
Apply that migration as a separate step if not already done.
