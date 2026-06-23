# Medical-grade survey & analytics audit — toward a GLP-1 partnership app

**2026-06-23. Reference / direction artifact, not an implementation order.**

Founder direction: JeniFit aims to evolve into a **GLP-1 partnership app** with
medical-grade survey questions, content, and analytics. The bar is *are we asking
the right questions, providing the right tools, giving the right analysis, really
helping manage + lose weight* — clinical efficacy first, soft/de-shame register
second. This audits the onboarding intake against a GLP-1-management-grade rubric.

Compliance floors that constrain every item below: Apple 5.2.1 (don't look like a
medical service / device), FTC NextMed (no drug-equivalence claims), **no drug
brand names on app surfaces**, no first-party numeric weight-loss claims, no
"GLP-1 alternative" framing (FDA Feb 2026). Stay a behavior/management companion,
not a prescriber. Keep it feeling like a consumer app, not a clinical form.

## ⚠️ The load-bearing finding (verified) — persistence

The cohort signal **never reaches the backend.** `glp1Status`, `hormonalStage`,
`sleepHours`, `stressLevel`, `eatingCadence/Window`, `foodRelationship` live only
in local `@AppStorage`. In the sync layer (`PlankApp/Sync/AppSync.swift`,
`Packages/PlankSync/.../SyncService.swift`) they appear **only** in
`clearOnboardingUserDefaults()` (the sign-out sweep, ~line 550) — they are **not**
in the synced `UserRecord` / `upsertUser` payload. So the entire GLP-1 cohort
strategy routes on a signal Supabase can't see, and no cohort analytics is
possible. There IS good infra to build on: an append-only `WeightLogRecord` and a
`ProgramPlanRecord` snapshotting start/goal weight + goalDate.

**This is P0 and a prerequisite — fix persistence before adding any clinical field,
or the new fields are also stranded on-device.** App-side: add the cohort fields to
`UserRecord` + write them at upsert + hydrate them back. Backend: add nullable
columns to the profiles table (needs founder Supabase credential / migration).

## Current intake (verified in OnboardingView.swift)

