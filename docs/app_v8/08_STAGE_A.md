# app v8 — STAGE A ONBOARDING: THE IMPLEMENTATION PLAN (2026-07-29)

Founder go received. Scope = 06_ONBOARDING Stage A exactly: reframe
over the tested v5 machine, minimal new state, typed clinic-door
seam dormant. v5's mechanics (typed machine, five acts, rulers,
cross-offs, fears, receipts, her-file, signature, hold-to-build,
reveal, paywall) are PRESERVED — this plan lists every touch.

## 1. What changes (and what only changes words)

**Copy-only (no state):**
- C1 · The contract sentence lands in Act 0 (the arrival beat's
  sub/credibility line): "jeni builds your care plan around your
  real days." — tested in-sequence, not in isolation.
- C2 · Verb law reaches v5's asks: the four "snap …" ask sites →
  "add …" (the demo keeps "snap" as the camera's name).
- C3 · The reveal reframes to "your care plan": projection +
  first-week rails speak care-plan components causally; zero
  mechanic changes.
- C4 · Expectation line ON the projection (no new screen):
  educational milestone framing — "the first milestone that
  changes health markers is 5-7% — for most people that arrives
  well before a final goal. everyone's pace is her own." Goal
  stays visible; no promise, no timeline, no disclaimer wall.

**New state (the minimum):**
- B1 · `shotDay` beat — GLP-1-current branch only, ONE screen
  after `appetiteRhythm`: "your shot day, if you want jeni to
  hold the rhythm" — weekday words + "skip for now". CLINICAL
  register (ink contrast, no stickers/hearts/rose, quiet).
  Writes `onb_v5_shot_day` ("mon"… / ""), ISO int derived.
- B2 · `supports` beat — all branches, after `dietary`: "do you
  already take any of these? · optional" — broad recognizable
  categories (protein powder · a multivitamin · vitamin d ·
  fiber · magnesium · electrolytes) + none. Multi-select CSV
  (`onb_v5_supports`), skippable, NEVER implies recommendation;
  nothing renders in-plan (FR8 law: supports render only when a
  care team authors them). Protein stays the foregrounded
  tracked support regardless of answers.
- B3 · `OnboardingContext` typed entry seam — `.consumer`
  default; `.clinicEnrollment(...)` case exists, unreferenced by
  any UI (the dormant door; no mock clinic surfaces).

## 2. Data handoff (completion)

At `handleOnboardingComplete` (the existing single completion
path):
- If `onb_v5_shot_day` picked AND cohort current AND
  `RegimenService.activeMedicationPlan` is nil-or-self →
  `setShotDay(iso)` (authority stays "self"; the shipped guard
  already refuses care_team mutation and never mints a
  duplicate). No pick / no med → NO regimen, NO medication
  surface anywhere (the row composes only off a real plan).
- `onb_v5_supports` stays an intake fact (personalization +
  future clinician supports authoring); creates NO records, NO
  daily UI, NO pill checkboxes.
- New keys join the `onb_v5_` sign-out sweep automatically
  (prefix rule).
- Everything else (plan creation, cohort keys, ClinicalBaseline,
  targets) unchanged — the first Home composes from the SAME
  served-protocol runtime as every later day.

## 3. Register rules for the new beats

B1 is the one clinical surface in onboarding: bare words, ink
selection, one privacy caption ("only you see this. never named
in notifications."), no celebration on advance (standard
transition, no act-receipt inclusion). B2 stays in the warm food
register (it is a food-adjacent fact, not medication) but plain:
no claims, "none of these" first-class, skip visible.

## 4. Test matrix (the brief's 20, mapped)

Unit: router chains (current w/ + w/o shot day; supports skip/
multi; fork integrity for past/considering/none), completion
handoff (regimen created only when picked; care_team plan
untouched — reuse the authority tests' managed fixture; no dup
on re-complete), served-protocol independence (onboarding never
reads network; CareProtocolStore fallback covered by S2 tests).
Walker: legs per cohort (TEST_RUNNER_GLP1_COHORT current/past +
default) driving the new beats incl. skip paths + screenshot per
beat; paywall reach asserted. Sim reel: both cohorts end-to-end,
reveal ↔ first-Home comparison, dynamic-type + SE spot checks.

## 5. Phases

P1 anchors (agent map) → P2 copy (C1-C4) → P3 machine (B1-B3:
store keys, router, screens, dispatch) → P4 handoff + guards →
P5 tests (unit + walker) → P6 sim reel + fixes → P7 docs/STATE.
Each phase builds green before the next.

## 6. Explicitly not done (named)

Clinic UI of any kind; medication names/doses at intake; supports
records or daily supports UI; S3 reconciliation flow (the shipped
guard IS the safe handoff); pricing/paywall changes; notification
copy changes. Metrics to watch post-release: funnel completion at
the two new beats, shot-day pick rate, supports skip rate,
D1 dose-row engagement for current-cohort completers.
