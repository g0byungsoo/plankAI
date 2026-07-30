# app v8 — THE BUILD RECORD (running, 2026-07-28)

What shipped, commit by commit. QA evidence per phase; postponements
land in 04_DECISIONS, never silently.

## Phase 1 — the platform seam (SHIPPED)

- `CareProtocol` (`Program/CareProtocol.swift`): every clinical
  constant as one injectable Codable config; `.default` == shipped
  behavior; engines (`CarePlanEngine` / `TargetsService` /
  `PrescriptionEngineV2` / `BandModel`) take `careProtocol:`
  defaulting to `.default`. The one deliberate behavior change:
  the GLP-1 small-body protein floor now caps at the advisory-band
  value (50kg: 90g → 80g) — the panel's honesty fix, documented in
  04_DECISIONS.
- `BrandVoice` (`Program/BrandVoice.swift`): rules/voice split for
  CarePlanEngine's spoken reasons; `JeniVoice` = the shipped
  strings, byte-pinned by tests; an alternate voice rewords without
  touching a rule (tested).
- Tests: `CareProtocolTests` (13) — Codable round-trip, every seam
  injected, voice snapshot + alternate-voice proof, protein policy
  incl. small-body band compliance.

## Phase 2 — the chart + regimen records (SHIPPED)

- `ObservationRecord` + `RegimenPlanRecord` (PlankSync @Models,
  registered in the app container + the ONE shared test
  container). Observations: typed, userId-scoped, deterministic
  per-(kind, day) ids, `source` provenance; survive sign-out like
  weight logs; delete-account drops them.
- `ObservationStore` (`Program/ObservationStore.swift`): record /
  valueText / series / countMatching ("queasy 3 of the last 7" is
  now computable) / deleteSingular (same-day correction) /
  one-time legacy backfill (day.reflection · day.sit · day.dose ·
  day.note · plan.tonight histories become records) / deleteAll.
- Sync: `observations` + `regimen_plans` own-row tables +
  `protocols` / `protocol_items` read-all tables seeded with the
  serialized default (migration
  `20260728_app_v8_care_platform_foundation.sql`, additive only);
  upsert/hydrate pairs with the graceful-404 posture; hydrate
  ordering: reflections → observations → regimen → backfill.
- Defect fixes (audit-found): `day.dose.` joins the sign-out
  sweep (cross-account leak class); the dose mark is no longer
  write-only (read paths below).
- Tests: `ObservationStoreTests` (7) — upsert semantics, append
  kinds, scoping, aggregation window, backfill incl. the orphaned
  dose family + malformed-key skip + once-only flag, delete-all
  scoping.

## Phase 3 — medication first-class (SHIPPED pending QA reel)

- `RegimenService` (`Program/RegimenService.swift`): active-plan
  resolve, shot-day set/end, pure date math (ISO weekday, dose-day
  detection, `dayInMedicationWeek` 0-6, titration window vs
  CareProtocol.regimen).
- Composition: `CarePlanEngine.Input` gains `isDoseDay` +
  `titrationWindowActive` (resolved in `TodayStateService` from
  her regimen; absent plan = absent fields). Dose day: medication
  is the day's TOP LINE (config `doseDayLeads`), the prescription's
  keystone demotes to supporting[0] (med + one keystone = the
  non-negotiables), a GENTLE dose day composes to the dose alone.
  Titration window: hydration leads the invitations (never
  counted, `sticker_teacup` — the founder's own locked asset,
  revived) with the fluids-first reason.
- The row: `ProgramDayPrescription.medication` — quiet `pills`
  SF mark (no sticker exists in the locked set; clinical reads
  quieter), butter disc, "your medication · dose day — mark it
  when taken". Row tap opens HER REGIMEN (`RegimenSheet`: weekday
  hairline menu, remove path, privacy caption); the mark stays on
  the circle/hold — a dose is a deliberate tap, never a side
  effect of navigation. Check-off writes the check record + a
  `doseTaken` observation + the legacy key (evening pre-fill);
  retraction deletes the day's record.
