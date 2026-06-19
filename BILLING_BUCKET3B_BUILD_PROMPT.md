# Build prompt: Bucket 3 — Part B — Community

> **Part 2 of 2** for Bucket 3 (the other is `BILLING_BUCKET3A_BUILD_PROMPT.md` = Pro
> AI artifacts). Community is the **single biggest build** in the whole tier plan and
> carries a real **safety/moderation liability** (audience is 16–18, i.e. minors), so
> it gets its **own session**. Build in **phases** and **commit after each** — if the
> session runs low, a shipped schema+feed is a clean stopping point, but **do not make
> the community publicly writable before moderation (§4) exists.**
>
> **How to use this:** open a fresh chat in this repo and paste:
> *"Read `BILLING_BUCKET3B_BUILD_PROMPT.md` and implement Community in the phase order
> given, committing after each phase. Stop and ask me before anything in
> **‼️ Confirm first**. Do not change pricing, meters, or the tier matrix."*

---

## 0. Orientation

- **Tier:** Community is a **paid-floor** feature — `Feature.community` is in **both**
  `basic` and `pro` sets ([entitlements.dart](lib/features/subscription/domain/entitlements.dart)).
  So gate it with `FeatureGate(feature: community)` (free sentinel = no access);
  **it is not Pro-only.**
- **Reuse the report→quarantine pattern** already written for the question pool:
  [20260617130000_question_pool.sql](supabase/migrations/20260617130000_question_pool.sql)
  (`question_reports` + `report_question()` with a distinct-reporter threshold). The
  community report/auto-hide flow is the same shape — copy it.
- **Risk flagged in the plan:** [BILLING_PRICING_AND_TIERS_PLAN.md](BILLING_PRICING_AND_TIERS_PLAN.md)
  §11 — *"Community is a build + a moderation/safety liability for a minor-heavy
  audience. Phase 2, and budget moderation — it's not a toggle."* Treat that as binding.
- **Migrations:** next free timestamp; never edit a committed one.

---

## 1. ‼️ Confirm first (do NOT start building until these are answered)

These are product/safety/legal calls the user must make — they change the schema and
the launch gate:

1. **v1 scope.** Recommend starting **narrow and safe**: topic-scoped Q&A / discussion
   threads (tied to subjects/chapters), **not** open DMs, **not** image uploads, **not**
   profiles with PII. Confirm the surface.
2. **Identity model.** Real names vs handles/aliases. For minors, **aliases + no PII**
   is the safer default. Confirm.
3. **Moderation ownership.** Who reviews the report queue, and the response time. A
   community for minors with no human in the loop is a liability — confirm there is one.
4. **Content policy + legal.** A posted content policy, and a quick check on minor-data
   obligations (India DPDP / age-appropriate design). Confirm the user has this covered
   or wants it scoped in.

If the user wants to **defer Community entirely**, that is a legitimate outcome — it is
explicitly the lowest-priority, highest-risk item.

---

## 2. Phase 1 — Schema + RLS (the foundation)

- `community_posts(id, user_id, body, subject_id?, chapter_id?, status default 'active',
  created_at)` — `status` ∈ active | hidden | removed.
- `community_comments(id, post_id, user_id, body, status default 'active', created_at)`.
- `community_reactions(user_id, post_id, primary key (user_id, post_id))` — simple likes.
- `community_reports(reporter_id, target_type, target_id, reason, created_at,
  primary key (reporter_id, target_type, target_id))` — dedup per reporter.
- `community_blocks(user_id, blocked_user_id, primary key (user_id, blocked_user_id))`.
- **RLS is the hard part:** reads only see `status='active'` (and not authors you've
  blocked / who blocked you); a user writes/edits/deletes **only their own** posts &
  comments; reports/blocks insert own rows only. Server (service-role) does moderation
  transitions. **Write RLS tests in this phase**, not later.

## 3. Phase 2 — Read + write surfaces (client)

- **Feed screen** (Pro+Basic, `FeatureGate(community)`): list active posts, optionally
  filtered by subject/chapter; paginated.
- **Composer:** create a post (and comments on a post detail screen). Run the §4 input
  filter on submit.
- **Reactions:** like/unlike (toggle, idempotent via the PK).
- Keep it text-only for v1 (no uploads) unless the user expanded scope in §1.

## 4. Phase 3 — Moderation & safety (NOT optional before public launch)

This is the phase that makes Community shippable for minors. Do not skip it.

- **Report → auto-hide:** copy `report_question()` — once N distinct reporters flag a
  post/comment, flip `status='hidden'` automatically (a `report_content()` RPC).
- **Input filter on submit:** a profanity/keyword block + basic PII pattern block
  (phone/email/links) — refuse or soft-flag. Confirm strictness with the user.
- **Block user:** `community_blocks` hides both directions in feed/threads.
- **Rate limiting:** per-user post/comment cap per hour (anti-spam) — enforce in the
  insert RPC or a trigger.
- **Moderation queue:** v1 can be the **Supabase dashboard** (query `status='hidden'`
  + `community_reports`), but for a minor audience prefer at least the auto-hide +
  input filter to be **proactive**, not purely reactive. A lightweight in-app admin
  view can come later.

## 5. Phase 4 — Polish
- Empty/loading/error states, optimistic reactions, deep links to a post, "your posts"
  view, edit/delete own content.

---

## 6. Build order & checkpoints
Phase 1 (schema+RLS) → 2 (feed+post) → **3 (moderation — required before any public
write access)** → 4 (polish). **Commit after each phase.** If the session budget runs
out mid-way, stop at a committed phase boundary and note where you stopped — but the
**Phase 1→3 sequence must complete before this is exposed to real users.**

## 7. Tests
- Extend [test/subscription/entitlements_test.dart](test/subscription/entitlements_test.dart):
  **both** Basic and Pro `can(community)` true; the `free` sentinel false.
- SQL/RLS tests: a user can't read `hidden`/`removed` content; can't edit another user's
  post; a second report by the same reporter is idempotent; the Nth distinct report
  auto-hides; blocked users disappear from each other's feed; rate-limit rejects the
  (cap+1)th post in the window.

## 8. Out of scope / explicitly deferred
- Image/file uploads, DMs, user profiles with PII (unless the user expands §1 scope).
- A full custom admin moderation dashboard (dashboard-based for v1).
- Pricing / meter-cap / tier-matrix changes.
- **If §1 isn't answered, Community stays deferred** — that's an acceptable result.
