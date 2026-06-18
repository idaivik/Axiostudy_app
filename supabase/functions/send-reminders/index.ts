// send-reminders — Feature 1 reminder ENGINE (BILLING_BUCKET1_BUILD_PROMPT.md §3).
//
// ONE engine, channeled by tier (read like consume_meter does):
//   Basic → rule-based reminders (decay / weakness / streak).
//   Pro   → spaced-repetition (SM-2-ish interval curve via topic_review_state)
//           — the advancedRevisionPlan surface, same engine, smarter due dates.
//
// Run daily by pg_cron. Per user with notifications enabled + a device token it
// composes AT MOST `max_per_day` pushes, never inside quiet hours, marks
// reminder_schedule.sent_at to avoid double-sends, and deletes stale tokens.
//
// Tone: warm & encouraging (confirmed). Cap default: 1/day, quiet 22:00–08:00.
//
// Secrets: FCM_SERVICE_ACCOUNT (+ FCM_PROJECT_ID). Optional REMINDERS_CRON_SECRET
// to gate who may invoke it.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getAccessToken, sendPush, ServiceAccount } from "../_shared/fcm.ts";

const DECAY_DAYS = 4;            // a weak chapter idle this long → "getting rusty"
const WEAKNESS_THRESHOLD = 3;    // this many weak chapters → "chapters waiting"

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

interface Reminder {
  kind: "decay" | "weakness" | "streak" | "spaced_rep";
  topicId: string | null;
  chapterId: string | null;
  title: string;
  body: string;
}

