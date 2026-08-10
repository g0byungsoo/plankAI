# E1 — THE SPINE (the first implementation era of THE SYSTEM)

2026-08-10 · the detailed brief. Parent law: `00_THE_SYSTEM.md`
(§6-§8, §14, roadmap E1). Gaps closed: G1-G5, G11, T1, T3, T4
(`03_GAP_MAP.md`). Status: **brief only — execution starts on the
founder's word.**

## WHY THIS ERA FIRST

Every other era leans on it. The medicated year (E2) delivers its
cycle-day teaching through the weekly read; movement (E3) writes its
cadence into program facts; food intelligence (E4) needs the events
floor; the dispersal (E5) delivers atoms through the read; the queue
(E6) reads authority from the fact chains. And it attacks the two
measured product wounds directly: the W1→W2 retention collapse (the
ritual is the evidence's answer) and the "what should i do today"
promise (composition that visibly learns). The walk proved the
surfaces are already waiting for it (G-map: "the surfaces are ready;
the system behind them is missing").

## GOAL

One adaptive program with memory, authority, and consent; one weekly
ritual where it earns the right to change; one notification brain
with a hard budget; a telemetry floor that can prove any of it. No
new tabs, no visual reset — new composition inside shipped anatomy.

## USER PROBLEM

"i did the day. nothing learned from it." Targets never move (7,500
steps forever; a kcal number derived at onboarding); nothing reviews
her week; reminders come from five uncoordinated schedulers; and when
the program IS right, nothing can prove it. For the medicated user,
the week already has a spine (dose day) the product ignores.

## THE FIVE BUILDS

### B1 — program_facts (the memory)

- New model + table `program_facts`: append-only chain per kind.
  v1 kinds: `stepGoal` · `kcalTarget` · `proteinFloor` ·
  `weighCadence` · `loggingMode` · `notificationPosture` ·
  `walkTiming`. Fields: value (typed jsonb), **authority**
  (`prescribed|preferred|recommended|default`), **basis**
  (`measured|stated|inferred|assigned`), source
  (`onboarding|user|weekly_read|clinic|migration`), supersedes_id,
  accepted_at, created_at. The v24 supersede-never-mutate chokepoint
  pattern, generalized: ONE writer (`applyProgramFact`), same-day
  coalescing, never mutate.
- Bootstrap migration-moment: current derived targets are written
  once as `default`-authority heads (source `migration`) so day one
  is behavior-identical — equivalence-pinned in tests
  (TargetsService before == after).
- `TargetsService` + `CarePlanEngine` + StepsService read chain
  heads; render precedence prescribed › preferred › recommended ›
  default lands in ONE resolver with table tests. iOS writes
  `prescribed` NEVER (S4 law; that authority arrives via server in
  E6 — the enum + precedence are structural NOW so nothing forks
  later).
- Settings "my pace" edits write `preferred` facts (and Jeni stops
  recommending against a preferred fact — offer engine rule).

### B2 — THE WEEKLY READ (the ritual)

- **Anchor**: the morning after her dose day (regimen chains know
  it); no regimen → her chosen morning (default sunday). One read
  per week; late opens are fine (the read waits; it never expires
  into guilt).
- **Grammar** (editorial register, the consult's drawn-evidence
  craft): serif title ("your week, read") → the week vs HER OWN
  3-week average (ink trajectory + blush comparison — the becoming
  body-card grammar, one level up) → what the record shows (2-3
  floor-gated observations from existing engines; era-aware;
  timing-never-causality) → ONE teaching line that explains the
  strongest observation (hand-authored v1 set, ~12 lines; the atom
  engine arrives E5) → **THE OFFER** (≤1, from the closed set) →
  accept (one tap, consequence echoed: "your walking goal breathes
  down to 5,200 this week.") / "keep it as is" (equal-rank, recorded,
  2-week cooldown before the same offer returns).
- **The closed safe set v1** (each offer floor-gated + provenance-
  stamped): stepGoal recalc (percentile engine, B3) · weighCadence
  adjust · loggingMode lighten (photo-only / protein-only days —
  the day-29 décrescendo's first face) · notificationPosture
  (quieter/steadier) · walkTiming (post-meal window preference).
  proteinFloor NEVER offers downward below the clinical floor;
  kcalTarget never offers via the read in v1 (safety-suppression
  interactions stay manual/settings).
- **Placement**: Becoming's crown (above the scope bar the week it's
  unread; a quiet row after) + a Home knock on read morning (the
  day-chip area, not a checklist row — the read is a ritual, not a
  task) + one brain-admitted notification ("your week is read.
  one small thing to decide."). The sunday recap notification
  retires into it.
- **Sparse honesty**: a quiet week reads "a quiet week. the record
  has room." — floors unmet = no observations invented, offer may
  still fire (loggingMode lighten is the natural sparse-week offer).
  Unrecorded is not skipped, anywhere.
- ReSigningView's pace-change flow is absorbed: the read IS the
  consented-change surface; the becoming door remains as "change my
  pace" → settings-style preferred edits.

### B3 — adaptive steps + the walking action

- Goal engine: 60th percentile of her own last 9-10 recorded days
  (Adams recipe), floor 2,500 / ceiling 8,000, recomputed at each
  weekly read (offered, not silently applied — the FIRST offer most
  weeks), rounded to friendly 50s. Static 7,500 anchor dies behind
  the migration bootstrap (her current anchor becomes the default
  head until the first read).
- **The walking beat**: CarePlanEngine gains a `walk` beat kind —
  composed when the gap is real but within reach (gap ≤ ~40% of
  goal, afternoon+), rendered as the gap ("2,100 steps left ·
  a 20-minute walk"), auto-completing on goal cross (StepsService
  observer exists). Post-meal variant when a large meal logged
  60-120 min ago and walkTiming allows ("ten gentle minutes — it
  helps the meal sit"). Never on gentle days; dose-day collision
  rules table-tested; supports cap unchanged.
- **HealthKit workout absorption**: any HK workout ≥10 min today
  auto-completes the movement/walk beat quietly ("you already
  moved today"). Never ask for what iOS knows.
- Becoming steps tile + Home move instrument read the adaptive goal
  (the ring's denominator becomes the fact head).

### B4 — THE NOTIFICATION BRAIN

- One arbiter module owning ALL scheduling: existing planners become
  CANDIDATE SOURCES (medication, anchors, keeping-zone, winback,
  recap→read, milestone); the brain decides send/hold/drop against:
  the **hard budget** (≤5/wk total, medication reminders exempt as
  medical rhythm — the v24 carve-out encoded as law, with the
  BreakState rule: breaks pause everything EXCEPT medication) ·
  **priority** (medication › read › zone/support › re-engagement) ·
  **timing heuristics** (her wake window from sleep timing, her
  habitual logging hour, dose hour; quiet hours absolute) ·
  **per-category auto-silence** (5-7 consecutive ignores → category
  sleeps + a soft in-app card "i'll hold the reminders — turn them
  back on any time"; never a push about pushes).
- Every candidate carries its why-now / why-her / why-open triple in
  code (asserted in tests; logged categorically).
- **MRT floor**: per-user per-category holdout assignment (stable
  hash), send/open/ignore/action ledger (local + categorical
  analytics), volume-vs-optout watch. No new send types beyond the
  read; Live Activities/widgets stay E7.
- Day-2 consent gate, surgical pending-removal, replace-never-stack
  all survive as brain rules (table-tested).

### B5 — the telemetry floor

- Ship §14's medication + program + read + brain event families
  (dose_marked, reminder_action, regimen_created/superseded,
  side_effect_logged, era_transition; program_fact_changed,
  today_composed, action_completed, walking_goal_hit; weekly_read_*
  ; notif_* ledger). Hygiene law audited per event (counts/
  categoricals only — kind names, never values with units attached
  to a person; no medication names ever).
- Delete the orphaned constants (journey_*, trial_start, …) in the
  same change (dead-code law).
- North-star dashboards (PostHog): W1→W2 cohort curve · read
  open/accept · dose-resolution visibility · notification
  actioned-vs-volume.

## MODE + AUTHORITY IN THIS ERA

Consumer-complete. Clinic-connected users get the same read with
prescribed facts rendered as her clinician's plan (read-only rows,
the b2b regimen register — walk-verified grammar) and offers drafted
ONLY in unprescribed space; no new clinic writes until E6. The
authority enum, precedence resolver, and announcement rule (any
prescribed fact arriving = the existing reconciliation moment) ship
NOW so E6 changes data, not architecture.

## DATA CHANGES

- Additive migration `2026xxxx_v25_e1_program_spine.sql`:
  `program_facts` + `weekly_reads` (+ RLS own-row, typed upserts,
  hydrate steps). Local-first until applied (sync 404 grace,
  standing pattern). Founder applies with the still-open v24
  medication migration (ordered).
- Local notification ledger (UserDefaults/SwiftData, not synced).
- No changes to existing tables.

## NON-GOALS (hard walls)

No food/EF changes · no method/atom engine (12 hand lines only) ·
no strength content · no clinic dashboard work · no widgets/Live
Activities · no Home/Becoming visual redesign · no new tabs · no
kcal-target offers · no ML timing (heuristics only) · no daily
adaptation of targets (composition adapts days; facts change weekly,
consented).

## PHASES (the loop after every phase; one build per commit-batch)

- **P1** program_facts engine + bootstrap + resolver + TargetsService/
  StepsService head-reads. Gate: equivalence pins green (nothing
  visibly changes).
- **P2** adaptive step engine + walking/post-meal beats + HK workout
  absorption + instrument denominators. Gate: composition goldens +
  a seeded walk film of the beat appearing/completing.
- **P3** THE WEEKLY READ end-to-end (composer → surface → offer →
  consent write → becoming/home placement). Gate: read film (fresh ·
  rich-week · sparse-week · clinic-connected), XXXL floors, walker
  leg green on erased sim.
- **P4** THE BRAIN consolidation + budget/timing/auto-silence +
  read notification + holdouts. Gate: brain table tests + a device-
  believable notification walk on sim (actions fire through
  MedicationLog untouched).
- **P5** telemetry floor + orphan sweep + doors/tooling riders
  (below) + full-suite + evidence doc `01_EVIDENCE.md` opens.

Riders: fix T3 seed determinism (kcal drift is P1's bootstrap made
deterministic; document b2b seed precedence) · T4 pre-start tab
sanity check · new doors (below) · v4/v5 onboarding sweep rides P5
ONLY if green time allows; else it stays a named leftover.

## QA DOORS (new)

`--uitest-seed-weeks N` (N weeks of realistic program history — the
read needs a past) · `--uitest-open-weekly-read` ·
`--uitest-force-read-day` · `--uitest-walk-read` (a TRUE in-app film
driver — T1's lesson: walker-armed doors cannot film; this one
self-drives) · `--uitest-notif-preview <category>` ·
`--uitest-brain-ledger` (dump the arbiter's week to console).

## TESTS

- Chain units: supersede/coalesce/precedence/preferred-blocks-
  recommend/prescribed-untouchable (table-driven).
- Offer engine: draft rules per state, one-offer law, 2-week
  cooldown, decline respected, floor gates, sparse-week behavior.
- Composition goldens per cohort × mode × day-type (dose/gentle/
  sparse/goal-crossed) incl. walk-beat appearance + collisions.
- Step engine: percentile math, floor/ceiling, breathes-down,
  friendly rounding (pure, seeded).
- Brain: budget arbitration matrix, carve-outs (medication vs
  break), auto-silence thresholds, timing windows, holdout
  stability.
- Analytics: every new event against the hygiene law (a test
  enumerates payload keys against an allowlist).
- Walker legs: read ritual (seeded, erased sim) · notification
  action leg (existing MED_DOSE untouched) · pre-start tab sanity.
- Equivalence pins: TargetsService, CarePlanEngine day-one output.

## SUCCESS CRITERIA (measured, not claimed)

- weekly read open ≥60% of active weeks; offer accept ≥30%;
  decline+cooldown respected 100% (asserted).
- W1→W2 retention +5pp vs pre-era cohort (PostHog cohort compare).
- notification opt-out flat while actioned-rate rises; total volume
  ≤5/wk p95.
- zero un-consented fact changes — a telemetry assertion
  (program_fact_changed where source=weekly_read requires an
  accept event in the same session) AND a unit invariant.
- dose adherence finally visible (dose_marked flowing).
- the loop's own evidence: films of the read (4 states), the walking
  beat, the auto-silence card; XXXL walks; erased-sim legs green.

## RISKS + MITIGATIONS

- **Ritual fatigue** → the read never expires into debt, renders
  sparse honestly, and is one screen; measure open decay, not
  streaks.
- **Consent fatigue** → ≤1 offer, cooldowns, "keep as is" equal
  rank; if accept <10% after 4 weeks, offers get rarer (posture
  fact), never louder.
- **Brain regressions eating v24's reminder trust** → medication
  scheduling code path untouched; the brain wraps it as a source
  with an exempt lane; the v24 walker leg is the regression gate.
- **Scope creep toward E2-E5** → the non-goal wall above is the law;
  anything discovered lands in the ledger, not the era.

## FOUNDER GATES (opened by this era)

Apply the ordered migrations (v24 medication + e1 spine) · review
the closed safe set v1 · the read's voice pass (12 teaching lines +
offer copy) · device walk of the read + notification actions when
the era ships.
