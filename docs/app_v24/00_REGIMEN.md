# APP v24 — THE REGIMEN
### the medication experience, reborn as a platform (2026-08-09)

**This document is the era's law.** `01_EVIDENCE.md` is THE LOOP's
record. Where this doc is silent, standing law holds: the design law
(`docs/design/00_JENI_DESIGN_LANGUAGE.md`), the v8 care platform +
clinical register (`docs/app_v8/`), the module contract
(`docs/app_v22/00_ONE_HAND.md`), and the v9 mission laws.

---

## §0 THE BRIEF (founder, 2026-08-09)

Study MeAgain and Shotsy deeply. Do not copy them. Then redesign the
entire medication experience so it belongs inside Jeni.

- **Jeni is NOT becoming another GLP-1 tracker.** Jeni is still a
  beautiful weight-loss coach. Medication is simply another piece of
  today's journey. The product philosophy remains: **Today. Jeni.
  Becoming.** Medication quietly fits inside that world. Never
  dominates it.
- **Two users.** B2B: a clinician prescribes; the patient should NOT
  configure — she confirms today's dose. Manual creation exists but
  feels rare. B2C: the onboarding already asks about GLP-1; NO keeps
  medication completely hidden (Settings can enable later); YES
  expands onboarding naturally.
- **Flexible medication model** — Ozempic, Wegovy, Mounjaro, Zepbound,
  Rybelsus, compounded semaglutide/tirzepatide, future medications,
  oral GLP-1s, future pills and injections — architecture never
  requires redesign when a new medication appears.
- **Medication is not static.** Dose/frequency/medication/schedule/
  time all change. Dose history, medication history, skip, missed,
  early, notes, clinician comments (future). **Everything historically
  correct. Never overwrite history.**
- **Home:** today's checklist includes "take today's shot" / "take
  today's pill" only when appropriate. Completed items disappear into
  today's history; missed items become gentle reminders.
- **Notifications:** weekly + daily + custom time, travel/timezones,
  snooze/taken/skip/log-later with almost no friction.
- **Patterns:** medication is only valuable connected to behavior —
  food, protein, fiber, water, steps, weight, photos, waist, sleep,
  mood, side effects, energy, coach. "Oh. This nausea happened after
  the dose increase." This is where Jeni wins.
- **Design:** warm paper, cream, ink, rose accents, editorial
  typography, minimal, Apple-quality, gender neutral. Medical enough
  to inspire trust, lifestyle enough to avoid feeling clinical.
- **Architecture like Apple:** system-first. Medication becomes a
  platform; future modules plug in naturally.

## §1 WHAT THE CATEGORY TAUGHT

63 MeAgain frames + 9 Shotsy frames studied end-to-end (onboarding →
home → logging → history → settings → paywall → widgets).

### 1.1 MeAgain (the maximal instrument)

What it does well — mechanics worth understanding:

- **The interview asks the right facts** and every question carries an
  escape hatch: journey stage ("already on" / "about to start") →
  medication (one flat list; syringe/glass icons carry the route;
  compounded first-class; "I haven't decided yet") → starting dose
  (chips; "you can edit this at any time") → frequency (every day / 7
  / 14 / custom / "not sure, still figuring it out") → **which weekday
  cravings hit hardest** → shot day timed so the medication's peak
  covers her hardest day. That last move is the smartest thing in the
  app: it turns a scheduling chore into a plan that serves HER week.
- **Site memory**: the shot log remembers "Stomach – Upper Left"; a
  small figure with a dot marks the spot on the Dose tab.
- **The dose tab vocabulary**: last dose (value + timestamp) · next
  dose (date + countdown ring) · injection site · side-effects prompt
  ("did you notice any side effects today?") · dose settings (5 rows:
  medication/schedule/dosage/location/reminder time).