- The evening close: dose "yes" marks the day's medication row
  kept; the ONE-TIME shot-day ask reveals after her first "yes"
  with no anchor (bare weekday words, two rows; re-offers on
  arrival while unanswered); "which day is your shot, usually?"
  → every engine reads it. The sit-check gains **"backed up"**
  (constipation was unrepresentable in three words — the most
  persistent GLP-1 complaint) and extends to the post-medication
  chapter; answers land as observations. Feeling / journal /
  tonight-plan writes dual-write (legacy key + observation);
  morning reads (`yesterdayFeeling`, `yesterdaySat`) go
  store-first with legacy fallback.
- Tests: `RegimenTests` (8) — ISO mapping, wrap math, titration
  boundaries, dose-day lead + demotion, gentle dose day,
  hydration invitation + caps, doseDayLeads config-off.

## Phase 4 — the language register pass (SHIPPED)

Audit verdict (full inventory ran as an agent sweep): the app was
already overwhelmingly in-register; violations clustered in two
systemic patterns, both fixed:
- **The verb law lands (D9):** every in-app food ASK now says
  **add** ("add a meal", "add your first plate", "add it") —
  17 sites across Today/Becoming/chat/food-rail/DailyBrief;
  "snap" survives only as the camera feature's name; the four
  weight "log" leaks became **weigh in**; "scan" retired
  (labels renamed to snap).
- **The founder-steer file:** `JKSignalVisuals` broke both
  steers in one shared Kit — "sweetness" → **sugar intake**,
  "fasting since / hours fasted / you fasted" → **overnight
  fast** noun forms (+ the same family in Becoming pages).
- Also: 12 em-dashes-between-words → periods/commas (incl. one
  in the new RegimenSheet); "in a deficit" → "running lower";
  "calorie burn" → "energy use"; out-burn/burns lesson titles
  re-verbed; "unlock everything" → "open"; "wild part" →
  "surprising part"; "melt fat" myth line re-grounded; "same
  vibe" → "same rhythm"; "scanned plate" → "kept plate".

Deliberately NOT changed: onboarding sites (founder-gated —
listed for Stage A in 06_ONBOARDING); "logged" as a past-tense
STATUS label (data-language, not an ask — 11 sites kept);
negated banned words ("nothing to earn", "not a deficit") —
they are the anti-shame reframes the register wants; one
composed "vibe" fragment in QuickAdd (structural, queued).
Hard counts after the pass: user-facing "AI" 0 · drug brand
names 0 · crush/shred 0 · em-dash-between-words ~1 (legacy
onboarding, gated). Suite green.

## Phase 5 — the founder refinements (2026-07-28, second brief)

Two research lanes (clinician assignment reality; medication
visual register), then surgical implementation — full entries in
04_DECISIONS FR1-FR6:

- **Authority (FR1):** `authority` "self"|"care_team" +
  rxnorm/strength reconciliation seams on RegimenPlanRecord +
  sync + additive migration `20260728_2_regimen_authority_seams
  .sql` (safe pre/post base migration); `isManagedByCareTeam`
  mutation guards (patient never silently edits a clinician
  plan); dose/sit observations stamp regimenId. Tests: managed
  plans refuse edits, authority enum alone locks, self plans
  stay editable.
- **Bridge (FR2):** settings door — "your medication" row in
  the program section (value = her shot day), opening the same
  RegimenSheet; reconciliation moment spec'd for S3.
- **Register (FR4):** clinical disc (hairline outline + ink
  glyph, no fill), "your dose day" voice line, timestamp-as-
  reward ("taken · 8:04 pm"), pen-tick haptic, rose off every
  medication surface (ink-contrast selection), heartless sit
  acks, privacy line once in the sheet, MarkAsDoneSheet
  medication grammar fixed. Warm surfaces untouched.
- **Row meaning (FR5):** cadence weigh-in + demoted keystone
  speak their reasons (BrandVoice: weighInCadence,
  keystoneProteinAnchor).
- **Supports (FR3):** deliberately unchanged — no empty state
  exists; reasoning recorded.

## Phase 6 — think from the clinic first (2026-07-29, third brief)

