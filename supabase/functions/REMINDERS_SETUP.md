# Feature 1 — Reminder engine: Firebase + deploy setup

Everything in the app + database + edge functions is already built. This is the
**external setup only you can do** (the ‼️ ask-first items). Until it's done, push
stays **dormant** — the app builds and runs normally, it just doesn't send pushes.

App identifiers (you'll need them below):
- **Android package name:** `com.axiostudy.app`
- **iOS bundle ID:** `com.axiostudy.app`

---

## 1. Create the Firebase project
1. https://console.firebase.google.com → **Add project** (e.g. "AxioStudy"). Skip
   Google Analytics unless you want it.

## 2. Register the Android app → `google-services.json`
1. Firebase console → **Add app → Android**.
2. Android package name: `com.axiostudy.app`.
3. Download **`google-services.json`** → place it at **`android/app/google-services.json`**.
4. Wire the Gradle plugin (Kotlin DSL):
   - `android/settings.gradle.kts` — in the `plugins { … }` block add:
     ```kotlin
     id("com.google.gms.google-services") version "4.4.2" apply false
     ```
   - `android/app/build.gradle.kts` — in its `plugins { … }` block add:
     ```kotlin
     id("com.google.gms.google-services")
     ```

## 3. Register the iOS app → `GoogleService-Info.plist` + APNs
1. Firebase console → **Add app → iOS**.
2. iOS bundle ID: `com.axiostudy.app`.
3. Download **`GoogleService-Info.plist`** and add it to **`ios/Runner/`** *through
   Xcode* (drag into the Runner target so it's in "Copy Bundle Resources").
4. In Xcode → Runner target → **Signing & Capabilities → + Capability**:
   - **Push Notifications**
   - **Background Modes** → tick **Remote notifications**
5. **APNs auth key** (the iOS hard part):
   - Apple Developer → Certificates, IDs & Profiles → **Keys → +** → enable **Apple
     Push Notifications service (APNs)** → download the **`.p8`** (one-time download)
     and note the **Key ID** + your **Team ID**.
   - Firebase console → Project settings → **Cloud Messaging → Apple app config →
     APNs Authentication Key → Upload** the `.p8` with Key ID + Team ID.

> After steps 2–3, `flutter run` activates push automatically — the app calls bare
> `Firebase.initializeApp()` and reads these native config files. (Optional: run
> `flutterfire configure` if you prefer a generated `firebase_options.dart`; the
> code doesn't require it.)

## 4. Service account → Supabase secrets
1. Firebase console → Project settings → **Service accounts → Generate new private
   key** → downloads a JSON.
2. Set the edge-function secrets (one line each):
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat path/to/service-account.json)"
   supabase secrets set FCM_PROJECT_ID="your-firebase-project-id"
   supabase secrets set REMINDERS_CRON_SECRET="$(openssl rand -hex 24)"
   # optional — defaults are sensible:
   # supabase secrets set GEMINI_CHEAP_MODEL="gemini-2.5-flash-lite"
   ```

## 5. Apply the new migrations
```bash
supabase db push     # or apply each new 20260618* migration via the MCP/dashboard
```
New this bucket: `ai_narrative`, `question_breakdown` (+ `question-explanations`
bucket), `formula_bank` (+ sample seed), `reminder_engine`, `reminders_cron`.

## 6. Deploy / redeploy the edge functions
The model pick was centralized into `_shared/gemini.ts`, so the two existing
functions must be **redeployed** alongside the two new ones:
```bash
supabase functions deploy send-reminders
supabase functions deploy analysis-narrative
supabase functions deploy generate-questions   # picks up _shared/gemini.ts
supabase functions deploy compute-analytics     # picks up _shared/gemini.ts
```

## 7. Schedule the daily run (pg_cron)
Run once in the SQL editor, filling in your values (template also in
`migrations/20260618170000_reminders_cron.sql`):
```sql
select cron.schedule(
  'send-reminders-daily',
  '30 13 * * *',  -- 13:30 UTC ≈ 7pm IST; per-user quiet hours/cap refine it
  $$
    select net.http_post(
      url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-reminders',
      headers := jsonb_build_object(
                   'Content-Type', 'application/json',
                   'x-reminders-secret', '<REMINDERS_CRON_SECRET>'
                 ),
      body    := '{}'::jsonb
    );
  $$
);
```

## 8. Verify
- Sign in on a device → Settings → toggle **Revision Reminders** on (grant the OS
  prompt) → a row should appear in `public.user_devices`.
- Manually fire the engine:
  ```bash
  curl -X POST 'https://<PROJECT_REF>.supabase.co/functions/v1/send-reminders' \
    -H 'x-reminders-secret: <REMINDERS_CRON_SECRET>'
  ```
- A Basic user with a stale weak chapter gets **one** rule-based push; a Pro user
  gets a spaced-rep-timed push. Check `reminder_schedule.sent_at` is set (no
  double-send) and that quiet hours / `max_per_day` (1) are respected.

---

### Defaults already baked in (you confirmed these)
- Frequency cap: **1/day**, quiet hours **22:00–08:00** (user-editable in Settings).
- Tone: **warm & encouraging** (copy lives in `send-reminders/index.ts`).
