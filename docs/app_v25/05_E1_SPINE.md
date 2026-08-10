# E1 — THE SPINE · architecture + decisions (living doc)

2026-08-10 · execution era. Parent: `00_THE_SYSTEM.md` §6-§8 ·
`04_FIRST_ERA.md`. Evidence lands in `06_E1_EVIDENCE.md`. This doc
records what was BUILT and WHY — including where implementation
reality overruled the plan (founder law: direction, not scripture).

## 0 · reconnaissance corrections to the plan (recorded)

1. **WeeklyReview (v4) is the proto-spine.** `Program/WeeklyReview.swift`
   already holds: due logic (`dueWeekIndex` — week-closing evening +
   3-day grace, break-aware, ≥3 elapsed days), a CLOSED conservative
   proposal set (`propose()` — protein ease/firm with provenance
   floors, moves ease, weigh soften, intent pick, hold steady),
   consent application (`apply()` → engine knobs), JSONL records, and
   the week-slice assembler. THE WEEKLY READ therefore EVOLVES this
   engine instead of shipping a parallel one. What it lacks is
   exactly E1's mandate: durable authority-carrying memory (knobs are
   loose UserDefaults ints/bools — `plan.proteinAdjustG`,
   `plan.sessionsAdjust`, `plan.weighSoftened`), sync, medication/
   era awareness, adaptive movement, and any telemetry.