- **Pharmacokinetic "Medication Level"** is their hero: an estimated
  mg-in-body decay curve (7d/30d/90d/1y), FDA-label-cited, heavily
  disclaimed, plus a home-screen widget. It makes the invisible
  visible — the emotional job is "it's still working between shots."
- **Notification pre-prompt** before the system dialog; widgets as a
  retention surface; medication features (graph, shot-day checklist)
  sit in the FREE tier — medication is the hook, food/chat is the
  paywall.

What Jeni rejects:

- **A medication dashboard.** Dose is a TAB — the app's center of
  gravity. In Jeni, medication composes into the day; it never owns a
  surface of its own on Home.
- **Fabricated persuasion.** "3x more effectively," "82% reported
  better outcomes," a fake-review rating gate, degenerate computed
  copy ("Losing **0 lbs** might feel overwhelming—but it's very
  realistic," a goal timeline reading 207 → 206.4 by next August).
  Jeni's honesty and data-provenance laws make every one of these
  impossible.
- **The slider wall.** Six 0–10 sliders on one screen is a medical
  intake form, not a gentle log.
- **The permission grab.** Forty HealthKit toggles before value.
- **The register.** Purple SaaS + capybara gamification + "dream
  weight." Charming for them; not Jeni.

### 1.2 Shotsy (the focused instrument)

What it does well:

- **The dose-annotated weight curve.** Weight trajectory segmented by
  dose era — grey 2.5mg → purple 5mg → teal 7.5mg → pink 10mg → blue
  12.5mg → red 15mg — with dose badges pinned to the curve. The
  single best visualization in the category: it answers "is this
  working" and "what did the dose change actually do" in one glance.
- **Shot day is one tap.** The Summary leads with "It's shot day!" +
  [Mark as taken]. No form. Friction ≈ zero.
- **Dose chips wear the pen's color** (0.25 teal, 0.5 pink, 1.0
  brown, 1.7 blue, 2.4 navy — the physical Wegovy pens). She
  recognizes her dose by the color in her fridge. Tactile-memory
  design.
- **Projection honesty**: the estimate curve draws the past solid and
  the future dashed, "(est.)" everywhere, "Jump to Today."
- **The two-question door**: "already taking / haven't started" +
  "do you already have a prescription?" — the whole triage in one
  screen. Route (Injection / Pill / Not sure) is its own beat.
- **Widgets carry the ritual**: a "You did it!" post-shot widget and
  the estimate curve on the home screen.

What Jeni rejects: the rainbow gauge + eight color themes (a toy
register), stat-grid results (Cal AI voice), tab-per-concern IA
(Summary/Shots/Results/Calendar — four dashboards for one weekly
event).

### 1.3 The reading

Both products sell **control through instrumentation**. Jeni sells
**understanding through composition**. The category's real lessons:
ask few questions with escape hatches; remember the site; make shot
day one tap; keep history per dose era; time the shot to her life;
speak estimates honestly. Jeni takes the lessons, not the surfaces.

## §2 THE THESIS

**Medication is a rhythm inside her day, not a product inside the
app.** One weekly (or daily) beat, kept honestly, explained gently,
connected to everything else she already logs.

1. **Today leads.** On dose day, the checklist gains one clinical row.
   Marking it is the whole ceremony. No tab, no dashboard, no gauge.
2. **The clinical register holds** (v8 FR2, unchanged): medication
   surfaces are unadorned ink — outline disc, ink glyph, no sticker,
   no rose, no celebration. The timestamp is the only reward
   ("taken · 8:04 pm"). Pen-tick haptic. Everything AROUND the row
   stays warm; the row itself is quiet and precise. Medical enough to
   trust; the warmth lives in the surrounding day.
