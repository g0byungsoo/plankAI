# app v8 — THE CARE-PROTOCOL ARCHITECTURE (2026-07-28)

The data architecture that lets the consumer app today and the
clinic platform tomorrow run on ONE set of records. Grounded in:
the pipeline + persistence audits (this session), the B2B
convergent object model (02_COMPETITORS §A7), the CY2026 billing
atoms (01_RESEARCH §A5), and adherence law (§B8). Rule of the
pass: **additive only; behavior-identical under the default;
nothing clinic-shaped renders.**

## 1. Current state (audit facts the design stands on)

- The day is composed by two engines in series:
  `PrescriptionEngineV2` (which beats exist — schedule floor) →
  `CarePlanEngine` (which render, in what role, at what volume;
  pure, typed, brand-free Input/Plan/Move records). The item
  vocabulary is the compile-time `ProgramDayPrescription` enum
  (9 cases; `water`/`plank`/`measurements` fully specced but
  never emitted — latent rows).
- Completion is already generic + synced:
  `ProgramDayCheckRecord(userId, programPlanId, programDay,
  itemKey, state, payload)` → `program_day_checks`. New protocol
  items ride it with ZERO schema change.
- Subjective answers are day-keyed UserDefaults strings
  (`day.reflection.` `day.sit.` `day.dose.` `day.note.`
  `plan.tonight.`) — partially synced (feeling+note via
  `day_reflections`), inconsistently swept (**`day.dose.` is
  missing from the sign-out sweep — defect**), and `day.dose.`
  is **written but never read** (write-only disclosure — the
  anti-pattern v7 outlawed). WeeklyReview records are
  device-local JSONL (die with the phone).
- Every clinical constant is a hardcoded `static let` (protein
  g/kg + clamps, pace floors, kcal floors/factors, step goals,
  band zones 1.4/2.3, weigh cadence, tone thresholds, promotion
  thresholds) — single-sourced but un-injectable. Rules and
  jeni's prose are fused inside the engines.
- No tenant dimension anywhere; no medication/supplement
  entities (medication exists only as cohort tags); the composed
  care plan is never persisted; `jenimethod_lessons` (read-all
  jsonb rows) is the one existing served-content pattern.
- SwiftData law: new @Models live in the PlankSync package or
  the app target (PlankFood cross-package registration hung iOS
  17); test containers enumerate the FULL model list; container
  registration at `PlankAIApp.swift:891-919`.

## 2. Target object model (the platform vocabulary)

Adopted from the teardown's convergent schema, unified with our
engines. Consumer app = the **org-null tenant**; a clinic later
arrives by filling fields, not migrating schemas.

```
CareProtocol      versioned config: every clinical constant +
                  item scheduling rules + ask caps + voice-free
                  thresholds. `.default` == today's shipped
                  behavior. (S1: bundled Swift value; S2: hydrated
                  from `protocols` rows; S4: org-authored.)
RegimenPlan       kind[medication|supplement], displayName
                  (HER words, sensitive), scheduleRule
                  (weeklyAnchor|daily|asNeeded), anchorWeekday
                  (the shot day), timeOfDay?, doseStageLabel?
                  (her words — never app-authored dosing),
                  active window, sourceProtocolId? (null =
                  self-created), orgId? (null).
Observation       append-only typed record: kind, dayKey,
                  effectiveAt, valueText/valueNum/unit, payload,
                  source[manual|derived|healthkit|photo],
                  userId-scoped. Absorbs the UserDefaults string
                  families + dose events + future waist/
                  hydration/care events. THE chart.
CareEvent         = Observation kind. severity + provenance +
                  disposition in payload. Consumer-side renders
                  as today's care lines; clinic-side becomes the
                  escalation feed (dormant).
ComposedDay       the sealed day's asked-set, persisted as ONE
                  observation (kind daySealed) — "asked vs done"
                  for future care-team reads at zero new
                  machinery.
ProgramPlanRecord (exists) = Enrollment. ProgramDayCheckRecord
                  (exists) = TaskInstance/completion.
Signal            (exists, in-memory) — v6 engine output;
                  severity mapping lands with CareEvents.
ConsentGrant/Org/CareTeam/FormTemplate — S3/S4; named, not built.
```

Provenance law extends: every Observation knows its `source`;
every reading is classifiable device / HealthKit-relay /
patient-keyed (the CY2026 billing atom + the clinician-trust
floor).

## 3. S1 scope (this pass, exact)

