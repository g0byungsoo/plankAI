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

## 6 · decisions (running ledger)

| # | decision | why | declined |
|---|---|---|---|
| D1 | evolve WeeklyReview into the read | it IS the consent pattern (founder: reuse the strongest); knobs→facts is the actual gap | parallel new engine (two consent languages) |
| D2 | kcal never a fact | live derivation is a shipped defect-fix; freezing regresses it | plan §6's kcalTarget listing |
| D3 | chain per (kind, authority); cross-authority render resolve | no-silent-overwrite made structural; revocation auto-resumes preferences | single chain w/ authority field on head (loses the preserved preference) |
| D4 | accepted recommendation stays authority=recommended + acceptedAt | provenance: "jeni proposed, she accepted" ≠ "she authored" | collapsing accepts into preferred |
| D5 | steps beat = action (supersedes v7 receipts-only law for the OWNED goal) | the gap against a consented target is an ask; ledgered in §0.3 | keeping steps passive (kills the walking action) |
| D6 | anchor ladder with enrollment-week default | zero GLP-1 leakage; v4 continuity for existing users; dose day only where physiological | dose-day-or-sunday for everyone |