One research lane (clinician dashboards + the supports layer),
then documentation-weighted refinement — entries FR7-FR9:
- `07_CLINIC_MIRROR.md` — the standing clinician↔patient mirror:
  the ladder mapped to objects, the render-rule audit, the
  monitor-side S3 anchors (status tokens, exception queue,
  alert-budget law, the guardrail sentence).
- `CareProtocol.supports: [SupportItem]` — the clinician-authored
  adjunct seam (consumer default empty; S3 renders one attributed
  observational line; pill-check rows banned by evidence). Seed
  updated. Suite green (Codable equivalence covers the field).
- FR9 verified the care-not-feature lens structurally; no code
  needed.

## Phase 7 — S2: the protocol is served (2026-07-29, migrations live)

Founder applied both migrations; verified end-to-end same session:
- **Live sync proven**: the seeded regimen row's `pendingUpsert`
  flipped 0 on-device (flips only after a successful server round
  trip) — `regimen_plans`/`observations` writes land.
- **CareProtocolStore** (enum service, house idiom): EVERY launch
  fetches `protocols.id=jenifit.default` → decode → the clinical
  sanity gate whole-or-reject → cache (last-good, cold-start
  bootstrap) → `CareProtocolStore.current`; TodayStateService +
  TargetsService compose from it. Bundled `.default` is the
  permanent floor. Tolerant decoding: additive fields
  (`supports`) decodeIfPresent — an older served row never fails
  whole (tested).
- **Verified live**: `careProtocol.served.v1` cache present
  on-sim after launch against the founder's row. 362/362 tests.
- **Crash found + fixed en route**: isolated-class deinit aborts
  in the concurrency runtime's back-deploy shim on the iOS 26.2
  sim (all tests pass, runner dies — zero failing cases). The
  store is instance-free by design; gotcha recorded in memory.
- The white-label mechanism is now LIVE mechanics: a clinic =
  a different protocols row through the same resolver.

## Phase 8 — Stage A onboarding SHIPPED (2026-07-29)