2. **kcalTarget is NOT a program fact.** The plan's §6 sketch listed
   it; TargetsService reality says calories are RE-DERIVED from
   latest weight + plan-implied rate (that recomputation was a
   deliberate v2 defect fix). Freezing kcal as a fact would
   reintroduce the frozen-target bug. Facts store ADJUSTMENTS and
   GOALS that have no formula (stepGoal, proteinAdjust ±10g,
   movesAdjust, weighCadence, loggingMode, notificationPosture,
   walkTiming, readAnchor) — formulas stay live, provenance stays
   true. (The walk's seed-order kcal drift 1,473↔1,596 is explained:
   different seeded weights → different derivation. Not a bug in the
   fact system's scope.)
3. **The walking beat rides the existing beat vocabulary** —
   CarePlanEngine composes `ProgramDayPrescription` beats through
   protocol-capped slots; a steps-shaped beat already exists in the
   vocabulary. The v7 "steps are receipts, never tasks" law is
   SUPERSEDED here by ledgered decision (00_THE_SYSTEM §9 MOVEMENT):
   the adaptive walking action is an action precisely because it now
   carries a target the program OWNS and adapts — a passive count
   stays a receipt; a gap against her consented goal is an ask.
4. **pbxproj mechanics**: objectVersion 77, classic references (no
   filesystem-sync groups) — every new file needs its 4 entries;
   done per commit-batch, pbxproj last. Test files register in the
   plankAITests target the same way; `TestModelContainer.shared` is
   the ONE in-memory container (new @Model types must join its list
   or every SwiftData test hangs).

## 1 · PROGRAM MEMORY (B1)

### the model

`ProgramFactRecord` (@Model, synced `program_facts`): one row = one
version of one fact. Fields: id · userId · kind · value (canonical
string encoding; jsonb server-side) · authority · basis · source ·
previousFactId · acceptedAt · endedAt · endReason · createdAt ·
updatedAt · pendingUpsert.

- **kind** (closed v1 set): `stepGoal` (Int absolute) ·
  `proteinAdjust` (Int, clamped ±10 — the v4 law, now versioned) ·
  `movesAdjust` (Int −1…+1) · `weighCadence` (`standard|softened`) ·
  `loggingMode` (`standard|lighter`) · `notificationPosture`
  (`standard|quieter`) · `walkTiming` (`afterMeals|anytime|off`) ·
  `readAnchor` (`auto|weekday:N`).
- **authority**: `prescribed | preferred | recommended | defaulted`.
  Render precedence: prescribed › preferred › recommended ›
  defaulted (00_THE_SYSTEM §2).
- **basis**: `assigned | stated | inferred | defaulted` — where the
  VALUE came from.
- **source**: `onboarding | migration | user | weekly_read | clinic
  | sync`.

### the semantics (the no-silent-overwrite law, structural)

- **One active chain per (kind, authority).** A clinician
  prescription NEVER ends a preferred row; it out-renders it. When
  the prescription ends, the preferred value RESUMES rendering —
  nothing was silently lost. Supersede happens only within the same
  (kind, authority) chain.
- **The resolver** returns the head: active row of the
  highest-precedence authority for a kind, else the coded default.
  Engines never read raw rows.
- **Writes**: ONE chokepoint `applyFact` (RegimenService's law
  generalized): same-day coalescing within a chain (corrections
  settle in place; versions are settled states), otherwise end +
  insert linked by previousFactId. iOS writes `prescribed` NEVER
  (server/sync-hydrate only — S4 law); `recommended` rows exist ONLY
  with acceptedAt set (an unaccepted offer is not a fact — offers
  live in weekly_reads); `preferred` = she authored the value
  (settings/pace); every write records source.
- **Recommended clamps** are tighter than preferred/prescribed:
  stepGoal recommended clamps 2,500-8,000 (r4); preferred may
  exceed (her body her call); prescribed passes through (clinician
  authority, rendered verbatim like the b2b regimen).
- **Bootstrap (migration moment, source=migration)**: reads the v4
  knobs (`plan.proteinAdjustG` → proteinAdjust/preferred·stated —
  she consented to it; `plan.sessionsAdjust` → movesAdjust;
  `plan.weighSoftened` → weighCadence) + the current steps goal
  (plan tier / 7,500 → stepGoal/defaulted) ONCE, then engines read
  heads. Old knobs stay written-through for one era (belt and
  braces) and die in E-next. Day-one output equivalence is
  test-pinned.

## 2 · THE WEEKLY READ (B2) — evolution of WeeklyReview

- **Anchor ladder** (generalized weekly rhythm — dose day preserved
  as insight, not dogma): explicit `readAnchor` fact if set →
  else the morning after her weekly-injectable dose day (weeklyAnchor
  regimen only) → else the enrollment-relative week closing the v4
  law already owns (program day 7/14/… evening + 3-day grace). Daily
  medication and non-medication users get a coherent week with ZERO
  GLP-1 leakage; weekly injectors get the physiological monday.
- **Grammar**: what happened (her week vs her own trailing window) →
  what matters (≤2 floor-gated observations, provenance-stamped) →
  one teaching line (12-line authored v1 set) → ONE offer from the
  closed set → consent (accept / "keep it as is", equal rank) →
  `applyFact(source: .weekly_read, authority: .recommended,
  acceptedAt: now)`.
- **Offer engine**: `propose()` evolves — keeps v4's conservative
  rules + provenance floors, adds: stepGoal recalc (percentile
  engine), loggingMode lighten (sparse-week answer), walkTiming,
  notificationPosture; drops intentPick into the compost (WeekIntent
  stays shipped but the read offers the E1 set first). Decline =
  recorded in the read record; same-kind cooldown 2 weeks.
- **Records**: `WeeklyReadRecord` (@Model, synced `weekly_reads`):
  window, anchor used, shown facts (compact), offerKey, decision,
  factId written (when accepted). v4 JSONL `signedWeeks` respected
  at bootstrap (no re-asking already-signed weeks).
- **Surface**: evolves ReSigningView's slot (Becoming) + the
  editorial arrival grammar; detailed in the build log below as
  built.

## 3 · ADAPTIVE MOVEMENT (B3)

- `AdaptiveStepsEngine` (pure): recommendedGoal = 60th percentile of
  her last 9-10 RECORDED days (days with >500 steps count as
  recorded; carry-habit self-correcting), clamp 2,500-8,000, round
  to 50, never moves >±15% in one recalc (conservative progression +
  relief), recalc offered at the read — never silently applied.
- The walking beat: composed by CarePlanEngine when gap is within
  reach (≤40% of goal remaining, after 14:00 local) as a SUPPORTING
  move with auto-complete on goal cross; post-meal variant when a
  ≥400 kcal plate logged 60-120 min ago and walkTiming == afterMeals.
  Never on gentle days. Absent when goal already crossed (the
  "already enough" state renders in the instrument, not as a beat).
- HealthKit workout absorption: any HKWorkout ≥10 min today marks
  the movement beat autoCompleted (never re-asked).

## 4 · THE NOTIFICATION BRAIN (B4)

(design held from 04_FIRST_ERA §B4; integration map lands from
recon in audit/04_notification_map.md; build log will record the
wrap points. Medication scheduling code path stays untouched — the
brain wraps it as an exempt-lane source.)

## 5 · TELEMETRY (B5)

Event families per 00_THE_SYSTEM §14; every payload key audited
against the hygiene allowlist test. Funnels: read eligible→surfaced→
opened→offer→decision→fact→adherence; movement surfaced→completed;
notification candidate→delivered→actioned; program recommendation→
accepted/declined/overridden.

## 5.5 · build log (as shipped)

- **P1 PROGRAM MEMORY — SHIPPED** (commits 86284fa · 5020ec5 ·
  943bb37). Pure core (`ProgramFacts.swift`: kinds, authority
  ladder, clamps, head resolution — 20 tests) → `ProgramFactRecord`
  in PlankSync + BOTH containers → `ProgramFactStore` chokepoint
  (chains, same-day coalesce, consent gate, prescribed-write
  rejection, endFact/resume, resolved-head legacy write-through,
  bootstrap w/ cross-device guard — 16 tests) → sync trio
  (upsert/hydrate w/ prescribed-server-authoritative split, sweep
  family, AppSync pass-through, hydrate-then-bootstrap order) →
  migration `20260810090000_v25_e1_program_spine.sql` (program_facts
  + weekly_reads; client role can never author/become prescribed —
  the S4 law in the schema) → TargetsService steps reads facts-first
  (`stepGoalResolved`). **Full suite 623/623 — zero regressions**
  (the equivalence pin: no fact written = pre-E1 behavior).
- P1 scope note: StepsService's 7,500 constant + PrescriptionEngineV2's
  baked tier goal intentionally NOT converged in P1 — P2's adaptive
  engine replaces both consumers wholesale (smaller honest step).
- **P2 ADAPTIVE MOVEMENT — SHIPPED** (commits 4de2ad3 · 1666251).
  `AdaptiveStepsEngine` (nearest-rank 60th percentile of her own
  recorded days >500; ≥5 recorded or nil — never a guess; ±15%
  conservative move; relief structural; the ONE clamp law shared —
  12 tests). THE WALKING ACTION composes in CarePlanEngine as a
  behavioral SUPPORT inside the cap (yields on full dose days):
  requires an OWNED stepGoal fact (consent-true rollout — no fact,
  no walk; days change only after she accepts a goal or sets a
  preference), gap within reach (200 ≤ gap ≤ 40%), afternoon gate
  lifted by the post-meal window (plate ≥400 kcal, 60-120 min ago),
  absorbed by any HealthKit workout ≥10 min
  (MovementService.workoutMinutesToday), walkTiming="off" kills it
  (11 new engine tests). Voice: walkGap (gain-frame, minutes
  translation) + walkAfterMeal (glucose framing, no calories).
  Beat rowTitle .steps → "take a walk" (itemKey untouched — SQL
  CHECK). HomeView auto-complete threshold fixed to the RESOLVED
  goal (was the baked tier number — a consented 5,150 goal would
  have completed at 7,500). Suite 646/646.
- **D7 (recorded)**: ONE walk beat whose REASON adapts (gap vs
  post-meal), not two beats; walkTiming default (no fact) = anytime;
  "afterMeals" narrows to the window; "off" removes. DECLINED: a
  separate post-meal beat kind (two rows for one behavior).
- **P3c THE OFFER ENGINE — SHIPPED**: `WeeklyReadOffers` (12 tests)
  — v4 propose() DELEGATION (its laws + tests preserved verbatim;
  clinical rules lead), then the step-goal recalc (first-goal =
  the walking action's consented onboarding; recalibration only
  when the move is ≥250 — a wobble is not an offer), then the
  sparse-week logging lighten (plates ≤2 of ≥5 days; the day-29
  décrescendo's first face). Declined kinds cool down (the caller
  reads 2-week windows from records); a declined kind can never
  resurface via the fallback. `applyAccepted` writes ONLY through
  ProgramFactStore (recommended + acceptedAt; v4 protein/moves
  deltas computed against the resolved head then re-clamped;
  weighSoften → the word fact; intentPick stays the v4 week-scoped
  knob by design — not program memory). holdSteady writes nothing.
- **P3a THE ANCHOR LADDER — SHIPPED**: `WeeklyReadAnchor` (pure,
  12 tests): preference (readAnchor weekday:N, 3-day grace) ›
  dose-day (the morning AFTER a weekly injectable's anchor; daily
  regimens pass nil by construction — zero GLP-1 leakage, test-
  pinned for daily-med + non-med users) › enrollment (the v4
  dueWeekIndex law preserved verbatim: slot-6 evening + slots 0-2
  grace). Window = the 7 days ending before the due day; signed
  windows + breaks silent; a no-anchor no-program user gets nothing
  (no fake intelligence).

## 6 · decisions (running ledger)

| # | decision | why | declined |
|---|---|---|---|
| D1 | evolve WeeklyReview into the read | it IS the consent pattern (founder: reuse the strongest); knobs→facts is the actual gap | parallel new engine (two consent languages) |
| D2 | kcal never a fact | live derivation is a shipped defect-fix; freezing regresses it | plan §6's kcalTarget listing |
| D3 | chain per (kind, authority); cross-authority render resolve | no-silent-overwrite made structural; revocation auto-resumes preferences | single chain w/ authority field on head (loses the preserved preference) |
| D4 | accepted recommendation stays authority=recommended + acceptedAt | provenance: "jeni proposed, she accepted" ≠ "she authored" | collapsing accepts into preferred |
| D5 | steps beat = action (supersedes v7 receipts-only law for the OWNED goal) | the gap against a consented target is an ask; ledgered in §0.3 | keeping steps passive (kills the walking action) |
| D6 | anchor ladder with enrollment-week default | zero GLP-1 leakage; v4 continuity for existing users; dose day only where physiological | dose-day-or-sunday for everyone |