Deno.serve(async (req: Request) => {
  // Gate invocation: require the service-role key or REMINDERS_CRON_SECRET when set.
  const cronSecret = Deno.env.get("REMINDERS_CRON_SECRET") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  if (cronSecret) {
    const auth = req.headers.get("Authorization") ?? "";
    const given = req.headers.get("x-reminders-secret") ?? "";
    if (given !== cronSecret && auth !== `Bearer ${serviceKey}`) {
      return json({ ok: false, error: "unauthorized" }, 401);
    }
  }

  try {
    const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}") as ServiceAccount;
    const projectId = Deno.env.get("FCM_PROJECT_ID") ?? sa.project_id ?? "";
    if (!sa.client_email || !sa.private_key || !projectId) {
      return json({ ok: false, error: "fcm not configured" }, 200);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const db = createClient(supabaseUrl, serviceKey);

    // Candidate users = those with at least one registered device.
    const { data: devices } = await db
      .from("user_devices")
      .select("user_id, fcm_token, platform");
    const tokensByUser = new Map<string, string[]>();
    for (const d of (devices ?? []) as { user_id: string; fcm_token: string }[]) {
      const arr = tokensByUser.get(d.user_id) ?? [];
      arr.push(d.fcm_token);
      tokensByUser.set(d.user_id, arr);
    }
    if (tokensByUser.size === 0) return json({ ok: true, sent: 0, note: "no devices" });

    // Chapter names (one fetch, reused for every user).
    const { data: chapterRows } = await db.from("chapters").select("id, name");
    const chapterName = new Map<string, string>(
      ((chapterRows ?? []) as { id: string; name: string }[]).map((c) => [c.id, c.name]),
    );

    let accessToken = "";
    let sentCount = 0;

    for (const [userId, tokens] of tokensByUser) {
      try {
        const plan = await effectivePlan(db, userId);
        if (plan === "free") continue; // reminders are a Basic/Pro feature

        const prefs = await loadPrefs(db, userId);
        if (!prefs.enabled) continue;

        const hour = localHour(prefs.timezone);
        if (inQuietHours(hour, prefs.quiet_start, prefs.quiet_end)) continue;
        if (await sentTodayCount(db, userId) >= prefs.max_per_day) continue;

        const reminder = plan === "pro"
          ? await buildSpacedRep(db, userId, chapterName)
          : await buildRuleBased(db, userId, chapterName);
        if (!reminder) continue;

        // Record the scheduled item (pending) before pushing.
        const { data: inserted } = await db
          .from("reminder_schedule")
          .insert({
            user_id: userId,
            topic_id: reminder.topicId,
            chapter_id: reminder.chapterId,
            due_at: new Date().toISOString(),
            kind: reminder.kind,
            title: reminder.title,
            body: reminder.body,
          })
          .select("id")
          .single();

        if (!accessToken) accessToken = await getAccessToken(sa);

        let delivered = false;
        for (const token of tokens) {
          const res = await sendPush(
            accessToken,
            projectId,
            token,
            reminder.title,
            reminder.body,
            { kind: reminder.kind, chapter_id: reminder.chapterId ?? "" },
          );
          if (res.ok) delivered = true;
          if (res.unregistered) {
            await db.from("user_devices").delete().eq("fcm_token", token);
          }
        }

        if (delivered && inserted?.id) {
          await db
            .from("reminder_schedule")
            .update({ sent_at: new Date().toISOString() })
            .eq("id", inserted.id);
          sentCount++;
        }
      } catch (e) {
        console.error("reminder for user", userId, "failed:", e);
      }
    }

    return json({ ok: true, sent: sentCount });
  } catch (e) {
    console.error("send-reminders error:", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});

// ── Tier resolution (mirrors consume_meter's effective-plan logic) ────────────
async function effectivePlan(
  db: ReturnType<typeof createClient>,
  userId: string,
): Promise<"basic" | "pro" | "free"> {
  const { data: p } = await db
    .from("profiles")
    .select("subscription_tier, subscription_status, subscription_expiry")
    .eq("id", userId)
    .single();
  if (!p) return "free";
  const status = p.subscription_status as string | null;
  const expiry = p.subscription_expiry ? Date.parse(p.subscription_expiry as string) : 0;
  const entitled = status === "trialing" || status === "active" ||
    ((status === "cancelled" || status === "past_due") && expiry > Date.now());
  if (!entitled) return "free";
  const tier = p.subscription_tier as string | null;
  if (tier === "pro" || tier === "premium" || tier === "professional") return "pro";
  if (tier === "basic") return "basic";
  return "free";
}

interface Prefs {
  enabled: boolean;
  quiet_start: string;
  quiet_end: string;
  max_per_day: number;
  timezone: string | null;
}
async function loadPrefs(
  db: ReturnType<typeof createClient>,
  userId: string,
): Promise<Prefs> {
  // notification_prefs is keyed by user_id; a missing row → spec defaults.
  const { data: row } = await db
    .from("notification_prefs")
    .select("enabled, quiet_start, quiet_end, max_per_day, timezone")
    .eq("user_id", userId)
    .maybeSingle();
  const r = row as Record<string, unknown> | null;
  return {
    enabled: r?.enabled as boolean ?? true,
    quiet_start: (r?.quiet_start as string) ?? "22:00:00",
    quiet_end: (r?.quiet_end as string) ?? "08:00:00",
    max_per_day: (r?.max_per_day as number) ?? 1,
    timezone: (r?.timezone as string) ?? null,
  };
}

async function sentTodayCount(
  db: ReturnType<typeof createClient>,
  userId: string,
): Promise<number> {
  const dayStart = new Date();
  dayStart.setUTCHours(0, 0, 0, 0);
  const { count } = await db
    .from("reminder_schedule")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("sent_at", dayStart.toISOString());
  return count ?? 0;
}

// ── Basic: rule-based (decay > weakness > streak) ─────────────────────────────
async function buildRuleBased(
  db: ReturnType<typeof createClient>,
  userId: string,
  chapterName: Map<string, string>,
): Promise<Reminder | null> {
  const { data: weak } = await db
    .from("user_weak_chapters")
    .select("chapter_id, weakness_score, last_updated")
    .eq("user_id", userId)
    .eq("status", "weak")
    .order("weakness_score", { ascending: true });
  const weakRows = (weak ?? []) as
    { chapter_id: string; weakness_score: number; last_updated: string }[];

  // decay: a weak chapter idle for DECAY_DAYS+.
  const cutoff = Date.now() - DECAY_DAYS * 86400_000;
  const stale = weakRows.find((w) =>
    w.last_updated && Date.parse(w.last_updated) < cutoff
  );
  if (stale) {
    const name = chapterName.get(stale.chapter_id) ?? "a weak chapter";
    return {
      kind: "decay",
      topicId: null,
      chapterId: stale.chapter_id,
      title: "Time for a quick revisit 📈",
      body: `${name} is getting rusty — a 10-minute set today keeps it sharp.`,
    };
  }

  // weakness: enough weak chapters waiting.
  if (weakRows.length >= WEAKNESS_THRESHOLD) {
    return {
      kind: "weakness",
      topicId: null,
      chapterId: null,
      title: "Your weak chapters are waiting 📈",
      body:
        `You've got ${weakRows.length} chapters to shore up — a quick AI practice ` +
        `set keeps your scores climbing.`,
    };
  }

  // streak: an active streak with nothing done today.
  const { data: streak } = await db
    .from("study_streaks")
    .select("current_streak, last_study_date")
    .eq("user_id", userId)
    .maybeSingle();
  const cur = (streak?.current_streak as number) ?? 0;
  const last = streak?.last_study_date as string | null;
  const today = new Date().toISOString().slice(0, 10);
  if (cur > 0 && last !== today) {
    return {
      kind: "streak",
      topicId: null,
      chapterId: null,
      title: "Keep your streak alive 🔥",
      body: `You're on a ${cur}-day streak — one quick practice set today keeps it going.`,
    };
  }
  return null;
}

// ── Pro: spaced repetition (SM-2-ish; intervals widen as mastery grows) ───────
async function buildSpacedRep(
  db: ReturnType<typeof createClient>,
  userId: string,
  chapterName: Map<string, string>,
): Promise<Reminder | null> {
  // Due review state first.
  const nowIso = new Date().toISOString();
  const { data: due } = await db
    .from("topic_review_state")
    .select("topic_id, interval_days, ease, reps, next_due_at")
    .eq("user_id", userId)
    .or(`next_due_at.is.null,next_due_at.lte.${nowIso}`)
    .order("next_due_at", { ascending: true, nullsFirst: true })
    .limit(1);
  let row = (due ?? [])[0] as
    | { topic_id: string; interval_days: number; ease: number; reps: number }
    | undefined;

  // Seed from the weakest chapter when there's no due review state yet.
  if (!row) {
    const { data: weak } = await db
      .from("user_weak_chapters")
      .select("chapter_id, weakness_score")
      .eq("user_id", userId)
      .order("weakness_score", { ascending: true })
      .limit(1);
    const w = (weak ?? [])[0] as { chapter_id: string; weakness_score: number } | undefined;
    if (!w) return null;
    row = { topic_id: w.chapter_id, interval_days: 1, ease: 2.5, reps: 0 };
  }

  // Mastery for this chapter drives how far the next interval widens.
  const { data: wc } = await db
    .from("user_weak_chapters")
    .select("weakness_score")
    .eq("user_id", userId)
    .eq("chapter_id", row.topic_id)
    .maybeSingle();
  const mastery = (wc?.weakness_score as number) ?? 30; // 0–100 (higher = stronger)
  // quality 0–5 from mastery; SM-2 ease + interval update.
  const quality = Math.max(0, Math.min(5, Math.round(mastery / 20)));
  const ease = Math.max(
    1.3,
    row.ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)),
  );
  const reps = row.reps + 1;
  const interval = reps <= 1 ? 1 : reps === 2 ? 3 : Math.round(row.interval_days * ease);
  const nextDue = new Date(Date.now() + interval * 86400_000).toISOString();

  await db.from("topic_review_state").upsert({
    user_id: userId,
    topic_id: row.topic_id,
    interval_days: interval,
    ease,
    reps,
    last_reviewed_at: nowIso,
    next_due_at: nextDue,
  }, { onConflict: "user_id,topic_id" });

  const name = chapterName.get(row.topic_id) ?? "a key chapter";
  return {
    kind: "spaced_rep",
    topicId: row.topic_id,
    chapterId: row.topic_id,
    title: "Revision due 📈",
    body: `It's the perfect time to review ${name} — spaced practice locks it into memory.`,
  };
}

// ── time helpers ──────────────────────────────────────────────────────────────
function localHour(tz: string | null): number {
  // The client stores a UTC offset in minutes (package-free); accept that or an
  // IANA name, falling back to UTC.
  if (tz && /^[-+]?\d+$/.test(tz)) {
    const offsetMin = parseInt(tz, 10);
    const now = new Date();
    const utcMin = now.getUTCHours() * 60 + now.getUTCMinutes();
    const localMin = (((utcMin + offsetMin) % 1440) + 1440) % 1440;
    return Math.floor(localMin / 60);
  }
  try {
    const s = new Intl.DateTimeFormat("en-US", {
      hour: "numeric",
      hour12: false,
      timeZone: tz ?? "UTC",
    }).format(new Date());
    return parseInt(s, 10) % 24;
  } catch {
    return new Date().getUTCHours();
  }
}

function inQuietHours(hour: number, start: string, end: string): boolean {
  const sh = parseInt(start.slice(0, 2), 10);
  const eh = parseInt(end.slice(0, 2), 10);
  if (sh === eh) return false;
  if (sh < eh) return hour >= sh && hour < eh; // same-day window
  return hour >= sh || hour < eh; // wraps midnight (e.g. 22:00–08:00)
}