Per 08_STAGE_A.md exactly; v5's tested mechanics untouched.
- **The contract** lands at arrival ("your care plan, made around
  real days"; antiShame + credibility carry it); the verb law
  reaches v5's asks; the reveal speaks the plan: "your first week
  of care" + causal rails — the current-cohort reveal carries the
  PLAIN clinical line "medication rhythm · <her day>s anchor the
  week" only when she picked one. The credible 5-7% milestone
  joins the credibility strip (educational, no promise).
- **Two beats on the tested machine**: `shotDay` (current branch
  only — the flow's ONE clinical screen: serif weekday hairlines,
  ink selection, privacy caption, first-class skip; walker frame
  09 caught a missing content inset, fixed same session) and
  `supports` (all branches, warm multi-list after dietary; "jeni
  recommends nothing here — skip freely"; CSV intake fact, no
  records, no daily UI). `OnboardingContext` typed clinic seam
  (dormant, unreferenced).
- **Handoff**: completion routes a picked day through the
  authority-guarded `setShotDay` (care_team-untouchable,
  duplicate-safe; skip/no-med writes nothing → no phantom
  medication state). New keys ride the `onb_v5_` sweep. Privacy
  audit: shot day + supports live in defaults + (shot day only)
  the self regimen; never in notifications/analytics payloads.
- **Rider**: 8 canonical mirror keys (onboarding_dietary,
  medication_status, goal_direction, stop_window,
  appetite_return, fear_offramp, fear_regain,
  medicalDisclaimerAckAtISO) joined the explicit sign-out sweep —
  a pre-existing leak-class gap the anchors pass surfaced.
- **Tests**: first-ever OV5 router unit coverage (10 tests:
  fork chains w/ + w/o the new beats, cohort isolation of
  shotDay, store persistence/resume, word→ISO, act membership).
  370/370 green. Walker legs re-run per cohort.
- **Walker hygiene laws learned (recorded)**: a persisted sandbox
  entitlement flips the phase machine to the expired wall
  MID-ONBOARDING on long-lived QA sims (erase before walker
  sessions); SpringBoard nags occlude taps (the walker now
  installs a system-alert interruption monitor); cohort env must
  be passed as `TEST_RUNNER_GLP1_COHORT` (xcodebuild strips
  unprefixed vars — the code reads GLP1_COHORT). A leg that
  "succeeds" while walking the void is detectable by MISSING
  cascades — read the manifest, then the frames.

## Phase 9 — S3: the visit-prep packet SHIPPED (2026-07-29)

Per 09_S3_PACKET.md. The packet is a deterministic 28-day
projection over the chart — no AI, valid offline, every line
traceable:
- **Engine**: adherence (scheduled-from-anchor overlap ·
  taken/skipped/unrecorded, "unrecorded is not skipped"), weight
  (counts always; direction word only past the trend floor),
  sit-check aggregates (timing notes at ≥2 qualifying records,
  never causation), protein consistency (≥5 logged days),
  movement, honest gap lines, bounded question rules (insert
  once, tombstoned removal, hers editable). **F1 resolved in
  code**: self-reported → "your weekly medication" (name never
  leaks — tested); care_team → assigned facts when present.
- **Consent seam**: ConsentGrantRecord + ConsentService
  (explicit, scoped, revocable, audit pair, INACTIVE by default,
  durable upsert; migration `20260729_s3_consent_grants.sql` —
  founder must apply). Nothing is delivered anywhere; the share
  sheet is her manual act on a file.
- **UI**: one entry (becoming's visitPrep page) → the packet
  sheet in the clinical register; editable questions; consent
  line + sheet; share-as-pdf (ImageRenderer print view:
  patient-entered vs summarized labeled, date range, no internal
  ids, no stickers). QA door `--uitest-open-visit-packet`.
- **Verified**: 381/381 (11 packet + consent tests first-run
  green: F1 leak, adherence arithmetic, timing law, tombstones,
  lifecycle, account isolation); on-sim capture checked
  line-by-line against seeded records (self-reported label,
  wednesdays anchor, 0-of-1 scheduled honesty, lb display,
  easing trend).
- **Named, not built**: connected clinic delivery (needs a real
  authenticated recipient + the FR2 reconciliation moment),
  consent hydrate-on-connect, visit-date field, multi-page PDF
  pagination, VoiceOver/dynamic-type deep pass (queued with the
  next QA reel).

## Phase 10 — S4: the first real clinic loop SHIPPED (2026-07-29)

Per `10_S4_CLINIC_LOOP.md`; decisions S4-1..S4-10 in 04. One
legitimate clinic actor connects to one consenting patient, reads
her canonical record, assigns care, and that exact care becomes her
lived daily plan — provenance preserved, consent explicit, isolation
server-enforced, access reversible. Built vertically A→E.

- **Server (migration `20260729180000_s4_clinic_loop.sql`, additive,
  live)**: organizations · org_members (owner/clinician/staff) ·
  patient_invitations (peppered-hash, single-use, 72h, throttled) ·
  care_relationships · consent_grants (+lookback + org scope) ·
  protocol_assignments · correction_requests · care_audit_events
  (append-only, trigger-guarded) · visit_packets. `private` helper
  schema (definer, pinned search_path). Clinician touches of patient
  data are RPC-ONLY (Postgres has no SELECT triggers → the RPC
  chokepoint is the only honest disclosure audit); patient charts
  carry no direct clinician policies. F1 masking is a server
  projection (self displayName never leaves the device). The FR1
  client guards became server law (regimen/consent/protocol policies
  tightened). Migration ledger normalized to timestamped versions;
  founder's three prior migrations repaired into the ledger.
- **Clinician dashboard** (`clinic/`, Vite+React+TS, Supabase-direct
  under the publishable key + RLS, every action an S4 RPC, no
  service-role, strict CSP, zero analytics): five screens — sign-in ·
  roster · patient detail (relationship + consent + canonical S3
  packet + assigned care + corrections + review) · assign sheets
  (protocol + mg-only regimen) · clinic (members + invitations).
  Clinical-editorial register, theme-aware, keyboard-navigable,
  narrow-viewport safe.
- **Patient side** (through the EXISTING runtime, no clinic Home):
  CareConnectionService (RPC wrappers) + connection/consent sheets
  (three scope toggles + 4-week/today lookback chooser + the
  mandatory not-monitored consent line; revoke from the same
  surface); care-team regimen hydrates server-authoritative and
  composes as the dose-day lead; RegimenSheet's read-only care-team
  face + correction door; the FR2 reconciliation moment (confirm
  retires the self plan, history intact, and joins future dose marks
  to the care-team id; "something's off" flags + opens the
  correction sheet, plan still composing); CorrectionSheet (164.526
  shape, never mutates); CareProtocolStore resolves a clinician
  assignment with default fallback; VisitPacketPublisher serializes
  the S3 packet to consented orgs; settings "your care team" door.
- **Revocation**: prospective + access-only — server denies further
  clinic reads/writes immediately, the published packet copy is
  removed, but observations, provenance, audit, and the assigned
  regimen's ACTIVE clinical status all survive (access ≠ treatment).
- **Verified**:
  - `scripts/s4_security_probe.py` — 62 live checks (isolation,
    invitation lifecycle incl. 5-min expiry, throttle, F1 masking,
    forgeries, scopes, corrections, disabled member, revocation,
    append-only audit). All green against the dev project.
  - Playwright E2E (`clinic/e2e/loop.spec.ts`) — sign in → roster →
    detail → assign regimen → server-side verify. Green.
  - `CareLoopTests` (15 iOS units): resolver-prefers-care-team,
    reconciliation machine incl. history preservation + flagged,
    F1-leak-through-packet, dose-join provenance, wire shape, RPC
    decode. **396/396** (381 prior unchanged + 15).
  - **Live on-sim E2E (§26, 20/20)**: the sim's real anon user
    connected to a live clinic, the clinician assigned care over the
    server, and it hydrated as the sim's Today dose lead (semaglutide
    0.5mg wednesdays); reconciliation → self plan retired → correction
    → clinician resolved (0.5→1.0mg) → revoke → server-side denial →
    full ordered audit chain → no duplicate active regimen → org-null
    control unchanged. Direct DB inspection confirmed provenance.
  - Design/frame audit: dashboard light+dark, focus ring visible,
    zero console errors, no pops/clipping/stale-data flashes; fixed a
    back-nav roster spinner flash (App-level cache) + narrow-viewport
    body overflow (media queries). Reconciliation sheet a11y-clean at
    accessibility-XXXL Dynamic Type.
- **QA doors (DEBUG)**: `--uitest-care-connect-code CODE` (real
  accept as the sim user), `--uitest-care-refresh`,
  `--uitest-care-auto-confirm`, `--uitest-care-submit-correction CAT`,
  `--uitest-care-revoke`, `--uitest-suppress-reconcile`,
  `--uitest-open-care-connect`, `--uitest-open-regimen`. The
  `--uitest-inapp-qa` determinism wipe now preserves care-team plans
  (server-authoritative).
- **Named, not built (§15/§29)**: e-prescribing/pharmacy; billing
  minutes ledger; staff drafts-pending-signature; FormTemplate
  intake; clinic BrandVoice; push; messaging; multi-clinic-per-
  patient; packet versions; protocol composer; population analytics;
  @supabase/ssr cookie sessions; org self-serve onboarding.
- **Honest boundary (§16)**: internal dev alpha, test data only, no
  BAA — never "HIPAA compliant"; a real clinic pilot gates on
  BAA + security-rule posture + breach process.

## Held in this phase (04_DECISIONS)

- Supplements UI: per D7 supplements are one collapsed optional
  line — lands with the language pass; RegimenPlanRecord already
  models them.
- Dose-day softening in the brief (day-1-2 fluid-first lines,
  day-5-7 hunger-return normalization) — the anchor now exists;
  the brief cascade is its own guarded pass.
- Sit-check ↔ medication-week correlation lines ("queasy has
  landed the two days after your shot") — needs 2+ weeks of
  observations; engine next pass.
