-- Feature 4 — Static formula bank + "Formulas to learn" widget
-- (BILLING_BUCKET1_BUILD_PROMPT.md §6), Pro (rides on advancedBreakdown).
--
-- A CURATED, static per-topic formula bank — NO AI extraction (a wrong formula is
-- worse than none, §1.4). This one table is the SINGLE source for both the
-- Feature 4 widget and the Phase-2 generated formula sheet, so they never
-- disagree. The widget is a plain lookup → NO meter (the metered formula_sheet,
-- 20/mo, is the P2 generated sheet, not this).
--
-- Content is a separate track (§9): this seeds a small illustrative SAMPLE for a
-- few high-value chapters (JEE + NEET) via name-based lookup so it adapts to the
-- live chapter IDs. Un-curated topics simply show nothing (graceful).

create table if not exists public.formula_bank (
  id          uuid primary key default gen_random_uuid(),
  exam        text not null,                 -- 'jee' | 'neet' | 'both'
  subject_id  text not null,
  chapter_id  text not null,
  topic_id    text,                          -- null = chapter-level formula
  name        text not null,
  formula_tex text not null,                 -- LaTeX (rendered by flutter_math_fork)
  importance  int  not null default 1,       -- higher = more important (ordering)
  note        text,                          -- optional one-line hint
  image_url   text,                          -- optional pre-rendered fallback image
  created_at  timestamptz not null default now(),
  unique (exam, chapter_id, name)            -- idempotent seeding + no dupes
);

create index if not exists formula_bank_topic_idx   on public.formula_bank (topic_id);
create index if not exists formula_bank_chapter_idx on public.formula_bank (chapter_id);
create index if not exists formula_bank_exam_idx     on public.formula_bank (exam);

comment on table public.formula_bank is
  'Curated static formula bank (Feature 4). Single source for the "formulas to '
  'learn" widget AND the Phase-2 formula sheet. No AI — content is authored.';

-- ── RLS: reference content, readable by every signed-in user ──────────────────
-- Authoring (insert/update/delete) is service-role / dashboard only — no write
-- policy is granted, so authenticated users can read but never mutate the bank.
alter table public.formula_bank enable row level security;

drop policy if exists "formula_bank readable" on public.formula_bank;
create policy "formula_bank readable" on public.formula_bank
  for select to authenticated using (true);

-- ── Sample seed (illustrative only — replace via the content track) ───────────
-- Joined to live chapters by name so it works whatever the chapter IDs are; a
-- non-matching pattern simply inserts nothing. Physics/Chemistry are shared by
-- both exams ('both'); Maths is JEE; one Biology example is NEET.
insert into public.formula_bank (exam, subject_id, chapter_id, name, formula_tex, importance, note)
select v.exam, c.subject_id, c.id, v.name, v.formula_tex, v.importance, v.note
from public.chapters c
join (
  values
    -- Physics · Rotational Motion (shared)
    ('both', '%rotational%', 'Rotational kinetic energy', 'KE_{rot} = \frac{1}{2} I \omega^2', 3, 'I = moment of inertia, ω = angular velocity'),
    ('both', '%rotational%', 'Torque',                    '\tau = I \alpha',                   3, 'Rotational analogue of F = ma'),
    ('both', '%rotational%', 'Angular momentum',          'L = I \omega',                      2, 'Conserved when net torque is zero'),
    ('both', '%rotational%', 'Moment of inertia (point mass)', 'I = m r^2',                    2, null),
    -- Physics · Kinematics (shared)
    ('both', '%kinematic%',  'Velocity (uniform acceleration)', 'v = u + a t',                 3, null),
    ('both', '%kinematic%',  'Displacement',              's = u t + \tfrac{1}{2} a t^2',      3, null),
    ('both', '%kinematic%',  'Velocity–displacement',     'v^2 = u^2 + 2 a s',                 2, 'Use when time is unknown'),
    -- Chemistry · Thermodynamics (shared)
    ('both', '%thermodynamic%', 'Gibbs free energy',      '\Delta G = \Delta H - T \Delta S',  3, 'ΔG < 0 → spontaneous'),
    ('both', '%thermodynamic%', 'First law',              '\Delta U = q + w',                  3, null),
    ('both', '%thermodynamic%', 'Enthalpy change',        '\Delta H = \Delta U + \Delta (PV)', 2, null),
    -- Maths · Differentiation / Calculus (JEE)
    ('jee',  '%differ%',     'Power rule',                '\frac{d}{dx} x^n = n x^{n-1}',      3, null),
    ('jee',  '%differ%',     'Product rule',              '(uv)'' = u''v + uv''',              2, null),
    ('jee',  '%differ%',     'Chain rule',                '\frac{dy}{dx} = \frac{dy}{du} \cdot \frac{du}{dx}', 2, null),
    -- Biology · Inheritance / Genetics (NEET)
    ('neet', '%inherit%',    'Hardy–Weinberg principle',  'p^2 + 2pq + q^2 = 1',               2, 'Allele frequencies sum to 1')
) as v(exam, chapter_pattern, name, formula_tex, importance, note)
  on c.name ilike v.chapter_pattern
on conflict (exam, chapter_id, name) do nothing;