3. **Becoming explains.** The medication tile renders the dose-era
   weight read (the category's best idea, in paper+ink) and WHAT
   FOLLOWS THE DOSE — floor-gated pattern observations in
   timing-never-causality grammar ("nausea has followed your last
   three dose days" — an observation about timing, never a claim of
   cause, never advice).
4. **Jeni understands.** The coach envelope knows dose day, the day
   after, the current dose, recent side effects — and mentions
   medication only when relevant.
5. **The platform is invisible.** Catalog + versioned regimen +
   dose events + observations. New medication = new catalog row.
   Nothing is overwritten, ever.

## §3 THE MODEL (never overwrite history)

Four layers, each append-only where it matters:

### 3.1 MedicationCatalog (static, versioned data — not user data)

`MedicationProduct`: id (stable string, e.g. `ozempic`,
`compounded-semaglutide`), display name, compound
(semaglutide/tirzepatide/liraglutide/dulaglutide/other), **route**
(injection/oral), **cadence default** (weekly/daily), dose ladder
(ordered mg steps for pickers — never a cap; custom always allowed),
unit (mg), flags (`compounded`, `emptyStomachGuidance` for oral
semaglutide), guidance strings. Plus `other` (freeform name,
either route) — the founder's "manual medication creation," present
but never the lead. **Adding Retatrutide-when-it-ships = one catalog
entry.** The catalog is code (versioned, testable), not a server
dependency; a future served catalog can override by id.

### 3.2 Regimen (versioned; EVOLVES `RegimenPlanRecord`, keeps its law)

The v8 `RegimenPlanRecord` (PlankSync `Models.swift:670`, table
`regimen_plans`) is the seed — we extend it ADDITIVELY, never fork:

- **existing fields keep their meaning**: `kind`, `displayName`,
  `scheduleRule` (`weeklyAnchor`/`daily`/`asNeeded`),
  `anchorWeekday`, `timeOfDayMinutes` (now actually used — the
  reminder hour), `doseStageLabel`, `instruction`, `startedAt`/
  `endedAt`, `reminderEnabled`, `authority` (`self`|`care_team` —
  iOS writes `self` ONLY, RLS enforces), `rxnormCode`,
  `strengthValue`/`strengthUnit`, `sourceProtocolId`/`orgId`.
- **new additive fields** (optional, lightweight-migrating):
  `productId: String?` (catalog ref; nil = pre-v24 or freeform),
  `route: String?` (`injection`/`oral`),
  `previousPlanId: String?` (the version chain),
  `endReason: String?` (`dose_changed` / `medication_changed` /
  `schedule_changed` / `paused` / `ended` / `care_team_assigned`).
- **`strengthValue`/`strengthUnit` open to self-declared doses**
  (v8 reserved them for the clinic bridge): the picker writes label
  strengths SHE declares; the app still never authors dose advice.
  The F1 packet masking for self-reported plans is untouched.
- **A change = end the current row (`endedAt`, `endReason`) + insert
  a new row with `previousPlanId` pointing back.** The chain IS the
  medication history. `activeMedicationPlan` (endedAt == nil)
  keeps working unchanged; dose events stamp the exact version.
- **displayName law evolves, carefully**: v24 renders medication
  names on surfaces SHE reads (dose sheet, regimen home — the
  care-team face already did). The hard floors stand: **never in
  notification payloads, never in analytics** ("your shot", "your
  dose" — the RegimenSheet privacy line survives verbatim).

### 3.3 DoseEventRecord (new PlankSync model + `dose_events` table)

One row per scheduled-or-logged dose. Deterministic id
`"\(userId.lowercased())-dose-\(dayKey)"` (the ObservationStore
discipline) so the checklist quick-mark, THE DOSE SHEET, the evening
ask and a notification action all converge on ONE row (one active
medication regimen at a time is the v1 contract — the existing
`activeMedicationPlan` singular). Fields: `regimenPlanId`
(provenance: the version in force) · `dayKey` + `scheduledAt` ·
**`status`** (`taken` / `skipped` / `missed` / `pending`) ·
`takenAt` (the actual timestamp — early and late doses stay honest:
we record what happened; the schedule stays what was planned) ·
`site` (nullable; 6 canonical sites) · `note` · `skipReason`
(traveling / out of medication / clinician paused / just didn't) ·
`source` (`checklist` / `sheet` / `notification` / `evening` /
`migration`). Missed is DERIVED (a past slot with no mark), stamped
lazily, reversible by a late log — "missed" never scolds; it becomes
"log it late" language.

**Dual-write stands**: marking still records the `.doseTaken`
observation (regimen-stamped) — the care packet, evening pre-fill
and legacy day keys keep reading it. The DoseEventRecord is the
rich record; the observation is the care-chart projection.

### 3.4 Side effects → ObservationStore (extended, not duplicated)

Side effects are observations (v8's chart), not a new store: kind
`symptom`, typed payload (symptom: nausea / constipation / loose
stomach / fatigue / headache / reflux / site tenderness / appetite
gone / appetite back / custom(text); severity: `aTouch` /
`noticeable` / `rough`; note). Deterministic per-day-per-symptom ids;
dual visibility with the care packet's symptom section (S3's
timing-never-causality law already governs rendering).

## §4 THE ENGINE (pure, tested, UI-free)

- **MedicationScheduleEngine** — from (regimen versions, dose events,
  now, timezone): today's beat (due / taken / none — the checklist
  asks this), next due date+time, the late window (weekly: the dose
  stays markable until the next one is due; daily: until midnight),
  missed derivation, what-happens-on-change (a dose change today
  re-anchors from today, never rewrites yesterday). **Local
  wall-clock anchoring**: "Tuesday 8pm" means Tuesday 8pm wherever
  she wakes up — travel doesn't move her shot day; the planner
  re-schedules on significant time change. DST-safe by construction
  (wall-clock components, never epoch math on anchors).
- **SiteRotationAdvisor** — 6 canonical sites (left/right abdomen,
  left/right thigh, left/right arm). Suggests the least-recently-used
  site favoring the mirror of last time; never insists. One sentence
  of why, once: rotation keeps the skin comfortable.
- **MedicationNotificationPlanner** — pure planning of
  UNNotificationRequests from the active regimen: weekly shot at her
  time; daily pill at her time (oral-semaglutide copy speaks the
  empty-stomach rhythm gently); a single gentle next-morning line if
  yesterday's dose went unmarked ("yesterday's shot is still open —
  log it late, or let it go."). Category actions: **taken** (marks,
  with site = suggestion default) · **snooze 1h** · **log later**
  (opens the sheet) — skip lives in the sheet, not the lock screen
  (a lock-screen "skip" is an accident magnet; "log later" is the
  no-pressure door). Surgical pending-removal (the daily_reminder
  discipline); consent-gated (day-2 law); respects the weekly
  ceiling by replacing, never stacking.
- **MedicationPatternEngine** — day-offset joins over the chart:
  for each signal (symptom observations, protein vs floor, water,
  weight momentum, sleep, steps, energy words), its distribution on
  D0/D+1/D+2 vs baseline. Emits floor-gated observations (≥3
  co-occurrences, ≥3 weeks of data) in R6 grammar, timing-never-
  causality, anti-shame (never "you always feel sick"; always "the
  day after your shot has run quieter on appetite — protein earns
  its floor harder that day"). Consumed by Becoming's detail page
  and the coach envelope. **The nausea-after-dose-increase sentence
  is this engine's proof case.**

## §5 THE SURFACES

1. **TODAY — the row** (exists since v8; re-grounded on the engine):
   dose day composes "mark today's dose" as a lead or support beat
   (CarePlanEngine already decides); pills compose daily at her hour.
   Clinical register. Done = compresses into the day's history with
   its timestamp, like every kept beat. Unmarked by evening = the
   evening ask (exists); unmarked by next morning = one gentle line.
2. **THE DOSE SHEET** (rebuilt): everything already known is already
   filled — her medication name, the dose, the day. What it asks:
   site (six quiet cells, the suggested one pre-ringed, "left thigh
   last time"), optional note. One button: **mark it**. Pen-tick,
   timestamp lands, sheet closes. "not today" sits quiet under the
   button → skipped (+optional reason chip). Late logging = the same
   sheet from the book/regimen home ("log it late"). B2B: a
   provenance line under the title — "assigned by your care team ·
   confirm what you took."
3. **THE REGIMEN — her medication's home** (Settings "your
   medication" door + long-press on the row): the current facts
   (medication · dose · rhythm · next dose · reminder), the history
   ledger (era seams: "0.25 mg · aug – sep"), the change doors
   (dose / day & time / medication / switch route / pause / end —
   each writes a new version; the sheet says so: "your history
   stays"), reminders toggle+time, the side-effect logger door, the
   privacy line (once: local-first, synced to her account, shared
   with a clinic only through the care loop's consent). B2B: facts
   are read-only with the care-team face + correction door (S4);
   only reminders + site memory stay hers.
4. **BECOMING — the tile** (clinical, renders only when a regimen
   exists): face = current dose + the last weeks as quiet dots
   (kept/skipped/missed as filled/open/absent — adherence without
   the word "adherence"). Detail page: **THE DOSE ERAS** — her
   weight trajectory with hairline seams where the dose changed
   (ink line, blush wash, tiny ink era labels; the category's best
   idea in Jeni's hand) · WHAT FOLLOWS THE DOSE (pattern engine
   observations, ≤3, floor-gated) · the dose ledger · provenance
   ("computed from your marks and your weigh-ins — estimates say
   so").
5. **ONBOARDING — the consult beats** (§7).
6. **SETTINGS**: the existing "your medication" door points at THE
   REGIMEN. No regimen + B2C = "add your medication" sits quietly in
   settings (the founder's later-enable path); nothing else in the
   app mentions medication.
7. **NOTIFICATIONS** (§4 planner). All copy in the notification
   voice law: her data, no shame, no streaks.
8. **CHAT**: the envelope gains medication facts (current regimen,
   dose day flags, day-after flag, last 7 days of symptom
   observations, adherence-this-month coarse). The EF prompt gains
   one rule: never raise medication unless she does or the day makes
   it relevant (dose day, day after, a logged symptom).

## §6 B2B / B2C — ONE MODULE, COMPOSED (v22 contract)

Same models, same engine, same sheets. Composition differs:

| | B2C self | B2B care_team |
|---|---|---|
| regimen source | onboarding beats / regimen home | clinic loop assignment (S4) |
| can edit facts | yes (new versions) | no — correction door (164.526 shape) |
| confirm moment | — | FR2 reconciliation (exists) — confirm retires the self plan, history intact |
| today's row | engine-driven | engine-driven (identical) |
| reminders/site/notes | hers | hers |
| onboarding | medication beats | clinic door → skip all medication beats |
| manual creation | the normal path | exists (rare): "add something your clinic hasn't set" → authority=self alongside |

Guardrails already in law: iOS never writes authority=care_team;
care_team regimens are mutation-guarded; dose events stamp the
regimen version so clinician changes never rewrite her past.

## §7 ONBOARDING — THE CONSULT BEATS

The consult already asks the GLP-1 question (cohort). NO → nothing
medication-shaped ever renders (unchanged). Clinic door → zero
medication beats (the clinician decides; her regimen arrives at
connect). **YES, current** → four beats in the consult's register
(plain, everyday, clinic-safe; every beat has an out):

1. **the route** — "shots, or pills?" (shots / pills / not sure yet)
2. **the medication** — list for her route from the catalog
   (compounded first-class; "something else" freeform; "not sure
   yet" keeps going)
3. **the dose** — her medication's ladder as quiet ink chips +
   "custom" + "not sure" ("your pen knows. you can fix it any
   time.")
4. **the rhythm** — shot day + hour (or pill hour) + "remind me"
   yes/no. Default suggestion: today's weekday if she took one this
   week, else the most common pattern language ("most people pick
   the day they'll be home").

**YES, about to start** → beats 1–2 + starting dose (ladder's first
steps lead) + "first shot day, if you know it" (skippable) — the
regimen starts `pending` until the first mark. MeAgain's
cravings-day timing question is acknowledged as smart and NOT taken:
one more question for a benefit the coach can deliver later from her
actual data ("your hardest day looks like Friday — a Saturday shot
would cover it. want to move it?" — a pattern-engine observation,
opt-in, once floors are met).

Completion writes ONE regimen version (authority=self) through the
engine + schedules reminders if consented. The reveal's
medication-rhythm rail (Stage A) now reads from the regimen.

*Supersession note:* the v8 router's "ONE cohort question — regimen
depth lives post-purchase" decision is superseded by this brief for
the CURRENT cohort only (2026-08-09). Every other cohort still gets
exactly one question. `V8Input.weekday(skip:)` — wired but
unclaimed since v8 — finally gets its beat.

## §8 COMPLIANCE + PRIVACY

- **Observed, never prescribed**: the app reminds of HER schedule and
  reflects label-level guidance in plain words (oral semaglutide:
  water, then a quiet half hour). It never advises doses, never says
  "take it now," never computes catch-up medical advice. Missed-dose
  copy is "log it late, or let it go" — recording, not directing.
- **Brand names in-app are product function** (her regimen), never
  marketing claims; ASO/marketing floors (glp1 strategy doc)
  untouched. ® on first render of a brand name in a picker, plain
  text after.
- **No numeric weight-loss claims, no equivalence claims** — the
  dose-era read shows HER curve, provenance-stamped.
- **Analytics**: categorical only (route, compound class, action,
  source) — never dose values, never symptom notes, never sites.
- **Sync**: user-scoped rows under RLS like every entity; side
  effects ride observations; clinician visibility ONLY through the
  S3/S4 consent machinery (nothing new leaks).
- **The photo question**: the founder's shot-log sketch listed an
  optional photo. Deferred deliberately — a site photo pushes the
  log toward a medical record (against "not medical, not scary"),
  and body photography in Jeni lives behind the body-privacy laws
  (local-first, backup-off). Queued as an open question with this
  reasoning; a note field ships.

## §9 MIGRATION (no data loss, no re-onboarding)

- Existing `RegimenPlanRecord` rows ARE version 1 — no rewrite
  needed (new fields are nil; `productId` nil renders as "your
  medication"; she can name it from the regimen home any time).
  All v8 resolvers (`activeMedicationPlan`,
  `isManagedByCareTeam`, `setShotDay` semantics) keep working;
  `setShotDay` learns to version instead of mutate.
- Historic `.doseTaken` observations + `day.dose.` keys remain the
  truth for pre-v24 days; the history ledger and dose-era read
  consume them via a read-through (observation → synthesized event
  view, source `migration`) so history predates the new store
  honestly. New days write both (dual-write law, §3.3).
- The dead Stage-A bridge (`PlankAIApp` reading `onb_v5_shot_day`,
  which v8 never writes) is replaced by the consult beats writing a
  full regimen at completion.
- New `onb_med_*` mirror keys join `--uitest-fresh-onboarding` +
  the sign-out sweep like every onboarding key.
- Supabase: additive migration only
  (`20260809_v24_medication_platform.sql`: `dose_events` table
  own-row RLS + `regimen_plans` additive columns `product_id`,
  `route`, `previous_plan_id`, `end_reason`); **founder applies**;
  sync 404s gracefully local-first until then (the v8 discipline).

## §10 TESTING STRATEGY

- **Engine (pure)**: schedule derivation across weekly/daily/everyN;
  late window edges; missed derivation + late-log reversal; timezone
  jump (NYC→Seoul), DST both directions; dose-change mid-week
  re-anchor; version chain integrity (no mutation of superseded
  versions); rotation advisor cycle + mirror preference; planner
  request diffs (surgical removal, no stacking); pattern engine
  floors (no observation below n=3), offset joins, grammar pins.
- **Stores**: deterministic ids converge (checklist + evening +
  notification action = one row); userId scoping; sign-out sweep.
- **Migration**: v8 plan → version 1 equivalence; legacy dose marks
  visible in history.
- **UI legs (solo, erased sim)**: consult beats per branch (current
  injectable / current oral / about-to-start / clinic skip / NO
  stays clean); dose-day Today mark via sheet; skip; oral daily;
  regimen change writes an era; becoming tile + detail render.
- **Doors**: `--uitest-seed-medication <injectable|oral|b2b|history>`
  (seeded regimen + weeks of events + observations),
  `--uitest-dose-day` (forces today), `--uitest-walk-medication`
  (self-driving film tour).

## §11 KNOWN TRADEOFFS (decided, documented)

1. **No pharmacokinetic curve in v1.** The category's hero mechanic
   fails Jeni's data-provenance law (every number traces to a
   collected field — a modeled mg-in-body is not collected) and
   drags the register toward instrumentation. The dose-era weight
   read answers the same emotional question ("is it working") from
   HER data. Revisit only as a founder call.
2. **No cravings-day question in onboarding** — the coach earns the
   same insight from data later (§7).
3. **No lock-screen "skip" action** — accident magnet; skip lives in
   the sheet with reasons.
4. **No site photo** (§8). **No pain slider** — site tenderness is a
   symptom chip, not a 0–10 scale.
5. **Side effects are chips, not sliders** — three severities, not
   eleven points; the care packet keeps its own clinical projection.
6. **No medication tab/dashboard** — permanently. The regimen home
   is a settings-anchored sheet, not a tab.
7. **Widgets deferred** — the category proves their power (Shotsy's
   post-shot widget); Jeni has no widget infrastructure yet; queued
   as its own future pass (`§13`).

## §12 ANALYTICS (categorical, honest)

`med_regimen_created {route, compound, authority, source}` ·
`med_regimen_changed {field: dose|day|time|medication|pause|end}` ·
`med_dose_marked {status, source, route}` ·
`med_symptom_logged {symptom, severity}` ·
`med_reminder_actioned {action}` ·
`med_becoming_detail_viewed`. No dose values, no notes, no sites,
no timestamps beyond PostHog's own.

## §13 PROPAGATION MAP + QUEUE

Touched this era: CarePlanEngine dose beat (re-grounded) · evening
dose ask (parity) · onboarding v8 consult (new beats) · settings
door · becoming tiles registry · chat envelope · notification
planner. Queued beyond: widgets pass · clinician comments surface
(S4-deferred messaging) · served catalog overrides · the
cravings-day steer (pattern-engine, floors met) · device walk.

## §14 DECISION LEDGER

- **D1 the name**: the era is THE REGIMEN; the user-facing noun is
  "your medication" (never "regimen" in copy — clinic-safe plain
  words).
- **D2 register**: clinical register (v8 FR2) governs every
  medication surface; warmth lives around, not on, the row.
- **D3 model**: catalog is code; regimens are versions; dose events
  are append-only; side effects are observations. Nothing user-
  entered is ever overwritten — supersede, don't mutate.
- **D4 the row's verbs** (v8 verb law): "mark today's dose" /
  "take today's shot" surfaces per composition; timestamps are the
  reward.
- **D5 missed is gentle**: derived, reversible, "log it late, or
  let it go."
- **D6 oral is its own experience**: daily rhythm, morning language,
  empty-stomach guidance for oral semaglutide (label-level, plain),
  water glyph, no injection vocabulary anywhere.
- **D7 rotation suggests, never insists.**
- **D8 B2B confirm-only** (FR2 exists): the patient's only
  configuration is site memory, notes, reminders.
- **D9 patterns speak timing, never causality**, floor-gated ≥3.
- **D10 escape hatches everywhere** in onboarding beats ("not sure
  yet" always continues).
