# APP v24 — THE REGIMEN · EVIDENCE

THE LOOP's record for the medication era. `00_REGIMEN.md` is the law.

## Phase record

- **P0 docs** (7c2b605) — law + this record.
- **P1 platform** (abbf5ba) — catalog (9 products; saxenda proves
  daily-injection, rybelsus oral empty-stomach) · RegimenPlanRecord
  additive evolution (productId/route/previousPlanId/endReason) ·
  `applySelfRegimen` version chokepoint (append-only chains,
  same-day coalescing, reminder toggles never version, schedule
  changes inherit the titration clock, care-team guard) ·
  DoseEventRecord (deterministic per-slot ids; dual-write to the
  chart) · MedicationScheduleEngine (wall clock; **the DST fold
  caught by my own test math before it shipped** — minute-addition
  from midnight became `bySettingHour`) · SiteRotationAdvisor ·
  sync (upserts omit nil v24 columns so pre-migration rows keep
  syncing; dose events in the pending sweep from day one) · SQL
  migration staged. **20/20 platform tests.**
- **P2 notifications** (ad9e0ba) — the app's FIRST actionable
  category (taken / in an hour / log later; deliberately no
  lock-screen skip) · wall-clock calendar triggers (travel-safe by
  construction) · weekly open-slot morning follow-up · replace-
  never-stack · reminders survive breaks (medical rhythm ≠
  engagement) · master toggle sweeps them.
- **P3 today** (ad9e0ba) — MedicationLog chokepoint (four truths
  converge: event, observation, legacy key, today's check +
  reminder retirement) · THE DOSE SHEET (facts eyebrow, serif
  title by route, six site cells with the rotation PRE-SELECTED —
  visible = honest, note, one ink mark, "not today" reasons, late
  face, oral face with the label rhythm line) · CarePlanEngine
  daily-cadence law (a rhythm rides as first support outside the
  cap; gentle days still lead with the dose) · row nouns per route
  ("take today's shot" / "take today's pill") · evening "yes"
  through the chokepoint ("no" stays an answer, not a skip) ·
  skipped compresses the row with "not today". **95/95 touched
  suites; injectable + oral sheet frames verified on-sim.**
- **P4 onboarding** (46aaa5a) — four consult beats for the CURRENT
  cohort, consumer door (route → which → dose chips off the label
  ladder → weekday → reminder hour; every beat has an out; clinic
  door skips all) · MedicationOnboardingBridge (pure; all-skips
  build NOTHING so the evening shot-day ask keeps its job) ·
  onb_med_* keys join both sweeps. **25/25.**
- **P5 regimen home** (fed73d4) — facts as doors (every save a
  version), next-dose line, THE RECORD (era rows off the chain),
  pause/stop with reasons, later-enable wizard, compound changes
  clear the dose, care face + record, settings value speaks
  name · dose. **Home frame verified with the history seed — the
  version chain renders as readable eras.**
- **P6 patterns + becoming + side effects + coach** (b021ac1) —
  MedicationPatternEngine (after-change lead read, after-dose
  cluster, protein day-after dip; ≥3 floors; timing grammar) ·
  SideEffectLog/-Sheet (gentle words, three severities, tap to
  record, tap to clear) · the becoming medication tile (compact,
  tally strip with honest gaps, DOSE ERAS ledger in her unit,
  numeric-suppression honored) · chat envelope medication{} block
  (compound never brand) + EF timing-empathy rule (founder
  deploys). **38/38 touched suites.**
- **P7 sync** — absorbed into P1 by design (models and their sync
  shipped together).
- **P8 the loop** — below.

## Frame-caught fixes

- The evening close auto-presented over the first Home capture
  (the evening law working; `--uitest-force-day` is the film's
  door).
- The QA sim carried a prior session's accessibility text size —
  Home held its layout at that size (the v21 floors working);
  reset for the standard captures.
- `reminderLine` range-pattern build break → plain conditionals.
- `BecomingTiles.planLine` switch non-exhaustive on the new kind.
- The stray SwiftUI edit artifact in CoachContextAssembler removed
  same-commit.

## Founder gates

- Apply `supabase/migrations/20260809090000_v24_medication_platform.sql`
  (dose_events + regimen_plans additive columns). Until then sync
  defers gracefully, local-first; v24-created regimens sync after.
- Deploy `supabase/functions/jeni-chat` (the medication
  timing-empathy prompt rule rides the next deploy).
- Device walk: notification actions on a locked device, a real
  timezone crossing, the dose sheet in-hand.
- Review §11 tradeoffs (no PK curve, no site photo, no lock-screen
  skip, era LEDGER over annotated curve in v1).

## Deferrals (honest)

- **About-to-start (considering) config beats** — v1 keeps zero
  configuration for the considering cohort (nothing exists to
  configure; the settings later-enable door is the path). The law
  §7's about-to-start sketch stands as design, unbuilt.
- **B2B "add something your clinic hasn't set"** — the v8
  one-medication-truth invariant holds this era; a self plan
  alongside an active care plan stays blocked (documented in
  applySelfRegimen's guard). Needs its own care-loop design pass.
- **The dose-era ANNOTATED CURVE** — v1 ships the era LEDGER in
  the tile detail (honest, floor-gated, zero new chart machinery);
  the annotated weight curve with era seams is queued as a
  JeniChart overlay pass.
- **Widgets** (the category's proven retention surface) — no
  widget infrastructure exists app-wide; its own future era.
- **Per-symptom notes sync** — notes ride the device-local payload
  (the observations table has no payload column by S1 design);
  symptom + severity sync.
- **Chip→row flash + XXXL floors on the three new sheets** — the
  loop's remaining sweep (below).

## The loop's runs

- **Full unit suite: 587/587** (was 557 pre-era; +30 platform /
  pattern / bridge tests). Zero regressions.
- **Consult walker (GLP-1 current), erased sim: GREEN** — the four
  medication beats answer and route end-to-end to the paywall
  (`testWalkV8ToPaywall`, TEST_RUNNER_GLP1_COHORT=current; the
  walker learned the beats: shots → ozempic → 0.5 mg → tuesday →
  evening).
- **Frames**: THE DOSE SHEET injectable + oral (medium) — facts
  eyebrow, pre-selected rotation cell, label rhythm line on oral;
  THE REGIMEN home with the era record off the version chain;
  Becoming with the compact medication row.
- **XXXL floors**: the dose sheet wraps everything (eyebrow, serif
  title, site cells two-up with grown text) — no truncation; scroll
  carries the rest. Home held a prior session's accessibility size
  without complaint (the v21 floors).
- **The mark-ceremony film** (4fps frame dump, 59 frames): rise
  over the ring → pre-selected cell → mark → "taken" → dismissal →
  the row compressed with its check. Frame-caught: the button
  label's default text swap double-rendered mid-crossfade → fixed
  with `.contentTransition(.opacity)`.
- The v8 timestamp reward now lives on the SHEET's taken face
  ("taken · 8:04 pm"); the row compresses per the v21 grammar —
  both laws honored across their surfaces.
- No other UI leg touches the medication surfaces (grep-verified);
  the row's module change (regimen → dose sheet) breaks nothing.