Motivation/identity (goal, identityFeeling, NSV); attribution; history (triedBefore,
priorAttempts #, priorWin); food (relationship, cadence, window, cuisine); activity
(movementBaseline, categorical); biometrics (gender, age, height, weight, goal weight,
derived BMI shown not stored); sleep bands; stress; hormonal stage (incl. postpartum);
GLP-1 status (class only: none/considering/past/current — no brand, with duty-of-care
inline cards); 3 psychometric fears; pace choice. The duty-of-care inline-card pattern
(cases 163/164/167) is strong scaffolding — care + competence, not warning.

## 1. Critical intake gaps (clinically load-bearing, ordered)

- **A. Pregnancy / breastfeeding / trying-to-conceive (safety gate).** Highest-liability
  omission. GLP-1s are contraindicated in pregnancy; deficit programming is too.
  `hormonalStage` has "postpartum" but no pregnancy/lactation flag or postpartum weeks.
  Add as a branch on the hormonal screen → route to a gentle/maintenance track + neutral
  "talk to your clinician" card (reuse the postpartum-card pattern). Never give med
  guidance.
- **B. Disordered-eating screen (safety + GLP-1-cohort risk).** Restriction programs are
  contraindicated with active EDs; the cohort overlaps with binge/loss-of-control eating.
  `foodRelationship` is a cue, not a screen. Use **SCOFF** (5 yes/no) reframed in the
  brand voice; ≥2 positives → internal soften-the-program flag + resource card, never a
  label, never a block. **Clinical + legal sign-off before shipping.**
- **C. Current GLP-1 detail: class/route, duration, titration phase.** The on/off status
  can't distinguish a week-1 titrating user (max nausea, min intake, lean-mass risk) from
  a 2-year maintenance user — yet the strategy bets on cohort routing. Capture class/route
  (weekly inj / daily inj / oral / not sure), duration bands, phase (just started /
  increasing / stable). **No brand names; self-reported; non-actionable — never recommend
  or comment on a dose.**
- **D. Side-effect / tolerability tracking (recurring).** Tolerability drives
  discontinuation; "your nausea is easing / protein is low" is the most credible companion
  surface. No symptom model exists today. Onboarding sets a baseline; recurring capture
  belongs on the Becoming dashboard. Frame as wellbeing check-ins, not AE reporting.
- **E. Comorbidities (risk stratification).** T2D/prediabetes, PCOS, thyroid, hypertension/
  cardiac — these change realistic loss rates (the pace projection currently over-promises
  for PCOS/hypothyroid → clinical-honesty + FTC risk) and should gate intensity. Highest
  Apple 5.2.1 risk (looks like a medical service) → keep short, optional, framed "so your
  plan is realistic for your body," store as modifiers only, no risk score/diagnosis output.
- **F. Weight history / trajectory.** Current weight is a point; trajectory is the signal.
  Highest adult weight + direction of travel (climbing/stable/coming down). Recent rapid
  loss (esp. on a GLP-1) changes lean-mass risk + pacing. Intake captures zero history.
- **G. Goal-weight realism / readiness + timeframe.** No guardrail if a user sets a
  clinically-low goal (ED red flag + claims liability). Extend case 286: if goal BMI < ~18.5,
  soft "set a first milestone instead?" — reframe, don't block.
- **H. Lean-mass / protein baseline + injury gate.** GLP-1 lean-mass loss is the 2026
  headline; protein-floor + resistance coaching is the defensible, non-prescribing value-add.
  No protein baseline, no injury/joint screen (intensity = pace alone).

## 2. Sharpen existing (close but not medical-grade)

- `glp1Status` → add class/duration/titration/side-effects (the #1 sharpen, §1C/D).
- `goalWeightKg` → readiness/realism/timeframe gate (§1G).
- `currentWeightKg` → add history (§1F).
- `hormonalStage` "postpartum" → weeks + pregnancy/lactation branch (§1A).
- `foodRelationship` → keep as the warm cue, NOT a substitute for SCOFF.
- `movementBaseline` → add injury/joint gate.
- `priorAttempts`/`priorWin` → also capture methods tried (incl. prior weight meds/surgery
  as history, not current Rx).

## 3. Analytics — outcomes a credible partner tracks

Today the sync layer tracks engagement, not outcomes or the cohort signal.
- **P0 data-model:** persist cohort + intake to Supabase (the ⚠️ finding); store BMI +
  raw biometrics + intake weight history.
- **Outcomes scoreboard:** %TBWL over time (per user + cohort); **actual vs. predicted
  trajectory** (the pace screen projects; nothing compares — highest-value analytic);
  adherence/engagement segmented by `glp1Status`; side-effect-burden trend; protein-floor /
  resistance adherence for the GLP-1 cohort; **retention by cohort + titration phase** (ties
  to the known W1→W2 collapse); goal-realism distribution.
- Internal analytics are fine; any user/marketing-facing aggregate cannot be a first-party
  numeric WL claim or imply drug-equivalence — keep dashboards internal pending legal review.

## 4. Prioritization

**P0 (partner-credibility prerequisite)**
- Persist cohort + clinical intake to Supabase — *safe to start app-side now; DB migration
  needs founder credential.* Highest ROI, lowest risk. **Do first.**
- Pregnancy/breastfeeding safety branch — *light legal review of copy*; routing pattern exists.
- GLP-1 class + duration + titration — *safe now* (class/route only, self-reported, no brand).
- %TBWL + actual-vs-predicted analytics — *safe now, internal.*

**P1**
- Disordered-eating screen (SCOFF) — **clinical + legal review before shipping.**
- Side-effect tracking (model + Becoming tile) — *review AE-framing.*
- Comorbidity multi-select — *Apple 5.2.1 review.*
- Goal-weight realism guardrail — *safe now.*
- Lean-mass/protein baseline + injury gate — *safe now.*

**P2**
- Weight history at intake; sleep-quality item; contraception detail; prior-methods expansion — *safe now.*

**Sequence:** persistence first, then safe-now intake, then the review-gated safety screens.

## 5. Validated instruments

- **SCOFF** (5 yes/no) — best consumer fit for the ED screen; reframe in brand voice; ≥2 =
  internal flag + resource card, never a label. (Prefer over EAT-26 — too clinical.)
- **Confidence ruler** (single 0–10 "how confident are you that you can stick with this?")
  — MI-derived, predictive of adherence, trivially consumer-friendly, clean analytics
  covariate. The evidence-based version of the cut `commitConfidence` Q — and unlike that
  one it has a real downstream consumer (adherence modeling). *Safe now.*
- **PHQ-2** (depression, 2 items) — clinically relevant but sharply raises the 5.2.1
  "medical service" profile + duty-of-care burden; defer to an explicit clinical partnership.

Posture: lightweight validated *items* (confidence ruler, single sleep-quality), not full
clinical batteries, with SCOFF the one full screen worth the friction. Every new field
self-reported, non-diagnostic, brand-name-free, framed "so your plan fits your body."