**3a. CareProtocol config** (`Program/CareProtocol.swift`, pure
Codable struct, no I/O):
- Gathers: protein perKg by cohort + clamps (fixing the
  small-body violation: floor = min(clampLo, round5(perKg×kg))
  branch — the panel's one-line honesty fix), pace floors, kcal
  floors/activity factors, step goals, band zones, weigh
  cadence by cohort, tone thresholds (sleep<6h, daysAway≥4),
  promotion thresholds (rapid-loss >1%/wk, protein deficit
  ≥25g), ask caps (moves ≤3, offered ≤2), titration-support
  window (weeks 1-8), hydration-ask gating.
- Engines gain a `protocol:` parameter defaulting to
  `.default`; literals move; **every existing test must pass
  unchanged** — that equivalence IS the review artifact a
  medical director later signs.

**3b. ObservationStore** (`ObservationRecord` @Model in
PlankSync + `observations` table, own-row RLS):
- Append-only API: `record(kind:dayKey:value:source:)` +
  typed reads (`latest(kind:)`, `series(kind:window:)`,
  `count(kind:matching:window:)` — the "queasy 3 of last 7"
  query the clinic panel demanded).
- Write-through: evening close writes BOTH legacy key (until
  readers migrate) and observation; one-time backfill sweeps
  existing day-keyed strings into records (history becomes
  chartable). Reads migrate this pass: brief's yesterdayFeeling
  / yesterdaySat come from the store.
- Sign-out: one store drop + **add `day.dose.` to the legacy
  sweep (defect fix)**.
- Sync: own-row upsert like day_reflections; dose-kind rows
  NEVER appear in notification payloads or analytics (stigma
  floor, 01_RESEARCH §A4).

**3c. RegimenPlanRecord** (@Model in PlankSync +
`regimen_plans` table):
- Medication + supplement plans; shot-day anchor
  (`anchorWeekday`) is the field every engine reads
  (`dayInMedicationWeek`). Dose-day = checklist presence;
  check-off writes the check record (UI state) + a doseTaken
  observation (the chart).
- Supplements: one collapsed "supports" line at most — never
  co-equal rows (evidence law B8.3).

**3d. Protocol vocabulary on Home**: `medication` case joins
`ProgramDayPrescription` (SF-mark disc — no new sticker; the
founder's locked set has no medication asset); `water` revives
as **hydration** during titration/escalation weeks using the
founder's own locked `sticker_teacup`. Composition: medication
is the required top line on dose days (med + one keystone =
the non-negotiables; cap stands at ≤3 moves).

**3e. BrandVoice seam, CarePlanEngine only**: `Move.because`
strings render through a `BrandVoice` protocol (JeniVoice =
today's exact strings, snapshot-tested byte-identical). Brief/
review engines migrate later (named debt, not silent).

**3f. Served-protocol target** (S2 prep): `protocols` +
`protocol_items` tables (read-all RLS, jsonb payload — the
jenimethod_lessons pattern), seeded with `.default` serialized.
`org_id uuid NULL` marks the tenancy seam on protocols +
regimen_plans only. No organizations table yet (building
tenancy tables before the authz design would be schema theater
— 04_DECISIONS).

**3g. Additive migration**: one SQL file — `regimen_plans`,
`observations`, `protocols`, `protocol_items` + RLS + indexes.
Zero changes to existing tables.

## 4. What deliberately does NOT change (S1)

- PrescriptionEngineV2's beat existence math, targets math,
  cohort floors — they read constants FROM CareProtocol.default
  and behave identically.
- The founder-locked Home grammar (rows/stickers/check-off/
  rails/rings) — content evolves, form persists.
- Paywall/auth/sync mechanics; the safety gate; signals law.
- No clinic UI, no org accounts, no export surfaces, no
  minutes-ledger (S3), no FormTemplate (S3), no served
  hydration of CareProtocol (S2).

## 5. The ladder after S1

- **S2 protocol served**: app hydrates CareProtocol +
  protocol_items from rows (bundled fallback, jenimethod_lessons
  precedent); notifications/education/chat-prompt configs become
  rows; content atoms land (v7 method→interventions verdict).
- **S3 a human on the other end**: visit-prep packet (the PA
  evidence dossier, consumer-face first — 01_RESEARCH §A7.3),
  ConsentGrant, exports, FormTemplate/Response, escalation feed
  over CareEvents, minutes-ledger primitives.
- **S4 tenancy**: organizations + memberships + care teams,
  org-authored protocols, BrandVoice re-voicing, HIPAA/BAA
  program (non-app tracks gate this — 04_DECISIONS).

## 6. Testing law for the pass

326 existing tests stay green untouched. New suites:
CareProtocol equivalence (default == shipped literals),
regimen scheduling math (dose-day detection, week wrap, missed
week), ObservationStore (scoping, append-only, backfill,
sign-out drop, series queries), medication/hydration
composition (dose-day lead, titration gating, ask caps hold),
BrandVoice snapshot equality. UI legs run solo (chaining law).
